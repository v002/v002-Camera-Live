//
//  SyPLiveViewSession.h
//  CameraService
//
//  Created by Tom Butterworth on 31/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SyPGPhotoContext;

@interface SyPLiveViewSession : NSThread
- (id)initWithCamera:(NSDictionary<NSString *, id> *)description context:(SyPGPhotoContext *)context withReply:(void (^)(NSError *))reply;
- (void)endSession;
@property (readwrite, strong) void(^ _Nullable errorHandler)(NSError *);
@end

NS_ASSUME_NONNULL_END
