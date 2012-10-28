//
//  SyPCanonEVFImageBuffer.h
//  Syphamera
//
//  Created by Tom Butterworth on 04/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPImageBuffer.h"
#import "EDSDK.h"

@interface SyPCanonEVFImageBuffer : SyPImageBuffer
{
    EdsStreamRef _stream;
}
@property (readonly) EdsStreamRef stream;
@end
