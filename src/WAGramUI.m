#import "WAGramUI.h"

@implementation WAGRSectionHeader { UILabel *_l; }
- (instancetype)initWithTitle:(NSString *)t {
    if (!(self = [super init])) return nil;
    _l = [[UILabel alloc] init];
    _l.translatesAutoresizingMaskIntoConstraints = NO;
    _l.text = [t uppercaseString];
    _l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _l.textColor = [UIColor colorWithRed:.2 green:.5 blue:1 alpha:1];
    [self addSubview:_l];
    [NSLayoutConstraint activateConstraints:@[
        [_l.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [_l.bottomAnchor  constraintEqualToAnchor:self.bottomAnchor  constant:-6],
    ]];
    return self;
}
@end

UITableViewCell *WAGRIconCell(NSString *sym, UIColor *iconBG, NSString *title, NSString *detail, UITableViewCellAccessoryType acc) {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = WAGR_CELL();
    c.imageView.image = [UIImage new]; // placeholder
    // Icon box
    UIView *icon = WAGRIconView(sym, iconBG);
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [c.contentView addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:c.contentView.leadingAnchor constant:15],
        [icon.centerYAnchor constraintEqualToAnchor:c.contentView.centerYAnchor],
        [icon.widthAnchor   constraintEqualToConstant:29],
        [icon.heightAnchor  constraintEqualToConstant:29],
    ]];
    // Labels
    UILabel *tl = [[UILabel alloc] init];
    tl.text = title; tl.font = [UIFont systemFontOfSize:16]; tl.textColor = WAGR_LABEL();
    UILabel *dl = [[UILabel alloc] init];
    dl.text = detail; dl.font = [UIFont systemFontOfSize:12]; dl.textColor = WAGR_SEC();
    dl.numberOfLines = 2;
    UIStackView *sv = [[UIStackView alloc] initWithArrangedSubviews:@[tl, dl]];
    sv.axis = UILayoutConstraintAxisVertical; sv.spacing = 1;
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    [c.contentView addSubview:sv];
    [NSLayoutConstraint activateConstraints:@[
        [sv.leadingAnchor   constraintEqualToAnchor:icon.trailingAnchor   constant:12],
        [sv.trailingAnchor  constraintEqualToAnchor:c.contentView.trailingAnchor constant:-12],
        [sv.centerYAnchor   constraintEqualToAnchor:c.contentView.centerYAnchor],
    ]];
    if (!detail.length) [sv removeArrangedSubview:dl];
    c.accessoryType = acc;
    return c;
}
