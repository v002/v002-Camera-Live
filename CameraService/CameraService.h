//
//  CameraService.h
//  CameraService
//
//  Created by Tom Butterworth on 26/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CameraServiceProtocol.h"
#import "CameraPresenceProtocol.h"

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface CameraService : NSObject <CameraServiceProtocol>
@property (weak) NSXPCConnection *connection;
@end
