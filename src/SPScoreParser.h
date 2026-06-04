#import <Foundation/Foundation.h>

@interface SPNoteEvent : NSObject
{
    double start;
    double duration;
    int key;
    int velocity;
    int channel;
}
- (id)initWithStart:(double)aStart duration:(double)aDuration key:(int)aKey velocity:(int)aVelocity channel:(int)aChannel;
- (double)start;
- (double)duration;
- (int)key;
- (int)velocity;
- (int)channel;
@end

@interface SPScore : NSObject
{
    NSMutableArray *events;
    NSMutableDictionary *channelPrograms;
    double tempo;
}
- (id)init;
- (void)addEvent:(SPNoteEvent *)event;
- (NSArray *)events;
- (NSDictionary *)channelPrograms;
- (void)setProgram:(int)program forChannel:(int)channel;
- (double)tempo;
- (void)setTempo:(double)aTempo;
@end

@interface SPScoreParser : NSObject
+ (SPScore *)parseFile:(NSString *)path error:(NSString **)errorMessage;
@end
