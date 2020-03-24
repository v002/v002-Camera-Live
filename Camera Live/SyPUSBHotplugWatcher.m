//
//  SyPUSBHotplugWatcher.m
//  Camera Live
//
//  Created by Tom Butterworth on 23/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPUSBHotplugWatcher.h"
#include <libusb-1.0/libusb.h>
#include <poll.h>


// TODO:!
// Think about object lifetime through this - really we want a private object which is retained as long as any callbacks (or queues) have it
// which entirely encapsulates libusb - I think?

@interface SyPUSBHotplugWatcher (Private)
@property (readonly) dispatch_queue_t queue;
@property (readonly) libusb_context *USBContext;
- (void)handleUSBEvents;
- (void)handleUSBAddedFD:(int)fd forEvents:(short)events;
- (void)handleUSBRemovedFD:(int)fd;
- (void)handleUSBHotplugForDevice:(libusb_device *)device event:(libusb_hotplug_event)event;
@end

static void usb_event(void *info)
{
    SyPUSBHotplugWatcher *watcher = (SyPUSBHotplugWatcher *)info;
    [watcher handleUSBEvents];
}

static void usb_pollfd_added(int fd, short events, void *user_data)
{
    SyPUSBHotplugWatcher *watcher = (SyPUSBHotplugWatcher *)user_data;
    [watcher handleUSBAddedFD:fd forEvents:events];
}

static void usb_pollfd_removed(int fd, void *user_data)
{
    SyPUSBHotplugWatcher *watcher = (SyPUSBHotplugWatcher *)user_data;
    [watcher handleUSBRemovedFD:fd];
}

static int usb_hotplug_callback(libusb_context *ctx, libusb_device *device, libusb_hotplug_event event, void *user_data)
{
    SyPUSBHotplugWatcher *watcher = (SyPUSBHotplugWatcher *)user_data;
    [watcher handleUSBHotplugForDevice:device event:event];
    return 0;
}

@implementation SyPUSBHotplugWatcher {
    dispatch_queue_t _USBQueue;
    libusb_context *_USBContext;
    NSMutableSet *_sources;
    dispatch_source_t _timer;
    dispatch_source_t _notifications;
    libusb_hotplug_callback_handle _callbackHandle;
    void (^_handler)(SyPUSBHotplugEvent, NSError * _Nullable);
    dispatch_queue_t _userQueue;
    BOOL _running;
}

- (id)initWithQueue:(dispatch_queue_t)queue handler:(void (^)(SyPUSBHotplugEvent, NSError * _Nullable))handler
{
    self = [super init];
    if (self)
    {
        _handler = [handler copy];
        dispatch_retain(queue);
        _userQueue = queue;
        dispatch_source_t notifications = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, queue);
        dispatch_source_set_event_handler(notifications, ^{
            unsigned long pending = dispatch_source_get_data(notifications);
            if (pending & LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED)
            {
                handler(SyPUSBHotplugAdd, nil);
            }
            if (pending & LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT)
            {
                handler(SyPUSBHotplugRemove, nil);
            }
        });
        _notifications = notifications;
        dispatch_activate(_notifications);
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_LOW, 0);
        _sources = [[NSMutableSet alloc] initWithCapacity:8];
        _USBQueue = dispatch_queue_create("info.v002.camera-live.libusb", attr);
        if (![self setupUSB])
        {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [self teardownUSB];
    [_handler release];
    dispatch_release(_userQueue);
    dispatch_release(_USBQueue);
    [super dealloc];
}

- (BOOL)setupUSB
{
    _running = YES;
    int result = libusb_init(&_USBContext);
    if (result == LIBUSB_SUCCESS)
    {
        libusb_set_pollfd_notifiers(_USBContext, usb_pollfd_added, usb_pollfd_removed, self);
        const struct libusb_pollfd **list = libusb_get_pollfds(_USBContext);
        int count = 0;
        while (list && list[count])
        {
            usb_pollfd_added(list[count]->fd, list[count]->events, self);
            count++;
        }
        libusb_free_pollfds(list);
    }
    if (result == LIBUSB_SUCCESS)
    {
        dispatch_async(_USBQueue, ^{
            int result = libusb_hotplug_register_callback(_USBContext,
                                                          LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT | LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED,
                                                          LIBUSB_HOTPLUG_ENUMERATE,
                                                          LIBUSB_HOTPLUG_MATCH_ANY,
                                                          LIBUSB_HOTPLUG_MATCH_ANY,
                                                          LIBUSB_HOTPLUG_MATCH_ANY,
                                                          usb_hotplug_callback,
                                                          self,
                                                          &_callbackHandle);
            if (result != LIBUSB_SUCCESS)
            {
                [self postError:result];
            }
            else
            {
                // http://libusb.sourceforge.net/api-1.0/group__libusb__asyncio.html#eventthread
                // > Applications using hotplug support should start the thread at program init,
                // > after having successfully called libusb_hotplug_register_callback()
                //
                // ie call libusb_handle_events_timeout_completed() straight away
                usb_event(self);
            }
        });
    }
    return result == LIBUSB_SUCCESS ? YES : NO;
}

- (void)teardownUSB
{
    _running = NO;
    libusb_hotplug_deregister_callback(_USBContext, _callbackHandle);
    libusb_exit(_USBContext);
    if (_timer)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = NULL;
    }
    if (_notifications)
    {
        dispatch_source_cancel(_notifications);
        dispatch_release(_notifications);
        _notifications = NULL;
    }
    _USBContext = NULL;
    // libusb_exit should have cleared our sources
    assert(_sources.count == 0);
    [_sources release];
}

- (void)handleUSBEvents
{
    if (!_running)
    {
        return;
    }
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    int result = libusb_handle_events_timeout_completed(_USBContext, &tv, NULL);
    if (result == LIBUSB_SUCCESS)
    {
        result = libusb_get_next_timeout(_USBContext, &tv);
        if (result == 1)
        {
            uint64_t interval = (tv.tv_sec * NSEC_PER_SEC) + (tv.tv_usec * NSEC_PER_USEC);
            if (!_timer)
            {
                _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _USBQueue);
                dispatch_source_set_event_handler_f(_timer, usb_event);
                dispatch_set_context(_timer, self);
                dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, interval, 1 * NSEC_PER_SEC);
                dispatch_activate(_timer);
            }
            else
            {
                dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, interval, 1 * NSEC_PER_SEC);
            }
            result = LIBUSB_SUCCESS;
        }
        else if (result == 0 && _timer)
        {
            dispatch_source_cancel(_timer);
            dispatch_release(_timer);
            _timer = NULL;
        }
        else
        {

        }
    }
    if (result != LIBUSB_SUCCESS)
    {
        [self postError:result];
    }
}

- (void)handleUSBAddedFD:(int)fd forEvents:(short)events
{
    dispatch_source_t source = dispatch_source_create(events == POLLIN ? DISPATCH_SOURCE_TYPE_READ : DISPATCH_SOURCE_TYPE_WRITE,
                                                      fd, 0, _USBQueue);
    dispatch_source_set_event_handler_f(source, usb_event);
    dispatch_set_context(source, self);

    [_sources addObject:source];

    dispatch_activate(source);
    dispatch_release(source);
}

- (void)handleUSBRemovedFD:(int)fd
{
    dispatch_source_t source = NULL;
    for (dispatch_source_t next in _sources)
    {
        if (dispatch_source_get_handle(next) == fd)
        {
            dispatch_retain(next);
            source = next;
        }
    }
    assert(source);
    if (source)
    {
        [_sources removeObject:source];
        dispatch_source_cancel(source);
        dispatch_release(source);
    }
}

- (void)handleUSBHotplugForDevice:(libusb_device *)device event:(libusb_hotplug_event)event
{
    dispatch_source_merge_data(_notifications, event);
}

- (void)postError:(int)code
{
    dispatch_async(_userQueue, ^{
        NSString *string = [NSString stringWithUTF8String:libusb_strerror(code)];
        NSError *error = [NSError errorWithDomain:@"SyPUSBErrorDomain" code:code userInfo:@{NSLocalizedDescriptionKey: string}];
        _handler(SypUSBHotplugError, error);
    });
}

@end
