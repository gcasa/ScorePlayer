#import <Foundation/Foundation.h>

@interface SPDirectPlayer : NSObject
+ (BOOL)playMIDIFile:(NSString *)path error:(NSString **)errorMessage;
@end
