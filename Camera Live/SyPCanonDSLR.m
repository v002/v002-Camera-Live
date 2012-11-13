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
+ (void)handleCameraConnectionEvent;
+ (NSError *)errorForEDSError:(EdsError)code;
- (id)initWithCanonCameraRef:(EdsCameraRef)ref;
@property (readonly) EdsDeviceInfo *deviceInfo;
- (NSError *)startSession;
- (NSError *)endSession;
- (dispatch_queue_t)cameraQueue;
- (void)extendShutdown;
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

static EdsError SyPCanonDSLRHandlePropertyEvent(EdsPropertyEvent        inEvent,
                                                EdsPropertyID           inPropertyID,
                                                EdsUInt32               inParam,
                                                EdsVoid *               inContext)
{
//    NSLog(@"property propertyID %08lX param %lu", inPropertyID, inParam);
    return EDS_ERR_OK;
}

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
        [self startSession];
        if (result == EDS_ERR_OK)
        {
            result = EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, SyPCanonDSLRHandlePropertyEvent, self);
        }
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
    [self endSession];
    EdsSetObjectEventHandler(_camera, kEdsObjectEvent_All, NULL, NULL);
    EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, NULL, NULL);
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
        if ([self startSession] == nil)
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
            [self endSession];
        }
    }
    return _identifier;
}

static SyPCanonDSLR *mSession;

- (NSError *)startSession
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

- (NSError *)endSession
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

- (void)extendShutdown
{
    dispatch_async([self cameraQueue], ^{
        EdsSendCommand(_camera, kEdsCameraCommand_ExtendShutDownTimer, 0);
    });
}

- (void)endTimer
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
        
        [self endSession];
    }
}

- (void)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler
{
    dispatch_async([self cameraQueue], ^{
        _timersAlive += 2;
    });
    
    dispatch_async([self cameraQueue], ^{
        NSError *error = [self startSession];
        if (error) handler(nil, error);
    });
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [self cameraQueue]);
    dispatch_source_set_event_handler(_timer, ^{
        // TODO: this causes a retain loop until the source is cancelled, we could avoid that
        SyPImageBuffer *image = [self newLiveViewImage];
        if (image) dispatch_async(queue, ^{
            handler(image, nil);
        });
        [image release];
    });
    dispatch_source_set_cancel_handler(_timer, ^{
        [self endTimer];
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
        [self endTimer];
    });
    dispatch_source_set_timer(_stayAliveTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC * 60 * 28, NSEC_PER_SEC * 30);
    dispatch_resume(_stayAliveTimer);
    dispatch_resume(_timer);
}

- (void)stopLiveView
{    
    dispatch_source_cancel(_timer);
    dispatch_release(_timer);
    _timer = NULL;
    dispatch_source_cancel(_stayAliveTimer);
    dispatch_release(_stayAliveTimer);
    _stayAliveTimer = NULL;
}

- (SyPImage *)newLiveViewImage
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
            [image release];
            image = nil;
        }
    }
    return image;
}

- (EdsDeviceInfo *)deviceInfo
{
    return &_info;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%p {%s, %s, %lu, %lu}", _camera, _info.szPortName, _info.szDeviceDescription, _info.deviceSubType, _info.reserved];
}
@end
