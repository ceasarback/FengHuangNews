//
//  ContentModel.h
//  FengHuangNews
//
//  Created by Ceasarback on 14-1-2.
//  Copyright (c) 2014年 _CompanyName_. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ContentModel : NSObject

@property (nonatomic, copy) NSString    *title;
@property (nonatomic, copy) NSString    *thumbnail;
@property (nonatomic, copy) NSString    *commentsAll;

- (id)initWithData:(NSDictionary *)data;

@end
