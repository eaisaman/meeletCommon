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

#define SETTINGS_BUNDLE_serverUrl_IDENTIFIER @"server_url"

#define ENUM_NAME(x,v) [NSString stringWithCString:x##Name[v] encoding:NSASCIIStringEncoding]

typedef void (^ReponseBlock)(void);
typedef void (^ErrorBlock)(NSError* error);

typedef NS_ENUM(NSUInteger, ProjectMode) {
    WaitDownload = 0,
    WaitRefersh = 1,
    InProgress = 2
};

extern const char* ProjectModeName[];

@interface Global : NSObject

+ (void)initApplication;
+ (NetworkEngine*)engine;
+ (NSString*)sharedResourcePath;
+ (NSString*)tmpPath;
+ (NSString*)projectContentPath:(NSString*)projectId;
+ (NSString*)projectInfoPath:(NSString*)projectId;
+ (NSString*)projectsModulesPath;
+ (NSString*)embeddedPath;

+ (void)setLoginUser:(NSString*)loginName plainPassword:(NSString*)plainPassword userObj:(NSDictionary*)userObj;
+ (void)setLoginUser:(NSDictionary*)userObj;
+ (NSDictionary*)getLoginUser;
+ (NSArray*)getLocalProject;
+ (void)exitPage;
+ (void)downloadModules;
+ (void)downloadProject:(NSString*)projectId;
+ (void)pauseDownloadProject:(NSString*)projectId;
+ (void)scanProjectCode;
+ (void)deleteLocalProject:(NSString*)projectId;
+ (void)showProject:(NSString*)projectId codeBlock:(ReponseBlock)codeBlock errorBlock:(ErrorBlock)errorBlock;
+ (NSString*)saveAvatar:(NSString*)projectId filePath:(NSString*)filePath;

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
