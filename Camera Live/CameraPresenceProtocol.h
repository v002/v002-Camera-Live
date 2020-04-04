//
//  CameraPresenceProtocol.h
//  Camera Live
//
//  Created by Tom Butterworth on 26/03/2020.
//  Copyright © 2020 Tom Butterworth. All rights reserved.
//

#ifndef CameraPresenceProtocol_h
#define CameraPresenceProtocol_h

@protocol CameraPresenceProtocol
- (void)addCamera:(NSDictionary<NSString *, id> *)cam;
- (void)removeCamera:(NSDictionary<NSString *, id> *)cam;
- (void)error:(NSError *)error forCamera:(NSDictionary<NSString *, id> *)cam;
@end

#endif /* CameraPresenceProtocol_h */
