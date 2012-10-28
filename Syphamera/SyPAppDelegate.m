//
//  SyPAppDelegate.m
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPAppDelegate.h"
#import "EDSDK.h"
#import "SyPCanonDSLR.h"
#import "SyPImageBuffer.h"
#import <OpenGL/CGLMacro.h>

@interface SyPAppDelegate (Private)
- (void)addCamera:(SyPCamera *)camera;
@end

EdsError SyPHandleCameraAdded(EdsVoid *inContext )
{
    EdsCameraListRef list;
    EdsError result = EdsGetCameraList(&list);
    if (result == EDS_ERR_OK)
    {
        EdsUInt32 count = 0;
        result = EdsGetChildCount(list, &count);
        if (result == EDS_ERR_OK)
        {
            for (int i = 0; i < count; i++) {
                EdsCameraRef camera;
                result = EdsGetChildAtIndex(list, i, &camera);
                if (result == EDS_ERR_OK)
                {
                    SyPCanonDSLR *this = [[SyPCanonDSLR alloc] initWithCanonCameraRef:camera];
                    [(SyPAppDelegate *)inContext addCamera:this];
                    if (((SyPAppDelegate *)inContext).activeCamera == nil)
                    {
                        ((SyPAppDelegate *)inContext).activeCamera = this;
                    }
                    NSLog(@"added: %@", this.name);
                    [this release];
                    EdsRelease(camera);
                    
                }
            }
        }
        EdsRelease(list);
    }
    return EDS_ERR_OK;
}

@implementation SyPAppDelegate

- (void)addCamera:(SyPCamera *)camera
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_cameras addObject:camera];
    }];
}

@synthesize window = _window;

- (NSArray *)cameras { return _cameras; }

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _cameras = [[NSMutableArray alloc] initWithCapacity:4];
    _decompressor = tjInitDecompress();
    EdsInitializeSDK();
    EdsSetCameraAddedHandler(SyPHandleCameraAdded, self);
    SyPHandleCameraAdded(self);
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self setActiveCamera:nil];
    [_cameras removeAllObjects];
    EdsTerminateSDK();
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
    if (_active)
    {
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
            }
            else
            {
                NSLog(@"bums error creating context");
            }

        }
        if (_server == nil && cgl_ctx)
        {
            _server = [[SyphonServer alloc] initWithName:@"" context:cgl_ctx options:nil];
        }
        [_active startLiveViewWithHandler:^(id camera, SyPImageBuffer *image) {
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
                }
                result = tjDecompress2(_decompressor, image.baseAddress, image.length, _buffer, width, wanted_bpr, height, TJPF_BGRA, TJFLAG_BOTTOMUP);
                if (result == 0)
                {
                    SyphonImage *serverImage = [_server newFrameImage];
                    if (serverImage == nil || serverImage.textureSize.width != width || serverImage.textureSize.height != height)
                    {
                        [serverImage release];
                        [_server bindToDrawFrameOfSize:(NSSize){width, height}];
                        [_server unbindAndPublish];
                        serverImage = [_server newFrameImage];
                    }
                    
                    if (serverImage)
                    {
                        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, serverImage.textureName);
                        glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _buffer);
                        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
                        [_server bindToDrawFrameOfSize:(NSSize){width, height}];
                        [_server unbindAndPublish];
                    }
                    [serverImage release];
                }
            }
        }];
    }
}
@end
