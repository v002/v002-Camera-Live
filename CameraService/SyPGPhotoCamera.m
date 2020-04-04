//
//  SyPGPhotoCamera.m
//  Camera Live
//
//  Created by Tom Butterworth on 22/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPGPhotoCamera.h"
#include "SyPGPhotoImageBuffer.h"
//#include "SyPUSBHotplugWatcher.h"
#include <gphoto2/gphoto2.h>
#include <gphoto2/gphoto2-abilities-list.h>
#include "SyPGPhotoUtility.h"
#include "SyPGPhotoContext.h"
#include <os/log.h>

@interface SyPGPhotoCamera (Private)

@end

/*
 libgphoto2 cameras
 */

static int
describe_widget(CameraWidget *widget, int indent, NSMutableString *destination)
{
    NSString *spaces = @" ";
    while (spaces.length < indent * 2)
    {
        spaces = [spaces stringByAppendingString:@" "];
    }
    int result = GP_OK;
    const char *name = NULL;
    const char *info = NULL;
    const char *label = NULL;
    const char *typestring = NULL;
    CameraWidgetType type;
    int readonly = 0;
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
    SyPGPhotoContext *_context;
    NSDictionary *_description;
    Camera *_camera;
    int _logCount;
}

+ (NSString *)driverName
{
    return @"libgphoto2";
}

+ (void)startDriver
{

}

+ (void)endDriver
{

}

- (instancetype)initWithContext:(SyPGPhotoContext *)context camera:(Camera *)camera description:(NSDictionary *)description
{
    self = [super init];
    if (self)
    {
        _context = context;
        gp_camera_ref(camera);
        _camera = camera;
        _description = description;
    }
    return self;
}

- (void)dealloc
{
    if (_camera)
    {
        gp_camera_exit(_camera, self.context.GPContext);
        gp_camera_unref(_camera);
        [self.context end:_description];
    }
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

- (void)startLiveView
{
    [super startLiveView];

    _logCount = 0;

    // libgphoto samples use this, though it doesn't appear to be necessary
    // - ignore the result as it can fail for some cameras
    canon_enable_capture(_camera, 1, self.context.GPContext);
}

- (void)stopLiveView
{
    canon_enable_capture(_camera, 0, self.context.GPContext);
    [super stopLiveView];
}

- (SyPImageBuffer *)getImageWithError:(NSError *__autoreleasing *)error
{
    int result = GP_OK;
    SyPGPhotoImageBuffer *file = [[SyPGPhotoImageBuffer alloc] init];
    if (!file)
    {
        result = GP_ERROR_NO_MEMORY;
    }
    if (result == GP_OK)
    {
        result = gp_camera_capture_preview(_camera, file.file, self.context.GPContext);
        if (result != GP_OK && _logCount < 6)
        {
            os_log_error(OS_LOG_DEFAULT, "gp_camera_capture_preview: %d %{public}s", result, gp_result_as_string(result));
            _logCount++;
        }
    }
    if (result == GP_OK)
    {
        const char *mime = NULL;
        if (gp_file_get_mime_type(file.file, &mime) != GP_OK || strcmp(mime, GP_MIME_JPEG) != 0)
        {
            os_log_error(OS_LOG_DEFAULT, "Unsupported MIME type: %{public}s", mime);
            NSString *description = [NSString stringWithFormat:@"Unsupported MIME type: %s", mime];
            if (error)
            {
                *error = [NSError errorWithDomain:@"SyPInternalErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: description}];
            }
            return nil;
        }
    }
    if (result != GP_OK)
    {
        file = nil;
    }
    if (error)
    {
        *error = [SyPGPhotoContext errorForResult:result];
    }
    return file;
}

- (NSString *)stateStringWithError:(NSError **)error
{
    NSString *description = @"";

    int result = list_widgets(_camera, self.context.GPContext, &description);
    if (error)
    {
        *error = [SyPGPhotoContext errorForResult:result];
    }
    return description;
}

@end
