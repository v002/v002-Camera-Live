/*
 SyPAppDelegate.m
 Camera Live
 
 Created by Tom Butterworth on 03/09/2012.
 
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

#import "SyPAppDelegate.h"
#import "SyPCamera.h"
#import "SyPImageBuffer.h"
#import <OpenGL/CGLMacro.h>

#define kActiveCameraIDDefaultsKey @"ActiveCameraID"

@interface SyPAppDelegate (Private)
- (void)addCamera:(SyPCamera *)camera;
- (void)removeCamera:(SyPCamera *)camera;
@end


@implementation SyPAppDelegate

- (void)addCamera:(SyPCamera *)camera
{
    [self.camerasArrayController addObject:camera];
    if (self.activeCamera == nil)
    {
        self.toolbarDelegate.status = @"Ready";
        NSString *previousID = [[NSUserDefaults standardUserDefaults] objectForKey:kActiveCameraIDDefaultsKey];
        if ([previousID isEqualToString:camera.identifier])
        {
            [self.camerasArrayController setSelectedObjects:[NSArray arrayWithObject:camera]];
        }
    }
}

- (void)removeCamera:(SyPCamera *)camera
{
    [self.camerasArrayController removeObject:camera];
    if ([self.cameras count] == 0)
    {
        self.toolbarDelegate.status = @"No Camera";
    }
}

@synthesize window = _window, camerasArrayController = _camerasArrayController, toolbarDelegate = _toolbarDelegate;

- (NSArray *)cameras { return _cameras; }

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.toolbarDelegate.status = @"No Camera";
    _cameras = [[NSMutableArray alloc] initWithCapacity:4];
    _decompressor = tjInitDecompress();
    [self bind:@"selectedCameras" toObject:self.camerasArrayController withKeyPath:@"selectedObjects" options:nil];
    [[NSNotificationCenter defaultCenter] addObserverForName:SyPCameraAddedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      [self addCamera:[note object]];
                                                  }];
    [[NSNotificationCenter defaultCenter] addObserverForName:SyPCameraRemovedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      [self removeCamera:[note object]];
                                                  }];
    for (SyPCamera *camera in [SyPCamera cameras]) {
        [self addCamera:camera];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self.camerasArrayController removeObjects:[self.camerasArrayController arrangedObjects]];
}

- (NSArray *)selectedCameras
{
    return _selectedCameras;
}

- (void)setSelectedCameras:(NSArray *)selectedCameras
{
    [selectedCameras retain];
    [_selectedCameras release];
    _selectedCameras = selectedCameras;
    SyPCamera *selected = [selectedCameras lastObject];
    if ([[self.camerasArrayController arrangedObjects] count])
    {
        // we only want to record an identifier (or lack thereof) if the selection (or lack thereof) was from at least
        // one existant camera
        [[NSUserDefaults standardUserDefaults] setObject:selected.identifier forKey:kActiveCameraIDDefaultsKey];
    }
    self.activeCamera = selected;
}

- (SyPCamera *)activeCamera
{
    return _active;
}

- (void)setActiveCamera:(SyPCamera *)activeCamera
{
    [activeCamera retain];
    [_active stopLiveView];
    [_active release];
    _active = activeCamera;
    if (_queue == nil)
    {
        _queue = dispatch_queue_create("info.v002.Camera-Live.liveview", DISPATCH_QUEUE_SERIAL);
    }
    if (_active)
    {
        dispatch_async(_queue, ^{
            _started = NO;
        });
        
        NSString *status = nil;
        if (cgl_ctx == nil)
        {
            CGLPixelFormatAttribute attribs[] = {
                kCGLPFAAccelerated,
                kCGLPFAAllowOfflineRenderers,
                kCGLPFAColorSize, 32,
                kCGLPFADepthSize, 0,
                0};
            
            CGLPixelFormatObj pixelFormat;
            GLint count;
            CGLError result = CGLChoosePixelFormat(attribs, &pixelFormat, &count);
            
            if (result == kCGLNoError)
            {
                result = CGLCreateContext(pixelFormat, NULL, &cgl_ctx);
                CGLReleasePixelFormat(pixelFormat);
            }
            
            if (result == kCGLNoError)
            {
                glEnable(GL_TEXTURE_RECTANGLE_ARB);
                glDisable(GL_DEPTH);
                glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            }
            else
            {
                status = @"OpenGL Error";
            }
        }
        if (_server == nil && status == nil)
        {
            _server = [[SyphonServer alloc] initWithName:activeCamera.name context:cgl_ctx options:nil];
            if (_server == nil)
            {
                status = @"Syphon Error";
            }
        }
        else if (status == nil)
        {
            _server.name = activeCamera.name;
        }
        if (status == nil)
        {
            [_active startLiveViewOnQueue:_queue withHandler:^(SyPImageBuffer *image, NSError *error) {
                if (image)
                {
                    if (!_started)
                    {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.toolbarDelegate.status = @"Active";
                        }];
                        _started = YES;
                    }
                    int width, height;
                    int result = tjDecompressHeader(_decompressor, image.baseAddress, image.length, &width, &height);
                    if (result == 0)
                    {
                        size_t wanted_bpr = TJPAD(tjPixelSize[TJPF_BGRA] * width);
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
                            if ([_server bindToDrawFrameOfSize:(NSSize){width, height}])
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
                }
                else if (error)
                {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        self.toolbarDelegate.status = @"Camera Error";
                    }];
                }
            }];
        }
        if (status)
        {
            [_active release];
            _active = nil;
            [_camerasArrayController setSelectedObjects:[NSArray array]];
            dispatch_async(_queue, ^{
                [_server stop];
                [_server release];
                _server = nil;
            });
        }
        else
        {
            status = @"Starting";
        }
        self.toolbarDelegate.status = status;
    }
    else if (_queue)
    {
        if ([self.cameras count]) self.toolbarDelegate.status = @"Ready";
        else self.toolbarDelegate.status = @"No Camera";
        dispatch_async(_queue, ^{
            [_server stop];
            [_server release];
            _server = nil;
        });
    }
}
@end
