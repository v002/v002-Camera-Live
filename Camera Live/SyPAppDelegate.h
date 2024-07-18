/*
 SyPAppDelegate.h
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

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <turbojpeg.h>
#import "Syphon/Syphon.h"
#import "SyPToolbarDelegate.h"

@class SyPCamera;

@interface SyPAppDelegate : NSObject <NSApplicationDelegate>
{
    NSWindow *_window;
    NSArrayController *_camerasArrayController;
    SyPToolbarDelegate *_toolbarDelegate;
    NSMutableArray *_cameras;
    NSArray *_selectedCameras;
    dispatch_queue_t _queue;
    SyPCamera *_active;
    tjhandle _decompressor;
    void *_buffer;
    size_t _bufferSize;
    BOOL _started;
    SyphonServer *_server;
    CGLContextObj cgl_ctx;
    IOPMAssertionID _noSleepAssertion;
}
@property (assign) IBOutlet NSWindow *window;
@property (readonly) NSArray *cameras;
@property (readwrite, retain) SyPCamera *activeCamera;
@property (readwrite, retain) NSArray *selectedCameras;
@property (assign) IBOutlet NSArrayController *camerasArrayController;
@property (assign) IBOutlet SyPToolbarDelegate *toolbarDelegate;
- (IBAction)setIso:(NSMenuItem *)sender;
- (IBAction)goToWebIssues:(id)sender;
@end
