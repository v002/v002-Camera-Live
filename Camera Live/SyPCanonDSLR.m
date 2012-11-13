/*
 SyPCanonDSLR.m
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

#import "SyPCanonDSLR.h"
#import "SyPCanonEVFImageBuffer.h"

@interface SyPCanonDSLR (Private)
+ (NSError *)errorForEDSError:(EdsError)code;
- (id)initWithCanonCameraRef:(EdsCameraRef)ref;
@property (readonly) EdsDeviceInfo *deviceInfo;
- (void)extendShutdown;
- (dispatch_queue_t)cameraQueue;
@end

/*
 Only call the following on cameraQueue:
 */
@interface SyPCanonDSLR (Camera)
- (NSError *)startSessionOnQueue;
- (NSError *)endSessionOnQueue;
- (SyPImageBuffer *)newLiveViewImageOnQueueWithError:(NSError **)error;
- (void)endTimerOnQueue;
@end

static EdsError SyPCanonDSLRHandleCameraAdded(EdsVoid *inContext )
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSSet *currentCameras = [[[SyPCamera cameras] copy] autorelease];
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
                EdsDeviceInfo info;
                result = EdsGetChildAtIndex(list, i, &camera);
                if (result == EDS_ERR_OK)
                {
                    result = EdsGetDeviceInfo(camera, &info);
                    if (result == EDS_ERR_OK)
                    {
                        BOOL isNew = YES;
                        for (SyPCamera *camera in currentCameras)
                        {
                            if ([camera isKindOfClass:[SyPCanonDSLR class]] && strcmp(info.szPortName, ((SyPCanonDSLR *)camera).deviceInfo->szPortName) == 0)
                            {
                                isNew = NO;
                            }
                        }
                        if (isNew)
                        {
                            SyPCanonDSLR *this = [[SyPCanonDSLR alloc] initWithCanonCameraRef:camera];
                            [SyPCamera addCamera:this];
//                            NSLog(@"added: %@", [this description]);
                            [this release];
                        }
                    }
                    EdsRelease(camera);
                }
            }
        }
        EdsRelease(list);
    }
    [pool drain];
    return EDS_ERR_OK;
}

/*
static EdsError SyPCanonDSLRHandlePropertyEvent(EdsPropertyEvent        inEvent,
                                                EdsPropertyID           inPropertyID,
                                                EdsUInt32               inParam,
                                                EdsVoid *               inContext)
{
//    NSLog(@"property propertyID %08lX param %lu", inPropertyID, inParam);
    return EDS_ERR_OK;
}
*/

static EdsError SyPCanonDSLRHandleStateEvent(EdsStateEvent           inEvent,
                                             EdsUInt32               inEventData,
                                             EdsVoid *               inContext)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (inEvent == kEdsStateEvent_Shutdown)
    {
        [(SyPCanonDSLR *)inContext retain];
        [SyPCamera removeCamera:(SyPCanonDSLR *)inContext];
//        NSLog(@"removed: %@", [(SyPCanonDSLR *)inContext description]);
        [(SyPCanonDSLR *)inContext release];
    }
    else if (inEvent == kEdsStateEvent_WillSoonShutDown)
    {
        [(SyPCanonDSLR *)inContext extendShutdown];
    }
//    else
//    {
//        NSLog(@"new state %lu", inEvent);
//    }
    [pool drain];
    return EDS_ERR_OK;
}

@implementation SyPCanonDSLR

+ (void)load
{
    EdsInitializeSDK();
    EdsSetCameraAddedHandler(SyPCanonDSLRHandleCameraAdded, NULL);
    SyPCanonDSLRHandleCameraAdded(NULL);
}

__attribute__((destructor)) static void finalizer()
{
	EdsTerminateSDK();
}

+ (NSError *)errorForEDSError:(EdsError)code
{
    if (code != EDS_ERR_OK)
    {
        return [NSError errorWithDomain:@"SyPCanonErrorDomain" code:code userInfo:nil];
    }
    else
    {
        return nil;
    }
}

- (id)initWithCanonCameraRef:(EdsCameraRef)ref
{
    self = [super init];
    if (self)
    {
        EdsRetain(ref);
        _camera = ref;
        
        EdsError result = EdsGetDeviceInfo(_camera, &_info);
        /*
        if (result == EDS_ERR_OK)
        {
            result = EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, SyPCanonDSLRHandlePropertyEvent, self);
        }
         */
        if (result == EDS_ERR_OK)
        {
            result = EdsSetCameraStateEventHandler(_camera, kEdsStateEvent_All, SyPCanonDSLRHandleStateEvent, self);
        }
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
//    EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, NULL, NULL);
    EdsSetCameraStateEventHandler(_camera, kEdsStateEvent_All, NULL, NULL);
    EdsRelease(_camera);
    if (_queue) dispatch_release(_queue);
    [super dealloc];
}

- (dispatch_queue_t)cameraQueue
{
    if (_queue == NULL)
    {
        dispatch_queue_t queue = dispatch_queue_create("info.v002.Camera-Live.Canon.liveview", DISPATCH_QUEUE_SERIAL);
        if (!OSAtomicCompareAndSwapPtr(NULL, queue, (void **)&_queue))
        {
            dispatch_release(queue);
        }
    }
    return _queue;
}

- (NSString *)name
{
    return [NSString stringWithCString:_info.szDeviceDescription encoding:NSUTF8StringEncoding];
}

- (NSString *)identifier
{
    if (_identifier == nil)
    {
        dispatch_sync([self cameraQueue], ^{
            if ([self startSessionOnQueue] == nil)
            {
                EdsDataType propType;
                EdsUInt32 propSize = 0;
                
                EdsError error = EdsGetPropertySize(_camera, kEdsPropID_BodyIDEx, 0, &propType, &propSize);
                
                if (error == EDS_ERR_OK && propSize > 0)
                {
                    char uidCString[propSize];
                    
                    error = EdsGetPropertyData(_camera, kEdsPropID_BodyIDEx, 0, propSize, &uidCString);
                    
                    if (error == EDS_ERR_OK)
                    {
                        NSString *identifier = [@"SyPCanonDSLR-" stringByAppendingString:[NSString stringWithCString:uidCString encoding:NSASCIIStringEncoding]];
                        [identifier retain];
                        if (!OSAtomicCompareAndSwapPtr(nil, identifier, (void **)&_identifier))
                        {
                            [identifier release];
                        }
                    }
                }
                [self endSessionOnQueue];
            }
        });
    }
    return _identifier;
}

- (EdsDeviceInfo *)deviceInfo
{
    return &_info;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%p {%s, %s, %lu, %lu}", _camera, _info.szPortName, _info.szDeviceDescription, _info.deviceSubType, _info.reserved];
}

- (void)extendShutdown
{
    dispatch_async([self cameraQueue], ^{
        EdsSendCommand(_camera, kEdsCameraCommand_ExtendShutDownTimer, 0);
    });
}

- (void)startToObserveSleepWithQueue:(dispatch_queue_t)queue handler:(SyPCameraImageHandler)handler
{
    _sleepObserver = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceWillSleepNotification
                                                                                     object:nil
                                                                                      queue:nil
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                     [self stopLiveView];
                                                                                     [self startToObserveWakeWithQueue:queue handler:handler];
                                                                                 }];
}

- (void)startToObserveWakeWithQueue:(dispatch_queue_t)queue handler:(SyPCameraImageHandler)handler
{
    _wakeObserver = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidWakeNotification
                                                                                    object:nil
                                                                                     queue:nil
                                                                                usingBlock:^(NSNotification *note) {
                                                                                    [self resumeLiveViewOnQueue:queue
                                                                                                    withHandler:handler];
                                                                                }];
}

- (void)resumeLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:_wakeObserver];
    _wakeObserver = nil;
    [self startLiveViewOnQueue:queue withHandler:handler];
}

- (void)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler
{
    dispatch_async([self cameraQueue], ^{
        _timersAlive += 2;
    });
    
    dispatch_async([self cameraQueue], ^{
        NSError *error = [self startSessionOnQueue];
        if (error) handler(nil, error);
    });
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [self cameraQueue]);
    dispatch_source_set_event_handler(_timer, ^{
        // TODO: this causes a retain loop until the source is cancelled, we could avoid that
        NSError *error = nil;
        SyPImageBuffer *image = [self newLiveViewImageOnQueueWithError:&error];
        if (image || error) dispatch_async(queue, ^{
            handler(image, error);
        });
        [image release];
    });
    dispatch_source_set_cancel_handler(_timer, ^{
        [self endTimerOnQueue];
    });
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 60, 0);
    
    _stayAliveTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [self cameraQueue]);
    dispatch_source_set_event_handler(_stayAliveTimer, ^{
        // Periodically set live view, otherwise it stops of its own accord after 30 minutes
        EdsUInt32 device;
        EdsError err = EdsGetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
        if(err == EDS_ERR_OK)
        {
            device |= kEdsEvfOutputDevice_PC;
            EdsSetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0 , sizeof(device), &device);
        }
    });
    dispatch_source_set_cancel_handler(_stayAliveTimer, ^{
        [self endTimerOnQueue];
    });
    dispatch_source_set_timer(_stayAliveTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC * 60 * 28, NSEC_PER_SEC * 30);
    dispatch_resume(_stayAliveTimer);
    dispatch_resume(_timer);
    
    [self startToObserveSleepWithQueue:queue handler:handler];
}

- (void)stopLiveView
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:_sleepObserver];
    _sleepObserver = nil;
    dispatch_source_cancel(_timer);
    dispatch_release(_timer);
    _timer = NULL;
    dispatch_source_cancel(_stayAliveTimer);
    dispatch_release(_stayAliveTimer);
    _stayAliveTimer = NULL;
}
@end

@implementation SyPCanonDSLR (Camera)

static SyPCanonDSLR *mSession;

- (NSError *)startSessionOnQueue
{
    NSError *error = nil;
    if (!_hasSession)
    {
        if (OSAtomicCompareAndSwapPtrBarrier(NULL, self, (void **)&mSession))
        {
            _hasSession = YES;
            EdsError result = EdsOpenSession(_camera);
            error = [SyPCanonDSLR errorForEDSError:result];
        }
        else
        {
            error = [NSError errorWithDomain:@"SyPErrorDomain" code:1 userInfo:nil];
        }
    }
    return error;
}

- (NSError *)endSessionOnQueue
{
    NSError *error = nil;
    if (_hasSession)
    {
        OSAtomicCompareAndSwapPtrBarrier(self, NULL, (void **)&mSession);
        _hasSession = NO;
        EdsError result = EdsCloseSession(_camera);
        error = [SyPCanonDSLR errorForEDSError:result];
    }
    return error;
}

- (void)endTimerOnQueue
{
    _timersAlive--;
    if (_timersAlive == 0)
    {
        // Get the output device for the live view image
        EdsUInt32 device;
        EdsError err = EdsGetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
        // PC live view ends if the PC is disconnected from the live view image output device.
        if(err == EDS_ERR_OK)
        {
            device &= ~kEdsEvfOutputDevice_PC;
            EdsSetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0 , sizeof(device), &device);
        }
        
        [self endSessionOnQueue];
    }
}

- (SyPImageBuffer *)newLiveViewImageOnQueueWithError:(NSError **)error
{
    SyPCanonEVFImageBuffer *image = [[SyPCanonEVFImageBuffer alloc] init];
    if (image)
    {
        EdsStreamRef stream = image.stream;
        EdsEvfImageRef evfImage;
        EdsError result = EdsCreateEvfImageRef(stream, &evfImage);
        if (result == EDS_ERR_OK)
        {
            result = EdsDownloadEvfImage(_camera, evfImage);
            EdsRelease(evfImage);
        }
        if (result != EDS_ERR_OK)
        {
            if (result != EDS_ERR_OBJECT_NOTREADY)
            {
                *error = [SyPCanonDSLR errorForEDSError:result];
            }
            [image release];
            image = nil;
        }
    }
    return image;
}

@end
