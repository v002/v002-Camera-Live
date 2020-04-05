//
//  SyPVersionCheck.h
//  Camera Live
//
//  Created by Tom Butterworth on 20/03/2011.
//  Copyright 2011-2020 Tom Butterworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyPVersionCheck : NSObject <NSXMLParserDelegate>
+ (SyPVersionCheck *)checkWithURL:(NSURL *)url userInitiated:(BOOL)user handler:(void(^)(BOOL checkSucceeded, NSUInteger currentVersion, NSUInteger latestVersion, NSURL *downloadLink))handler;
- (void)invalidate;
@end
