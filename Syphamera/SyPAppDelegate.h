//
//  SyPAppDelegate.h
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import "turbojpeg.h"
#import "Syphon/Syphon.h"

@class SyPCamera;

@interface SyPAppDelegate : NSObject <NSApplicationDelegate>
{
    NSWindow *_window;
    NSMutableArray *_cameras;
    SyPCamera *_active;
    tjhandle _decompressor;
    void *_buffer;
    size_t _bufferSize;
    SyphonServer *_server;
    CGLContextObj cgl_ctx;
}
@property (assign) IBOutlet NSWindow *window;
@property (readonly) NSArray *cameras;
@property (readwrite, retain) SyPCamera *activeCamera;
@end
