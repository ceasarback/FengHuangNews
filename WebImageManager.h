//
//  WebImageManager.h
//  TaoBao
//
//  Created by Ceasarback on 13-12-31.
//  Copyright (c) 2013年 _CompanyName_. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WebImageManager : NSObject

+ (id)shareManager;

- (UIImage *)getCacheImage:(NSString *)imgUrl;
- (BOOL)saveCacheImage:(UIImage *)image forUrl:(NSString *)imgUrl;
- (BOOL)clearCacheImage;

@end
