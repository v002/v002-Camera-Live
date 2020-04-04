//
//  CameraErrors.h
//  Camera Live
//
//  Created by Tom Butterworth on 29/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#ifndef CameraErrors_h
#define CameraErrors_h

#define kCameraErrorDomain @"info.v002.Camera"

typedef enum : NSUInteger {
    CameraErrorNone = 0,
    CameraErrorDeviceEnumerationError,
    CameraErrorTimeout,
} CameraError;

#endif /* CameraErrors_h */
