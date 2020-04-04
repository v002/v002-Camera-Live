//
//  SyPLiveViewSession.m
//  CameraService
//
//  Created by Tom Butterworth on 31/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPLiveViewSession.h"
#import "SyPGPhotoCamera.h"
#import "SyPGPhotoContext.h"
#import "SyPSyphonServer.h"
#import "SyPCameraKeys.h"

@interface SyPLiveViewSession ()
@property (readwrite, atomic, strong) SyPImageBuffer *buffer;
@end

@implementation SyPLiveViewSession {
    NSDictionary<NSString *, id> *_description;
    NSCondition *_condition;
    BOOL _waitable;
    SyPGPhotoContext *_context;
    void (^_reply)(NSError *);
}

- (id)initWithCamera:(NSDictionary<NSString *, id> *)description context:(SyPGPhotoContext *)context withReply:(void (^)(NSError *))reply
{
    self = [super init];
    if (self)
    {
        _description = description;
        _context = context;
        _condition = [NSCondition new];
        _reply = reply;
        self.name = [@"info.v002.camera-live.camera." stringByAppendingString:_description[kSyPGPhotoKeyIdentifier]];
    }
    return self;
}

- (void)start
{
    [_condition lock];
    _waitable = YES;
    [_condition unlock];
    [super start];
}

- (void)main
{
    id activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep | NSActivityLatencyCritical reason:@"Camera running"];

    NSError *error = nil;

    SyPGPhotoCamera *camera = [_context cameraForDescription:_description withError:&error];

    SyPSyphonServer *server = [[SyPSyphonServer alloc] initWithName:_description[kSyPGPhotoKeyName]];

    dispatch_queue_t queue = dispatch_queue_create([@"info.v002.camera-live.syphon." stringByAppendingString:_description[kSyPGPhotoKeyIdentifier]].UTF8String,
                                                   dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1));

    // Use a dispatch source so we coalesce frame updates if the server can't keep up
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, queue);

    dispatch_source_set_event_handler(source, ^{
        unsigned long fires = dispatch_source_get_data(source);
        if (fires > 0)
        {
            NSError *e = [server output:self.buffer];
            if (e)
            {
                self.errorHandler(e);
            }
        }
    });

    dispatch_activate(source);

    [camera startLiveView];

    _reply(error);
    _reply = nil;

    if (!error)
    {
        while (!self.isCancelled)
        {
            @autoreleasepool {
                SyPImageBuffer *buffer = [camera getImageWithError:&error];
                if (buffer)
                {
                    self.buffer = buffer;
                    dispatch_source_merge_data(source, 1);
                }
                if (error)
                {
                    if ([SyPGPhotoContext errorIsFatal:error])
                    {
                        [self cancel];
                    }
                    self.errorHandler(error);
                }
            }
        }
    }

    dispatch_source_cancel(source);

    [camera stopLiveView];

    [[NSProcessInfo processInfo] endActivity:activity];

    [_condition lock];
    _waitable = NO;
    [_condition broadcast];
    [_condition unlock];
}

- (void)endSession
{
    [self cancel];
    [_condition lock];
    if (_waitable)
    {
        [_condition wait];
    }
    [_condition unlock];
}
@end
