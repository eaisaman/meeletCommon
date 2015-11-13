//
//  NetworkEngine.m
//  MeeletCommon
//
//  Created by jill on 15/5/24.
//
//

#import <Foundation/Foundation.h>
#import "Global.h"
#import "NetworkEngine.h"
#import "SecurityContext.h"
#import <Pods/JSONKit/JSONKit.h>

@implementation NetworkEngine

+(ResubmittableRecordStore*)recordStore
{
    static ResubmittableRecordStore* store = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString* str = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
        NSString* strPath=[str stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        store = [[ResubmittableRecordStore alloc] initWithLocation:strPath];
    });
    
    return store;
}

-(void)initEngine
{
    int port = 80;
    NSString* serverUrl = nil;
    NSString *finalPath = [[[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"] stringByAppendingPathComponent:@"Root.plist"];
    NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:finalPath];
    NSArray *prefSpecifierArray = [settingsDict objectForKey:@"PreferenceSpecifiers"];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString* urlValue = [standardUserDefaults objectForKey:SETTINGS_BUNDLE_serverUrl_IDENTIFIER];
    if (urlValue) {
        NSArray *splits = [urlValue componentsSeparatedByString:@":"];
        serverUrl = splits[0];
        if(splits.count>1)
            port = [splits[1] intValue];
    } else {
        for (NSDictionary *prefItem in prefSpecifierArray)
        {
            NSString *keyValueStr = [prefItem objectForKey:@"Key"];
            id defaultValue = [prefItem objectForKey:@"DefaultValue"];
            
            if ([keyValueStr isEqualToString:SETTINGS_BUNDLE_serverUrl_IDENTIFIER] && defaultValue)
            {
                NSArray *splits = [defaultValue componentsSeparatedByString:@":"];
                serverUrl = splits[0];
                if(splits.count>1)
                    port = [splits[1] intValue];
                
                [standardUserDefaults registerDefaults:[NSDictionary dictionaryWithObject:defaultValue forKey:SETTINGS_BUNDLE_serverUrl_IDENTIFIER]];
                break;
            }
        }
    }

    NSString* chatSeverHostValue = [standardUserDefaults objectForKey:SETTINGS_BUNDLE_chatserverHost_IDENTIFIER];
    if (!chatSeverHostValue) {
        for (NSDictionary *prefItem in prefSpecifierArray)
        {
            NSString *keyValueStr = [prefItem objectForKey:@"Key"];
            id defaultValue = [prefItem objectForKey:@"DefaultValue"];
            
            if ([keyValueStr isEqualToString:SETTINGS_BUNDLE_chatserverHost_IDENTIFIER] && defaultValue)
            {
                chatSeverHostValue = defaultValue;

                [standardUserDefaults registerDefaults:[NSDictionary dictionaryWithObject:defaultValue forKey:SETTINGS_BUNDLE_chatserverHost_IDENTIFIER]];
                break;
            }
        }
    }
    
    NSString* chatSeverPortValue = [standardUserDefaults objectForKey:SETTINGS_BUNDLE_chatserverPort_IDENTIFIER];
    if (!chatSeverHostValue) {
        for (NSDictionary *prefItem in prefSpecifierArray)
        {
            NSString *keyValueStr = [prefItem objectForKey:@"Key"];
            id defaultValue = [prefItem objectForKey:@"DefaultValue"];
            
            if ([keyValueStr isEqualToString:SETTINGS_BUNDLE_chatserverPort_IDENTIFIER] && defaultValue)
            {
                chatSeverPortValue = defaultValue;
                
                [standardUserDefaults registerDefaults:[NSDictionary dictionaryWithObject:defaultValue forKey:SETTINGS_BUNDLE_chatserverPort_IDENTIFIER]];
                break;
            }
        }
    }

    if(serverUrl==nil || serverUrl.length == 0 || chatSeverHostValue==nil || chatSeverHostValue.length == 0 || chatSeverPortValue==nil || chatSeverPortValue.length == 0) {
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                                      message:NSLocalizedString(@"ServerUrlEmptyError", @"")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Exit", @"")
                                            otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    _serverUrl = serverUrl;
    _port = port;
    _chatServerHost = chatSeverHostValue;
    _chatServerPort = chatSeverPortValue;

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    [headers setValue:@"iOS" forKey:@"x-client-identifier"];
    self.engine = [CommonNetworkEngine getObject:self.serverUrl customHeaderFields:headers];
    self.engine.portNumber = self.port;
    self.engine.reachabilityChangedHandler = ^(NetworkStatus ns){
        if (ns == NotReachable) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:ResubmittableRecordNotification object:nil];
            
            [[NetworkEngine recordStore] stopNotification];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resubmit:)
                                                         name:ResubmittableRecordNotification
                                                       object:nil];
            [[NetworkEngine recordStore] startNotification];
        }
    };
}

-(BOOL)isReachable {
    return [self engine].isReachable;
}

-(void) resubmit:(NSNotification*)notification
{
    NSArray* records = (NSArray*) notification.object;
    if (records && records.count) {
        for (ResubmittableRecord* record in records) {
        }
    }
}

-(CommonNetworkOperation*) doLogin:(NSString*)loginName plainPassword:(NSString*)plainPassword codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/private/user"
                                                     params:@{@"userFilter":[@{@"loginName":loginName, @"plainPassword":plainPassword} JSONStringWithOptions:JKSerializeOptionNone error:NULL]}
                                                 httpMethod:@"GET"];
    [op setBasicAuthUsername:loginName password:plainPassword];
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) getUser:(NSString*)loginName codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/private/user"
                                                     params:@{@"userFilter":[@{@"loginName":loginName} JSONStringWithOptions:JKSerializeOptionNone error:NULL]}
                                                 httpMethod:@"GET"];
    op.isCacheable = YES;
    [op setBasicAuthUsername:[SecurityContext getObject].details.loginName password:[SecurityContext getObject].details.plainPassword];
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) getUserDetails:(NSString*)userFilter codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/private/userDetail"
                                                     params:@{@"userFilter":userFilter}
                                                 httpMethod:@"GET"];
    op.isCacheable = YES;
    [op setBasicAuthUsername:[SecurityContext getObject].details.loginName password:[SecurityContext getObject].details.plainPassword];
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) getProject:(NSString*)projectFilter codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/project"
                                                         params:@{@"projectFilter":projectFilter}
                                                     httpMethod:@"GET"];
    op.isCacheable = YES;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) downloadModules:(NKResponseBlock)codeBlock onError:(NKErrorBlock)errorBlock progressBlock:(DownloadProgressBlock)progressBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/moduleFile"
                                                         params:@{}
                                                     httpMethod:@"GET"];
    op.isPersistable = YES;
    op.downloadSizePerRequest = 512000;
    [op addHeaders:@{@"Accept-Encoding":@"application/octet-stream"}];
    [op setFileToBeSaved:[NSURL fileURLWithPath:[[Global tmpPath] stringByAppendingPathComponent:@"modules.zip"]]];
    [op addCompletionHandler:codeBlock errorHandler:errorBlock];
    [op onDownloadProgressChanged:progressBlock];
    
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) downloadProject:(NSString*)projectId codeBlock:(NKResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock progressBlock:(DownloadProgressBlock)progressBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/projectFile"
                                                         params:@{@"projectId":projectId}
                                                     httpMethod:@"GET"];
    op.isPersistable = YES;
    op.downloadSizePerRequest = 512000;
    [op addHeaders:@{@"Accept-Encoding":@"application/octet-stream"}];
    [op setFileToBeSaved:[NSURL fileURLWithPath:[[Global tmpPath] stringByAppendingPathComponent:[projectId stringByAppendingPathExtension:@"zip"]]]];
    [op addCompletionHandler:codeBlock errorHandler:errorBlock];
    [op onDownloadProgressChanged:progressBlock];

    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(NSDictionary*) downloadProjectInfo:(NSString *)projectId
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/projectFile"
                                                         params:@{@"projectId":projectId}
                                                     httpMethod:@"GET"];
    return op.downloadInfo;
}

-(BOOL) downloadProjectInProgress:(NSString *)projectId
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/projectFile"
                                                         params:@{@"projectId":projectId}
                                                     httpMethod:@"GET"];
    return [CommonNetworkEngine operationExists:op.uniqueIdentifier];
}

-(void) pauseDownloadProject:(NSString *)projectId
{
    [self.engine stopDownload:@"api/public/projectFile" params:@{@"projectId":projectId}];
}



-(CommonNetworkOperation*) createChat:(NSString*)userId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/chat"
                                                         params:@{@"userId":userId}
                                                     httpMethod:@"POST"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) connectChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/connectChat"
                                                         params:@{@"userId": userId, @"chatId":chatId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) pauseChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/pauseChat"
                                                         params:@{@"userId": userId, @"chatId":chatId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) closeChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/closeChat"
                                                         params:@{@"userId": userId, @"chatId":chatId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) deleteChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/chat"
                                                         params:@{@"userId": userId, @"chatId":chatId}
                                                     httpMethod:@"DELETE"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) connectTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/connectTopic"
                                                         params:@{@"userId": userId, @"topicId":topicId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) closeTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/closeTopic"
                                                         params:@{@"userId": userId, @"topicId":topicId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) deleteTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/topic"
                                                         params:@{@"userId": userId, @"topicId":topicId}
                                                     httpMethod:@"DELETE"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) connectInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/connectInbox"
                                                         params:@{@"userId": userId, @"inboxId":inboxId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) closeInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/closeInbox"
                                                         params:@{@"userId": userId, @"inboxId":inboxId}
                                                     httpMethod:@"PUT"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

-(CommonNetworkOperation*) deleteInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock
{
    CommonNetworkOperation *op = [self.engine operationWithPath:@"api/public/inbox"
                                                         params:@{@"userId": userId, @"inboxId":inboxId}
                                                     httpMethod:@"DELETE"];
    op.isCacheable = NO;
    [op addHeaders:@{@"Accept":@"text/plain;charset=utf-8"}];
    [op addCompletionHandler:^(CommonNetworkOperation *operation) {
        codeBlock([operation responseString]);
    } errorHandler:^(CommonNetworkOperation *errorOp, NSString* prevResponsePath, NSError *error) {
        errorBlock(errorOp, prevResponsePath, error);
    }];
    [self.engine enqueueOperation:op forceReload:NO];
    
    return op;
}

@end