//
//  DPHTTPRequest.m
//  DPHTTPRequest-Master
//
//  Created by DancewithPeng on 11/22/13.
//  Copyright (c) 2013 dancewithpeng@gmail.com. All rights reserved.
//

#import "DPHTTPRequest.h"
#include <sys/socket.h>

enum {
    kPostBufferSize = 32768
};

#pragma mark - NSStream (BoundPairAdditions)


static void CFStreamCreateBoundPairCompat(
                                          CFAllocatorRef      alloc,
                                          CFReadStreamRef *   readStreamPtr,
                                          CFWriteStreamRef *  writeStreamPtr,
                                          CFIndex             transferBufferSize
                                          )
// This is a drop-in replacement for CFStreamCreateBoundPair that is necessary because that
// code is broken on iOS versions prior to iOS 5.0 <rdar://problem/7027394> <rdar://problem/7027406>.
// This emulates a bound pair by creating a pair of UNIX domain sockets and wrapper each end in a
// CFSocketStream.  This won't give great performance, but it doesn't crash!
{
#pragma unused(transferBufferSize)
    int                 err;
    Boolean             success;
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    int                 fds[2];
    
    readStream = NULL;
    writeStream = NULL;
    
    // Create the UNIX domain socket pair.
    
    err = socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
    if (err == 0) {
        CFStreamCreatePairWithSocket(alloc, fds[0], &readStream,  NULL);
        CFStreamCreatePairWithSocket(alloc, fds[1], NULL, &writeStream);
        
        // If we failed to create one of the streams, ignore them both.
        
        if ( (readStream == NULL) || (writeStream == NULL) ) {
            if (readStream != NULL) {
                CFRelease(readStream);
                readStream = NULL;
            }
            if (writeStream != NULL) {
                CFRelease(writeStream);
                writeStream = NULL;
            }
        }
//        assert( (readStream == NULL) == (writeStream == NULL) );
        if (!((readStream == NULL) == (writeStream == NULL)))
            return;
            
        // Make sure that the sockets get closed (by us in the case of an error,
        // or by the stream if we managed to create them successfull).
        
        if (readStream == NULL) {
            err = close(fds[0]);
            if (err)
                return;
            err = close(fds[1]);
            if (err)
                return;
        } else {
            success = CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            if (!success)
                return;
            success = CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            if (!success)
                return;
        }
    }
    
    *readStreamPtr = readStream;
    *writeStreamPtr = writeStream;
}

@interface NSStream (BoundPairAdditions)
+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr outputStream:(NSOutputStream **)outputStreamPtr bufferSize:(NSUInteger)bufferSize;
@end

@implementation NSStream (BoundPairAdditions)

+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr outputStream:(NSOutputStream **)outputStreamPtr bufferSize:(NSUInteger)bufferSize
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    
    if ((inputStreamPtr == NULL) || (outputStreamPtr == NULL))
        return;
    
    readStream = NULL;
    writeStream = NULL;
    
#if defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && (__MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
#error If you support Mac OS X prior to 10.7, you must re-enable CFStreamCreateBoundPairCompat.
#endif
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 50000)
#error If you support iOS prior to 5.0, you must re-enable CFStreamCreateBoundPairCompat.
#endif
    
    if (NO) {
        CFStreamCreateBoundPairCompat(
                                      NULL,
                                      ((inputStreamPtr  != nil) ? &readStream : NULL),
                                      ((outputStreamPtr != nil) ? &writeStream : NULL),
                                      (CFIndex) bufferSize
                                      );
    } else {
        CFStreamCreateBoundPair(
                                NULL,
                                ((inputStreamPtr  != nil) ? &readStream : NULL),
                                ((outputStreamPtr != nil) ? &writeStream : NULL),
                                (CFIndex) bufferSize
                                );
    }
    
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}

@end



#pragma mark - DPHTTPRequest



@interface DPHTTPRequest () <NSStreamDelegate>

@property (nonatomic, assign)   id<DPHTTPRequestDelegate>   pDelegate;
@property (nonatomic, retain)   NSURLConnection             *pConnection;

@property (nonatomic, retain)   NSURL           *pUrl;
@property (nonatomic)           NSInteger       pTag;
@property (nonatomic, retain)   NSDictionary    *pUserInfo;
@property (nonatomic, retain)   NSMutableData   *pData;
@property (nonatomic, copy)     NSString        *pResponseStr;
@property (nonatomic, retain)   NSError         *pError;

@property (nonatomic, retain)   NSURLRequest    *pRequest;


@property (nonatomic, retain)   NSInputStream   *fileStream;
@property (nonatomic, retain)   NSInputStream   *consumerStream;
@property (nonatomic, retain)   NSOutputStream  *producerStream;
@property (nonatomic, assign)   const uint8_t   *buffer;
@property (nonatomic, assign)   uint8_t         *bufferOnHeap;
@property (nonatomic, assign)   size_t          bufferOffset;
@property (nonatomic, assign)   size_t          bufferLimit;
@property (nonatomic, copy)     NSData          *bodyPrefixData;
@property (nonatomic, copy)     NSData          *bodySuffixData;

@end

@implementation DPHTTPRequest

@synthesize pUrl = _url;
@synthesize pTag = _tag;
@synthesize pUserInfo = _userInfo;
@synthesize pData = _data;
@synthesize pResponseStr = _responseStr;
@synthesize pError = _error;
@synthesize pDelegate = _delegate;
@synthesize pConnection = _connection;
@synthesize pRequest = _request;

- (void)dealloc
{
    self.pDelegate = nil;
    self.pConnection = nil;
    self.pUrl = nil;
    self.pUserInfo = nil;
    self.pData = nil;
    self.pResponseStr = nil;
    self.pError = nil;
    self.pRequest = nil;
    
    self.didFailedSeletor = nil;
    self.didFinishedSeletor = nil;
    
    self.fileStream = nil;
    self.consumerStream = nil;
    self.producerStream = nil;
    
#if(!__has_feature(objc_arc))
    [super dealloc];
#endif
}


- (NSURL *)url
{
    return _url;
}

- (NSInteger)tag
{
    return _tag;
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (NSData *)responseData
{
    return _data;
}

- (NSString *)responseString
{
    return _responseStr;
}

- (NSError *)responseError
{
    return _error;
}

+ (NSString *)createParameterString:(NSDictionary *)params
{
    NSMutableString *paramsStr = [NSMutableString stringWithCapacity:0];
    for (NSString *key in [params allKeys])
    {
        NSString *value = [params objectForKey:key];

        [paramsStr appendFormat:@"&%@=%@", key, value];
    }
    
    return paramsStr;
}

+ (id)createRequestWithURLString:(NSString *)urlStr andDelegate:(id)delegate
{
    DPHTTPRequest *request = [[DPHTTPRequest alloc] init];
    urlStr = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    request.pUrl = [NSURL URLWithString:urlStr];
    request.pDelegate = delegate;
    request.pData = [NSMutableData dataWithCapacity:0];
    request.didFinishedSeletor = @selector(requestDidFinished:);
    request.didFailedSeletor = @selector(requestDidFailed:);
    
#if(!__has_feature(objc_arc))
    return [request autorelease];
#endif
    
    return request;
}

+ (id)requestWithURLString:(NSString *)urlStr andDelegate:(id)delegate
{
    DPHTTPRequest *request = [DPHTTPRequest createRequestWithURLString:urlStr andDelegate:delegate];
    request.pRequest = [NSURLRequest requestWithURL:request.pUrl];
    
    return request;
}

+ (id)postRequestWithURLString:(NSString *)urlStr andParameter:(NSDictionary *)params andDelegate:(id)delegate
{
    DPHTTPRequest *request = [DPHTTPRequest createRequestWithURLString:urlStr andDelegate:delegate];
    request.pRequest = [NSMutableURLRequest requestWithURL:request.pUrl];
    
    NSMutableURLRequest *mRequest = (NSMutableURLRequest *)request.pRequest;
    [mRequest setHTTPMethod:@"POST"];
    [mRequest setHTTPBody:[[DPHTTPRequest createParameterString:params] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return request;
}

- (void)sendWithAsync
{
    if (self.pConnection)
        [self.pConnection cancel];

#if(!__has_feature(objc_arc))
    [self.pDelegate retain];
#endif
    
    self.pConnection = [NSURLConnection connectionWithRequest:self.pRequest delegate:self];
}

- (NSData *)sendWithSync
{
    NSData *data;
    NSError *error = nil;
    data = [NSURLConnection sendSynchronousRequest:self.pRequest returningResponse:nil error:&error];
    
    self.pError = error;
    self.pData = [NSMutableData dataWithData:data];
    
    return self.responseData;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
    NSMutableURLRequest *mRequest = (NSMutableURLRequest *)self.pRequest;
    [mRequest setValue:value forHTTPHeaderField:field];
}

- (NSString *)generateBoundaryString
{
    CFUUIDRef       uuid;
    CFStringRef     uuidStr;
    NSString *      result;
    
    uuid = CFUUIDCreate(NULL);
    uuidStr = CFUUIDCreateString(NULL, uuid);
    
    result = [NSString stringWithFormat:@"Boundary-%@", uuidStr];
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

- (void)addFile:(NSString *)filePath
{
    NSURL *                 url;
    NSMutableURLRequest *   request;
    NSString *              boundaryStr;
    NSString *              contentType;
    NSString *              bodyPrefixStr;
    NSString *              bodySuffixStr;
    NSNumber *              fileLengthNum;
    unsigned long long      bodyLength;
    NSInputStream *         consStream;
    NSOutputStream *        prodStream;
    
    if (!filePath)
        return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
        return;
    
    url = self.pUrl;
        
    boundaryStr = [self generateBoundaryString];
    if (!boundaryStr)
        return;
        
    bodyPrefixStr = [NSString stringWithFormat:
                     @
                     // empty preamble
                     "\r\n"
                     "--%@\r\n"
                     "Content-Disposition: form-data; name=\"fileContents\"; filename=\"%@\"\r\n"
                     "Content-Type: %@\r\n"
                     "\r\n",
                     boundaryStr,
                     [filePath lastPathComponent],       // +++ very broken for non-ASCII
                     contentType
                     ];
    bodySuffixStr = [NSString stringWithFormat:
                     @
                     "\r\n"
                     "--%@\r\n"
                     "Content-Disposition: form-data; name=\"uploadButton\"\r\n"
                     "\r\n"
                     "Upload File\r\n"
                     "--%@--\r\n"
                     "\r\n"
                     //empty epilogue
                     ,
                     boundaryStr,
                     boundaryStr
                     ];
    
    self.bodyPrefixData = [bodyPrefixStr dataUsingEncoding:NSASCIIStringEncoding];
    self.bodySuffixData = [bodySuffixStr dataUsingEncoding:NSASCIIStringEncoding];
    
    fileLengthNum = (NSNumber *) [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] objectForKey:NSFileSize];
    
    bodyLength =
    (unsigned long long) [self.bodyPrefixData length]
    + [fileLengthNum unsignedLongLongValue]
    + (unsigned long long) [self.bodySuffixData length];
    
    self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    
    [self.fileStream open];
    
    [NSStream createBoundInputStream:&consStream outputStream:&prodStream bufferSize:32768];
    self.consumerStream = consStream;
    self.producerStream = prodStream;
    
    self.producerStream.delegate = self;
    [self.producerStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.producerStream open];
    
    self.buffer      = [self.bodyPrefixData bytes];
    self.bufferLimit = [self.bodyPrefixData length];
    
    request = (NSMutableURLRequest *)self.pRequest;
    [request setHTTPBodyStream:consStream];
    
    [self setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", boundaryStr] forHTTPHeaderField:@"Content-Type"];
    [self setValue:[NSString stringWithFormat:@"%llu", bodyLength] forHTTPHeaderField:@"Content-Length"];
}


- (void)stopSendWithStatus:(NSString *)statusString
{
    if (self.bufferOnHeap) {
        free(self.bufferOnHeap);
        self.bufferOnHeap = NULL;
    }
    self.buffer = NULL;
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
    if (self.pConnection != nil) {
        [self.pConnection cancel];
        self.pConnection = nil;
    }
    self.bodyPrefixData = nil;
    if (self.producerStream != nil) {
        self.producerStream.delegate = nil;
        [self.producerStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.producerStream close];
        self.producerStream = nil;
    }
    self.consumerStream = nil;
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    self.bodySuffixData = nil;
}


// An NSStream delegate callback that's called when events happen on our
// network stream.
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
#pragma unused(aStream)
    assert(aStream == self.producerStream);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            // NSLog(@"producer stream opened");
        } break;
        case NSStreamEventHasBytesAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            // Check to see if we've run off the end of our buffer.  If we have,
            // work out the next buffer of data to send.
            
            if (self.bufferOffset == self.bufferLimit) {
                
                // See if we're transitioning from the prefix to the file data.
                // If so, allocate a file buffer.
                
                if (self.bodyPrefixData != nil) {
                    self.bodyPrefixData = nil;
                    
                    assert(self.bufferOnHeap == NULL);
                    self.bufferOnHeap = malloc(kPostBufferSize);
                    assert(self.bufferOnHeap != NULL);
                    self.buffer = self.bufferOnHeap;
                    
                    self.bufferOffset = 0;
                    self.bufferLimit  = 0;
                }
                
                // If we still have file data to send, read the next chunk.
                
                if (self.fileStream != nil) {
                    NSInteger   bytesRead;
                    
                    bytesRead = [self.fileStream read:self.bufferOnHeap maxLength:kPostBufferSize];
                    
                    if (bytesRead == -1) {
                        [self stopSendWithStatus:@"File read error"];
                    } else if (bytesRead != 0) {
                        self.bufferOffset = 0;
                        self.bufferLimit  = bytesRead;
                    } else {
                        // If we hit the end of the file, transition to sending the
                        // suffix.
                        
                        [self.fileStream close];
                        self.fileStream = nil;
                        
                        assert(self.bufferOnHeap != NULL);
                        free(self.bufferOnHeap);
                        self.bufferOnHeap = NULL;
                        self.buffer       = [self.bodySuffixData bytes];
                        
                        self.bufferOffset = 0;
                        self.bufferLimit  = [self.bodySuffixData length];
                    }
                }
                
                // If we've failed to produce any more data, we close the stream
                // to indicate to NSURLConnection that we're all done.  We only do
                // this if producerStream is still valid to avoid running it in the
                // file read error case.
                
                if ( (self.bufferOffset == self.bufferLimit) && (self.producerStream != nil) ) {
                    // We set our delegate callback to nil because we don't want to
                    // be called anymore for this stream.  However, we can't
                    // remove the stream from the runloop (doing so prevents the
                    // URL from ever completing) and nor can we nil out our
                    // stream reference (that causes all sorts of wacky crashes).
                    //
                    // +++ Need bug numbers for these problems.
                    self.producerStream.delegate = nil;
                    // [self.producerStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                    [self.producerStream close];
                    // self.producerStream = nil;
                }
            }
            
            // Send the next chunk of data in our buffer.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                bytesWritten = [self.producerStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                if (bytesWritten <= 0) {
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            NSLog(@"producer stream error %@", [aStream streamError]);
            [self stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            assert(NO);     // should never happen for the output stream
        } break;
        default: {
            assert(NO);
        } break;
    }
}


#pragma mark - NSURLConnectionDataDelegate


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self.pData setLength:0];
    
    if ([self.pDelegate respondsToSelector:@selector(request:didReceiveResponse:)])
        [self.pDelegate request:self didReceiveResponse:response];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.pData appendData:data];
    
    if ([self.pDelegate respondsToSelector:@selector(request:didReceiveData:)])
        [self.pDelegate request:self didReceiveData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *rspdStr = [[NSString alloc] initWithData:self.pData encoding:NSUTF8StringEncoding];
    self.pResponseStr = rspdStr;
    
#if(!__has_feature(objc_arc))
    [rspdStr release];
#endif
    
    if ([self.pDelegate respondsToSelector:self.didFinishedSeletor])
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.pDelegate performSelector:self.didFinishedSeletor withObject:self];
#pragma clang diagnostic pop
    
#if(!__has_feature(objc_arc))
    [self.pDelegate release];
#endif
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.pError = error;
    
    if ([self.pDelegate respondsToSelector:self.didFailedSeletor])
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.pDelegate performSelector:self.didFailedSeletor withObject:self];
#pragma clang diagnostic pop
    
#if(!__has_feature(objc_arc))
    [self.pDelegate release];
#endif
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([self.pDelegate respondsToSelector:@selector(requestDidCanceled:)])
        [self.pDelegate requestDidCanceled:self];
    
#if(!__has_feature(objc_arc))
    [self.pDelegate release];
#endif
}

@end
