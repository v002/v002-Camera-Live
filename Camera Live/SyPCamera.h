/*
 SyPCamera.h
 Camera Live
 
 Created by Tom Butterworth on 03/09/2012.
 
 Copyright (c) 2012 Tom Butterworth & Anton Marini.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

@class SyPImageBuffer;

extern NSString * const SyPCameraAddedNotification;
extern NSString * const SyPCameraRemovedNotification;

typedef void(^SyPCameraImageHandler)(SyPImageBuffer *image, NSError *error);

@interface SyPCamera : NSObject
@property (class, readonly) NSString *driverName;
+ (void)startDriver;
+ (void)endDriver;
+ (NSSet *)cameras;
@property (readonly) NSString *name;
@property (readonly) NSString *identifier; // Unique per device and persistent
- (void)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler;
- (void)stopLiveView;
@property (readonly) BOOL isInLiveView;
- (NSString *)stateStringWithError:(NSError **)error;
@end

@interface SyPCamera (Subclassing)
+ (void)addCamera:(SyPCamera *)added;
+ (void)removeCamera:(SyPCamera *)removed;
@end
