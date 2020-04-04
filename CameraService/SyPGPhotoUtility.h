//
//  SyPGPhotoUtility.h
//  CameraService
//
//  Created by Tom Butterworth on 29/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#ifndef SyPGPhotoUtility_h
#define SyPGPhotoUtility_h

#include <gphoto2/gphoto2.h>

/*
 * This function opens a camera depending on the specified model and port.
 * If the pointers at pil and cal are NULL, they will be created for you
 * (you may gp_*_unref them after or reuse them in a subsequent call)
 */
int
camera_open(Camera ** camera, const char *model, const char *port, GPContext *context, GPPortInfoList **pil, CameraAbilitiesList **cal);

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
int
camera_get_config_value_string(Camera *camera, const char *key, char **string, GPContext *context);


/*
* This enables/disables the specific canon capture mode.
*
* For non canons this is not required, and will just return
* with an error (but without negative effects).
*/
int
canon_enable_capture(Camera *camera, int onoff, GPContext *context);

#endif /* SyPGPhotoUtility_h */
