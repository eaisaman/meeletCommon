//
//  NetworkEngine.h
//  MeeletCommon
//
//  Created by jill on 15/5/24.
//
//

#ifndef MeeletCommon_NetworkEngine_h
#define MeeletCommon_NetworkEngine_h

#import <Foundation/Foundation.h>
#import "CommonNetworkKit.h"
#import "ResubmittableRecordStore.h"

typedef void (^StringResponseBlock)(NSString* str);
typedef void (^DownloadProgressBlock)(double progress);

@interface NetworkEngine : NSObject

@property (nonatomic, retain) CommonNetworkEngine *engine;
@property (nonatomic, readonly) NSString* serverUrl;
@property (nonatomic, readonly) int port;
@property (nonatomic, readonly) NSString* chatServerHost;
@property (nonatomic, readonly) NSString* chatServerPort;

+(ResubmittableRecordStore*)recordStore;
-(void)initEngine;
-(BOOL)isReachable;

-(CommonNetworkOperation*) doLogin:(NSString*)loginName plainPassword:(NSString*)plainPassword codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) getUser:(NSString*)loginName codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) getUserDetails:(NSString*)userFilter codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) getProject:(NSString*)projectFilter codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) downloadModules:(NKResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock progressBlock:(DownloadProgressBlock)progressBlock;
-(CommonNetworkOperation*) downloadProject:(NSString*)projectId codeBlock:(NKResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock progressBlock:(DownloadProgressBlock)progressBlock;
-(NSDictionary*) downloadProjectInfo:(NSString*)projectId;
-(BOOL) downloadProjectInProgress:(NSString *)projectId;
-(void) pauseDownloadProject:(NSString*)projectId;

-(CommonNetworkOperation*) createChat:(NSString*)userId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) connectChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) closeChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) deleteChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) pauseChat:(NSString*)userId chatId:(NSString*)chatId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;

-(CommonNetworkOperation*) createTopic:(NSString*)userId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) connectTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) closeTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) deleteTopic:(NSString*)userId topicId:(NSString*)topicId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;

-(CommonNetworkOperation*) createInbox:(NSString*)userId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) connectInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) closeInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;
-(CommonNetworkOperation*) deleteInbox:(NSString*)userId inboxId:(NSString*)inboxId codeBlock:(StringResponseBlock) codeBlock onError:(NKErrorBlock) errorBlock;

@end

#endif
