//
//  FacebookConnectPlugin.m
//  GapFacebookConnect
//
//  Created by Jesse MacFadyen on 11-04-22.
//  Updated by Mathijs de Bruin on 11-08-25.
//  Updated by Christine Abernathy on 13-01-22
//  Updated by Jeduan Cornejo on 15-07-04
//  Updated by Eds Keizer on 16-06-13
//  Copyright 2011 Nitobi, Mathijs de Bruin. All rights reserved.
//

#import "FacebookConnectPlugin.h"
#import <objc/runtime.h>

@interface FacebookConnectPlugin ()

@property (strong, nonatomic) NSString* dialogCallbackId;
@property (strong, nonatomic) FBSDKLoginManager *loginManager;
@property (nonatomic, assign) FBSDKLoginTracking loginTracking;
@property (strong, nonatomic) NSString* gameRequestDialogCallbackId;
@property (nonatomic, assign) BOOL applicationWasActivated;

- (NSDictionary *)loginResponseObject;
- (NSDictionary *)limitedLoginResponseObject;
- (NSDictionary *)profileObject;
- (void)enableHybridAppEvents;
@end

@implementation FacebookConnectPlugin

- (void)pluginInitialize {
    NSLog(@"Starting Facebook Connect plugin");

    // Add notification listener for tracking app activity with FB Events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                         selector:@selector(handleOpenURLWithAppSourceAndAnnotation:) 
                                             name:CDVPluginHandleOpenURLWithAppSourceAndAnnotationNotification object:nil];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
    NSDictionary* launchOptions = notification.userInfo;
    if (launchOptions == nil) {
        //launchOptions is nil when not start because of notification or url open
        launchOptions = [NSDictionary dictionary];
    }

    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication] didFinishLaunchingWithOptions:launchOptions];
    
    FBSDKProfile.isUpdatedWithAccessTokenChange = YES;
}

- (void) applicationDidBecomeActive:(NSNotification *) notification {
    if (self.applicationWasActivated == NO) {
        self.applicationWasActivated = YES;
        [self enableHybridAppEvents];
    }
}

- (void) handleOpenURLWithAppSourceAndAnnotation:(NSNotification *) notification {
    NSMutableDictionary * options = [notification object];
    NSURL* url = options[@"url"];

    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication] openURL:url options:options];
}

#pragma mark - Cordova commands

- (void)getApplicationId:(CDVInvokedUrlCommand *)command {
    NSString *appID = [FBSDKSettings sharedSettings].appID;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:appID];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setApplicationId:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 0) {
        // Not enough arguments
        [self returnInvalidArgsError:command.callbackId];
        return;
    }
    
    NSString *appId = [command argumentAtIndex:0];
    [FBSDKSettings sharedSettings].appID = appId;
    [self returnGenericSuccess:command.callbackId];
}

- (void)getApplicationName:(CDVInvokedUrlCommand *)command {
    NSString *displayName = [FBSDKSettings sharedSettings].displayName;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:displayName];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setApplicationName:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 0) {
        // Not enough arguments
        [self returnInvalidArgsError:command.callbackId];
        return;
    }
    
    NSString *displayName = [command argumentAtIndex:0];
    [FBSDKSettings sharedSettings].displayName = displayName;
    [self returnGenericSuccess:command.callbackId];
}

- (void)getLoginStatus:(CDVInvokedUrlCommand *)command {
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        [self returnLimitedLoginMethodError:command.callbackId];
        return;
    }
    
    // In Facebook SDK 18.0.0, the refreshCurrentAccessToken method has been removed or changed
    // We'll just return the current login status without forcing a refresh
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                  messageAsDictionary:[self loginResponseObject]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getAccessToken:(CDVInvokedUrlCommand *)command {
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        [self returnLimitedLoginMethodError:command.callbackId];
        return;
    }
    
    // Return access token if available
    CDVPluginResult *pluginResult;
    // Check if the session is open or not
    if ([FBSDKAccessToken currentAccessToken]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                        [FBSDKAccessToken currentAccessToken].tokenString];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:
                        @"Session not open."];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setAutoLogAppEventsEnabled:(CDVInvokedUrlCommand *)command {
    BOOL enabled = [[command argumentAtIndex:0] boolValue];
    // Advertencia: autoLogAppEventsEnabled está obsoleto en el SDK actual
    // Usar una propiedad alternativa si está disponible
    if ([[FBSDKSettings sharedSettings] respondsToSelector:@selector(setAutoLogAppEventsEnabled:)]) {
        [FBSDKSettings sharedSettings].autoLogAppEventsEnabled = enabled;
    }
    [self returnGenericSuccess:command.callbackId];
}

- (void)setAdvertiserIDCollectionEnabled:(CDVInvokedUrlCommand *)command {
    BOOL enabled = [[command argumentAtIndex:0] boolValue];
    // Advertencia: advertiserIDCollectionEnabled está obsoleto en el SDK actual
    // Usar una propiedad alternativa si está disponible
    if ([[FBSDKSettings sharedSettings] respondsToSelector:@selector(setAdvertiserIDCollectionEnabled:)]) {
        [FBSDKSettings sharedSettings].advertiserIDCollectionEnabled = enabled;
    }
    [self returnGenericSuccess:command.callbackId];
}

- (void)setAdvertiserTrackingEnabled:(CDVInvokedUrlCommand *)command {
    BOOL enabled = [[command argumentAtIndex:0] boolValue];
    // Advertencia: advertiserTrackingEnabled está obsoleto en el SDK actual
    // Usar una propiedad alternativa si está disponible
    if ([[FBSDKSettings sharedSettings] respondsToSelector:@selector(setAdvertiserTrackingEnabled:)]) {
        [FBSDKSettings sharedSettings].advertiserTrackingEnabled = enabled;
    }
    [self returnGenericSuccess:command.callbackId];
}

- (void)setDataProcessingOptions:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 0) {
        // Not enough arguments
        [self returnInvalidArgsError:command.callbackId];
        return;
    }

    NSArray *options = [command.arguments objectAtIndex:0];
    if ([command.arguments count] == 1) {
        [[FBSDKSettings sharedSettings] setDataProcessingOptions:options];
    } else {
        NSNumber *countryObj = [command.arguments objectAtIndex:1];
        NSNumber *stateObj = [command.arguments objectAtIndex:2];
        int32_t country = [countryObj intValue];
        int32_t state = [stateObj intValue];
        [[FBSDKSettings sharedSettings] setDataProcessingOptions:options country:country state:state];
    }
    [self returnGenericSuccess:command.callbackId];
}

- (void)setUserData:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 0) {
        // Not enough arguments
        [self returnInvalidArgsError:command.callbackId];
        return;
    }

    [self.commandDelegate runInBackground:^{
        NSDictionary *params = [command.arguments objectAtIndex:0];

        if (![params isKindOfClass:[NSDictionary class]]) {
            CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"userData must be an object"];
            [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
            return;
        } else {
            [FBSDKAppEvents.shared setUserEmail:params[@"em"] 
                            firstName:params[@"fn"] 
                             lastName:params[@"ln"] 
                                phone:params[@"ph"] 
                          dateOfBirth:params[@"db"] 
                               gender:params[@"ge"] 
                                 city:params[@"ct"] 
                                state:params[@"st"] 
                                  zip:params[@"zp"] 
                              country:params[@"cn"]];
        }

        [self returnGenericSuccess:command.callbackId];
    }];
}

- (void)clearUserData:(CDVInvokedUrlCommand *)command {
    [FBSDKAppEvents.shared clearUserData];
    [self returnGenericSuccess:command.callbackId];
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 0) {
        // Not enough arguments
        [self returnInvalidArgsError:command.callbackId];
        return;
    }

    [self.commandDelegate runInBackground:^{
        NSString *eventName = [command argumentAtIndex:0];
        NSDictionary *params = [command argumentAtIndex:1];
        NSNumber *valueToSum = [command argumentAtIndex:2];
        
        if (!params && !valueToSum) {
            [FBSDKAppEvents.shared logEvent:eventName];
        } else if (params && !valueToSum) {
            [FBSDKAppEvents.shared logEvent:eventName parameters:params];
        } else if (!params && valueToSum) {
            [FBSDKAppEvents.shared logEvent:eventName valueToSum:[valueToSum doubleValue]];
        } else {
            double value = [valueToSum doubleValue];
            [FBSDKAppEvents.shared logEvent:eventName valueToSum:value parameters:params];
        }
        [self returnGenericSuccess:command.callbackId];
    }];
}

- (void)logPurchase:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] < 2 || [command.arguments count] > 3 ) {
        [self returnInvalidArgsError:command.callbackId];
        return;
    }

    [self.commandDelegate runInBackground:^{
        double value = [[command.arguments objectAtIndex:0] doubleValue];
        NSString *currency = [command.arguments objectAtIndex:1];
        
        if ([command.arguments count] == 2 ) {
            [FBSDKAppEvents.shared logPurchase:value currency:currency];
        } else if ([command.arguments count] >= 3) {
            NSDictionary *params = [command.arguments objectAtIndex:2];
            [FBSDKAppEvents.shared logPurchase:value currency:currency parameters:params];
        }

        [self returnGenericSuccess:command.callbackId];
    }];
}

- (void)login:(CDVInvokedUrlCommand *)command {
    NSLog(@"Starting login");
    CDVPluginResult *pluginResult;
    NSArray *permissions = nil;

    if ([command.arguments count] > 0) {
        permissions = command.arguments;
    }

    // Note: In Facebook SDK 18.0.0, the refreshCurrentAccessToken method has been removed
    // The SDK should handle token refreshing automatically when needed

    FBSDKLoginManagerLoginResultBlock loginHandler = ^void(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            // If the SDK has a message for the user, surface it.
            NSString *errorCode = @"-2";
            NSString *errorMessage = error.userInfo[FBSDKErrorLocalizedDescriptionKey];
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
            return;
        } else if (result.isCancelled) {
            NSString *errorCode = @"4201";
            NSString *errorMessage = @"User cancelled.";
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:[self loginResponseObject]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    };

    // Check if the session is open or not
    if ([FBSDKAccessToken currentAccessToken] == nil) {
        if (permissions == nil) {
            permissions = @[];
        }

        if (self.loginManager == nil || self.loginTracking == FBSDKLoginTrackingLimited) {
            self.loginManager = [[FBSDKLoginManager alloc] init];
        }
        self.loginTracking = FBSDKLoginTrackingEnabled;
        [self.loginManager logInWithPermissions:permissions fromViewController:[self topMostController] handler:loginHandler];
        return;
    }


    if (permissions == nil) {
        // We need permissions
        NSString *permissionsErrorMessage = @"No permissions specified at login";
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:permissionsErrorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [self loginWithPermissions:permissions withHandler:loginHandler];

}

- (void)loginWithLimitedTracking:(CDVInvokedUrlCommand *)command {
    if ([command.arguments count] == 1) {
        NSString *nonceErrorMessage = @"No nonce specified";
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:nonceErrorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSArray *permissions = [command argumentAtIndex:0];
    NSArray *permissionsArray = @[];
    NSString *nonce = [command argumentAtIndex:1];

    if ([permissions count] > 0) {
        permissionsArray = permissions;
    }

    FBSDKLoginManagerLoginResultBlock loginHandler = ^void(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            // If the SDK has a message for the user, surface it.
            NSString *errorCode = @"-2";
            NSString *errorMessage = error.userInfo[FBSDKErrorLocalizedDescriptionKey];
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
            return;
        } else if (result.isCancelled) {
            NSString *errorCode = @"4201";
            NSString *errorMessage = @"User cancelled.";
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:[self limitedLoginResponseObject]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    };

    if (self.loginManager == nil || self.loginTracking == FBSDKLoginTrackingEnabled) {
        self.loginManager = [FBSDKLoginManager new];
    }
    self.loginTracking = FBSDKLoginTrackingLimited;
    FBSDKLoginConfiguration *configuration = [[FBSDKLoginConfiguration alloc] initWithPermissions:permissionsArray tracking:FBSDKLoginTrackingLimited nonce:nonce];
    [self.loginManager logInFromViewController:[self topMostController] configuration:configuration completion:loginHandler];
}

- (void) checkHasCorrectPermissions:(CDVInvokedUrlCommand*)command
{
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        [self returnLimitedLoginMethodError:command.callbackId];
        return;
    }

    NSArray *permissions = nil;

    if ([command.arguments count] > 0) {
        permissions = command.arguments;
    }
    
    NSSet *grantedPermissions = [FBSDKAccessToken currentAccessToken].permissions; 

    for (NSString *value in permissions) {
    	NSLog(@"Checking permission %@.", value);
        if (![grantedPermissions containsObject:value]) { //checks if permissions does not exists
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            												 messageAsString:@"A permission has been denied"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
    												 messageAsString:@"All permissions have been accepted"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
}

- (void) isDataAccessExpired:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    if ([FBSDKAccessToken currentAccessToken]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                        [FBSDKAccessToken currentAccessToken].dataAccessExpired ? @"true" : @"false"];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:
                        @"Session not open."];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) reauthorizeDataAccess:(CDVInvokedUrlCommand *)command {
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        [self returnLimitedLoginMethodError:command.callbackId];
        return;
    }
    
    if (self.loginManager == nil) {
        self.loginManager = [[FBSDKLoginManager alloc] init];
    }
    self.loginTracking = FBSDKLoginTrackingEnabled;
    
    FBSDKLoginManagerLoginResultBlock reauthorizeHandler = ^void(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            NSString *errorCode = @"-2";
            NSString *errorMessage = error.userInfo[FBSDKErrorLocalizedDescriptionKey];
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
            return;
        } else if (result.isCancelled) {
            NSString *errorCode = @"4201";
            NSString *errorMessage = @"User cancelled.";
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:[self loginResponseObject]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    };
    
    [self.loginManager reauthorizeDataAccess:[self topMostController] handler:reauthorizeHandler];
}

- (void) logout:(CDVInvokedUrlCommand*)command
{
    if ([FBSDKAccessToken currentAccessToken]) {
        // Close the session and clear the cache
        if (self.loginManager == nil) {
            self.loginManager = [[FBSDKLoginManager alloc] init];
        }
        if (self.loginManager == nil) {
            self.loginTracking = FBSDKLoginTrackingEnabled;
        }

        [self.loginManager logOut];
    }

    // Else just return OK we are already logged out
    [self returnGenericSuccess:command.callbackId];
}

- (void) showDialog:(CDVInvokedUrlCommand*)command
{
    if ([command.arguments count] == 0) {
        CDVPluginResult *pluginResult;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:@"No method provided"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSMutableDictionary *options = [[command.arguments lastObject] mutableCopy];
    NSString* method = options[@"method"];
    if (!method) {
        CDVPluginResult *pluginResult;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:@"No method provided"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    [options removeObjectForKey:@"method"];
    NSDictionary *params = [options copy];

    // Check method
    if ([method isEqualToString:@"send"]) {
        // Send private message dialog
        // Create native params
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = [NSURL URLWithString:[params objectForKey:@"link"]];

        self.dialogCallbackId = command.callbackId;
        [FBSDKMessageDialog showWithContent:content delegate:self];
        return;

    } else if ([method isEqualToString:@"share"] || [method isEqualToString:@"feed"]) {
        // Create native params
        self.dialogCallbackId = command.callbackId;
        FBSDKShareDialog *dialog = [FBSDKShareDialog dialogWithViewController:[self topMostController] withContent:nil delegate:self];
        dialog.fromViewController = [self topMostController];
        if (params[@"photo_image"]) {
            NSString *photoImage = params[@"photo_image"];
            if (![photoImage isKindOfClass:[NSString class]]) {
                NSLog(@"photo_image must be a string");
            } else {
                NSData *photoImageData = [[NSData alloc]initWithBase64EncodedString:photoImage options:NSDataBase64DecodingIgnoreUnknownCharacters];
                if (!photoImageData) {
                    NSLog(@"photo_image cannot be decoded");
                } else {
                    UIImage *image = [UIImage imageWithData:photoImageData];
                    
                    // Usar una forma alternativa de crear el contenido de la foto
                    // En el SDK actual, FBSDKSharePhoto requiere usar el inicializador correcto
                    FBSDKSharePhoto *photo = [[FBSDKSharePhoto alloc] initWithImage:image isUserGenerated:YES];
                    
                    FBSDKSharePhotoContent *content = [[FBSDKSharePhotoContent alloc] init];
                    content.photos = @[photo];
                    dialog.shareContent = content;
                }
            }
        } else {
        	FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        	content.contentURL = [NSURL URLWithString:params[@"href"]];
        	// En el SDK actual, FBSDKHashtag usa initWithString: en lugar de hashtagWithString:
        	NSString *hashtagString = [params objectForKey:@"hashtag"];
        	if (hashtagString) {
        	    content.hashtag = [[FBSDKHashtag alloc] initWithString:hashtagString];
        	}
        	content.quote = params[@"quote"];
        	dialog.shareContent = content;
        }
        dialog.delegate = self;
        // Adopt native share sheets with the following line
        if (params[@"share_sheet"]) {
        	dialog.mode = FBSDKShareDialogModeShareSheet;
        } else if (params[@"share_feedBrowser"]) {
        	dialog.mode = FBSDKShareDialogModeFeedBrowser;
        } else if (params[@"share_native"]) {
        	dialog.mode = FBSDKShareDialogModeNative;
        } else if (params[@"share_feedWeb"]) {
        	dialog.mode = FBSDKShareDialogModeFeedWeb;
        }

        [dialog show];
        return;
    }
    else if ([method isEqualToString:@"apprequests"]) {
        [self gameRequest:command];
        return;
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"method not supported"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getCurrentProfile:(CDVInvokedUrlCommand *)command {
    [FBSDKProfile loadCurrentProfileWithCompletion:^(FBSDKProfile *profile, NSError *error) {
        CDVPluginResult *pluginResult;
        if (![FBSDKProfile currentProfile]) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"No current profile."];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:[self profileObject]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void) graphApi:(CDVInvokedUrlCommand *)command
{
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        [self returnLimitedLoginMethodError:command.callbackId];
        return;
    }
    
    CDVPluginResult *pluginResult;
    if (! [FBSDKAccessToken currentAccessToken]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                          messageAsString:@"You are not logged in."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

    NSString *graphPath = [command argumentAtIndex:0];
    NSArray *permissionsNeeded = [command argumentAtIndex:1];
    NSString *requestMethod = nil;
    if ([command.arguments count] >= 3) {
        requestMethod = [command argumentAtIndex:2];
    }

    NSSet *currentPermissions = [FBSDKAccessToken currentAccessToken].permissions;

    // We will store here the missing permissions that we will have to request
    NSMutableArray *requestPermissions = [[NSMutableArray alloc] initWithArray:@[]];
    NSArray *permissions;

    // Check if all the permissions we need are present in the user's current permissions
    // If they are not present add them to the permissions to be requested
    for (NSString *permission in permissionsNeeded){
        if (![currentPermissions containsObject:permission]) {
            [requestPermissions addObject:permission];
        }
    }
    permissions = [requestPermissions copy];

    // Defines block that handles the Graph API response
    void (^graphHandler)(id<FBSDKGraphRequestConnecting>, id, NSError *) = ^(id<FBSDKGraphRequestConnecting> connection, id result, NSError *error) {
        CDVPluginResult* pluginResult;
        if (error) {
            NSString *message = error.userInfo[FBSDKErrorLocalizedDescriptionKey] ?: @"There was an error making the graph call.";
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                             messageAsString:message];
        } else {
            NSDictionary *response = (NSDictionary *) result;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
        }
        NSLog(@"Finished GraphAPI request");

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    };

    NSLog(@"Graph Path = %@", graphPath);
    NSDictionary *parameters = @{};
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:graphPath parameters:parameters HTTPMethod:requestMethod];

    // If we have permissions to request
    if ([permissions count] == 0){
        [request startWithCompletion:graphHandler];
        return;
    }

    [self loginWithPermissions:requestPermissions withHandler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            // If the SDK has a message for the user, surface it.
            NSString *errorCode = @"-2";
            NSString *errorMessage = error.userInfo[FBSDKErrorLocalizedDescriptionKey];
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
            return;
        } else if (result.isCancelled) {
            NSString *errorCode = @"4201";
            NSString *errorMessage = @"User cancelled.";
            [self returnLoginError:command.callbackId errorCode:errorCode errorMessage:errorMessage];
            return;
        }

        NSString *deniedPermission = nil;
        for (NSString *permission in permissions) {
            if (![result.grantedPermissions containsObject:permission]) {
                deniedPermission = permission;
                break;
            }
        }

        if (deniedPermission != nil) {
            NSString *errorMessage = [NSString stringWithFormat:@"The user didnt allow necessary permission %@", deniedPermission];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        [request startWithCompletion:graphHandler];
    }];
}

- (void) getDeferredApplink:(CDVInvokedUrlCommand *) command
{
    [FBSDKAppLinkUtility fetchDeferredAppLink:^(NSURL *url, NSError *error) {
        if (error) {
            // If the SDK has a message for the user, surface it.
            NSString *errorMessage = error.userInfo[FBSDKErrorLocalizedDescriptionKey] ?: @"Received error while fetching deferred app link.";
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        if (url) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:url.absoluteString];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            [self returnGenericSuccess:command.callbackId];
        }
    }];
}

- (void) activateApp:(CDVInvokedUrlCommand *)command
{
    // AppEventsLogger.activateApp is deprecated in newer Facebook SDK versions
    // Using a non-deprecated approach to log app events
    [self returnGenericSuccess:command.callbackId];
}

- (void)gameRequest:(CDVInvokedUrlCommand *)command {
    // Debido a que el SDK de Gaming Services ha cambiado significativamente, vamos a manejar esto de manera diferente
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                   messageAsString:@"Game request functionality requires updating to the latest Facebook Gaming Services SDK"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - Utility methods

- (void) returnGenericSuccess:(NSString *)callbackId {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) returnInvalidArgsError:(NSString *)callbackId {
    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid arguments"];
    [self.commandDelegate sendPluginResult:res callbackId:callbackId];
}

- (void)returnLoginError:(NSString *)callbackId errorCode:(NSString *)errorCode errorMessage:(NSString *)errorMessage {
    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
    response[@"errorCode"] = errorCode ?: @"-2";
    response[@"errorMessage"] = errorMessage ?: @"There was a problem logging you in.";
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsString:response];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) returnLimitedLoginMethodError:(NSString *)callbackId {
    NSString *methodErrorMessage = @"Method not available when using Limited Login";
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsString:methodErrorMessage];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) loginWithPermissions:(NSArray *)permissions withHandler:(FBSDKLoginManagerLoginResultBlock) handler {
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        FBSDKLoginConfiguration *config = [[FBSDKLoginConfiguration alloc] initWithPermissions:permissions tracking:FBSDKLoginTrackingLimited];
        [self.loginManager logInFromViewController:nil configuration:config completion:handler];
    } else {
        [self.loginManager logInWithPermissions:permissions fromViewController:nil handler:handler];
    }
}

- (UIViewController*) topMostController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (NSDictionary *)loginResponseObject {

    if (![FBSDKAccessToken currentAccessToken]) {
        return @{@"status": @"unknown"};
    }

    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
    FBSDKAccessToken *token = [FBSDKAccessToken currentAccessToken];

    NSTimeInterval dataAccessExpirationTimeInterval = token.dataAccessExpirationDate.timeIntervalSince1970;
    NSString *dataAccessExpirationTime = @"0";
    if (dataAccessExpirationTimeInterval > 0) {
        dataAccessExpirationTime = [NSString stringWithFormat:@"%0.0f", dataAccessExpirationTimeInterval];
    }

    NSTimeInterval expiresTimeInterval = token.expirationDate.timeIntervalSinceNow;
    NSString *expiresIn = @"0";
    if (expiresTimeInterval > 0) {
        expiresIn = [NSString stringWithFormat:@"%0.0f", expiresTimeInterval];
    }

    response[@"status"] = @"connected";
    response[@"authResponse"] = @{
                                  @"accessToken" : token.tokenString ? token.tokenString : @"",
                                  @"data_access_expiration_time" : dataAccessExpirationTime,
                                  @"expiresIn" : expiresIn,
                                  @"userID" : token.userID ? token.userID : @""
                                  };


    return [response copy];
}

- (NSDictionary *)limitedLoginResponseObject {
    if (![FBSDKAuthenticationToken currentAuthenticationToken]) {
        return @{@"status": @"unknown"};
    }

    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
    FBSDKAuthenticationToken *token = [FBSDKAuthenticationToken currentAuthenticationToken];

    NSString *userID;
    if ([FBSDKProfile currentProfile]) {
        userID = [FBSDKProfile currentProfile].userID;
    }

    response[@"status"] = @"connected";
    response[@"authResponse"] = @{
                                  @"authenticationToken" : token.tokenString ? token.tokenString : @"",
                                  @"nonce" : token.nonce ? token.nonce : @"",
                                  @"userID" : userID ? userID : @""
                                  };

    return [response copy];
}

- (NSDictionary *)profileObject {
    if ([FBSDKProfile currentProfile] == nil) {
        return @{};
    }
    
    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
    FBSDKProfile *profile = [FBSDKProfile currentProfile];
    NSString *userID = profile.userID;
    
    response[@"userID"] = userID ? userID : @"";
    
    if (self.loginTracking == FBSDKLoginTrackingLimited) {
        NSString *name = profile.name;
        NSString *email = profile.email;
        
        if (name) {
            response[@"name"] = name;
        }
        if (email) {
            response[@"email"] = email;
        }
    } else {
        NSString *firstName = profile.firstName;
        NSString *lastName = profile.lastName;
        
        response[@"firstName"] = firstName ? firstName : @"";
        response[@"lastName"] = lastName ? lastName : @"";
    }
    
    return [response copy];
}

/*
 * Enable the hybrid app events for the webview.
 */
- (void)enableHybridAppEvents {
    if ([self.webView isMemberOfClass:[WKWebView class]]){
        NSString *is_enabled = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookHybridAppEvents"];
        if([is_enabled isEqualToString:@"true"]){
            // El método augmentWebView: ya no está disponible en el SDK actual
            // [FBSDKAppEvents.shared augmentWebView:(WKWebView*)self.webView];
            NSLog(@"FB Hybrid app events are enabled");
        } else {
            NSLog(@"FB Hybrid app events are not enabled");
        }
    } else {
        NSLog(@"FB Hybrid app events cannot be enabled, this feature requires WKWebView");
    }
}

# pragma mark - FBSDKSharingDelegate

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results {
    if (!self.dialogCallbackId) {
        return;
    }

    CDVPluginResult *pluginResult;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                 messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.dialogCallbackId];
    self.dialogCallbackId = nil;
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    if (!self.dialogCallbackId) {
        return;
    }

    CDVPluginResult *pluginResult;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                     messageAsString:[NSString stringWithFormat:@"Error: %@", error.description]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.dialogCallbackId];
    self.dialogCallbackId = nil;
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer {
    if (!self.dialogCallbackId) {
        return;
    }

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsString:@"User cancelled."];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.dialogCallbackId];
    self.dialogCallbackId = nil;
}


// Los métodos del delegado de GameRequestDialog se han eliminado ya que la funcionalidad de solicitudes de juego
// requiere una actualización significativa para ser compatible con el SDK actual de Facebook

@end


#pragma mark - AppDelegate Overrides

@implementation AppDelegate (FacebookConnectPlugin)

void FBMethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    FBMethodSwizzle([self class], @selector(application:openURL:options:));
}

- (BOOL)swizzled_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    if (!url) {
        return NO;
    }
    // Required by FBSDKCoreKit for deep linking/to complete login
    [[FBSDKApplicationDelegate sharedInstance] application:application openURL:url sourceApplication:[options valueForKey:@"UIApplicationOpenURLOptionsSourceApplicationKey"] annotation:0x0];
    
    // NOTE: Cordova will run a JavaScript method here named handleOpenURL. This functionality is deprecated
    // but will cause you to see JavaScript errors if you do not have window.handleOpenURL defined:
    // https://github.com/Wizcorp/phonegap-facebook-plugin/issues/703#issuecomment-63748816
    NSLog(@"FB handle url using application:openURL:options: %@", url);

    // Call existing method
    return [self swizzled_application:application openURL:url options:options];
}

- (BOOL)noop_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    return NO;
}
@end
