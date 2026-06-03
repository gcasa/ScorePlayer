#import <Foundation/Foundation.h>
#import "SPScoreParser.h"

@interface SPMIDIWriter : NSObject
+ (BOOL)writeScore:(SPScore *)score toFile:(NSString *)path error:(NSString **)errorMessage;
@end
