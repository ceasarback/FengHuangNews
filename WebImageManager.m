//
//  WebImageManager.m
//  TaoBao
//
//  Created by Ceasarback on 13-12-31.
//  Copyright (c) 2013年 _CompanyName_. All rights reserved.
//

#import "WebImageManager.h"

@interface WebImageManager ()

@property (nonatomic, retain) NSMutableDictionary   *dict;

@end


@implementation WebImageManager

- (void)dealloc
{
    self.dict = nil;
    
    [super dealloc];
}

static WebImageManager *_manager;
+ (id)shareManager
{
    if (!_manager)
    {
        _manager = [[self alloc] init];
    }
    
    return _manager;
}

- (id)init
{
    if (self = [super init])
    {
        _dict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (UIImage *)getCacheImage:(NSString *)imgUrl
{
    return [_dict objectForKey:imgUrl];
}

- (BOOL)saveCacheImage:(UIImage *)image forUrl:(NSString *)imgUrl
{
    [_dict setObject:image forKey:imgUrl];
    
    return YES;
}

- (BOOL)clearCacheImage
{
    [_dict removeAllObjects];
    
    return YES;
}

@end


