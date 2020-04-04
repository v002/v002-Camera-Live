//
//  SyPGPhotoContext.m
//  CameraService
//
//  Created by Tom Butterworth on 29/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPGPhotoContext.h"
#import <gphoto2/gphoto2.h>
#include "SyPGPhotoUtility.h"
#include "SyPGPhotoCamera.h"
#include "CameraPresenceProtocol.h"
#include "SyPCameraKeys.h"
#include <os/log.h>

static void
context_error_callback(GPContext *context, const char *str, void *data)
{
    os_log_error(OS_LOG_DEFAULT, "libgphoto2: %{public}s", str);
}

static void
context_status_callback(GPContext *context, const char *str, void *data)
{
    os_log_info(OS_LOG_DEFAULT, "libgphoto2: %{public}s", str);
}

@interface SyPGPhotoCamera (Context)
- (instancetype)initWithContext:(SyPGPhotoContext *)context camera:(Camera *)camera description:(NSDictionary *)description;
@end

@implementation SyPGPhotoContext {
    GPContext *_context;
    CameraAbilitiesList *_cal;
    GPPortInfoList *_pil;
    NSMutableSet *_active;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // Tell libgphoto2 to use our bundled cam libs
            NSURL *base = [NSBundle bundleForClass:[self class]].builtInPlugInsURL;
            NSURL *iolibsurl = [base URLByAppendingPathComponent:@"Ports" isDirectory:YES];
            NSURL *camlibsurl = [base URLByAppendingPathComponent:@"Cameras" isDirectory:YES];
            setenv("IOLIBS", iolibsurl.fileSystemRepresentation, 1);
            setenv("CAMLIBS", camlibsurl.fileSystemRepresentation, 1);
        });
        _context = gp_context_new();
        if (!_context)
        {
            self = nil;
        }
        else
        {
            gp_context_set_error_func (_context, context_error_callback, NULL);
            gp_context_set_status_func (_context, context_status_callback, NULL);
        }
    }
    return self;
}

- (void)dealloc
{
    if (_cal)
    {
        gp_abilities_list_free(_cal);
    }
    if (_pil)
    {
        gp_port_info_list_free(_pil);
    }
    if (_context)
    {
        gp_context_unref(_context);
    }
}

- (GPContext *)GPContext
{
    return _context;
}

- (SyPGPhotoCamera *)cameraForDescription:(NSDictionary<NSString *,id> *)description withError:(NSError **)error
{
    Camera *camera;
    NSString *model = [description objectForKey:kSyPGPhotoKeyLibraryModel];
    NSString *port = [description objectForKey:kSyPGPhotoKeyPort];
    [self use:description];
    int result = camera_open(&camera, model.UTF8String, port.UTF8String, _context, &_pil, &_cal);
    if (error)
    {
        *error = [[self class] errorForResult:result];
    }
    if (result == GP_OK)
    {
        SyPGPhotoCamera *cam = [[SyPGPhotoCamera alloc] initWithContext:self camera:camera description:description];
        gp_camera_unref(camera); // ref'd by cam
        return cam;
    }
    [[self class] end:description];
    os_log_error(OS_LOG_DEFAULT, "Couldn't open camera: %d %{public}s", result, gp_result_as_string(result));
    return nil;
}

- (NSSet<NSDictionary<NSString *, id> *> *)getConnectedCameraInfo
{
    NSMutableSet *cameras = [NSMutableSet setWithCapacity:1];

    CameraList *list = NULL;
    int result = gp_list_new(&list);
    if (result == GP_OK)
    {
        gp_list_reset(list);
        int count = gp_camera_autodetect(list, _context);

        for (int i = 0; i < count && result == GP_OK; i++)
        {
            const char *name, *port;

            gp_list_get_name(list, i, &name);
            gp_list_get_value(list, i, &port);

            NSDictionary<NSString *,id> * existing = [self activeCameraForModel:[NSString stringWithUTF8String:name]
                                                                           port:[NSString stringWithUTF8String:port]];
            if (existing)
            {
                [cameras addObject:existing];
                continue;
            }

            Camera *camera = NULL;
            result = camera_open(&camera, name, port, _context, &_pil, &_cal);

            if (result == GP_OK)
            {
                NSMutableDictionary *description = [NSMutableDictionary dictionaryWithCapacity:3];

                [description setObject:[NSString stringWithUTF8String:name] forKey:kSyPGPhotoKeyLibraryModel];
                [description setObject:[NSString stringWithUTF8String:port] forKey:kSyPGPhotoKeyPort];

                char *model = NULL, *serial = NULL, *eosserial = NULL;

                camera_get_config_value_string(camera, "cameramodel", &model, _context);
                camera_get_config_value_string(camera, "serialnumber", &serial, _context);
                camera_get_config_value_string(camera, "eosserialnumber", &eosserial, _context);

                gp_camera_unref(camera);

                if (model)
                {
                    [description setObject:[NSString stringWithUTF8String:model] forKey:kSyPGPhotoKeyName];
                    free(model);
                }
                else
                {
                    [description setObject:[NSString stringWithUTF8String:name] forKey:kSyPGPhotoKeyName];
                }

                if (serial)
                {
                    [description setObject:[NSString stringWithUTF8String:serial] forKey:kSyPGPhotoKeyIdentifier];
                    free(serial);
                }
                else
                {
                    [description setObject:[NSString stringWithFormat:@"%s!%s", name, port] forKey:kSyPGPhotoKeyIdentifier];
                    os_log_info(OS_LOG_DEFAULT, "using ad-hoc identifier for camera");
                }

                if (eosserial)
                {
                    [description setObject:[NSString stringWithUTF8String:eosserial] forKey:kSyPGPhotoKeyEOSSerial];
                    free(eosserial);
                }

                [cameras addObject:description];
            }
            else
            {
                os_log_info(OS_LOG_DEFAULT, "camera_open failed during enumeration for %{public}s (%{public}s): %{public}s", name, port, gp_result_as_string(result));
            }
        }
        gp_list_unref(list);
    }

    return cameras;
}

+ (NSError *)errorForResult:(int)result
{
    if (result == GP_OK)
    {
        return nil;
    }
    const char *str = gp_result_as_string(result);
    return [NSError errorWithDomain:@"SyPGPhotoErrorDomain"
                               code:result
                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error communicating with the camera:\n %s", str]}];
}

+ (BOOL)errorIsFatal:(NSError *)error
{
    if ([error.domain isEqualToString:@"SyPGPhotoErrorDomain"])
    {
        switch (error.code) {
            // TODO: more
            case GP_ERROR_IO_USB_FIND:
                return YES;
            default:
                break;
        }
    }
    return NO;
}

- (NSMutableSet *)activeSet
{
    if (!_active)
    {
        _active = [NSMutableSet setWithCapacity:1];
    }
    return _active;
}

- (void)use:(NSDictionary<NSString *,id> *)camera
{
    @synchronized(self) {
        [[self activeSet] addObject:camera];
    }
}

- (void)end:(NSDictionary<NSString *,id> *)camera
{
    @synchronized(self) {
        [[self activeSet] removeObject:camera];
    }
}

- (NSDictionary<NSString *,id> *)activeCameraForModel:(NSString *)model port:(NSString *)port
{
    @synchronized(self) {
        for (NSDictionary<NSString *,id> *candidate in [self activeSet]) {
            if ([candidate[kSyPGPhotoKeyLibraryModel] isEqualToString:model] &&
                [candidate[kSyPGPhotoKeyPort] isEqualToString:port])
            {
                return candidate;
            }
        }
    }
    return nil;
}
@end
