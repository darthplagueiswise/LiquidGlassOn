// WAGRBackupScopePickerVC.m — Scope picker UI, RyukGram visual style.

#import "WAGRBackupScopePickerVC.h"
#import "../WAGramUI.h"

@interface WAGRBackupScopePickerVC ()
@property (nonatomic) NSUInteger waabCount;
@property (nonatomic) NSUInteger contextCount;
@property (nonatomic) BOOL waabSelected;
@property (nonatomic) BOOL contextSelected;
@property (nonatomic, copy) void (^onContinue)(WAGRBackupScope);
@property (nonatomic, strong) UIBarButtonItem *continueBtn;
@end

@implementation WAGRBackupScopePickerVC

- (instancetype)initWithWAABCount:(NSUInteger)waabCount
                     contextCount:(NSUInteger)contextCount
                       onContinue:(void (^)(WAGRBackupScope))onContinue {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _waabCount = waabCount;
    _contextCount = contextCount;
    _waabSelected = waabCount > 0;
    _contextSelected = contextCount > 0;
    _onContinue = [onContinue copy];
    self.title = @"Importar Backup";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGR_BG();
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                             target:self action:@selector(cancel)];
    _continueBtn = [[UIBarButtonItem alloc] initWithTitle:@"Continuar"
                                                    style:UIBarButtonItemStyleDone
                                                   target:self action:@selector(continueTapped)];
    self.navigationItem.rightBarButtonItem = _continueBtn;
    [self updateContinueState];
}

- (void)updateContinueState {
    _continueBtn.enabled = _waabSelected || _contextSelected;
}

- (void)cancel { [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }

- (void)continueTapped {
    WAGRBackupScope s = 0;
    if (_waabSelected)    s |= WAGRBackupScopeWAAB;
    if (_contextSelected) s |= WAGRBackupScopeContext;
    void (^cb)(WAGRBackupScope) = self.onContinue;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(s);
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 1; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 2; }

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    return [[WAGRSectionHeader alloc] initWithTitle:@"INCLUIR"];
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 36; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return @"Marque os escopos que quer importar. As chaves do escopo selecionado serão substituídas pelas do backup.";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    BOOL isWAAB = (ip.row == 0);
    NSUInteger count = isWAAB ? _waabCount : _contextCount;
    BOOL selected = isWAAB ? _waabSelected : _contextSelected;

    NSString *title    = isWAAB ? @"WAAB Flags" : @"Context Gates";
    NSString *subtitle = [NSString stringWithFormat:@"%lu chaves · %@", (unsigned long)count,
                          isWAAB ? @"wagr.waab.* + aura_*" : @"wagr.context.*"];
    NSString *icon     = isWAAB ? @"flag.fill" : @"hammer.fill";
    UIColor  *color    = isWAAB ? WAGR_ACCENT() : WAGR_ORANGE();

    UITableViewCell *c = WAGRIconCell(icon, color, title, subtitle, UITableViewCellAccessoryNone);
    UIImage *check = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"];
    UIImageView *iv = [[UIImageView alloc] initWithImage:check];
    iv.tintColor = selected ? WAGR_ACCENT() : WAGR_SEC();
    iv.frame = CGRectMake(0, 0, 26, 26);
    iv.contentMode = UIViewContentModeScaleAspectFit;
    c.accessoryView = iv;
    if (count == 0) {
        c.contentView.alpha = 0.45;
        c.userInteractionEnabled = NO;
    }
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == 0) _waabSelected = !_waabSelected;
    else             _contextSelected = !_contextSelected;
    [self updateContinueState];
    [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
}

@end
