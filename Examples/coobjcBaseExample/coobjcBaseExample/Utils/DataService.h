#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <coobjc/coobjc.h>

@interface DataService : NSObject

+ (instancetype)sharedInstance;

- (id)requestJSONWithURL:(NSString*)url CO_ASYNC;

- (void)saveDataToCache:(NSData*)data
         withIdentifier:(NSString*)identifier CO_ASYNC;

- (NSData*)getDataWithIdentifier:(NSString*)identifier CO_ASYNC;

- (UIImage*)imageWithURL:(NSString*)url CO_ASYNC;

@end
