//
//  SyPVersionCheck.m
//  Camera Live
//
//  Created by Tom Butterworth on 20/03/2011.
//  Copyright 2011-2020 Tom Butterworth. All rights reserved.
//
/*

 Sample XML:

 <?xml version="1.0" encoding="UTF-8"?>
 <versions>
     <release>
         <version>23</version>
         <link>
             http://somewhere.com/your_download_page.html
         </link>
     </release>
 </versions>

 */
#import "SyPVersionCheck.h"

#define kVersionCheckUserDefaultsID @"info.v002.updatecheck.last"

@implementation SyPVersionCheck {
@private
    NSBackgroundActivityScheduler   *_scheduler;
    NSUInteger                      _highestVersion;
    NSURL                           *_highestLink;
    NSMutableString                 *_incomingString;
    NSURL                           *_currentLink;
    NSUInteger                      _currentVersion;
}

+ (SyPVersionCheck *)checkWithURL:(NSURL *)url userInitiated:(BOOL)user handler:(void(^)(BOOL checkSucceeded, NSUInteger currentVersion, NSUInteger latestVersion, NSURL *downloadLink))handler
{
    return [[self alloc] initWithURL:url userInitiated:user handler:handler];
}

- (id)initWithURL:(NSURL *)url userInitiated:(BOOL)user handler:(void(^)(BOOL checkSucceeded, NSUInteger currentVersion, NSUInteger latestVersion, NSURL *downloadLink))handler
{
    self = [super init];
    if (self)
    {
        if (!handler || ! url)
        {
            return nil;
        }
        if (user)
        {
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            id activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated
                                                                         reason: @"Checking for application update"];
            [queue addOperationWithBlock:^{
                [self performCheckForURL:url withHandler:handler];
                [[NSProcessInfo processInfo] endActivity:activity];
            }];
        }
        else
        {
            _scheduler = [[NSBackgroundActivityScheduler alloc] initWithIdentifier:@"info.v002.updatecheck"];
            _scheduler.interval = 60 * 60 * 24 * 3; // 3 days
            _scheduler.repeats = YES;
            [_scheduler scheduleWithBlock:^(NSBackgroundActivityCompletionHandler _Nonnull completionHandler) {
                [self performCheckForURL:url withHandler:handler];
                completionHandler(NSBackgroundActivityResultFinished);
            }];
        }
    }
    return self;
}

- (void)performCheckForURL:(NSURL *)url withHandler:(void(^)(BOOL checkSucceeded, NSUInteger currentVersion, NSUInteger latestVersion, NSURL *downloadLink))handler
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kVersionCheckUserDefaultsID];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    [parser setDelegate:self];
    BOOL success = [parser parse];
    NSUInteger currentVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
    handler(success, currentVersion, self->_highestVersion, self->_highestLink);
}

- (void)invalidate
{
    [_scheduler invalidate];
}

@end
@implementation SyPVersionCheck (XMLParsing)
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"release"])
    {
        _currentLink = nil;
        _currentVersion = 0;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (!_incomingString)
    {
        _incomingString = [[NSMutableString alloc] initWithCapacity:50];
    }
    [_incomingString appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    NSString *trimmed = [_incomingString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([elementName isEqualToString:@"version"])
    {
        _currentVersion = (NSUInteger)[trimmed integerValue];

    }
    else if ([elementName isEqualToString:@"link"])
    {
        _currentLink = [[NSURL alloc] initWithString:trimmed];
    }
    else if ([elementName isEqualToString:@"release"])
    {
        if (_currentVersion > _highestVersion)
        {
            _highestVersion = _currentVersion;
            _highestLink = _currentLink;
        }
    }
    _incomingString = nil;
}
@end
