//
//  Global.m
//  MeeletCommon
//
//  Created by jill on 15/5/25.
//
//

#import <Foundation/Foundation.h>
#import "Global.h"
#import "ProjectViewController.h"
#import "UserDetails.h"
#import "SecurityContext.h"
#import "QRCodeViewController.h"
#import <Pods/JSONKit/JSONKit.h>
#import <Pods/CocoaLumberjack/DDLog.h>
#import <Pods/CocoaLumberjack/DDTTYLogger.h>
#import <Pods/CocoaHTTPServer/HTTPServer.h>
#import <Pods/CocoaHTTPServer/DAVConnection.h>
#import <Pods/SSZipArchive/SSZipArchive.h>
#import <Pods/FreeStreamer/FSAudioController.h>

const char *ProjectModeName[] = {"waitDownload", "waitRefresh", "inProgress"};

AppEventDefine(login);
AppEventDefine(logout);
AppEventDefine(projectScan);
AppEventDefine(normalScan);
AppEventDefine(getProjectError);
AppEventDefine(getProjectModulesError);
AppEventDefine(deleteLocalProject);
AppEventDefine(downloadProjectStart);
AppEventDefine(downloadProjectStop);
AppEventDefine(downloadProjectDone);
AppEventDefine(downloadProjectError);
AppEventDefine(downloadProjectProgress);
AppEventDefine(downloadProjectModulesStart);
AppEventDefine(downloadProjectModulesDone);
AppEventDefine(downloadProjectModulesError);
AppEventDefine(downloadProjectModulesProgress);
AppEventDefine(getJoinItems);

#define AVATAR_PATH @"avatar"
#define RESOURCE_PATH @"resource"
#define TMP_PATH @"tmp"
#define PROJECT_PATH @"project"
#define PROJECT_HOST_PATH @"host"
#define PROJECT_INFO_PATH @"info"
#define PROJECT_CONTENT_PATH @"content"
#define PROJECT_MODULES_PATH @"modules"

static ProjectViewController *currentController;
static id<IEventDispatcher> eventDispatcher;

@implementation Global

+(NetworkEngine*)engine
{
    static NetworkEngine *networkEngine = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        networkEngine = [[NetworkEngine alloc] init];
    });
    
    return networkEngine;
}

+(HTTPServer*)httpServer
{
    static HTTPServer *server = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        server = [[HTTPServer alloc] init];
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [server setType:@"_http._tcp."];
        
        [server setPort:8080];
        
        [server setConnectionClass:[DAVConnection class]];
        
        // Serve files from our embedded Web folder
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *webPath = [paths objectAtIndex:0];
        
        [server setDocumentRoot:webPath];
    });
    
    return server;
}

+(FSAudioController*) audioController
{
    static FSAudioController *controller = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[FSAudioController alloc] init];
    });
    
    return controller;
}

+(void)initApplication
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self restoreLoginUser];
        [[self engine] initEngine];

#warning Launch HTTP server to browse application files for debug. Should disable this feature in the phase of release.
        NSError *error;
        HTTPServer *httpServer = [self httpServer];
        if([httpServer start:&error])
        {
            ALog(@"Started HTTP Server on port %hu, document root %@", [httpServer listeningPort], [httpServer documentRoot]);
        }
        else
        {
            ALog(@"Error starting HTTP Server: %@", error);
        }
    });
}

+ (void)initEventDispatcher:(id<IEventDispatcher>)dispatcher
{
    eventDispatcher = dispatcher;
}

+ (void)dispatchEvent:(NSString*)eventType eventObj:(NSDictionary*)eventObj
{
    if (eventDispatcher) {
        [eventDispatcher sendAppEventWithName:eventType body:eventObj];
    }
}

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary *)userObj
{
    if (loginName && loginName.length) {
        UserDetails *details = [[UserDetails alloc] init];
        details.loginName = loginName;
        details.plainPassword = plainPassword;
        details.detailsObject = userObj;
        
        [SecurityContext getObject].details = details;
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *userDict = [userObj mutableCopy];
        [userDict addEntriesFromDictionary:@{@"loginName":loginName, @"plainPassword":plainPassword}];
        [ud setObject:[userDict JSONStringWithOptions:JKSerializeOptionNone error:NULL] forKey:@"loginUser"];
        [ud synchronize];
    } else {
        [SecurityContext getObject].details = [UserDetails getDefault];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud removeObjectForKey:@"loginUser"];
        [ud synchronize];
    }
}

+ (void)setLoginUser:(NSDictionary*)userObj
{
    NSString *userName = [userObj objectForKey:@"loginName"];
    NSAssert(![userName isEqualToString:[UserDetails getDefault].loginName], [NSString stringWithFormat:@"Invalid user name, maybe not log on."]);
    
    [SecurityContext getObject].details.detailsObject = userObj;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *strUser = [ud objectForKey:@"loginUser"];
    
    if (strUser) {
        NSMutableDictionary *userDict = [[strUser objectFromJSONString] mutableCopy];
        [userDict addEntriesFromDictionary:userObj];
        [ud setObject:[userDict JSONStringWithOptions:JKSerializeOptionNone error:NULL] forKey:@"loginUser"];
        [ud synchronize];
    }
}

+(void) restoreLoginUser {
    NSDictionary *userDict = [self getLoginUser];
    
    if (userDict && userDict.count) {
        UserDetails *details = [[UserDetails alloc] init];
        NSString *plainPassword = [userDict objectForKey:@"plainPassword"];
        details.loginName = [userDict objectForKey:@"loginName"];
        details.plainPassword = plainPassword;
        details.detailsObject = userDict;
        [SecurityContext getObject].details = details;
    }
}

+ (NSDictionary*)getLoginUser {
    NSHTTPCookie *sessionCookie = nil;
    
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            sessionCookie = cookie;
        }
    }
    
    NSDictionary *userDict = @{};
    if (sessionCookie) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSString *strUser = [ud objectForKey:@"loginUser"];
        
        if (strUser) {
            userDict = [strUser objectFromJSONString];
        }
    }
    
    return userDict;
}

+ (NSArray*)getLocalProject
{
    NSMutableArray *result = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnumerator =[fileManager enumeratorAtURL:[NSURL fileURLWithPath:[self projectsInfoPath] isDirectory:YES] includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLFileResourceTypeKey, nil] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];

    for (NSURL *subDirectory in directoryEnumerator) {
        NSString *dirType = nil;
        [subDirectory getResourceValue:&dirType forKey:NSURLFileResourceTypeKey error:nil];

        if ([dirType isEqual:NSURLFileResourceTypeDirectory]) {
            NSString *jsonPath = [[subDirectory path] stringByAppendingPathComponent:@"project.json"];
            if ([fileManager fileExistsAtPath:jsonPath]) {
                NSString *jsonContent = [NSString stringWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:nil];
                [result addObject:[jsonContent objectFromJSONString]];
            }
        }
    }
    
    return result;
}

+ (void)exitPage
{
    if (currentController) {
        [currentController dismissViewControllerAnimated:YES completion:nil];
        currentController = NULL;
    }
}

+ (void)downloadModules
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *projectModulesPath = [self projectsModulesPath];

    if ([manager fileExistsAtPath:projectModulesPath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dispatchEvent:downloadProjectModulesDoneEvent eventObj:@{}];
        });
    } else {
        [[self engine] downloadModules:^(CommonNetworkOperation *completedOperation) {
            DLog(@"Download modules complete");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dispatchEvent:downloadProjectModulesDoneEvent eventObj:@{}];
            });
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *tmpPath = [[Global tmpPath] stringByAppendingPathComponent:@"modules.zip"];
                NSString *moduleFolderTmpPath = [[Global tmpPath] stringByAppendingPathComponent:@"modules"];
                
                if ([manager fileExistsAtPath:tmpPath]) {
                    //Compare time of downloaded temp file to that of project module path
                    NSDate *downloadTime = nil, *tmpDownloadTime = nil;
                    
                    NSDictionary *tmpAttrs = [manager attributesOfItemAtPath:tmpPath error:nil];
                    if (tmpAttrs != nil) {
                        tmpDownloadTime = (NSDate*)[tmpAttrs objectForKey: NSFileCreationDate];
                    }
                    
                    if ([manager fileExistsAtPath:projectModulesPath]) {
                        NSDictionary *attrs = [manager attributesOfItemAtPath:projectModulesPath error:nil];
                        if (attrs != nil) {
                            downloadTime = (NSDate*)[attrs objectForKey: NSFileCreationDate];
                        }
                    }
                    
                    if (!tmpDownloadTime || !downloadTime || [tmpDownloadTime compare:downloadTime] == NSOrderedDescending) {
                        DLog(@"Start unzip...");
                        if ([manager fileExistsAtPath:moduleFolderTmpPath]) {
                            [manager removeItemAtPath:moduleFolderTmpPath error:nil];
                        }
                        [SSZipArchive unzipFileAtPath:tmpPath toDestination:moduleFolderTmpPath];
                        
                        if ([manager fileExistsAtPath:projectModulesPath]) {
                            [manager removeItemAtPath:projectModulesPath error:nil];
                        }
                        [manager moveItemAtPath:moduleFolderTmpPath toPath:projectModulesPath error:nil];
                    }
                }
            });
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dispatchEvent:downloadProjectModulesErrorEvent eventObj:@{@"error":[error localizedDescription]}];
            });
        } progressBlock:^(double progress) {
            DLog(@"Download in progress %.2f", progress);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dispatchEvent:downloadProjectModulesProgressEvent eventObj:@{@"progress":[NSNumber numberWithUnsignedLong:(unsigned long)ceilf(progress * 100)]}];
            });
        }];
    }
}

+ (void)downloadProject:(NSString*)projectId
{
    NSString *infoPath = [self projectInfoPath:projectId];
    NSString *projectJsonPath = [infoPath stringByAppendingPathComponent:@"project.json"];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    if (![manager fileExistsAtPath:infoPath]) {
        [manager createDirectoryAtPath:infoPath withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    if (![manager fileExistsAtPath:projectJsonPath]) {
        [[Global engine] getProject:[@{@"_id":projectId} JSONString] codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *dict = arr[0];
                [[dict JSONString] writeToFile:projectJsonPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dispatchEvent:getProjectErrorEvent eventObj:@{@"projectId":projectId, @"error":@"Project record cannot be found."}];
                });
            }
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dispatchEvent:getProjectErrorEvent eventObj:@{@"projectId":projectId, @"error":[error localizedDescription]}];
            });
        }];
    }
    
    //Project mode: 0.Wait Download; 1.Wait Refresh; 2. Download or Refresh in Progress
    [self dispatchEvent:downloadProjectStartEvent eventObj:@{@"projectId":projectId, @"mode":ENUM_NAME(ProjectMode, InProgress)}];

    [[self engine] downloadProject:projectId codeBlock:^(CommonNetworkOperation *completedOperation) {
        ALog(@"Download complete %@", projectId);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dispatchEvent:downloadProjectDoneEvent eventObj:@{@"projectId":projectId, @"mode":ENUM_NAME(ProjectMode, WaitRefersh)}];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileManager *manager = [NSFileManager defaultManager];
            NSString *tmpPath = [[Global tmpPath] stringByAppendingPathComponent:[projectId stringByAppendingPathExtension:@"zip"]];
            NSString *projectTmpPath = [[Global tmpPath] stringByAppendingPathComponent:projectId];
            NSString *projectPath = [self projectContentPath:projectId];

            if ([manager fileExistsAtPath:tmpPath]) {
                //Compare time of downloaded temp file to that of project path
                NSDate *downloadTime = nil, *tmpDownloadTime = nil;
                
                NSDictionary *tmpAttrs = [manager attributesOfItemAtPath:tmpPath error:nil];
                if (tmpAttrs != nil) {
                    tmpDownloadTime = (NSDate*)[tmpAttrs objectForKey: NSFileCreationDate];
                }
                
                if ([manager fileExistsAtPath:projectPath]) {
                    NSDictionary *attrs = [manager attributesOfItemAtPath:projectPath error:nil];
                    if (attrs != nil) {
                        downloadTime = (NSDate*)[attrs objectForKey: NSFileCreationDate];
                    }
                }
                
                if (!tmpDownloadTime || !downloadTime || [tmpDownloadTime compare:downloadTime] == NSOrderedDescending) {
                    DLog(@"Start unzip...");

                    if ([manager fileExistsAtPath:projectTmpPath]) {
                        [manager removeItemAtPath:projectTmpPath error:nil];
                    }
                    [SSZipArchive unzipFileAtPath:tmpPath toDestination:projectTmpPath];
                    
                    if ([manager fileExistsAtPath:projectPath]) {
                        [manager removeItemAtPath:projectPath error:nil];
                    }
                    [manager moveItemAtPath:projectTmpPath toPath:projectPath error:nil];
                }
            }
        });
    } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUInteger prevProgress = [self projectProgress:projectId];
            NSString *mode = [self projectMode:projectId];
            [self dispatchEvent:downloadProjectErrorEvent eventObj:@{@"projectId":projectId, @"mode":mode, @"prevProgress":[NSNumber numberWithUnsignedLong:prevProgress], @"error":[error localizedDescription]}];
        });
    } progressBlock:^(double progress) {
        DLog(@"Download in progress %.2f", progress);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dispatchEvent:downloadProjectProgressEvent eventObj:@{@"projectId":projectId, @"progress":[NSNumber numberWithUnsignedLong:(unsigned long)ceilf(progress * 100)]}];
        });
    }];
}

+ (void)pauseDownloadProject:(NSString *)projectId
{
    [[self engine] pauseDownloadProject:projectId];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *mode = [self projectMode:projectId];
        [self dispatchEvent:downloadProjectStopEvent eventObj:@{@"projectId":projectId, @"mode":mode}];
    });
}

+ (BOOL)isValidObjectId:(NSString*)idStr
{
    NSRegularExpression *objectIdPattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{24}$" options:NSRegularExpressionCaseInsensitive error:nil];
    
    return idStr && idStr.length == 24 && [objectIdPattern numberOfMatchesInString:idStr options:NSMatchingReportCompletion range:NSMakeRange(0, 24)];
}

+ (NSDate*)parseDateString:(NSString*)dateString
{
    static NSDateFormatter *formatter = nil;
    static NSRegularExpression *regex = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
        
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\.[0-9]{3}Z$" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    
    dateString = [regex stringByReplacingMatchesInString:dateString options:0 range:NSMakeRange(0, dateString.length) withTemplate:@"GMT+00:00"];
    NSDate *date = [formatter dateFromString:dateString];
    
    return date;
}

+ (NSDictionary*)restoreJSONDate:(NSDictionary*)dict
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:dict];
    
    NSString *time = [result objectForKey:@"createTime"];
    if (time) {
        [result setObject:[self parseDateString:time] forKey:@"createTime"];
    }
    
    time = [result objectForKey:@"updateTime"];
    if (time) {
        [result setObject:[self parseDateString:time] forKey:@"updateTime"];
    }
    
    return result;
}

+ (void)scanQRCode
{
    UIViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
    QRCodeViewController *ctrl = [[QRCodeViewController alloc] init];
    ctrl.resultBlock = ^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dispatchEvent:normalScanEvent eventObj:@{@"code":code}];
        });
    };
    [viewController presentViewController:ctrl animated:YES completion:nil];
}

    
#pragma GCC diagnostic ignored "-Wundeclared-selector"
+ (void)scanProjectCode
{
    UIViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
    QRCodeViewController *ctrl = [[QRCodeViewController alloc] init];
    ctrl.resultBlock = ^(NSString *projectId) {
        if ([self isValidObjectId:projectId]) {
            DLog(@"Scanned project id:%@", projectId);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dispatchEvent:projectScanEvent eventObj:@{@"projectId":projectId}];
            });
        }
    };
    [viewController presentViewController:ctrl animated:YES completion:nil];
}

+ (void)deleteLocalProject:(NSString *)projectId
{
    NSFileManager *manager = [NSFileManager defaultManager];

    NSString *projectPath = [self projectContentPath:projectId];
    if ([manager fileExistsAtPath:projectPath]) {
        [manager removeItemAtPath:projectPath error:nil];
    }
    
    NSString *tmpPath = [[Global tmpPath] stringByAppendingPathComponent:[projectId stringByAppendingPathExtension:@"zip"]];
    if ([manager fileExistsAtPath:tmpPath]) {
        [manager removeItemAtPath:tmpPath error:nil];
    }
    
    NSString *projectInfoPath = [self projectInfoPath:projectId];
    if ([manager fileExistsAtPath:projectInfoPath]) {
        [manager removeItemAtPath:projectInfoPath error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self dispatchEvent:deleteLocalProjectEvent eventObj:@{@"projectId":@[projectId]}];
        });
    }
}

+ (void)showProject:(NSString *)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *projectPath = [self projectContentPath:projectId];
    NSString *projectModulePath = [projectPath stringByAppendingPathComponent:@"modules"];//common javascript modules
    NSString *projectEmbeddedPath = [projectPath stringByAppendingPathComponent:@"embedded"];//cordova.js
    NSString *indexPath = [projectPath stringByAppendingPathComponent:@"index.html"];
    BOOL exists = [manager fileExistsAtPath:[self projectsModulesPath]];
    exists = [manager fileExistsAtPath:[self embeddedPath]];
    
    if ([manager fileExistsAtPath:projectPath] && [manager fileExistsAtPath:indexPath]) {
        if (codeBlock) {
            codeBlock();
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [manager removeItemAtPath:projectModulePath error:nil];
            [manager createSymbolicLinkAtPath:projectModulePath withDestinationPath:[self projectsModulesPath] error:nil];
            
            [manager removeItemAtPath:projectEmbeddedPath error:nil];
            [manager createSymbolicLinkAtPath:projectEmbeddedPath withDestinationPath:[self embeddedPath] error:nil];

            ProjectViewController *ctrl = [[ProjectViewController alloc] init];
            ctrl.wwwFolderName = [[NSURL fileURLWithPath:projectPath] absoluteString];
            ctrl.startPage = @"index.html";
            currentController = ctrl;

            UIViewController *viewController = [[[UIApplication sharedApplication] delegate] performSelector:@selector(viewController)];
            [viewController presentViewController:ctrl animated:YES completion:nil];
        });
    } else {
        if (errorBlock) {
            errorBlock([NSError errorWithDomain:APP_ERROR_DOMAIN code:APP_ERROR_OPEN_FILE_CODE userInfo:@{@"error":@"Directory not found."}]);
        }
    }
}

+ (void)showHostProject:(NSString *)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    NSError *error = [Global buildProjectHost];
    if (error) {
        errorBlock(error);
    }
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *projectPath = [self projectContentPath:projectId];
    NSString *projectModulePath = [projectPath stringByAppendingPathComponent:@"modules"];//common javascript modules
    NSString *projectEmbeddedPath = [projectPath stringByAppendingPathComponent:@"embedded"];//cordova.js
    NSString *indexPath = [projectPath stringByAppendingPathComponent:@"index.html"];
    BOOL exists = [manager fileExistsAtPath:[self projectsModulesPath]];
    exists = [manager fileExistsAtPath:[self embeddedPath]];
    
    if ([manager fileExistsAtPath:projectPath] && [manager fileExistsAtPath:indexPath]) {
        if (codeBlock) {
            codeBlock();
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [manager removeItemAtPath:projectModulePath error:nil];
            [manager createSymbolicLinkAtPath:projectModulePath withDestinationPath:[self projectsModulesPath] error:nil];
            
            [manager removeItemAtPath:projectEmbeddedPath error:nil];
            [manager createSymbolicLinkAtPath:projectEmbeddedPath withDestinationPath:[self embeddedPath] error:nil];
            
            MainViewController *ctrl = [[MainViewController alloc] init];
            ctrl.wwwFolderName = [[NSURL fileURLWithPath:[Global embeddedPath]] absoluteString];
            ctrl.startPage = @"index.html";
            
            NSString *projectHostLink = [[self embeddedPath] stringByAppendingPathComponent:projectId];
            [manager removeItemAtPath:projectHostLink error:nil];
            [manager createSymbolicLinkAtPath:projectHostLink withDestinationPath:projectPath error:nil];

            UIWindow *window = [[[UIApplication sharedApplication] delegate] performSelector:@selector(window)];
            UIViewController *viewController = window.rootViewController;
            [viewController presentViewController:ctrl animated:YES completion:nil];
        });
    } else {
        if (errorBlock) {
            errorBlock([NSError errorWithDomain:APP_ERROR_DOMAIN code:APP_ERROR_OPEN_FILE_CODE userInfo:@{@"error":@"Directory not found."}]);
        }
    }
}

+(NSError*) buildProjectHost
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDate *folderTime = nil, *flagFileTime = nil;
    NSString *wwwFolder = [[NSBundle mainBundle] pathForResource:@"www" ofType:@""], *hostPath = [self projectsHostPath];
    NSDictionary *attrs = [manager attributesOfItemAtPath:wwwFolder error:nil];
    if (attrs != nil) {
        folderTime = (NSDate*)[attrs objectForKey: NSFileCreationDate];
    }
    NSString *flagFile = [hostPath stringByAppendingPathComponent:@"hostFlag"];
    if ([manager fileExistsAtPath:flagFile]) {
        attrs = [manager attributesOfItemAtPath:flagFile error:nil];
        if (attrs != nil) {
            flagFileTime = (NSDate*)[attrs objectForKey: NSFileCreationDate];
        }
    }
    
    NSError *error = nil;
    if (!flagFileTime || [folderTime compare:flagFileTime] == NSOrderedDescending) {
        if ([manager fileExistsAtPath:flagFile]) {
            [manager removeItemAtPath:flagFile error:&error];
        }

        NSString *wwwHostFolder = [hostPath stringByAppendingPathComponent:@"www"];
        if ([manager fileExistsAtPath:wwwHostFolder]) {
            [manager removeItemAtPath:wwwHostFolder error:&error];
        }
        
        if (!error) {
            [manager copyItemAtPath:wwwFolder toPath:wwwHostFolder error:&error];
            
            if (!error) {
                if (![manager createFileAtPath:flagFile contents:nil attributes:nil]) {
                    error = [NSError errorWithDomain:APP_ERROR_DOMAIN code:APP_ERROR_CREATE_FILE_CODE userInfo:@{@"error":@"Cannot create host flag file."}];
                }
            }
        }
    }
    
    return  error;
}

+(void) sendChatMessage:(NSString *)userId chatId:(NSString *)chatId payload:(NSDictionary *)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    
}

+(void) sendInboxMessage:(NSString *)userId inboxId:(NSString *)inboxId payload:(NSDictionary *)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    
}

+(void)sendTopicMessage:(NSString *)userId topicId:(NSString *)topicId payload:(NSDictionary *)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock
{
    
}

+(NSString*) saveAvatar:(NSString*)projectId filePath:(NSString*)filePath
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *returnPath = @"";
    
    if ([manager fileExistsAtPath:filePath]) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *extension = [fileName pathExtension];
        NSString *name = [fileName substringToIndex:fileName.length - extension.length];
        
        //Avatar picture file is named after pattern ***-character.[extension]
        fileName = [NSString stringWithFormat:@"character-%@.%@", name, extension];

        //Save to user's avatar folder
        returnPath = [[self avatarPath] stringByAppendingPathComponent:fileName];
        [manager copyItemAtPath:filePath toPath:returnPath error:nil];
        
        if (projectId && projectId.length) {
            //Save to user project's image resource folder
            NSString *projectPath = [self projectContentPath:projectId];
            
            if ([manager fileExistsAtPath:projectPath]) {
                NSString *imagePath = [projectPath stringByAppendingPathComponent:@"resource/image"];
                if (![manager fileExistsAtPath:imagePath]) {
                    [manager createDirectoryAtPath:imagePath withIntermediateDirectories:YES attributes:nil error:nil];
                }
                returnPath = [imagePath stringByAppendingPathComponent:fileName];
                [manager copyItemAtPath:filePath toPath:returnPath error:nil];
            }
        }
        
#warning Upload to user folder hosting on server
    }
    
    return returnPath;
}

+(void) playSound:(NSURL *)url playLoop:(BOOL)playLoop
{
    if ([self audioController].isPlaying && [url isEqual:[self audioController].activeStream.url]) {
        return;
    }
         
    if (playLoop) {
        [self audioController].onStateChange = ^(FSAudioStreamState state) {
            if (state == kFsAudioStreamPlaybackCompleted) {
                [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(playSoundWithLoop:) userInfo:url repeats:NO];
            }
        };
    }
    
    [[self audioController] playFromURL:url];
}

+(void) playSoundWithLoop:(NSTimer*)timer
{
    NSURL *url = (NSURL*)timer.userInfo;
    
    [self playSound:url playLoop:YES];
}

+(void) stopPlaySound
{
    [[self audioController] stop];
}

+(BOOL) isPlayingSound
{
    return [self audioController].isPlaying;
}

+(NSString*)documentPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

+(NSString*)userFilePath
{
    NSString *path = [[self documentPath] stringByAppendingPathComponent:[SecurityContext getObject].details.loginName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)avatarPath
{
    NSString *path = [[self userFilePath] stringByAppendingPathComponent:AVATAR_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)sharedResourcePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:RESOURCE_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)tmpPath
{
    NSString *path = [[self userFilePath] stringByAppendingPathComponent:TMP_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsPath
{
    NSString *path = [[self userFilePath] stringByAppendingPathComponent:PROJECT_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

//The H5 content of app will be copied to host path, so that we can make change in the folder.
+(NSString*)projectsHostPath
{
    NSString *path = [[self projectsPath] stringByAppendingPathComponent:PROJECT_HOST_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsInfoPath
{
    NSString *path = [[self projectsPath] stringByAppendingPathComponent:PROJECT_INFO_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsContentPath
{
    NSString *path = [[self projectsPath] stringByAppendingPathComponent:PROJECT_CONTENT_PATH];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil];
    
    return path;
}

+(NSString*)projectsModulesPath
{
    NSString *path = [[self documentPath] stringByAppendingPathComponent:PROJECT_MODULES_PATH];
    
    return path;
}

+ (NSString*)embeddedPath
{
    NSString *hostEmbeddedPath = [[self projectsHostPath] stringByAppendingPathComponent:@"www"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:hostEmbeddedPath]) {
        return hostEmbeddedPath;
    } else {
        return [[NSBundle mainBundle] pathForResource:@"www" ofType:@""];
    }
}

+(NSString*)projectContentPath:(NSString*)projectId
{
    return [[self projectsContentPath] stringByAppendingPathComponent:projectId];
}

+(NSString*)projectInfoPath:(NSString*)projectId
{
    return [[self projectsInfoPath] stringByAppendingPathComponent:projectId];
}

//Project mode: 0.Wait Download; 1.Wait Refresh; 2. Download or Refresh in Progress
+(NSString*)projectMode:(NSString*)projectId
{
    if ([[self engine] downloadProjectInProgress:projectId]) {
        return ENUM_NAME(ProjectMode, InProgress);
    } else {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[self projectContentPath:projectId]]) {
            return ENUM_NAME(ProjectMode, WaitRefersh);
        } else {
            return ENUM_NAME(ProjectMode, WaitDownload);
        }
    }
}

+(NSUInteger)projectProgress:(NSString*)projectId
{
    NSDictionary *downloadInfo = [[self engine] downloadProjectInfo:projectId];
    if (downloadInfo) {
        NSNumber *unitCompleted = [downloadInfo objectForKey:@"unitCompleted"];
        NSNumber *unitTotal = [downloadInfo objectForKey:@"unitTotal"];
        if (unitCompleted && unitTotal) {
            float progress = [unitCompleted floatValue] / [unitTotal floatValue];
            return (NSUInteger)ceilf(progress * 100);
        }
    }
    
    return 0;
}

@end