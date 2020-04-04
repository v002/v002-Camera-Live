//
//  CameraServiceProtocol.h
//  CameraService
//
//  Created by Tom Butterworth on 26/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol CameraServiceProtocol
- (void)startWithReply:(void (^)(NSError *))reply;
- (void)stop;
- (void)startForDescription:(NSDictionary *)description withReply:(void (^)(NSError *))reply;
- (void)stopForDescription:(NSDictionary *)description withReply:(void (^)(NSError *))reply;
- (void)infoTextForDescription:(NSDictionary *)description withReply:(void (^)(NSString *, NSError *))reply;
@end
