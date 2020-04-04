//
//  SyPSyphonServer.m
//  CameraService
//
//  Created by Tom Butterworth on 30/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPSyphonServer.h"
#import "SyPImageBuffer.h"
#import <turbojpeg.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h> // TODO: update to core profile
#import <Syphon/Syphon.h>

@implementation SyPSyphonServer {
    tjhandle _decompressor;
    SyphonServer *_server;
    void *_buffer;
    int _bufferSize;
}

static NSMutableSet *theNameStore = nil;

+ (NSString *)uniqueName:(NSString *)candidate
{
    @synchronized(self) {
        if (!theNameStore)
        {
            theNameStore = [NSMutableSet setWithCapacity:1];
        }
        int added = 1;
        NSString *derived = candidate;
        while ([theNameStore containsObject:derived])
        {
            derived = [candidate stringByAppendingFormat:@" %d", added];
            added++;
        }
        [theNameStore addObject:derived];
        return derived;
    }
}

+ (void)endUniqueName:(NSString *)name
{
    @synchronized(self) {
        [theNameStore removeObject:name];
        if (theNameStore.count == 0)
        {
            theNameStore = nil;
        }
    }
}

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self)
    {
        _decompressor = tjInitDecompress();

        CGLPixelFormatAttribute attribs[] = {
            kCGLPFAAccelerated,
            kCGLPFAAllowOfflineRenderers,
            kCGLPFAColorSize, 32,
            kCGLPFADepthSize, 0,
            0};

        CGLPixelFormatObj pixelFormat;
        GLint count;
        CGLError result = CGLChoosePixelFormat(attribs, &pixelFormat, &count);

        CGLContextObj context = NULL;
        if (result == kCGLNoError)
        {
            result = CGLCreateContext(pixelFormat, NULL, &context);
            CGLReleasePixelFormat(pixelFormat);
        }
        if (result == kCGLNoError)
        {
            CGLSetCurrentContext(context);
            glEnable(GL_TEXTURE_RECTANGLE_ARB);
            glDisable(GL_DEPTH);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

            _server = [[SyphonServer alloc] initWithName:[[self class] uniqueName:name]
                                                 context:context
                                                 options:nil];

            CGLReleaseContext(context); // retained by the SyphonServer
        }

    }
    return self;
}

- (NSError *)output:(SyPImageBuffer *)image
{
    if (image)
    {
        int width, height;
        BOOL bound = NO;
        int result = tjDecompressHeader(_decompressor, (unsigned char *)image.baseAddress, image.length, &width, &height);
        if (result == 0)
        {
            CGLSetCurrentContext(_server.context);
            int wanted_bpr = TJPAD(tjPixelSize[TJPF_BGRA] * width);
            if (wanted_bpr * height != _bufferSize)
            {
                free(_buffer);
                _bufferSize = wanted_bpr * height;
                _buffer = malloc(_bufferSize);
                glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_ARB, _bufferSize, _buffer);

            }
            result = tjDecompress2(_decompressor, image.baseAddress, image.length, _buffer, width, wanted_bpr, height, TJPF_BGRA, TJFLAG_BOTTOMUP);
            if (result == 0)
            {
                bound = [_server bindToDrawFrameOfSize:(NSSize){width, height}];
                if (bound)
                {
                    SyphonImage *serverImage = [_server newFrameImage];
                    if (serverImage)
                    {
                        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, serverImage.textureName);
                        glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
                                        GL_TEXTURE_STORAGE_HINT_APPLE,
                                        GL_STORAGE_SHARED_APPLE);
                        glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _buffer);
                        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
                    }
                    [_server unbindAndPublish];
                }
            }
        }
        if (result != 0)
        {
            return [NSError errorWithDomain:@"libjpegturbo"
                                       code:result
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:tjGetErrorStr2(_decompressor)]}];
        }
        else if (!bound)
        {
            return [NSError errorWithDomain:@"Syphon"
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey: @"An error occurred on the GPU"}];
        }
    }
    return nil;
}

- (void)dealloc
{
    if (_decompressor)
    {
        tjDestroy(_decompressor);
    }
    free(_buffer);
    [_server stop];
    [[self class] endUniqueName:_server.name];
}

@end
