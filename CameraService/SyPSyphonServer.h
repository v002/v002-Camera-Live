//
//  SyPSyphonServer.h
//  CameraService
//
//  Created by Tom Butterworth on 30/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SyPImageBuffer;

@interface SyPSyphonServer : NSObject
- (instancetype)initWithName:(NSString *)name;
- (NSError * _Nullable)output:(SyPImageBuffer *)image;
@end

NS_ASSUME_NONNULL_END
