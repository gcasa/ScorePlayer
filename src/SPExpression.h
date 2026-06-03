#import <Foundation/Foundation.h>

@interface SPExpression : NSObject
+ (double)evaluate:(NSString *)text variables:(NSDictionary *)variables ok:(BOOL *)ok;
@end
