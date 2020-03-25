//
//  SyPGPhotoCamera.m
//  Camera Live
//
//  Created by Tom Butterworth on 22/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPGPhotoCamera.h"
#include "SyPGPhotoImageBuffer.h"
#include "SyPUSBHotplugWatcher.h"
#include <gphoto2/gphoto2.h>
#include <gphoto2/gphoto2-abilities-list.h>

@interface SyPGPhotoCamera (Private)
@property (class, readwrite, strong) SyPUSBHotplugWatcher *hotplug;
@property (class, readwrite) GPContext *cameraContext;
@property (class, readwrite, strong) dispatch_queue_t cameraQueue;
+ (void)updateCameraList;
@end

/*
 libgphoto2 cameras
 */

static void
camera_error_callback(GPContext *context, const char *str, void *data)
{
    NSLog(@"GP error: %s", str);
}

static void
camera_status_callback(GPContext *context, const char *str, void *data)
{
    NSLog(@"GP status: %s", str);
}

static int
camera_lookup_widget(CameraWidget*widget, const char *key, CameraWidget **child)
{
    int ret = gp_widget_get_child_by_name (widget, key, child);
    if (ret < GP_OK)
        ret = gp_widget_get_child_by_label (widget, key, child);
    return ret;
}

/* Based on code from libgphoto2 examples/config.c
 * Gets a string configuration value.
 * This can be:
 *  - A Text widget
 *  - The current selection of a Radio Button choice
 *  - The current selection of a Menu choice
 *
 * Sample (for Canons eg):
 *   get_config_value_string (camera, "ownername", &ownerstr, context);
 */
static int
camera_get_config_value_string(Camera *camera, const char *key, NSString **string, GPContext *context) {
    CameraWidget *widget = NULL, *child = NULL;
    CameraWidgetType type;
    int ret;
    char *val;

    ret = gp_camera_get_single_config (camera, key, &child, context);
    if (ret == GP_OK)
    {
        assert(child);
        widget = child;
    }
    else
    {
        ret = gp_camera_get_config (camera, &widget, context);
        if (ret < GP_OK)
        {
            return ret;
        }
        ret = camera_lookup_widget (widget, key, &child);
        if (ret < GP_OK)
        {
            goto out;
        }
    }

    /* This type check is optional, if you know what type the label
     * has already. If you are not sure, better check. */
    ret = gp_widget_get_type (child, &type);
    if (ret < GP_OK)
    {
        goto out;
    }
    switch (type) {
        case GP_WIDGET_MENU:
        case GP_WIDGET_RADIO:
        case GP_WIDGET_TEXT:
        break;
    default:
        ret = GP_ERROR_BAD_PARAMETERS;
        goto out;
    }

    /* This is the actual query call. Note that we just
     * a pointer reference to the string, not a copy... */
    ret = gp_widget_get_value (child, &val);
    if (ret < GP_OK)
    {
        goto out;
    }
    /* Create a new copy for our caller. */
    *string = [NSString stringWithUTF8String:val];
out:
    gp_widget_free (widget);
    return ret;
}

/*
 * This function opens a camera depending on the specified model and port.
 */
int
camera_open(Camera ** camera, const char *model, const char *port, GPContext *context) {
    int m, portIndex;
    CameraAbilities abilities;
    GPPortInfo portinfo;

    static GPPortInfoList *portinfolist = NULL;
    static CameraAbilitiesList *abilitieslist = NULL;

    int result = gp_camera_new (camera);
    if (result < GP_OK) return result;

    if (!abilitieslist)
    {
        /* Load all the camera drivers we have... */
        result = gp_abilities_list_new (&abilitieslist);
        if (result < GP_OK) return result;
        result = gp_abilities_list_load (abilitieslist, context);
        if (result < GP_OK) return result;
    }

    /* First lookup the model / driver */
    m = gp_abilities_list_lookup_model (abilitieslist, model);
    if (m < GP_OK) return result;
    result = gp_abilities_list_get_abilities (abilitieslist, m, &abilities);
    if (result < GP_OK) return result;
    result = gp_camera_set_abilities (*camera, abilities);
    if (result < GP_OK) return result;

    if (!portinfolist)
    {
        /* Load all the port drivers we have... */
        result = gp_port_info_list_new (&portinfolist);
        if (result < GP_OK) return result;
        result = gp_port_info_list_load (portinfolist);
        if (result < 0) return result;
    }

    /* Then associate the camera with the specified port */
    portIndex = gp_port_info_list_lookup_path (portinfolist, port);
    if (portIndex < GP_OK) return portIndex;
    result = gp_port_info_list_get_info (portinfolist, portIndex, &portinfo);
    if (result < GP_OK) return result;
    result = gp_camera_set_port_info (*camera, portinfo);
    if (result < GP_OK) return result;
    result = gp_camera_init(*camera, context);

    return result;
}

/*
 * This enables/disables the specific canon capture mode.
 *
 * For non canons this is not required, and will just return
 * with an error (but without negative effects).
 */
static int
canon_enable_capture(Camera *camera, int onoff, GPContext *context) {
    CameraWidget        *widget = NULL;
    CameraWidgetType    type;
    int            ret;

    ret = gp_camera_get_single_config (camera, "capture", &widget, context);
    if (ret < GP_OK)
    {
        return ret;
    }

    ret = gp_widget_get_type (widget, &type);
    if (ret < GP_OK)
    {
        goto out;
    }
    switch (type)
    {
        case GP_WIDGET_TOGGLE:
        break;
    default:
        ret = GP_ERROR_BAD_PARAMETERS;
        goto out;
    }
    /* Now set the toggle to the wanted value */
    ret = gp_widget_set_value (widget, &onoff);
    if (ret < GP_OK)
    {
        goto out;
    }
    /* OK */
    ret = gp_camera_set_single_config (camera, "capture", widget, context);
    if (ret < GP_OK)
    {
        return ret;
    }
out:
    gp_widget_free (widget);
    return ret;
}

static int
describe_widget(CameraWidget *widget, int indent, NSMutableString *destination)
{
    NSString *spaces = @" ";
    while (spaces.length < indent * 2)
    {
        spaces = [spaces stringByAppendingString:@" "];
    }
    int result = GP_OK;
    const char *name;
    const char *info;
    const char *label;
    const char *typestring;
    CameraWidgetType type;
    int readonly;
    if (result == GP_OK)
    {
        result = gp_widget_get_name(widget, &name);
    }
    if (result == GP_OK)
    {
        result = gp_widget_get_type(widget, &type);
    }
    if (result == GP_OK)
    {
        result = gp_widget_get_info(widget, &info);
    }
    if (result == GP_OK)
    {
        result = gp_widget_get_label(widget, &label);
    }
    if (result == GP_OK)
    {
        result = gp_widget_get_readonly(widget, &readonly);
    }
    if (result == GP_OK)
    {
        switch (type) {
            case GP_WIDGET_WINDOW:
                typestring = "WINDOW";
                break;
            case GP_WIDGET_SECTION:
                typestring = "SECTION";
                break;
            case GP_WIDGET_TEXT:
                typestring = "TEXT";
                break;
            case GP_WIDGET_RANGE:
                typestring = "RANGE";
                break;
            case GP_WIDGET_TOGGLE:
                typestring = "TOGGLE";
                break;
            case GP_WIDGET_RADIO:
                typestring = "RADIO";
                break;
            case GP_WIDGET_MENU:
                typestring = "MENU";
                break;
            case GP_WIDGET_BUTTON:
                typestring = "BUTTON";
                break;
            case GP_WIDGET_DATE:
                typestring = "DATE";
                break;
            default:
                assert(false);
                typestring = "UNKNOWN TYPE";
                break;
        }
    }
    int count = gp_widget_count_children(widget);
    if (result == GP_OK)
    {
        [destination appendFormat:@"%@%s %s / %s / %s / %s ", spaces, name, typestring, readonly ? "readonly" : "readwrite", label, info];
        switch (type) {
            case GP_WIDGET_MENU:
            case GP_WIDGET_RADIO:
            case GP_WIDGET_TEXT:
            {
                const char *val;
                result = gp_widget_get_value (widget, &val);
                [destination appendFormat:@"/ %s", val];
                break;
            }

            case GP_WIDGET_RANGE:
            {
                float val;
                result = gp_widget_get_value (widget, &val);
                [destination appendFormat:@"/ %f", val];
                break;
            }
                break;
            case GP_WIDGET_TOGGLE:
            case GP_WIDGET_DATE:
            {
                int val;
                result = gp_widget_get_value(widget, &val);
                [destination appendFormat:@"/ %d", val];
                break;
            }
            case GP_WIDGET_WINDOW:
            case GP_WIDGET_SECTION:
            case GP_WIDGET_BUTTON:
                // no value
                break;
        }
        [destination appendFormat:@"\n"];
    }
    if (count > 0)
    {
        [destination appendFormat:@"%@{\n", spaces];
    }
    for (int i = 0; i < count && result == GP_OK; i++)
    {
        CameraWidget *child;
        result = gp_widget_get_child(widget, i, &child);
        if (result == GP_OK)
        {
            result = describe_widget(child, indent + 1, destination);
        }
    }
    if (count > 0)
    {
        [destination appendFormat:@"%@} (%s)\n", spaces, name];
    }
    return result;
}

static int
list_widgets(Camera *camera, GPContext *context, NSString **string)
{
    CameraWidget *widget = NULL;
    CameraAbilities abilities;
    NSMutableString *s = [NSMutableString string];
    int result = gp_camera_get_abilities(camera, &abilities);
    if (result == GP_OK)
    {
        NSString *library = [NSString stringWithUTF8String:abilities.library];
        library = [library lastPathComponent];
        [s appendFormat:@"%s / %@ / porttype:%#04x / ops:%#04x / file:%#04x / folder:%#04x\n", abilities.model, library, abilities.port, abilities.operations, abilities.file_operations, abilities.folder_operations];
    }
    if (result == GP_OK)
    {
        result = gp_camera_get_config (camera, &widget, context);
    }
    if (result == GP_OK)
    {
        result = describe_widget(widget, 1, s);
    }
    *string = s;
    return result;
}

@implementation SyPGPhotoCamera {
    NSString *_name;
    NSString *_port;
    NSString *_identifier;
    NSOperationQueue *_queue;
}

static dispatch_queue_t theCameraQueue = nil;
static SyPUSBHotplugWatcher *theHotplug = nil;
static GPContext *theCameraContext = NULL;

+ (dispatch_queue_t)cameraQueue
{
    return theCameraQueue;
}

+ (void)setCameraQueue:(dispatch_queue_t)cameraQueue
{
    if (cameraQueue)
    {
        dispatch_retain(cameraQueue);
    }
    if (theCameraQueue)
    {
        dispatch_release(theCameraQueue);
    }
    theCameraQueue = cameraQueue;
}

+ (SyPUSBHotplugWatcher *)hotplug
{
    return theHotplug;
}

+ (void)setHotplug:(SyPUSBHotplugWatcher *)hotplug
{
    [hotplug retain];
    [theHotplug release];
    theHotplug = hotplug;
}

+ (GPContext *)cameraContext
{
    return theCameraContext;
}

+ (void)setCameraContext:(GPContext *)cameraContext
{
    theCameraContext = cameraContext;
}

+ (void)updateCameraList
{
    NSSet *before = [self cameras];
    NSMutableSet *added = [NSMutableSet setWithCapacity:1];
    NSMutableSet *all = [NSMutableSet setWithCapacity:1];

    CameraList *list = NULL;
    int result = gp_list_new(&list);
    if (result == GP_OK)
    {
        gp_list_reset(list);
        int count = gp_camera_autodetect(list, self.cameraContext);

        for (int i = 0; i < count && result == GP_OK; i++)
        {
            const char *name, *value;
            gp_list_get_name(list, i, &name);
            gp_list_get_value(list, i, &value);

            BOOL exists = NO;
            for (SyPGPhotoCamera *candidate in before)
            {
                if (strcmp(candidate.name.UTF8String, name) == 0 &&
                    strcmp(candidate._port.UTF8String, value) == 0)
                {
                    exists = YES;
                    break;
                }
            }
            SyPGPhotoCamera *camera = [[SyPGPhotoCamera alloc] initWithName:[NSString stringWithUTF8String:name]
                                                                       port:[NSString stringWithUTF8String:value]
                                                             loadIdentifier:!exists];
            // TODO: feed back error here
            if (camera)
            {
                if (!exists)
                {
                    [added addObject:camera];
                }
                [all addObject:camera];
            }
        }
        gp_list_unref(list);

        for (SyPGPhotoCamera *camera in before) {
            BOOL matched = NO;
            for (SyPGPhotoCamera *candidate in all) {
                if ([candidate.name isEqualToString:camera.name] &&
                    [candidate._port isEqualToString:camera._port])
                {
                    matched = YES;
                    break;
                }
            }
            if (!matched)
            {
                [self removeCamera:camera];
            }
        }
        for (SyPGPhotoCamera *camera in added)
        {
            [self addCamera:camera];
        }
    }
}

+ (NSString *)driverName
{
    return @"libgphoto2";
}

+ (void)startDriver
{
    // Tell libgphoto2 to use our bundled cam libs
    NSURL *base = [NSBundle mainBundle].builtInPlugInsURL;
    NSURL *iolibsurl = [base URLByAppendingPathComponent:@"Ports" isDirectory:YES];
    NSURL *camlibsurl = [base URLByAppendingPathComponent:@"Cameras" isDirectory:YES];
    // TODO: not the following if it remains a straight passthrough
    NSString *iolibs = [NSString stringWithFormat:@"%s", iolibsurl.fileSystemRepresentation];
    NSString *camlibs = [NSString stringWithFormat:@"%s", camlibsurl.fileSystemRepresentation];
    setenv("IOLIBS", iolibs.UTF8String, 1);
    setenv("CAMLIBS", camlibs.UTF8String, 1);

    assert(!self.cameraQueue);
    self.cameraQueue = dispatch_queue_create("info.v002.camera-live.camera-presence", DISPATCH_QUEUE_SERIAL);

    dispatch_async(self.cameraQueue, ^{
        self.cameraContext = gp_context_new();
        gp_context_set_error_func (self.cameraContext, camera_error_callback, NULL);
        gp_context_set_status_func (self.cameraContext, camera_status_callback, NULL);
    });

    dispatch_release(self.cameraQueue); // we just retained it above
    assert(!self.hotplug);
    self.hotplug = [[[SyPUSBHotplugWatcher alloc] initWithQueue:self.cameraQueue handler:^(SyPUSBHotplugEvent event, NSError * _Nullable error) {
        if (event == SypUSBHotplugError)
        {
            // TODO: handle error
        }
        else
        {
            [self updateCameraList];
        }
    }] autorelease];
}

+ (void)endDriver
{
    assert(self.hotplug);
    self.hotplug = nil;
    dispatch_sync(self.cameraQueue, ^{
        gp_context_unref(self.cameraContext);
        self.cameraContext = NULL;
    });

    self.cameraQueue = nil;
}

- (id)initWithName:(NSString *)name port:(NSString *)port loadIdentifier:(BOOL)doIdent
{
    self = [super init];
    if (self)
    {
        _name = [name retain];
        _port = [port retain];

        if (doIdent)
        {
            Camera *camera;

            int result = camera_open(&camera, name.UTF8String, port.UTF8String, [self class].cameraContext);

            NSString *serial = nil;

            if (result == GP_OK)
            {
                result = camera_get_config_value_string (camera, "serialnumber", &serial, [self class].cameraContext);

                gp_camera_unref(camera);
            }

            if ([serial isEqualToString:@"None"])
            {
                serial = nil;
            }
            if (!serial)
            {
                serial = name;
            }

            _identifier = [serial retain];

            if (result != GP_OK)
            {
                // TODO: some errors are OK
                [self release];
                self = nil;
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [_name release];
    [_identifier release];
    [_port release];
    [super dealloc];
}

- (NSString *)name
{
    return _name;
}

- (NSString *)_port
{
    return _port;
}

- (NSString *)identifier
{
    return _identifier;
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
                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:str]}];
}

- (void)startLiveViewOnQueue:(dispatch_queue_t)queue withHandler:(SyPCameraImageHandler)handler
{
    [super startLiveViewOnQueue:queue withHandler:handler];

    if (!_queue)
    {
        _queue = [[NSOperationQueue alloc] init];
        _queue.qualityOfService = NSQualityOfServiceUserInteractive;
        _queue.name = [@"info.v002.camera-live.camera." stringByAppendingString:self.identifier];
    }
    [_queue addOperationWithBlock:^{
        Camera *camera;

        int result = camera_open(&camera, self.name.UTF8String, self._port.UTF8String, [self class].cameraContext);
        if (result == GP_OK)
        {
            // libgphoto samples use this, though it doesn't appear to be necessary
            // - ignore the result as it can fail for some cameras
            canon_enable_capture(camera, 1, [self class].cameraContext);
            while (self.isInLiveView) {
                SyPGPhotoImageBuffer *file = [[SyPGPhotoImageBuffer alloc] init];
                if (file)
                {
                    result = gp_camera_capture_preview(camera, file.file, [self class].cameraContext);
                }
                NSError *error = nil;
                if (result != GP_OK)
                {
                    error = [[self class] errorForResult:result];
                }
                dispatch_async(queue, ^{
                    handler(error ? nil : file, error);
                });
                [file release];

            }
            canon_enable_capture(camera, 0, [self class].cameraContext);
            gp_camera_unref(camera);
        }
    }];
}

- (void)stopLiveView
{
    [super stopLiveView];
    // If we don't wait then during quit the camera isn't properly closed and won't connect next time
    // TODO: let this happen in the background
    [_queue waitUntilAllOperationsAreFinished];
    [_queue release];
    _queue = nil;
}

- (NSString *)stateStringWithError:(NSError **)error
{
    NSString *description = @"";
    Camera *camera;
    int result = camera_open(&camera, self.name.UTF8String, self._port.UTF8String, [self class].cameraContext);
    if (result == GP_OK)
    {
        result = list_widgets(camera, [self class].cameraContext, &description);
        gp_camera_unref(camera);
    }
    if (error)
    {
        *error = [[self class] errorForResult:result];
    }
    return description;
}

@end
