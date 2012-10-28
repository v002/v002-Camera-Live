//
//  SyPImageBuffer.h
//  Syphamera
//
//  Created by Tom Butterworth on 04/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPImage.h"

@interface SyPImageBuffer : SyPImage
@property (readonly) void *baseAddress;
@property (readonly) size_t length;
@end
