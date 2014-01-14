//
//  UIImageView+WebImage.m
//  TaoBao
//
//  Created by Ceasarback on 13-12-31.
//  Copyright (c) 2013年 _CompanyName_. All rights reserved.
//

#import "UIImageView+WebImage.h"
#import "WebImageManager.h"

@implementation UIImageView (WebImage)

- (void)setImageWithURLString:(NSString *)urlAdress
{
    DPHTTPRequest *request = [DPHTTPRequest requestWithURLString:urlAdress andDelegate:self];
    [request setDidFailedSeletor:@selector(downloadFailed:)];
    [request setDidFinishedSeletor:@selector(downloadFinished:)];
    [request sendWithAsync];
}

- (void)downloadFailed:(DPHTTPRequest *)request
{
    
}


- (void)downloadFinished:(DPHTTPRequest *)request
{
    UIImage *image = [UIImage imageWithData:request.responseData];
    self.image = image;
    [[WebImageManager shareManager] saveCacheImage:image forUrl:request.url.absoluteString];
    
    if (self.tag == 10086)
    {
        
    }
}

@end
