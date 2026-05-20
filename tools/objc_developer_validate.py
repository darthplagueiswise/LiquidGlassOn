#!/usr/bin/env python3
import sys, os, struct, re, json
from collections import defaultdict
import lief
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM

SEL_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_:]{0,240}$')
def looks(s): return bool(s) and bool(SEL_RE.match(s))

class MachOObjC:
    def __init__(self,path):
        self.path=path
        fat=lief.MachO.parse(path)
        self.b=fat.at(0) if hasattr(fat,'at') else fat
        self.base=getattr(self.b,'imagebase',0) or 0
        self.segs=[]; self.sections={}
        for seg in self.b.segments:
            data=bytes(seg.content)
            self.segs.append((seg.virtual_address, seg.virtual_address+seg.virtual_size, data, seg.name))
            for sect in seg.sections:
                self.sections[sect.name]=(sect.virtual_address, sect.virtual_address+sect.size, bytes(sect.content))
        self.segs.sort(key=lambda x:x[0]); self._last=0; self.class_cache={}
        # binding by address
        self.binding_by_addr={}
        try:
            for bind in self.b.bindings:
                try:
                    sym=bind.symbol.name if bind.has_symbol else None
                    lib=bind.library.name if bind.has_library else None
                    self.binding_by_addr[bind.address]=(sym,lib)
                except Exception:
                    pass
        except Exception: pass
    def find_seg(self,va):
        i=self._last
        if 0<=i<len(self.segs):
            s,e,d,n=self.segs[i]
            if s<=va<e: return s,e,d,n
        for j,(s,e,d,n) in enumerate(self.segs):
            if s<=va<e: self._last=j; return s,e,d,n
        return None,None,None,None
    def in_img(self,va): return self.find_seg(va)[2] is not None
    def read(self,va,n):
        s,e,d,name=self.find_seg(va)
        if d is None: return None
        off=va-s
        if off<0 or off+n>len(d): return None
        return d[off:off+n]
    def u64(self,va):
        b=self.read(va,8); return struct.unpack('<Q',b)[0] if b and len(b)==8 else None
    def cstr(self,va,maxlen=600):
        s,e,d,name=self.find_seg(va)
        if d is None: return None
        off=va-s; end=min(off+maxlen,len(d)); null=d.find(b'\0',off,end)
        if null<0: return None
        return d[off:null].decode('utf-8','ignore')
    def decode(self,p):
        if not p: return None
        if (p>>63)&1: return None
        if self.in_img(p): return p
        cand=(self.base or 0)+(p & 0xffffffff)
        if self.in_img(cand): return cand
        cand=p & 0xffffffff
        if self.in_img(cand): return cand
        return None
    def class_name_at(self,cls_va):
        if not cls_va: return None
        if cls_va in self.class_cache: return self.class_cache[cls_va]
        cs=self.read(cls_va,40)
        if not cs or len(cs)<40: return None
        data_ptr=struct.unpack('<QQQQQ',cs)[4]
        data=self.decode(data_ptr)
        if not data: return None
        data &= ~0x7
        ro=self.read(data,80)
        if not ro or len(ro)<40: return None
        name_ptr=struct.unpack('<Q',ro[24:32])[0]
        name=self.cstr(self.decode(name_ptr),400) if self.decode(name_ptr) else None
        self.class_cache[cls_va]=name
        return name
    def method_list(self,list_va):
        if not list_va: return []
        h=self.read(list_va,8)
        if not h or len(h)<8: return []
        flags,count=struct.unpack('<II',h)
        if count==0 or count>10000: return []
        rel=bool(flags & 0x80000000); entsize=flags & 0xffff
        if entsize<12 or entsize>64: return []
        out=[]
        for i in range(count):
            entry=list_va+8+i*entsize
            e=self.read(entry,entsize)
            if not e or len(e)<min(entsize,12): break
            sel=None; imp=None
            if rel:
                no,to,io=struct.unpack('<iii',e[:12])
                s=self.cstr(entry+no,300)
                if looks(s): sel=s
                imp=(entry+8)+io
                if not self.in_img(imp): imp=entry+io
                if not self.in_img(imp): imp=None
            else:
                sp,tp,ip=struct.unpack('<QQQ',e[:24])
                d=self.decode(sp); s=self.cstr(d,300) if d else None
                if looks(s): sel=s
                imp=self.decode(ip)
            if sel: out.append((sel,imp))
        return out
    def class_method_list_va(self,cls_va, meta=False):
        if not cls_va: return None
        target=cls_va
        if meta:
            isa=self.u64(cls_va); target=self.decode(isa)
            if not target: return None
        cs=self.read(target,40)
        if not cs or len(cs)<40: return None
        data_ptr=struct.unpack('<QQQQQ',cs)[4]
        data=self.decode(data_ptr)
        if not data: return None
        data &= ~0x7
        ro=self.read(data,80)
        if not ro or len(ro)<40: return None
        ml_ptr=struct.unpack('<Q',ro[32:40])[0]
        return self.decode(ml_ptr)
    def iter_classes(self):
        sec=self.sections.get('__objc_classlist')
        if not sec: return
        _,_,data=sec
        for i in range(len(data)//8):
            ptr=struct.unpack_from('<Q',data,i*8)[0]
            va=self.decode(ptr)
            if va:
                name=self.class_name_at(va)
                if name: yield va,name
    def iter_categories(self):
        sec=self.sections.get('__objc_catlist')
        if not sec: return
        va0,_,data=sec
        for i in range(len(data)//8):
            ptr=struct.unpack_from('<Q',data,i*8)[0]
            cat_va=self.decode(ptr)
            if not cat_va: continue
            body=self.read(cat_va,56)
            if not body or len(body)<56: continue
            name_ptr,cls_ptr,inst_ptr,cls_m_ptr,protos,inst_props,cls_props=struct.unpack('<QQQQQQQ',body)
            cat_name=self.cstr(self.decode(name_ptr),400) if self.decode(name_ptr) else None
            cls_va=self.decode(cls_ptr); cls_name=self.class_name_at(cls_va) if cls_va else None
            if not cls_name:
                sym=self.binding_by_addr.get(cat_va+8)
                cls_name=f'<bind:{hex(cls_ptr)} {sym[0] if sym else "?"} {sym[1] if sym else "?"}>'
            yield cat_va,cat_name,cls_name,self.decode(inst_ptr),self.decode(cls_m_ptr),cls_ptr
    def disasm(self,va,count=12):
        if not va: return []
        code=self.read(va,4*count)
        if not code: return []
        md=Cs(CS_ARCH_ARM64, CS_MODE_ARM); md.detail=False
        return [f'0x{i.address:x}: {i.mnemonic}\t{i.op_str}' for i in md.disasm(code,va)]

def run(path):
    o=MachOObjC(path)
    classes=list(o.iter_classes())
    clsmap={name:va for va,name in classes}
    wanted=['isDebugMenuAllowed','isDebugMenuShortcutEnabled','presentDebugControllerIfNeeded','debugViewController','debugShortcutContainerView','appDidFinishLaunchingSetup','resolveDebugMenuProviding','debugMenuProvider','isVerifiedChannelFeatureFlagEnabled','isInternalUser','isMetaEmployeeOrInternalTester','is_meta_employee_or_internal_tester','boolForKey:defaultValue:','stringForKey:defaultValue:','integerForKey:defaultValue:','doubleForKey:defaultValue:','isEnabled','isUserEligible','isSettingsRowEnabled','isKillSwitchActive']
    res={'file':os.path.basename(path),'base':hex(o.base),'class_count':len(classes),'category_count':sum(1 for _ in o.iter_categories()),'classes':{},'base_hits':[],'category_hits':[],'target_category_methods':[],'disassembly':{}}
    check=['WAContextMain','WASettingsViewController','WASettingsNavigationController','WADebugViewController','_TtC15WADebugMenuMain17DebugMenuProvider','WAFeatureControlGateKeeper','WAServerProperties','WAABProperties','FOAWAABPropertiesImpl','WAAuraGating','WACustomBehaviorsTableView','MobileConfigGating']
    for c in check: res['classes'][c]=c in clsmap
    # base inst and class method hits for wanted
    for name,va in [(n,clsmap[n]) for n in clsmap]:
        for meta in [False,True]:
            ml=o.class_method_list_va(va,meta=meta)
            for sel,imp in o.method_list(ml):
                if sel in wanted:
                    res['base_hits'].append({'class':name,'kind':'+' if meta else '-','selector':sel,'imp':hex(imp) if imp else None})
                    if len(res['disassembly'])<30 and imp:
                        res['disassembly'][f'{os.path.basename(path)} {"+" if meta else "-"}[{name} {sel}]']=o.disasm(imp,10)
    for cat_va,cat,cls,inst_va,cls_va,raw in o.iter_categories():
        inst=o.method_list(inst_va) if inst_va else []
        cm=o.method_list(cls_va) if cls_va else []
        selected=[]
        for sel,imp in inst:
            if sel in wanted:
                res['category_hits'].append({'class':cls,'category':cat,'kind':'-','selector':sel,'imp':hex(imp) if imp else None})
                selected.append(('-',sel,imp))
        for sel,imp in cm:
            if sel in wanted:
                res['category_hits'].append({'class':cls,'category':cat,'kind':'+','selector':sel,'imp':hex(imp) if imp else None})
                selected.append(('+',sel,imp))
        if cat and ('WADebugMenu' in cat or 'WADependencyProvider' in cat):
            res['target_category_methods'].append({'class':cls,'category':cat,'inst':[s for s,_ in inst],'class_methods':[s for s,_ in cm]})
        for kind,sel,imp in selected:
            if imp:
                res['disassembly'][f'{os.path.basename(path)} {kind}[{cls}({cat}) {sel}]']=o.disasm(imp,12)
    return res

if __name__=='__main__':
    allres=[run(p) for p in sys.argv[1:]]
    print(json.dumps(allres,indent=2,ensure_ascii=False))
