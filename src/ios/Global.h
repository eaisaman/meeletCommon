//
//  Global.h
//  MeeletCommon
//
//  Created by jill on 15/5/24.
//
//

#ifndef MeeletCommon_Global_h
#define MeeletCommon_Global_h

#import "NetworkEngine.h"

#define APP_ERROR_DOMAIN @"meeletCommonErrorDomain"
#define APP_ERROR_OPEN_FILE_CODE -1
#define APP_ERROR_PLAY_SOUND_CODE -2
#define APP_ERROR_CREATE_FILE_CODE -3

#define SETTINGS_BUNDLE_serverUrl_IDENTIFIER @"server_url"
#define SETTINGS_BUNDLE_chatserverHost_IDENTIFIER @"chat_server_host"
#define SETTINGS_BUNDLE_chatserverPort_IDENTIFIER @"chat_server_port"

#define AppEventDeclare(x) extern NSString *x##Event;
#define AppEventDefine(x) NSString *x##Event=@#x;
#define ENUM_NAME(x,v) [NSString stringWithCString:x##Name[v] encoding:NSASCIIStringEncoding]

typedef void (^ReponseBlock)(void);
typedef void (^ErrorBlock)(NSError* error);

typedef NS_ENUM(NSUInteger, ProjectMode) {
    WaitDownload = 0,
    WaitRefersh = 1,
    InProgress = 2
};

extern const char* ProjectModeName[];

AppEventDeclare(projectScan);
AppEventDeclare(normalScan);
AppEventDeclare(getProjectError);
AppEventDeclare(getProjectModulesError);
AppEventDeclare(deleteLocalProject);
AppEventDeclare(downloadProjectStart);
AppEventDeclare(downloadProjectStop);
AppEventDeclare(downloadProjectDone);
AppEventDeclare(downloadProjectError);
AppEventDeclare(downloadProjectProgress);
AppEventDeclare(downloadProjectModulesStart);
AppEventDeclare(downloadProjectModulesDone);
AppEventDeclare(downloadProjectModulesError);
AppEventDeclare(downloadProjectModulesProgress);

@protocol IEventDispatcher <NSObject>

- (void)sendAppEventWithName:(NSString *)name body:(NSDictionary*)body;

@end

@interface Global : NSObject

+ (void)initApplication;
+ (void)initEventDispatcher:(id<IEventDispatcher>)dispatcher;
+ (NetworkEngine*)engine;
+ (NSString*)sharedResourcePath;
+ (NSString*)tmpPath;
+ (NSString*)projectContentPath:(NSString*)projectId;
+ (NSString*)projectInfoPath:(NSString*)projectId;
+ (NSString*)projectsModulesPath;
+ (NSString*)embeddedPath;
+ (void)dispatchEvent:(NSString*)eventType eventObj:(NSDictionary*)eventObj;

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary*)userObj;
+ (void)setLoginUser:(NSDictionary*)userObj;
+ (NSDictionary*)getLoginUser;
+ (NSArray*)getLocalProject;
+ (void)exitPage;
+ (void)downloadModules;
+ (void)downloadProject:(NSString*)projectId;
+ (void)pauseDownloadProject:(NSString*)projectId;
+ (void)scanProjectCode;
+ (void)scanQRCode;
+ (void)deleteLocalProject:(NSString*)projectId;
+ (void)showProject:(NSString*)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;
+ (void)showHostProject:(NSString*)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;
+ (NSString*)saveAvatar:(NSString*)projectId filePath:(NSString*)filePath;
//Sometimes we need to display project content in an H5 app content, instead of displaying in a UIWebView alone.
//We will clone app's www folder to some place and launch MainViewController there.
+ (NSError*)buildProjectHost;
+ (void)sendChatMessage:(NSString*)userId chatId:(NSString*)chatId payload:(NSDictionary*)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;
+ (void)sendTopicMessage:(NSString*)userId topicId:(NSString*)topicId payload:(NSDictionary*)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;
+ (void)sendInboxMessage:(NSString*)userId inboxId:(NSString*)inboxId payload:(NSDictionary*)paylod codeBlock:(StringResponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;

+ (BOOL)isValidObjectId:(NSString*)idStr;
+ (NSDate*)parseDateString:(NSString*)dateString;
+ (NSDictionary*)restoreJSONDate:(NSDictionary*)dict;
+ (NSString*)projectMode:(NSString*)projectId;
+ (NSUInteger)projectProgress:(NSString*)projectId;
+ (void)playSound:(NSURL*)url playLoop:(BOOL)playLoop;
+ (void)stopPlaySound;
+ (BOOL) isPlayingSound;

@end

#endif
