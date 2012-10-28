//
//  SyPImage.h
//  Syphamera
//
//  Created by Tom Butterworth on 04/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SyPImageFormats.h"

@interface SyPImage : NSObject
@property (readonly) SyPImageFormat format;
@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@end
