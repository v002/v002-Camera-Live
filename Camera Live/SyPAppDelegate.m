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
#import <objc/runtime.h>
#import "CameraServiceProtocol.h"
#import "SyPCameraKeys.h"
#define kActiveCameraIDDefaultsKey @"ActiveCameraID"


@implementation SyPAppDelegate
- (void)addCamera:(NSDictionary<NSString *, id> *)camera
{
    if (!_awaitingTermination)
    {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self.camerasArrayController addObject:camera];
            if (self.activeCamera == nil)
            {
                self.toolbarDelegate.status = @"Ready";
                NSString *previousID = [[NSUserDefaults standardUserDefaults] objectForKey:kActiveCameraIDDefaultsKey];
                if ([previousID isEqualToString:camera[kSyPGPhotoKeyIdentifier]])
                {
                    [self.camerasArrayController setSelectedObjects:[NSArray arrayWithObject:camera]];
                }
            }
        }];
    }
}

- (void)removeCamera:(NSDictionary<NSString *, id> *)camera
{
    if (!_awaitingTermination)
    {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self.camerasArrayController removeObject:camera];
            if ([self.cameras count] == 0)
            {
                self.toolbarDelegate.status = @"No Camera";
            }
            if ([self.activeCamera isEqualToDictionary:camera])
            {
                self.activeCamera = nil;
            }
        }];
    }
}

- (void)error:(NSError *)error forCamera:(NSDictionary<NSString *, id> *)cam
{
    if ([self.activeCamera isEqualToDictionary:cam])
    {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            self.toolbarDelegate.status = @"Camera Error";
        }];
    }
}

@synthesize window = _window, camerasArrayController = _camerasArrayController, toolbarDelegate = _toolbarDelegate;

- (NSArray *)cameras { return _cameras; }

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.toolbarDelegate.status = @"No Camera";
    _cameras = [[NSMutableArray alloc] initWithCapacity:4];
    
    [self bind:@"selectedCameras" toObject:self.camerasArrayController withKeyPath:@"selectedObjects" options:nil];
    _cameraService = [[NSXPCConnection alloc] initWithServiceName:@"info.v002.CameraService"];
    _cameraService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(CameraServiceProtocol)];
    _cameraService.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(CameraPresenceProtocol)];
    _cameraService.exportedObject = self;
    [_cameraService resume];

    [_cameraService.remoteObjectProxy startWithReply:^(NSError *error) {
        if (error)
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [[NSApplication sharedApplication] presentError:error];
            }];
        }
    }];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (self.activeCamera)
    {
        self.activeCamera = nil;
        _awaitingTermination = YES;
        return NSTerminateLater;
    }
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    self.activeCamera = nil;
    [_cameraService invalidate];
    [self.camerasArrayController removeObjects:[self.camerasArrayController arrangedObjects]];
}

- (NSArray<NSDictionary<NSString *, id> *> *)selectedCameras
{
    return _selectedCameras;
}

- (void)setSelectedCameras:(NSArray<NSDictionary<NSString *, id> *> *)selectedCameras
{
    _selectedCameras = selectedCameras;
    NSDictionary<NSString *, id> *selected = [selectedCameras lastObject];
    if ([[self.camerasArrayController arrangedObjects] count])
    {
        // we only want to record an identifier (or lack thereof) if the selection (or lack thereof) was from at least
        // one existant camera
        [[NSUserDefaults standardUserDefaults] setObject:selected[kSyPGPhotoKeyIdentifier]
                                                  forKey:kActiveCameraIDDefaultsKey];
    }
    self.activeCamera = selected;
}

- (NSDictionary<NSString *, id> *)activeCamera
{
    return _active;
}

- (void)setActiveCamera:(NSDictionary<NSString *, id> *)activeCamera
{
    BOOL stopping = NO;
    if (_active)
    {
        stopping = YES;
        self.toolbarDelegate.status = @"Stopping";
        [_cameraService.remoteObjectProxy stopForDescription:_active withReply:^(NSError *error) {
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                if ([self.toolbarDelegate.status isEqualToString:@"Stopping"])
                {
                    [self setIdleStatus];
                }
                if (self->_awaitingTermination)
                {
                    // TODO: once we support multiple cameras, wait for them all, not just the first
                    [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
                }
           }];
        }];
    }
    _active = activeCamera;
    if (_active)
    {
        if (_noSleepAssertion == 0)
        {
            IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleSystemSleep,
                                               CFSTR("Live Camera View"),
                                               CFSTR("Maintaining connection to camera"),
                                               NULL,
                                               NULL,
                                               0,
                                               NULL,
                                               &_noSleepAssertion);
        }
        self.toolbarDelegate.status = @"Starting";
        [_cameraService.remoteObjectProxy startForDescription:_active withReply:^(NSError *error) {
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                if (error)
                {
                    self.toolbarDelegate.status = @"Camera Error";
                }
                else
                {
                    self.toolbarDelegate.status = @"Active";
                }
            }];
        }];
    }
    else
    {
        if (!stopping)
        {
            [self setIdleStatus];
        }
        if (_noSleepAssertion)
        {
            IOPMAssertionRelease(_noSleepAssertion);
            _noSleepAssertion = 0;
        }
    }
}

- (void)setIdleStatus
{
    if (self.cameras.count)
    {
        self.toolbarDelegate.status = @"Ready";
    }
    else
    {
        self.toolbarDelegate.status = @"No Camera";
    }
}

- (IBAction)goToWebIssues:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/v002/v002-Camera-Live/issues"]];
}

// swizzle -[ICCameraDevice registerForImageCaptureEventNotifications:] to prevent ImageCapture stuff from crashing on 10.13.
// TODO: avoid this if we can

static void newProcess(id instance, SEL selector, void *arg1)
{
    // do nothing
}

void patchICCameraDeviceImageCaptureStuff()
{
    Class nsClass;
    Method method;
    nsClass = objc_getClass("ICCameraDevice");
    if (nsClass)
    {
        method = class_getInstanceMethod(nsClass, NSSelectorFromString(@"registerForImageCaptureEventNotifications:"));
        
        if (method)
        {
            method_setImplementation(method, (IMP)newProcess);
        }

        method = class_getInstanceMethod(nsClass, NSSelectorFromString(@"handleContent:"));

        if (method)
        {
            method_setImplementation(method, (IMP)newProcess);
        }
    }
}

+(void)load
{
    patchICCameraDeviceImageCaptureStuff();
}

- (IBAction)cameraDescriptionToClipboard:(id)sender
{
    NSInteger index = self.tableView.selectedRow;
    if (self.cameras.count > index)
    {
        [_cameraService.remoteObjectProxy infoTextForDescription:self.cameras[index] withReply:^(NSString *state, NSError *error) {
            [NSOperationQueue.mainQueue addOperationWithBlock:^{
                if (error)
                {
                    [[NSApplication sharedApplication] presentError:error];
                }
                else
                {
                    [NSPasteboard.generalPasteboard clearContents];
                    [NSPasteboard.generalPasteboard setString:state forType:NSPasteboardTypeString];
                }
            }];
        }];
    }
}

@end
