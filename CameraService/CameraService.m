//
//  CameraService.m
//  CameraService
//
//  Created by Tom Butterworth on 26/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "CameraService.h"
#import "SyPUSBHotplugWatcher.h"
#import "CameraErrors.h"
#import "SyPGPhotoContext.h"
#import "SyPGPhotoCamera.h"
#import "SyPLiveViewSession.h"
#import "SyPCameraKeys.h"

@implementation CameraService {
    SyPUSBHotplugWatcher *_watcher;
    dispatch_queue_t _watcherQueue;
    NSSet<NSDictionary<NSString *, id> *> *_cameras;
    NSMutableDictionary<NSString *, SyPLiveViewSession *> *_sessions;
    SyPGPhotoContext *_context;
}

static int theInstanceCount = 0;

- (void)startWithReply:(void (^)(NSError *))reply
{
    if (!_context)
    {
        _context = [SyPGPhotoContext new];
    }
    [[NSProcessInfo processInfo] disableAutomaticTermination:@"Camera Presence"];
    assert(theInstanceCount == 0);
    theInstanceCount++;
    // TODO: rejig watcher to simply use its own queue
    _watcherQueue = dispatch_queue_create("info.v002.camera-live.camera-presence", DISPATCH_QUEUE_SERIAL);
    _watcher = [[SyPUSBHotplugWatcher alloc] initWithQueue:_watcherQueue handler:^(SyPUSBHotplugEvent event, NSError * _Nullable error) {
        [self handleUSBHotplug:event withError:error];
    }];
    if (!_watcher)
    {
        reply([NSError errorWithDomain:kCameraErrorDomain
                                  code:CameraErrorDeviceEnumerationError
                              userInfo:@{NSLocalizedDescriptionKey: @"Could not start USB device detection."}]);
    }
    else
    {
        reply(nil);
    }
}


- (void)stop
{
    _watcher = nil;
    _watcherQueue = nil;
    [[NSProcessInfo processInfo] enableAutomaticTermination:@"Camera Presence"];
    theInstanceCount--;
}

- (void)startForDescription:(NSDictionary *)description withReply:(void (^)(NSError *))reply
{
    if (!_sessions)
    {
        _sessions = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    NSString *identifier = [description objectForKey:kSyPGPhotoKeyIdentifier];
    if (identifier)
    {
        [_sessions setValue:[[SyPLiveViewSession alloc] initWithCamera:description context:_context withReply:reply] forKey:identifier];
        [_sessions objectForKey:identifier].qualityOfService = NSQualityOfServiceUserInteractive;
        [_sessions objectForKey:identifier].errorHandler = ^(NSError * _Nonnull error) {
            [self.connection.remoteObjectProxy error:error forCamera:description];
        };
        [[_sessions objectForKey:identifier] start];
        // session will call reply for us once it is running
    }
    else
    {
        reply([NSError errorWithDomain:@"SyPServiceErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"A camera could not be identified"}]);
    }
    xpc_transaction_begin();
}


- (void)stopForDescription:(NSDictionary *)description withReply:(void (^)(NSError *))reply
{
    NSString *identifier = [description objectForKey:kSyPGPhotoKeyIdentifier];
    if (identifier)
    {
        [[_sessions objectForKey:identifier] endSession];
        [_sessions objectForKey:identifier].errorHandler = nil;
        [_sessions removeObjectForKey:identifier];
        xpc_transaction_end();
    }
    reply(nil); // This reply is needed to let the host know we finished
}

- (void)infoTextForDescription:(NSDictionary *)description withReply:(void (^)(NSString *, NSError *))reply
{
    NSError *error = nil;
    SyPGPhotoCamera *camera = [_context cameraForDescription:description
                                                   withError:&error];
    NSString *state = [camera stateStringWithError:&error];
    reply(state, error);
}

- (void)handleUSBHotplug:(SyPUSBHotplugEvent)event withError:(NSError * _Nullable)error
{
    if (event == SypUSBHotplugError)
    {
        // TODO: handle error
    }
    else
    {
        NSSet<NSDictionary<NSString *, id> *> *cameras = [_context getConnectedCameraInfo];
        NSSet *removed = [_cameras objectsPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull obj, BOOL * _Nonnull stop) {
            return ![cameras containsObject:obj];
        }];
        NSSet *added = [cameras objectsPassingTest:^BOOL(NSDictionary<NSString *,id> * _Nonnull obj, BOOL * _Nonnull stop) {
            return ![_cameras containsObject:obj];
        }];
        _cameras = cameras;
        for (NSDictionary<NSString *,id> *camera in removed)
        {
            [self.connection.remoteObjectProxy removeCamera:camera];
        }
        for (NSDictionary<NSString *,id> *camera in added)
        {
            [self.connection.remoteObjectProxy addCamera:camera];
        }
    }
}

@end
