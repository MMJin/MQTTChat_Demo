//
//  ChatCell.m
//  MQTTChat
//
//  Created by Christoph Krey on 12.07.15.
// Copyright © 2014-2016  Owntracks. All rights reserved.
//

#import "ChatCell.h"

@implementation ChatCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self layoutViews];
    }
    return self;
}
- (void)layoutViews
{
    self.backgroundColor = [UIColor clearColor];

    //设定项目名字
    self.settingText = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, [UIScreen mainScreen].bounds.size.width, 44)];
    self.settingText.textColor = [UIColor blackColor];
    self.settingText.numberOfLines = 0;
    self.settingText.font = [UIFont systemFontOfSize:13];
    [self.contentView addSubview:_settingText];

}
@end
