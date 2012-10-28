//
//  SyPCanonEVFImageBuffer.m
//  Syphamera
//
//  Created by Tom Butterworth on 04/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPCanonEVFImageBuffer.h"

@implementation SyPCanonEVFImageBuffer
- (id)init
{
    self = [super init];
    if (self)
    {
        EdsError result = EdsCreateMemoryStream(0, &_stream);
        if (result != EDS_ERR_OK)
        {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    EdsRelease(_stream);
    [super dealloc];
}

- (void *)baseAddress
{
    EdsVoid *pointer;
    EdsError result = EdsGetPointer(_stream, &pointer);
    if (result == EDS_ERR_OK) return pointer;
    else return NULL;
}

- (size_t)length
{
    EdsUInt32 length;
    EdsError result = EdsGetLength(_stream, &length);
    if (result == EDS_ERR_OK) return length;
    else return 0;
}

- (EdsStreamRef)stream
{
    return _stream;
}

- (SyPImageFormat)format { return SyPImageFormatJPEG; }
@end
