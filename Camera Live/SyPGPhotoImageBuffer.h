//
//  SyPGPhotoImageBuffer.h
//  Camera Live
//
//  Created by Tom Butterworth on 22/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPImageBuffer.h"
#include <gphoto2/gphoto2.h>

NS_ASSUME_NONNULL_BEGIN

@interface SyPGPhotoImageBuffer : SyPImageBuffer
@property (readonly) CameraFile *file;
@end

NS_ASSUME_NONNULL_END
