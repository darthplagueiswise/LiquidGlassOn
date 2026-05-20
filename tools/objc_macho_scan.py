#!/usr/bin/env python3
import lief, struct, re, sys, json, os, traceback
from collections import defaultdict

SEL_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_:]{0,240}$')

def looks_like_selector(s):
    return bool(s) and bool(SEL_RE.match(s))

class ObjCScan:
    def __init__(self,path):
        self.path=path
        fat=lief.MachO.parse(path)
        self.binary=fat.at(0) if hasattr(fat,'at') else fat
        self.base = getattr(self.binary,'imagebase',0) or 0
        self.segments=[]
        self.sections={}
        for seg in self.binary.segments:
            va=seg.virtual_address; size=seg.virtual_size
            # content can be expensive, convert once
            data=bytes(seg.content)
            self.segments.append((va, va+size, data, seg.name))
            for sect in seg.sections:
                self.sections[sect.name]=(sect.virtual_address, sect.virtual_address+sect.size, bytes(sect.content))
        self.segments.sort(key=lambda x:x[0])
        self._last=0
        self.class_cache={}
    def find_seg(self,va):
        i=self._last
        if 0<=i<len(self.segments):
            s,e,d,n=self.segments[i]
            if s<=va<e: return s,e,d,n
        for j,(s,e,d,n) in enumerate(self.segments):
            if s<=va<e:
                self._last=j; return s,e,d,n
        return None,None,None,None
    def in_image(self,va):
        return self.find_seg(va)[2] is not None
    def read_bytes(self,va,size):
        s,e,d,n=self.find_seg(va)
        if d is None: return None
        off=va-s
        if off<0 or off+size>len(d): return None
        return d[off:off+size]
    def read_u64(self,va):
        b=self.read_bytes(va,8)
        return struct.unpack('<Q',b)[0] if b and len(b)==8 else None
    def read_cstr(self,va,maxlen=600):
        s,e,d,n=self.find_seg(va)
        if d is None: return None
        off=va-s
        end=min(off+maxlen,len(d))
        null=d.find(b'\x00',off,end)
        if null<0: return None
        try: return d[off:null].decode('utf-8','ignore')
        except: return None
    def decode_ptr(self,p):
        if not p: return None
        # binds/auth high bits: ignore if top bit set
        if (p>>63)&1: return None
        # Direct VA?
        if self.in_image(p): return p
        # Chained target as low 32-bit offset + image base
        cand=(self.base or 0)+(p & 0xffffffff)
        if self.in_image(cand): return cand
        # For dylibs with base 0, low32 itself
        cand=(p & 0xffffffff)
        if self.in_image(cand): return cand
        return None
    def methname_range_contains(self,va):
        r=self.sections.get('__objc_methname')
        return r and r[0]<=va<r[1]
    def parse_method_list(self,list_va):
        if not list_va: return []
        hdr=self.read_bytes(list_va,8)
        if not hdr or len(hdr)<8: return []
        entsize_flags,count=struct.unpack('<II',hdr)
        if count==0 or count>10000: return []
        is_relative=bool(entsize_flags & 0x80000000)
        entsize=entsize_flags & 0xffff
        if entsize < 12 or entsize>64: return []
        sels=[]
        for i in range(count):
            entry_va=list_va+8+i*entsize
            e=self.read_bytes(entry_va,entsize)
            if not e or len(e)<min(entsize,12): break
            sel=None
            if is_relative:
                off=struct.unpack('<i',e[:4])[0]
                # In relative method lists, name is usually direct rel32 to cstring
                cva=entry_va+off
                ss=self.read_cstr(cva,300)
                if looks_like_selector(ss): sel=ss
                if sel is None:
                    # fallback: offset points to a slot containing chained ptr
                    ptr=self.read_u64(cva)
                    if ptr:
                        d=self.decode_ptr(ptr)
                        ss=self.read_cstr(d,300) if d else None
                        if looks_like_selector(ss): sel=ss
            else:
                ptr=struct.unpack('<Q',e[:8])[0]
                d=self.decode_ptr(ptr)
                ss=self.read_cstr(d,300) if d else None
                if looks_like_selector(ss): sel=ss
            if sel: sels.append(sel)
        return sels
    def parse_method_list_with_meta(self,list_va):
        # returns (sel, imp_va) where possible
        if not list_va: return []
        hdr=self.read_bytes(list_va,8)
        if not hdr or len(hdr)<8: return []
        entsize_flags,count=struct.unpack('<II',hdr)
        if count==0 or count>10000: return []
        is_relative=bool(entsize_flags & 0x80000000)
        entsize=entsize_flags & 0xffff
        if entsize < 12 or entsize>64: return []
        out=[]
        for i in range(count):
            entry_va=list_va+8+i*entsize
            e=self.read_bytes(entry_va,entsize)
            if not e or len(e)<min(entsize,12): break
            sel=None; imp_va=None
            if is_relative:
                name_off,types_off,imp_off=struct.unpack('<iii',e[:12])
                cva=entry_va+name_off
                ss=self.read_cstr(cva,300)
                if looks_like_selector(ss): sel=ss
                imp_va=entry_va+8+imp_off  # usually relative to field address? rough
                if not self.in_image(imp_va): imp_va=entry_va+imp_off
                if not self.in_image(imp_va): imp_va=None
            else:
                sptr,tptr,iptr=struct.unpack('<QQQ',e[:24])
                d=self.decode_ptr(sptr)
                ss=self.read_cstr(d,300) if d else None
                if looks_like_selector(ss): sel=ss
                imp_va=self.decode_ptr(iptr)
            if sel: out.append((sel,imp_va))
        return out
    def class_name_at(self,cls_va):
        if not cls_va: return None
        if cls_va in self.class_cache: return self.class_cache[cls_va]
        cs=self.read_bytes(cls_va,40)
        if not cs or len(cs)<40: return None
        vals=struct.unpack('<QQQQQ',cs)
        data_ptr=vals[4]
        data_va=self.decode_ptr(data_ptr)
        if not data_va: return None
        data_va &= ~0x7
        ro=self.read_bytes(data_va,80)
        if not ro or len(ro)<40: return None
        # class_ro name ptr at offset 24
        name_ptr=struct.unpack('<Q',ro[24:32])[0]
        name_va=self.decode_ptr(name_ptr)
        name=self.read_cstr(name_va,400) if name_va else None
        self.class_cache[cls_va]=name
        return name
    def class_base_methods(self,cls_va):
        cs=self.read_bytes(cls_va,40)
        if not cs or len(cs)<40: return []
        data_ptr=struct.unpack('<QQQQQ',cs)[4]
        data_va=self.decode_ptr(data_ptr)
        if not data_va: return []
        data_va &= ~0x7
        ro=self.read_bytes(data_va,80)
        if not ro or len(ro)<40: return []
        base_methods_ptr=struct.unpack('<Q',ro[32:40])[0]
        base_methods_va=self.decode_ptr(base_methods_ptr)
        return self.parse_method_list(base_methods_va)
    def iter_classlist(self):
        sec=self.sections.get('__objc_classlist')
        if not sec: return []
        va0,va1,data=sec
        n=len(data)//8
        for i in range(n):
            ptr=struct.unpack_from('<Q',data,i*8)[0]
            cls_va=self.decode_ptr(ptr)
            if cls_va:
                name=self.class_name_at(cls_va)
                if name: yield cls_va,name
    def iter_catlist(self):
        sec=self.sections.get('__objc_catlist')
        if not sec: return []
        va0,va1,data=sec
        n=len(data)//8
        for i in range(n):
            ptr=struct.unpack_from('<Q',data,i*8)[0]
            cat_va=self.decode_ptr(ptr)
            if not cat_va: continue
            body=self.read_bytes(cat_va,56)
            if not body or len(body)<56: continue
            name_ptr,cls_ptr,inst_ptr,cls_m_ptr,protos,inst_props,cls_props=struct.unpack('<QQQQQQQ',body)
            cat_name=self.read_cstr(self.decode_ptr(name_ptr),400) if self.decode_ptr(name_ptr) else None
            cls_va=self.decode_ptr(cls_ptr)
            cls_name=self.class_name_at(cls_va) if cls_va else None
            if not cls_name:
                cls_name=f'<bind:{hex(cls_ptr)}>'
            inst_va=self.decode_ptr(inst_ptr)
            class_va=self.decode_ptr(cls_m_ptr)
            yield cat_name,cls_name,inst_va,class_va,cls_ptr

def scan(path, wanted):
    o=ObjCScan(path)
    print('\n===== FILE', os.path.basename(path), 'base', hex(o.base), '=====')
    classes=list(o.iter_classlist())
    print('classes', len(classes), 'categories', sum(1 for _ in o.iter_catlist()))
    # class presence
    for cn in ['WAContextMain','WASettingsViewController','WASettingsNavigationController','WAFeatureControlGateKeeper','WAABProperties','FOAWAABPropertiesImpl','WAAuraGating','WADebugViewController','_TtC15WADebugMenuMain17DebugMenuProvider','WAServerProperties','WACustomBehaviorsTableView','WAMobileConfigGating','MobileConfigGating']:
        print(' class?', cn, any(name==cn for _,name in classes))
    # owner hits base
    base_hits=[]
    for cls_va,name in classes:
        sels=o.class_base_methods(cls_va)
        for sel in sels:
            if sel in wanted or any(sel.lower().find(w.lower())>=0 for w in []):
                base_hits.append((name,sel,'base-inst?'))
    print('\nBase method hits:')
    for h in sorted(set(base_hits)): print(' ',h)
    # category hits
    cat_hits=[]
    target_cats=[]
    for cat,cls,inst_va,cls_va,raw_cls in o.iter_catlist():
        inst=o.parse_method_list(inst_va) if inst_va else []
        clss=o.parse_method_list(cls_va) if cls_va else []
        for sel in inst:
            if sel in wanted: cat_hits.append((cls,cat,'-',sel))
        for sel in clss:
            if sel in wanted: cat_hits.append((cls,cat,'+',sel))
        if cat and any(x in cat for x in ['WADebugMenu','WADependencyProvider','DebugMenu']):
            target_cats.append((cls,cat,inst,clss,raw_cls))
    print('\nCategory wanted hits:')
    for h in sorted(set(cat_hits)): print(' ',h)
    print('\nTarget category full lists:')
    for cls,cat,inst,clss,raw in target_cats:
        print('---',cls,'('+str(cat)+')','raw_cls',hex(raw))
        print('  inst',len(inst), sorted(set(inst))[:80])
        print('  class',len(clss), sorted(set(clss))[:80])
    return o

wanted={
    'isDebugMenuAllowed','isDebugMenuShortcutEnabled','enableDebugMenu','setEnableDebugMenu:',
    'isInternalUser','isMetaEmployeeOrInternalTester','is_meta_employee_or_internal_tester',
    'isDebugBuild','isTestFlightApp','isBetaOrMoreVerbose','graphQLEmployeeC1Disabled',
    'debugMenuProvider','setDebugMenuProvider:','resolveDebugMenuProviding',
    'isVerifiedChannelFeatureFlagEnabled',
    'boolForKey:defaultValue:','stringForKey:defaultValue:','integerForKey:defaultValue:','doubleForKey:defaultValue:',
    'isEnabled','isUserEligible','isSettingsRowEnabled','isKillSwitchActive',
}
if __name__=='__main__':
    for path in sys.argv[1:]:
        scan(path,wanted)
