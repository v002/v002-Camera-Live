/*
 SyPCanonEVFImageBuffer.m
 Camera Live
 
 Created by Tom Butterworth on 04/09/2012.
 
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
    EdsUInt64 length;
    EdsError result = EdsGetLength(_stream, &length);
    if (result == EDS_ERR_OK && length <= SIZE_T_MAX) return (size_t)length;
    else return 0;
}

- (EdsStreamRef)stream
{
    return _stream;
}

- (SyPImageFormat)format { return SyPImageFormatJPEG; }
@end
