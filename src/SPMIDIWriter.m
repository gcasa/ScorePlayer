#import "SPMIDIWriter.h"

@interface SPMIDIEvent : NSObject
{
    unsigned long tick;
    unsigned int order;
    unsigned char status;
    unsigned char data1;
    unsigned char data2;
}
- (id)initWithTick:(unsigned long)aTick order:(unsigned int)anOrder status:(unsigned char)aStatus data1:(unsigned char)aData1 data2:(unsigned char)aData2;
- (unsigned long)tick;
- (unsigned int)order;
- (unsigned char)status;
- (unsigned char)data1;
- (unsigned char)data2;
@end

@implementation SPMIDIEvent
- (id)initWithTick:(unsigned long)aTick order:(unsigned int)anOrder status:(unsigned char)aStatus data1:(unsigned char)aData1 data2:(unsigned char)aData2
{
    self = [super init];
    if (self != nil) {
        tick = aTick;
        order = anOrder;
        status = aStatus;
        data1 = aData1;
        data2 = aData2;
    }
    return self;
}
- (unsigned long)tick { return tick; }
- (unsigned int)order { return order; }
- (unsigned char)status { return status; }
- (unsigned char)data1 { return data1; }
- (unsigned char)data2 { return data2; }
@end

@interface SPMIDIWriter (Private)
+ (void)append16:(unsigned int)value toData:(NSMutableData *)data;
+ (void)append32:(unsigned long)value toData:(NSMutableData *)data;
+ (void)appendVar:(unsigned long)value toData:(NSMutableData *)data;
@end

@implementation SPMIDIWriter

+ (NSData *)dataForScore:(SPScore *)score
{
    NSMutableArray *midiEvents;
    NSMutableData *track;
    NSMutableData *file;
    NSArray *events;
    NSArray *sorted;
    unsigned int i;
    unsigned long lastTick;
    unsigned short ppq;
    unsigned long tempoUsec;

    ppq = 480;
    midiEvents = [NSMutableArray array];
    {
        NSDictionary *channelPrograms;
        NSEnumerator *enumerator;
        NSNumber *channelNumber;

        channelPrograms = [score channelPrograms];
        enumerator = [channelPrograms keyEnumerator];
        while ((channelNumber = [enumerator nextObject]) != nil) {
            NSNumber *programNumber;
            unsigned char channel;
            int program;

            programNumber = [channelPrograms objectForKey:channelNumber];
            channel = (unsigned char)([channelNumber intValue] & 0x0f);
            program = [programNumber intValue];
            if (program < 0)
                program = 0;
            if (program > 127)
                program = 127;
            [midiEvents addObject:[[[SPMIDIEvent alloc] initWithTick:0 order:0 status:0xc0 | channel data1:(unsigned char)program data2:0] autorelease]];
        }
    }
    events = [score events];
    for (i = 0; i < [events count]; i++) {
        SPNoteEvent *event;
        unsigned long startTick;
        unsigned long endTick;
        unsigned char channel;

        event = [events objectAtIndex:i];
        startTick = (unsigned long)([event start] * ppq + 0.5);
        endTick = (unsigned long)(([event start] + [event duration]) * ppq + 0.5);
        if (endTick <= startTick)
            endTick = startTick + 1;
        channel = (unsigned char)([event channel] & 0x0f);
        [midiEvents addObject:[[[SPMIDIEvent alloc] initWithTick:startTick order:1 status:0x90 | channel data1:(unsigned char)[event key] data2:(unsigned char)[event velocity]] autorelease]];
        [midiEvents addObject:[[[SPMIDIEvent alloc] initWithTick:endTick order:0 status:0x80 | channel data1:(unsigned char)[event key] data2:0] autorelease]];
    }

    sorted = [midiEvents sortedArrayUsingSelector:@selector(compare:)];
    track = [NSMutableData data];

    [self appendVar:0 toData:track];
    {
        unsigned char tempoBytes[6];
        tempoUsec = (unsigned long)(60000000.0 / [score tempo] + 0.5);
        tempoBytes[0] = 0xff;
        tempoBytes[1] = 0x51;
        tempoBytes[2] = 0x03;
        tempoBytes[3] = (unsigned char)((tempoUsec >> 16) & 0xff);
        tempoBytes[4] = (unsigned char)((tempoUsec >> 8) & 0xff);
        tempoBytes[5] = (unsigned char)(tempoUsec & 0xff);
        [track appendBytes:tempoBytes length:6];
    }

    lastTick = 0;
    for (i = 0; i < [sorted count]; i++) {
        SPMIDIEvent *event;
        unsigned char bytes[3];
        unsigned int byteCount;
        event = [sorted objectAtIndex:i];
        [self appendVar:[event tick] - lastTick toData:track];
        bytes[0] = [event status];
        bytes[1] = [event data1];
        bytes[2] = [event data2];
        byteCount = (([event status] & 0xf0) == 0xc0 || ([event status] & 0xf0) == 0xd0) ? 2 : 3;
        [track appendBytes:bytes length:byteCount];
        lastTick = [event tick];
    }

    [self appendVar:0 toData:track];
    {
        unsigned char endBytes[3];
        endBytes[0] = 0xff;
        endBytes[1] = 0x2f;
        endBytes[2] = 0x00;
        [track appendBytes:endBytes length:3];
    }

    file = [NSMutableData data];
    [file appendBytes:"MThd" length:4];
    [self append32:6 toData:file];
    [self append16:0 toData:file];
    [self append16:1 toData:file];
    [self append16:ppq toData:file];
    [file appendBytes:"MTrk" length:4];
    [self append32:[track length] toData:file];
    [file appendData:track];

    return file;
}

+ (BOOL)writeScore:(SPScore *)score toFile:(NSString *)path error:(NSString **)errorMessage
{
    NSData *file;

    file = [self dataForScore:score];
    if (![file writeToFile:path atomically:YES]) {
        if (errorMessage != NULL)
            *errorMessage = @"Could not write MIDI file.";
        return NO;
    }
    return YES;
}

+ (void)append16:(unsigned int)value toData:(NSMutableData *)data
{
    unsigned char bytes[2];
    bytes[0] = (unsigned char)((value >> 8) & 0xff);
    bytes[1] = (unsigned char)(value & 0xff);
    [data appendBytes:bytes length:2];
}

+ (void)append32:(unsigned long)value toData:(NSMutableData *)data
{
    unsigned char bytes[4];
    bytes[0] = (unsigned char)((value >> 24) & 0xff);
    bytes[1] = (unsigned char)((value >> 16) & 0xff);
    bytes[2] = (unsigned char)((value >> 8) & 0xff);
    bytes[3] = (unsigned char)(value & 0xff);
    [data appendBytes:bytes length:4];
}

+ (void)appendVar:(unsigned long)value toData:(NSMutableData *)data
{
    unsigned long buffer;
    unsigned char byte;

    buffer = value & 0x7f;
    while ((value >>= 7) != 0) {
        buffer <<= 8;
        buffer |= ((value & 0x7f) | 0x80);
    }
    for (;;) {
        byte = (unsigned char)(buffer & 0xff);
        [data appendBytes:&byte length:1];
        if (buffer & 0x80)
            buffer >>= 8;
        else
            break;
    }
}

@end

@implementation SPMIDIEvent (Compare)
- (NSComparisonResult)compare:(SPMIDIEvent *)other
{
    if ([self tick] < [other tick])
        return NSOrderedAscending;
    if ([self tick] > [other tick])
        return NSOrderedDescending;
    if ([self order] < [other order])
        return NSOrderedAscending;
    if ([self order] > [other order])
        return NSOrderedDescending;
    return NSOrderedSame;
}
@end
