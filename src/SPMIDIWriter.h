#import <Foundation/Foundation.h>
#import "SPScoreParser.h"

@interface SPMIDIWriter : NSObject
+ (NSData *)dataForScore:(SPScore *)score;
+ (BOOL)writeScore:(SPScore *)score toFile:(NSString *)path error:(NSString **)errorMessage;
@end
