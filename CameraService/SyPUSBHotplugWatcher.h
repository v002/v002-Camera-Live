//
//  SyPUSBHotplugWatcher.h
//  Camera Live
//
//  Created by Tom Butterworth on 23/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    SyPUSBHotplugAdd,
    SyPUSBHotplugRemove,
    SypUSBHotplugError
} SyPUSBHotplugEvent;

@interface SyPUSBHotplugWatcher : NSObject
- (id)initWithQueue:(dispatch_queue_t)queue handler:(void(^)(SyPUSBHotplugEvent event, NSError * _Nullable error))handler;
@end

NS_ASSUME_NONNULL_END
