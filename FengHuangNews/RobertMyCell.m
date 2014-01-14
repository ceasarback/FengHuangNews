//
//  RobertMyCell.m
//  FengHuangNews
//
//  Created by Ceasarback on 14-1-2.
//  Copyright (c) 2014年 _CompanyName_. All rights reserved.
//

#import "RobertMyCell.h"

@implementation RobertMyCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)dealloc {
    [_iconView release];
    [_summary release];
    [_comment release];
    [_vedioIcon release];
    
    [super dealloc];
}
@end
