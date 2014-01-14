//
//  DPHTTPRequest.h
//  DPHTTPRequest-Master
//
//  Created by DancewithPeng on 11/22/13.
//  Copyright (c) 2013 dancewithpeng@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DPHTTPRequest;


// Protocol
@protocol DPHTTPRequestDelegate <NSObject>

@optional
- (void)requestDidFinished:(DPHTTPRequest *)request;
- (void)requestDidFailed:(DPHTTPRequest *)request;
- (void)requestDidCanceled:(DPHTTPRequest *)request;

- (void)request:(DPHTTPRequest *)request didReceiveResponse:(NSURLResponse *)response;
- (void)request:(DPHTTPRequest *)request didReceiveData:(NSData *)data;

@end


// Class Interface
@interface DPHTTPRequest : NSObject <NSURLConnectionDataDelegate>
{
    id<DPHTTPRequestDelegate> __unsafe_unretained   _delegate;
    
    NSURLConnection *_connection;

    NSURL           *_url;
    NSInteger       _tag;
    NSDictionary    *_userInfo;
    
    NSMutableData   *_data;
    NSString        *_responseStr;
    NSError         *_error;
    
    NSURLRequest    *_request;
}

@property (nonatomic, readonly) NSURL           *url;
@property (nonatomic, readonly) NSInteger       tag;
@property (nonatomic, readonly) NSDictionary    *userInfo;

@property (nonatomic, assign)   SEL             didFinishedSeletor;
@property (nonatomic, assign)   SEL             didFailedSeletor;

@property (nonatomic, readonly) NSData          *responseData;
@property (nonatomic, readonly) NSString        *responseString;
@property (nonatomic, readonly) NSError         *responseError;

+ (id)requestWithURLString:(NSString *)urlStr andDelegate:(id)delegate;
+ (id)postRequestWithURLString:(NSString *)urlStr andParameter:(NSDictionary *)params andDelegate:(id)delegate;

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;
- (void)addFile:(NSString *)filePath;

- (void)sendWithAsync;
- (NSData *)sendWithSync;

@end
