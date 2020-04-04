/*
 SyPCamera.m
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

#import "SyPCamera.h"

NSString * const SyPCameraAddedNotification = @"SyPCameraAddedNotification";
NSString * const SyPCameraRemovedNotification = @"SyPCameraRemovedNotification";

@interface SyPCamera (Private)
@property (readwrite) BOOL isInLiveView;
@end

@implementation SyPCamera {
    BOOL _isInLiveView;
}

@dynamic driverName; // subclasses provide it

+ (NSMutableSet *)mutableCameras
{
    static NSMutableSet *mCameras = nil;
    if (mCameras == nil)
    {
        mCameras = [[NSMutableSet alloc] initWithCapacity:1];
    }
    return mCameras;
}

+ (void)addCamera:(SyPCamera *)added
{
    @synchronized([self class]) {
        [[self mutableCameras] addObject:added];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SyPCameraAddedNotification object:added];
}

+ (void)removeCamera:(SyPCamera *)removed
{
    @synchronized([self class]) {
       [[self mutableCameras] removeObject:removed];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SyPCameraRemovedNotification object:removed];
}

+ (NSSet *)cameras
{
    NSSet *cameras;
    @synchronized(self) {
        cameras = [[self mutableCameras] copy];
    }
    return cameras;
}

+ (void)startDriver
{

}

+ (void)endDriver
{

}

- (NSString *)name { return @""; }
- (NSString *)identifier { return @""; }
- (void)startLiveView
{
    _isInLiveView = YES;
}

- (void)stopLiveView
{
    _isInLiveView = NO;
}

- (SyPImageBuffer *)getImageWithError:(NSError **)error
{
    return nil;
}

- (BOOL)isInLiveView
{
    return _isInLiveView;
}

- (NSString *)stateStringWithError:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    return @"";
}
@end
