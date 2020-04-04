//
//  SyPGPhotoImageBuffer.m
//  Camera Live
//
//  Created by Tom Butterworth on 22/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import "SyPGPhotoImageBuffer.h"

@implementation SyPGPhotoImageBuffer {
    CameraFile *_file;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        int result = gp_file_new(&_file);
        if (result != GP_OK)
        {
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_file)
    {
        gp_file_unref(_file);
    }
}

- (const void *)baseAddress
{
    const char *data;
    unsigned long length;
    int result = gp_file_get_data_and_size(_file, &data, &length);
    if (result == GP_OK)
    {
        return data;
    }
    return NULL;
}

- (size_t)length
{
    const char *data;
    unsigned long length;
    int result = gp_file_get_data_and_size(_file, &data, &length);
    if (result == GP_OK)
    {
        return length;
    }
    return 0;
}

@end
