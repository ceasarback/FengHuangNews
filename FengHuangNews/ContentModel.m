//
//  ContentModel.m
//  FengHuangNews
//
//  Created by Ceasarback on 14-1-2.
//  Copyright (c) 2014年 _CompanyName_. All rights reserved.
//

#import "ContentModel.h"

@implementation ContentModel

- (id)initWithData:(NSDictionary *)data
{
    if (self = [super init])
    {
        self.commentsAll = [data objectForKey:@"commentsAll"];
        self.thumbnail = [data objectForKey:@"thumbnail"];
        self.title = [data objectForKey:@"title"];
    }
    
    return self;
}

- (void)dealloc
{
    self.commentsAll = nil;
    self.title = nil;
    self.thumbnail = nil;
    
    [super dealloc];
}

@end
