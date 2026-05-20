// WAGRSurfaceBrowserVC.m — Ryukgram-style. Groups by class/prefix. UISwitch only.
#import "WAGRSurfaceBrowserVC.h"
#import "../WAGramPrefix.h"
#import "../Runtime/WAGRSurface.h"
#import <objc/runtime.h>
extern BOOL WAGRInstallHookForEntry(WAGREntry *e);
static const void *kEntryKey = &kEntryKey;

// ── Dark Ryuk-style palette ──────────────────────────────────────────────────
static UIColor *RBG(void)  { return [UIColor colorWithRed:.010 green:.010 blue:.012 alpha:1]; }
static UIColor *RCELL(void){ return [UIColor colorWithRed:.120 green:.120 blue:.130 alpha:1]; }
static UIColor *RACC(void) { return [UIColor colorWithRed:.23 green:.51 blue:.96 alpha:1]; }
static UIColor *RGRN(void) { return [UIColor colorWithRed:.2  green:.78 blue:.35 alpha:1]; }
static UIColor *RRED(void) { return [UIColor colorWithRed:.95 green:.23 blue:.21 alpha:1]; }
static UIColor *RSUB(void) { return [UIColor colorWithWhite:.58 alpha:1]; }
static UIColor *RSEP(void) { return [UIColor colorWithWhite:.22 alpha:1]; }

@interface WAGRSurfaceBrowserVC () <UISearchResultsUpdating>
@property(nonatomic,strong) WAGRSurfaceSpec *spec;
@property(nonatomic,strong) NSArray<WAGREntry*> *all;
@property(nonatomic,strong) NSArray<NSString*> *sectionKeys;
@property(nonatomic,strong) NSDictionary<NSString*,NSArray<WAGREntry*>*> *byClass;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,assign) BOOL hasScanned;
@end

static NSString *WAGRFeatureName(WAGREntry *e) {
    NSString *n = e.displayName.length ? e.displayName : e.selectorName;
    if (!n.length) return @"";
    while ([n hasPrefix:@"@property "]) n = [n substringFromIndex:10];
    while ([n hasPrefix:@"@prop "]) n = [n substringFromIndex:6];
    while ([n hasPrefix:@"- "] || [n hasPrefix:@"+ "]) n = [n substringFromIndex:2];
    return n;
}

static NSString *WAGRPrefixSectionForName(NSString *name) {
    if (!name.length) return @"Other";
    NSString *n = name;
    NSCharacterSet *seps = [NSCharacterSet characterSetWithCharactersInString:@"_-.:"];
    NSRange r = [n rangeOfCharacterFromSet:seps];
    NSString *p = (r.location != NSNotFound && r.location > 0) ? [n substringToIndex:r.location] : nil;
    if (!p.length) {
        NSMutableString *m = [NSMutableString string];
        for (NSUInteger i = 0; i < n.length; i++) {
            unichar c = [n characterAtIndex:i];
            if (i > 0 && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c]) break;
            if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:c]) [m appendFormat:@"%C", c];
        }
        p = m.length ? m : @"Other";
    }
    return p.length ? p.lowercaseString : @"Other";
}

static NSString *WAGRSectionForEntry(WAGRSurfaceSpec *spec, WAGREntry *e) {
    if ([spec.surfaceID isEqualToString:@"bundle_general"]) return WAGRPrefixSectionForName(WAGRFeatureName(e));
    return e.className.length ? e.className : @"Other";
}

@implementation WAGRSurfaceBrowserVC
- (instancetype)initWithSpec:(WAGRSurfaceSpec*)spec {
    if(!(self=[super initWithStyle:UITableViewStyleInsetGrouped]))return nil;
    _spec=spec; _all=@[]; _byClass=@{}; _sectionKeys=@[];
    self.title=spec.title; return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=RBG();
    self.tableView.backgroundColor=RBG();
    self.tableView.backgroundView=[UIView new];
    self.tableView.backgroundView.backgroundColor=RBG();
    self.tableView.rowHeight=UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight=76;
    self.tableView.separatorColor=RSEP();
    self.tableView.separatorInset=UIEdgeInsetsMake(0,16,0,16);
    _search=[[UISearchController alloc]initWithSearchResultsController:nil];
    _search.searchResultsUpdater=self;
    _search.obscuresBackgroundDuringPresentation=NO;
    _search.searchBar.placeholder=@"Buscar feature / classe";
    _search.searchBar.tintColor=RACC();
    self.navigationItem.searchController=_search;
    self.navigationItem.hidesSearchBarWhenScrolling=NO;
    UIBarButtonItem *scan=[[UIBarButtonItem alloc]initWithTitle:@"Scan"
        style:UIBarButtonItemStylePlain target:self action:@selector(scan)];
    scan.tintColor=RACC();
    UIBarButtonItem *reset=[[UIBarButtonItem alloc]initWithImage:
        [UIImage systemImageNamed:@"arrow.counterclockwise"]
        style:UIBarButtonItemStylePlain target:self action:@selector(resetAll)];
    reset.tintColor=RRED();
    self.navigationItem.rightBarButtonItems=@[scan,reset];
}
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    self.navigationController.navigationBar.prefersLargeTitles=NO;
    self.view.backgroundColor=RBG();
    self.tableView.backgroundColor=RBG();
}
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    if(!_hasScanned)[self scan];
}
- (void)scan {
    _hasScanned=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSArray<WAGREntry*>*entries=[WAGRScanner scanSurface:self.spec];
        entries=[entries sortedArrayUsingComparator:^NSComparisonResult(WAGREntry*a,WAGREntry*b){
            NSString *sa = WAGRSectionForEntry(self.spec, a);
            NSString *sb = WAGRSectionForEntry(self.spec, b);
            NSComparisonResult r=[sa localizedCaseInsensitiveCompare:sb];
            if(r!=NSOrderedSame)return r;
            BOOL ha=WAGRHasOverride(a.overrideKey),hb=WAGRHasOverride(b.overrideKey);
            if(ha&&!hb)return NSOrderedAscending;
            if(!ha&&hb)return NSOrderedDescending;
            return [WAGRFeatureName(a) localizedCaseInsensitiveCompare:WAGRFeatureName(b)];
        }];
        dispatch_async(dispatch_get_main_queue(),^{
            self.all=entries;
            [self applyFilter:self.search.searchBar.text];
        });
    });
}
- (void)applyFilter:(NSString*)q {
    NSArray<WAGREntry*>*base=q.length
        ?[_all filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WAGREntry*e,NSDictionary*_){
            NSString*hay=[NSString stringWithFormat:@"%@ %@ %@",e.className,WAGRFeatureName(e),e.category].lowercaseString;
            return [hay containsString:q.lowercaseString];
        }]]
        :_all;
    NSMutableDictionary*map=[NSMutableDictionary dictionary];
    for(WAGREntry*e in base){
        NSString *section = WAGRSectionForEntry(_spec, e);
        if(!map[section])map[section]=[NSMutableArray array];
        [(NSMutableArray*)map[section] addObject:e];
    }
    _sectionKeys=[map.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    _byClass=map;
    NSUInteger overrides=0;
    for(WAGREntry*e in base)if(WAGRHasOverride(e.overrideKey))overrides++;
    self.title=overrides
        ?[NSString stringWithFormat:@"%@ (%lu ON)",_spec.title,(unsigned long)overrides]
        :_spec.title;
    [self.tableView reloadData];
}
- (void)updateSearchResultsForSearchController:(UISearchController*)sc{
    [self applyFilter:sc.searchBar.text];
}
- (void)resetAll {
    NSUInteger n=0;
    for(WAGREntry*e in _all)if(WAGRHasOverride(e.overrideKey)){WAGRClearOverride(e.overrideKey);n++;}
    [self applyFilter:_search.searchBar.text];
    if(n){UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Reset"
        message:[NSString stringWithFormat:@"%lu overrides removidos.",(unsigned long)n]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return(NSInteger)_sectionKeys.count;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{
    return(NSInteger)((NSArray*)_byClass[_sectionKeys[(NSUInteger)s]]).count;
}
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    NSString *cls=_sectionKeys[(NSUInteger)s];
    NSArray *rows=_byClass[cls];
    NSUInteger on=0; for(WAGREntry*e in rows)if(WAGRHasOverride(e.overrideKey)&&WAGROverrideBool(e.overrideKey))on++;
    UIView*v=[[UIView alloc]initWithFrame:CGRectMake(0,0,tv.bounds.size.width,34)];
    v.backgroundColor=RBG();
    UILabel*l=[[UILabel alloc]initWithFrame:CGRectMake(20,7,tv.bounds.size.width-80,20)];
    l.text=cls; l.font=[UIFont boldSystemFontOfSize:12];
    l.textColor=[UIColor colorWithWhite:.62 alpha:1];
    [v addSubview:l];
    if(on){
        UILabel*badge=[[UILabel alloc]initWithFrame:CGRectMake(tv.bounds.size.width-70,6,60,22)];
        badge.text=[NSString stringWithFormat:@"%lu ON",(unsigned long)on];
        badge.font=[UIFont boldSystemFontOfSize:11];
        badge.textColor=RGRN(); badge.textAlignment=NSTextAlignmentRight;
        [v addSubview:badge];
    }
    return v;
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s{return 34;}
- (WAGREntry*)entryAt:(NSIndexPath*)ip {
    NSArray*rows=_byClass[_sectionKeys[(NSUInteger)ip.section]];
    return(ip.row<(NSInteger)rows.count)?rows[(NSUInteger)ip.row]:nil;
}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell*c=[tv dequeueReusableCellWithIdentifier:@"e"];
    if(!c)c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"e"];
    WAGREntry*e=[self entryAt:ip]; if(!e)return c;
    c.backgroundColor=RCELL();
    c.contentView.backgroundColor=RCELL();
    c.selectionStyle=UITableViewCellSelectionStyleDefault;
    c.imageView.image=nil;
    c.imageView.hidden=YES;
    c.indentationLevel=0;
    c.indentationWidth=0;
    BOOL hasOv=WAGRHasOverride(e.overrideKey);
    BOOL effVal=hasOv?WAGROverrideBool(e.overrideKey):NO;

    NSString *featureName = WAGRFeatureName(e);
    c.textLabel.text=featureName;
    c.textLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    c.textLabel.textColor=hasOv?(effVal?RGRN():RRED()):UIColor.labelColor;
    c.textLabel.numberOfLines=0;
    c.textLabel.lineBreakMode=NSLineBreakByCharWrapping;
    c.textLabel.adjustsFontSizeToFitWidth=NO;

    NSString*pfx=e.isProperty?@"@prop":(e.isClassMethod?@"+":@"-");
    NSString *state = hasOv ? (effVal ? @"override 1" : @"override 0") : @"sys";
    c.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@", pfx, state];
    c.detailTextLabel.textColor=hasOv?(effVal?RGRN():RRED()):RSUB();
    c.detailTextLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    c.detailTextLabel.numberOfLines=1;

    UISwitch*sw=(UISwitch*)objc_getAssociatedObject(c,kEntryKey);
    if(!sw){sw=[[UISwitch alloc]init];sw.onTintColor=RACC();
        [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(c,kEntryKey,sw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        c.accessoryView=sw;}
    sw.on=effVal; sw.tag=ip.section*100000+ip.row;
    return c;
}
- (void)toggled:(UISwitch*)sw {
    NSInteger s=sw.tag/100000, r=sw.tag%100000;
    WAGREntry*e=[self entryAt:[NSIndexPath indexPathForRow:r inSection:s]]; if(!e)return;
    if(sw.isOn){
        WAGRSetOverride(e.overrideKey,YES);
        WAGRInstallHookForEntry(e);
    } else {
        WAGRClearOverride(e.overrideKey);
    }
    [self applyFilter:_search.searchBar.text];
}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGREntry*e=[self entryAt:ip]; if(!e)return;
    UIAlertController*a=[UIAlertController alertControllerWithTitle:
        [NSString stringWithFormat:@"%@",WAGRFeatureName(e)]
        message:e.className preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Force TRUE (1)" style:UIAlertActionStyleDefault handler:^(id _){
        WAGRSetOverride(e.overrideKey,YES); WAGRInstallHookForEntry(e);
        [self applyFilter:self->_search.searchBar.text];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Force FALSE (0)" style:UIAlertActionStyleDefault handler:^(id _){
        WAGRSetOverride(e.overrideKey,NO); WAGRInstallHookForEntry(e);
        [self applyFilter:self->_search.searchBar.text];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Clear / System" style:UIAlertActionStyleDefault handler:^(id _){
        WAGRClearOverride(e.overrideKey);
        [self applyFilter:self->_search.searchBar.text];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
