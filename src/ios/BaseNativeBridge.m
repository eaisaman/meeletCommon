//
//  BaseNativeBridge.m
//  MeeletCommon
//
//  Created by jill on 15/5/25.
//
//

#import "BaseNativeBridge.h"
#import "Global.h"
#import <Pods/JSONKit/JSONKit.h>

@implementation BaseNativeBridge

-(NSDictionary*) prevResponse:(NSString*)prevResponsePath
{
    if (prevResponsePath && [[NSFileManager defaultManager] fileExistsAtPath:prevResponsePath]) {
        NSData *prevResponseData = [NSData dataWithContentsOfFile:prevResponsePath];
        if (prevResponseData && prevResponseData.length) {
            NSString *prevResponseString =[[NSString alloc] initWithData:prevResponseData encoding:NSUTF8StringEncoding];
            
            return @{@"data":[prevResponseString objectFromJSONString]};
        }
    }
    
    return @{@"data":@{@"result":@"ERROR"}};
}

-(void) getServerUrl:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[NSString stringWithFormat:@"http://%@:%i", [Global engine].serverUrl, [Global engine].port]}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) getUserDetail:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *userFilter = command.arguments[0];
        if ([userFilter objectFromJSONString]) {
            [[Global engine] getUserDetails:userFilter codeBlock:^(NSString *record) {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[record objectFromJSONString]}];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
                if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == kCFURLErrorCannotConnectToHost) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self prevResponse:prevResponsePath]];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    return;
                }
                
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
        } else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Empty query condition."];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) scanProjectCode:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    [Global scanProjectCode];
}

-(void) checkProjectMode:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *projectIdStr = command.arguments[0];
        NSArray *projectIdList = [projectIdStr objectFromJSONString];
        if (projectIdList && projectIdList.count) {
            NSMutableArray *result = [NSMutableArray array];
            for (NSString* projectId in projectIdList) {
                NSString *mode = [Global projectMode:projectId];
                NSUInteger progress = [Global projectProgress:projectId];
                [result addObject:@{@"mode":mode, @"progress":[NSNumber numberWithUnsignedInteger:progress]}];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":result}}];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) doLogin:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
            DLog(@"name: %@=%@;domain=%@;expires=%@\n", cookie.name, cookie.value, cookie.domain, cookie.expiresDate);
        }
        
        NSString *loginName = command.arguments[0];
        NSString *plainPassword = command.arguments[1];
        [[Global engine] doLogin:loginName plainPassword:plainPassword codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *userObj = arr[0];
                [Global setLoginUser:loginName plainPassword:plainPassword userObj:userObj];
                
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":userObj}}];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"User object not returned."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) doLogout:(CDVInvokedUrlCommand*)command
{
    NSHTTPCookie *sessionCookie = nil;
    
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            sessionCookie = cookie;
        }
    }
    
    if (sessionCookie) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:sessionCookie];
    }
    
    [Global setLoginUser:nil plainPassword:nil userObj:nil];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) refreshUser:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *loginName = command.arguments[0];
        [[Global engine] getUser:loginName codeBlock:^(NSString *record) {
            NSMutableDictionary *recordDict = [@{} mutableCopy];
            [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
            NSArray *arr = [recordDict objectForKey:@"resultValue"];
            
            if(arr.count) {
                NSDictionary *userObj = arr[0];
                [Global setLoginUser:userObj];
                
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":userObj}}];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"User object not returned."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) restoreUserFromStorage:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[Global getLoginUser]}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) getProject:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *projectFilter = command.arguments[0];
        
        if ([projectFilter objectFromJSONString]) {
            [[Global engine] getProject:projectFilter codeBlock:^(NSString *record) {
                NSMutableDictionary *recordDict = [@{} mutableCopy];
                [recordDict addEntriesFromDictionary:[record objectFromJSONString]];
                NSArray *arr = [recordDict objectForKey:@"resultValue"];
                
                if(arr.count) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":arr}}];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } else {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Project object not returned."];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
                
            } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
        } else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Empty query condition."];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) exitPage:(CDVInvokedUrlCommand*)command
{
    [Global exitPage];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) downloadModules:(CDVInvokedUrlCommand*)command
{
    [Global downloadModules];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) downloadProject:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        NSString *projectId = command.arguments[0];
        [Global downloadProject:projectId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) pauseDownloadProject:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 1) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        NSString *projectId = command.arguments[0];
        [Global pauseDownloadProject:projectId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) getLocalProject:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[Global getLocalProject]}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) deleteLocalProject:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        NSString *projectIdStr = command.arguments[0];
        NSArray *projectIdList = [projectIdStr objectFromJSONString];
        if (projectIdList && projectIdList.count) {
            NSString *checkMode = ENUM_NAME(ProjectMode, WaitRefersh);
            for (NSString* projectId in projectIdList) {
                NSString *mode = [Global projectMode:projectId];
                if ([mode isEqualToString:checkMode]) {
                    [Global deleteLocalProject:projectId];
                }
            }
        }

    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) showProject:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString *projectId = command.arguments[0];
        [Global showProject:projectId codeBlock:^{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } errorBlock:^(NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) playSound:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count >= 2) {
        NSString *projectId = command.arguments[0];
        NSString *path = command.arguments[1];
        BOOL playLoop = NO;
        
        if (command.arguments.count >= 2) {
            playLoop = [command.arguments[2] boolValue];
        }
        
        path = [[Global projectContentPath:projectId] stringByAppendingPathComponent:path];
        
        NSURL* url = [NSURL fileURLWithPath:path];

        [Global playSound:url playLoop:playLoop];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) stopPlaySound:(CDVInvokedUrlCommand *)command
{
    [Global stopPlaySound];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void) isPlayingSound:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":[Global isPlayingSound]?@"true":@"false"}}];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


-(void) saveAvatar:(CDVInvokedUrlCommand *)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* projectId = command.arguments[0];
        NSString* path = command.arguments[1];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSString* returnPath = [Global saveAvatar:projectId filePath:path];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":@{@"result":@"OK", @"resultValue":returnPath}}];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Cannot find file at path %@", path]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) createChat:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString* userId = command.arguments[0];
        
        [[Global engine] createChat:userId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

-(void) connectChat:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* chatId = command.arguments[1];
        
        [[Global engine] connectChat:userId chatId:chatId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) pauseChat:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* chatId = command.arguments[1];
        
        [[Global engine] pauseChat:userId chatId:chatId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) closeChat:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* chatId = command.arguments[1];
        
        [[Global engine] closeChat:userId chatId:chatId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) deleteChat:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* chatId = command.arguments[1];
        
        [[Global engine] deleteChat:userId chatId:chatId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) createTopic:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString* userId = command.arguments[0];
        
        [[Global engine] createTopic:userId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) connectTopic:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* topicId = command.arguments[1];
        
        [[Global engine] connectTopic:userId topicId:topicId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) closeTopic:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* topicId = command.arguments[1];
        
        [[Global engine] closeTopic:userId topicId:topicId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) deleteTopic:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* topicId = command.arguments[1];

        [[Global engine] deleteTopic:userId topicId:topicId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) createInbox:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 1) {
        NSString* userId = command.arguments[0];

        [[Global engine] createInbox:userId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
} else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) connectInbox:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* inboxId = command.arguments[1];

        [[Global engine] connectInbox:userId inboxId:inboxId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
} else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) closeInbox:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* inboxId = command.arguments[1];

        [[Global engine] closeInbox:userId inboxId:inboxId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
} else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}

-(void) deleteInbox:(CDVInvokedUrlCommand*)command
{
    if (command.arguments && command.arguments.count == 2) {
        NSString* userId = command.arguments[0];
        NSString* inboxId = command.arguments[1];

        [[Global engine] deleteInbox:userId inboxId:inboxId codeBlock:^(NSString *str) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{@"data":[str objectFromJSONString]}];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } onError:^(CommonNetworkOperation *completedOperation, NSString *prevResponsePath, NSError *error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
} else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Incorrect argument number."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
    
}
@end
