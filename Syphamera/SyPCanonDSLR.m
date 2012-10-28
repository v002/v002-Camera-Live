//
//  SyPCanonDSLR.m
//  Syphamera
//
//  Created by Tom Butterworth on 03/09/2012.
//  Copyright (c) 2012 Tom Butterworth. All rights reserved.
//

#import "SyPCanonDSLR.h"
#import "SyPCanonEVFImageBuffer.h"

static EdsError SyPCanonDSLRHandleObjectEvent(EdsObjectEvent          inEvent,
                                              EdsBaseRef              inRef,
                                              EdsVoid *               inContext)
{
//    NSLog(@"object");
    return EDS_ERR_OK;
}

static EdsError SyPCanonDSLRHandlePropertyEvent(EdsPropertyEvent        inEvent,
                                                EdsPropertyID           inPropertyID,
                                                EdsUInt32               inParam,
                                                EdsVoid *               inContext)
{
//    NSLog(@"property");
    return EDS_ERR_OK;
}

static EdsError SyPCanonDSLRHandleStateEvent(EdsPropertyEvent        inEvent,
                                             EdsPropertyID           inPropertyID,
                                             EdsUInt32               inParam,
                                             EdsVoid *               inContext)
{
//    NSLog(@"state");
    return EDS_ERR_OK;
}

@interface SyPCanonDSLR (Private)
+ (NSError *)errorForEDSError:(EdsError)code;
- (NSError *)startSession;
- (NSError *)endSession;
@end

@implementation SyPCanonDSLR

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
        
        EdsError result = EdsSetObjectEventHandler(_camera, kEdsObjectEvent_All, SyPCanonDSLRHandleObjectEvent, self);
        if (result == EDS_ERR_OK)
        {
            result = EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, SyPCanonDSLRHandlePropertyEvent, self);
        }
        if (result == EDS_ERR_OK)
        {
            result = EdsSetPropertyEventHandler(_camera, kEdsStateEvent_All, SyPCanonDSLRHandleStateEvent, self);
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
    EdsCloseSession(_camera);
    EdsSetObjectEventHandler(_camera, kEdsObjectEvent_All, NULL, NULL);
    EdsSetPropertyEventHandler(_camera, kEdsPropertyEvent_All, NULL, NULL);
    EdsSetPropertyEventHandler(_camera, kEdsStateEvent_All, NULL, NULL);
    EdsRelease(_camera);
    [super dealloc];
}

- (NSString *)name
{
    EdsDeviceInfo info;
    EdsError result = EdsGetDeviceInfo(_camera, &info);
    if (result == EDS_ERR_OK)
    {
        return [NSString stringWithCString:info.szDeviceDescription encoding:NSUTF8StringEncoding];
    }
    else
    {
        return [super name];
    }
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

- (NSError *)startLiveViewWithHandler:(SyPCameraImageHandler)handler
{
    NSError *error = [self startSession];
    if (error) return error;
    
    EdsError result = EDS_ERR_OK;
    // Get the output device for the live view image
    EdsUInt32 device;
    result = EdsGetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
    // PC live view starts by setting the PC as the output device for the live view image.
    if(result == EDS_ERR_OK)
    {
        device |= kEdsEvfOutputDevice_PC;
        result = EdsSetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0 , sizeof(device), &device);
    }
    if (result == EDS_ERR_OK)
    {
        dispatch_queue_t queue = dispatch_queue_create("cx.kriss.syphamera.canon-dslr.liveview", DISPATCH_QUEUE_SERIAL);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_release(queue);
        dispatch_source_set_event_handler(_timer, ^{
            // TODO: this causes a retain loop until the source is cancelled, we could avoid that
            SyPImageBuffer *image = [self newLiveViewImage];
            handler(self, image);
            [image release];
        });
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 60, 0);
        dispatch_resume(_timer);
    }
    return [SyPCanonDSLR errorForEDSError:result];
}

- (NSError *)stopLiveView
{
    EdsError err = EDS_ERR_OK;
    // Get the output device for the live view image
    EdsUInt32 device;
    err = EdsGetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0, sizeof(device), &device);
    // PC live view ends if the PC is disconnected from the live view image output device.
    if(err == EDS_ERR_OK)
    {
        device &= ~kEdsEvfOutputDevice_PC;
        err = EdsSetPropertyData(_camera, kEdsPropID_Evf_OutputDevice, 0 , sizeof(device), &device);
    }
    
    [self endSession];
    
    dispatch_source_cancel(_timer);
    dispatch_release(_timer);
    _timer = NULL;
    
    return [SyPCanonDSLR errorForEDSError:err];
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
@end
