//
//  SyPCamera.m
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPCamera.h"

@implementation SyPCamera
- (NSString *)name { return @""; }
- (NSError *)startLiveViewWithHandler:(SyPCameraImageHandler)handler { return nil; }
- (NSError *)stopLiveView { return nil; }
- (SyPImageBuffer *)newLiveViewImage { return nil; }
@end
