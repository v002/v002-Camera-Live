//
//  SyPGPhotoCamera.h
//  Camera Live
//
//  Created by Tom Butterworth on 22/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPCamera.h"

NS_ASSUME_NONNULL_BEGIN

@class SyPGPhotoContext;

@interface SyPGPhotoCamera : SyPCamera
@property (readonly) SyPGPhotoContext *context;
@end

NS_ASSUME_NONNULL_END
