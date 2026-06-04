#import "SPScoreParser.h"
#import "SPExpression.h"
#include <math.h>

@implementation SPNoteEvent
- (id)initWithStart:(double)aStart duration:(double)aDuration key:(int)aKey velocity:(int)aVelocity channel:(int)aChannel
{
    self = [super init];
    if (self != nil) {
        start = aStart;
        duration = aDuration;
        key = aKey;
        velocity = aVelocity;
        channel = aChannel;
    }
    return self;
}
- (double)start { return start; }
- (double)duration { return duration; }
- (int)key { return key; }
- (int)velocity { return velocity; }
- (int)channel { return channel; }
@end

@implementation SPScore
- (id)init
{
    self = [super init];
    if (self != nil) {
        events = [[NSMutableArray alloc] init];
        channelPrograms = [[NSMutableDictionary alloc] init];
        tempo = 60.0;
    }
    return self;
}
- (void)dealloc
{
    [events release];
    [channelPrograms release];
    [super dealloc];
}
- (void)addEvent:(SPNoteEvent *)event { [events addObject:event]; }
- (NSArray *)events { return events; }
- (NSDictionary *)channelPrograms { return channelPrograms; }
- (void)setProgram:(int)program forChannel:(int)channel
{
    if (channel < 0 || channel > 15)
        return;
    if (program < 0)
        program = 0;
    if (program > 127)
        program = 127;
    [channelPrograms setObject:[NSNumber numberWithInt:program] forKey:[NSNumber numberWithInt:channel]];
}
- (double)tempo { return tempo; }
- (void)setTempo:(double)aTempo { if (aTempo > 0.0) tempo = aTempo; }
@end

@interface SPActiveNote : NSObject
{
    double start;
    int key;
    int velocity;
    int channel;
}
- (id)initWithStart:(double)aStart key:(int)aKey velocity:(int)aVelocity channel:(int)aChannel;
- (double)start;
- (int)key;
- (int)velocity;
- (int)channel;
@end

@implementation SPActiveNote
- (id)initWithStart:(double)aStart key:(int)aKey velocity:(int)aVelocity channel:(int)aChannel
{
    self = [super init];
    if (self != nil) {
        start = aStart;
        key = aKey;
        velocity = aVelocity;
        channel = aChannel;
    }
    return self;
}
- (double)start { return start; }
- (int)key { return key; }
- (int)velocity { return velocity; }
- (int)channel { return channel; }
@end

@interface SPScoreParser (Private)
+ (NSString *)stripComments:(NSString *)text;
+ (NSArray *)statementsFromText:(NSString *)text;
+ (NSString *)trim:(NSString *)text;
+ (NSDictionary *)parametersFromText:(NSString *)text;
+ (NSString *)keyForAnyKey:(NSArray *)keys inParameters:(NSDictionary *)params;
+ (BOOL)partDeclaration:(NSString *)declaration partName:(NSString **)partName instrumentName:(NSString **)instrumentName;
+ (NSString *)instrumentNameInParameters:(NSDictionary *)params;
+ (void)applyInstrumentName:(NSString *)instrumentName channel:(int)channel score:(SPScore *)score;
+ (BOOL)string:(NSString *)text contains:(NSString *)needle;
+ (int)programForInstrumentName:(NSString *)instrumentName;
+ (int)midiKeyFromValue:(NSString *)value parameterName:(NSString *)parameterName variables:(NSDictionary *)variables ok:(BOOL *)ok;
+ (double)frequencyForPitch:(NSString *)pitch ok:(BOOL *)ok;
+ (int)partChannel:(NSString *)part channels:(NSMutableDictionary *)channels error:(NSString **)errorMessage;
+ (NSMutableDictionary *)defaultsForPart:(NSString *)part defaults:(NSMutableDictionary *)defaults;
+ (void)closeActiveNote:(SPActiveNote *)active atTime:(double)time score:(SPScore *)score;
@end

@implementation SPScoreParser

+ (SPScore *)parseFile:(NSString *)path error:(NSString **)errorMessage
{
    NSString *text;
    NSArray *statements;
    NSMutableDictionary *variables;
    NSMutableDictionary *channels;
    NSMutableDictionary *activeNotes;
    NSMutableDictionary *defaults;
    SPScore *score;
    unsigned int i;
    BOOL inBody;
    double currentTime;

    text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (text == nil)
        text = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:NULL];
    if (text == nil) {
        if (errorMessage != NULL)
            *errorMessage = @"Could not read score file.";
        return nil;
    }

    score = [[[SPScore alloc] init] autorelease];
    variables = [NSMutableDictionary dictionary];
    [variables setObject:[NSNumber numberWithDouble:0.5] forKey:@"ran"];
    channels = [NSMutableDictionary dictionary];
    activeNotes = [NSMutableDictionary dictionary];
    defaults = [NSMutableDictionary dictionary];
    currentTime = 0.0;
    inBody = NO;

    statements = [self statementsFromText:[self stripComments:text]];
    for (i = 0; i < [statements count]; i++) {
        NSString *stmt;
        NSString *trimmed;

        stmt = [statements objectAtIndex:i];
        trimmed = [self trim:stmt];
        if ([trimmed length] == 0)
            continue;
        if ([trimmed isEqualToString:@"BEGIN"]) {
            inBody = YES;
            continue;
        }
        if ([trimmed isEqualToString:@"END"])
            break;

        if ([trimmed hasPrefix:@"info "]) {
            NSDictionary *params;
            NSString *tempoText;
            BOOL ok;
            params = [self parametersFromText:[trimmed substringFromIndex:5]];
            tempoText = [params objectForKey:@"tempo"];
            if (tempoText != nil) {
                double tempo;
                tempo = [SPExpression evaluate:tempoText variables:variables ok:&ok];
                if (ok)
                    [score setTempo:tempo];
            }
            continue;
        }

        if ([trimmed hasPrefix:@"var "]) {
            NSRange eq;
            NSString *left;
            NSString *right;
            BOOL ok;
            double value;

            eq = [trimmed rangeOfString:@"="];
            if (eq.location != NSNotFound) {
                left = [self trim:[trimmed substringWithRange:NSMakeRange(4, eq.location - 4)]];
                right = [self trim:[trimmed substringFromIndex:eq.location + 1]];
                value = [SPExpression evaluate:right variables:variables ok:&ok];
                if (ok)
                    [variables setObject:[NSNumber numberWithDouble:value] forKey:left];
            }
            continue;
        }

        if ([trimmed hasPrefix:@"part "]) {
            NSArray *parts;
            unsigned int p;
            NSString *list;
            list = [trimmed substringFromIndex:5];
            parts = [list componentsSeparatedByString:@","];
            for (p = 0; p < [parts count]; p++) {
                NSString *partName;
                NSString *instrumentName;
                int channel;
                if (![self partDeclaration:[parts objectAtIndex:p] partName:&partName instrumentName:&instrumentName])
                    continue;
                channel = [self partChannel:partName channels:channels error:errorMessage];
                if (channel < 0)
                    return nil;
                [self applyInstrumentName:instrumentName channel:channel score:score];
            }
            continue;
        }

        if (!inBody) {
            NSRange whitespace;
            whitespace = [trimmed rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (whitespace.location != NSNotFound) {
                NSString *part;
                NSString *instrumentName;
                NSDictionary *params;
                int channel;

                part = [self trim:[trimmed substringToIndex:whitespace.location]];
                params = [self parametersFromText:[trimmed substringFromIndex:whitespace.location + 1]];
                instrumentName = [self instrumentNameInParameters:params];
                if (instrumentName != nil) {
                    channel = [self partChannel:part channels:channels error:errorMessage];
                    if (channel < 0)
                        return nil;
                    [self applyInstrumentName:instrumentName channel:channel score:score];
                }
            }
            continue;
        }

        {
            NSRange eq;
            NSRange paren;
            eq = [trimmed rangeOfString:@"="];
            paren = [trimmed rangeOfString:@"("];
            if (eq.location != NSNotFound && (paren.location == NSNotFound || eq.location < paren.location)) {
                NSString *left;
                NSString *right;
                BOOL ok;
                double value;
                left = [self trim:[trimmed substringToIndex:eq.location]];
                right = [self trim:[trimmed substringFromIndex:eq.location + 1]];
                value = [SPExpression evaluate:right variables:variables ok:&ok];
                if (ok)
                    [variables setObject:[NSNumber numberWithDouble:value] forKey:left];
                continue;
            }
        }

        if ([trimmed hasPrefix:@"t "]) {
            NSString *timeExpr;
            BOOL relative;
            BOOL ok;
            double value;

            timeExpr = [self trim:[trimmed substringFromIndex:2]];
            relative = [timeExpr hasPrefix:@"+"];
            value = [SPExpression evaluate:timeExpr variables:variables ok:&ok];
            if (ok) {
                if (relative)
                    currentTime += value;
                else
                    currentTime = value;
            }
            continue;
        }

        {
            NSRange openParen;
            NSRange closeParen;
            NSString *part;
            NSString *kind;
            NSString *rest;
            NSDictionary *params;
            NSMutableDictionary *combinedParams;
            NSString *pitchKey;
            NSString *pitchText;
            NSString *ampText;
            NSString *velocityText;
            BOOL keyOK;
            int key;
            int velocity;
            int channel;

            openParen = [trimmed rangeOfString:@"("];
            closeParen = [trimmed rangeOfString:@")"];
            if (openParen.location == NSNotFound || closeParen.location == NSNotFound || closeParen.location <= openParen.location)
                continue;

            part = [self trim:[trimmed substringToIndex:openParen.location]];
            kind = [self trim:[trimmed substringWithRange:NSMakeRange(openParen.location + 1, closeParen.location - openParen.location - 1)]];
            rest = [trimmed substringFromIndex:closeParen.location + 1];
            params = [self parametersFromText:rest];
            combinedParams = [NSMutableDictionary dictionaryWithDictionary:[self defaultsForPart:part defaults:defaults]];
            [combinedParams addEntriesFromDictionary:params];
            channel = [self partChannel:part channels:channels error:errorMessage];
            if (channel < 0)
                return nil;

            if ([kind hasPrefix:@"noteUpdate"]) {
                [[self defaultsForPart:part defaults:defaults] addEntriesFromDictionary:params];
                [self applyInstrumentName:[self instrumentNameInParameters:params] channel:channel score:score];
                continue;
            }

            [self applyInstrumentName:[self instrumentNameInParameters:params] channel:channel score:score];

            if ([kind hasPrefix:@"noteOff"]) {
                NSArray *kindParts;
                NSString *tag;
                NSString *activeKey;
                SPActiveNote *active;

                kindParts = [kind componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t"]];
                tag = nil;
                if ([kindParts count] > 1)
                    tag = [kindParts objectAtIndex:[kindParts count] - 1];
                if (tag == nil || [tag length] == 0)
                    continue;
                activeKey = [NSString stringWithFormat:@"%@:%@", part, tag];
                active = [activeNotes objectForKey:activeKey];
                if (active != nil) {
                    [self closeActiveNote:active atTime:currentTime score:score];
                    [activeNotes removeObjectForKey:activeKey];
                }
                continue;
            }

            pitchKey = [self keyForAnyKey:[NSArray arrayWithObjects:@"freq", @"keyNum", @"freq1", @"freq0", nil] inParameters:combinedParams];
            pitchText = [combinedParams objectForKey:pitchKey];
            keyOK = NO;
            key = [self midiKeyFromValue:pitchText parameterName:pitchKey variables:variables ok:&keyOK];
            if (!keyOK)
                continue;

            velocity = 80;
            velocityText = [combinedParams objectForKey:@"velocity"];
            if (velocityText != nil) {
                BOOL ok;
                double velocityValue;
                velocityValue = [SPExpression evaluate:velocityText variables:variables ok:&ok];
                if (ok)
                    velocity = (int)lrint(velocityValue);
            } else {
                ampText = [combinedParams objectForKey:@"amp"];
                if (ampText != nil) {
                    BOOL ok;
                    double ampValue;
                    ampValue = [SPExpression evaluate:ampText variables:variables ok:&ok];
                    if (ok)
                        velocity = (int)lrint(ampValue * 127.0);
                }
            }
            if (velocity < 1)
                velocity = 1;
            if (velocity > 127)
                velocity = 127;

            if ([kind hasPrefix:@"noteOn"]) {
                NSArray *kindParts;
                NSString *tag;
                NSString *activeKey;
                SPActiveNote *oldActive;
                SPActiveNote *newActive;

                kindParts = [kind componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t"]];
                tag = nil;
                if ([kindParts count] > 1)
                    tag = [kindParts objectAtIndex:[kindParts count] - 1];
                if (tag == nil || [tag length] == 0)
                    tag = @"0";
                activeKey = [NSString stringWithFormat:@"%@:%@", part, tag];
                oldActive = [activeNotes objectForKey:activeKey];
                if (oldActive != nil)
                    [self closeActiveNote:oldActive atTime:currentTime score:score];
                newActive = [[[SPActiveNote alloc] initWithStart:currentTime key:key velocity:velocity channel:channel] autorelease];
                [activeNotes setObject:newActive forKey:activeKey];
            } else {
                BOOL ok;
                double duration;
                duration = [SPExpression evaluate:kind variables:variables ok:&ok];
                if (ok && duration > 0.0) {
                    SPNoteEvent *event;
                    event = [[[SPNoteEvent alloc] initWithStart:currentTime duration:duration key:key velocity:velocity channel:channel] autorelease];
                    [score addEvent:event];
                }
            }
        }
    }

    {
        NSEnumerator *enumerator;
        SPActiveNote *active;
        enumerator = [activeNotes objectEnumerator];
        while ((active = [enumerator nextObject]) != nil)
            [self closeActiveNote:active atTime:currentTime score:score];
    }

    if ([[score events] count] == 0 && errorMessage != NULL)
        *errorMessage = @"No playable notes were found in the supported score subset.";
    return score;
}

+ (NSString *)stripComments:(NSString *)text
{
    NSMutableString *out;
    NSUInteger i;
    BOOL inComment;

    out = [NSMutableString string];
    inComment = NO;
    for (i = 0; i < [text length]; i++) {
        unichar c;
        unichar n;
        c = [text characterAtIndex:i];
        n = (i + 1 < [text length]) ? [text characterAtIndex:i + 1] : 0;
        if (!inComment && c == '/' && n == '/') {
            while (i < [text length] && [text characterAtIndex:i] != '\n')
                i++;
            if (i < [text length])
                [out appendString:@"\n"];
            continue;
        }
        if (!inComment && c == '/' && n == '*') {
            inComment = YES;
            i++;
            continue;
        }
        if (inComment && c == '*' && n == '/') {
            inComment = NO;
            i++;
            continue;
        }
        if (!inComment)
            [out appendFormat:@"%C", c];
    }
    return out;
}

+ (NSArray *)statementsFromText:(NSString *)text
{
    NSMutableArray *statements;
    NSMutableString *current;
    NSUInteger i;
    int bracketDepth;

    statements = [NSMutableArray array];
    current = [NSMutableString string];
    bracketDepth = 0;
    for (i = 0; i < [text length]; i++) {
        unichar c;
        c = [text characterAtIndex:i];
        if (c == '[' || c == '{')
            bracketDepth++;
        if ((c == ']' || c == '}') && bracketDepth > 0)
            bracketDepth--;
        if (c == ';' && bracketDepth == 0) {
            [statements addObject:[NSString stringWithString:current]];
            [current setString:@""];
        } else {
            [current appendFormat:@"%C", c];
        }
    }
    if ([[self trim:current] length] > 0)
        [statements addObject:[NSString stringWithString:current]];
    return statements;
}

+ (NSString *)trim:(NSString *)text
{
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSDictionary *)parametersFromText:(NSString *)text
{
    NSMutableDictionary *params;
    NSScanner *scanner;

    params = [NSMutableDictionary dictionary];
    scanner = [NSScanner scannerWithString:text];
    [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@" \t\r\n,"]];
    while (![scanner isAtEnd]) {
        NSString *key;
        NSString *value;
        NSCharacterSet *keyStop;
        NSCharacterSet *valueStop;

        key = nil;
        value = nil;
        keyStop = [NSCharacterSet characterSetWithCharactersInString:@": \t\r\n,"];
        if (![scanner scanUpToCharactersFromSet:keyStop intoString:&key])
            break;
        if (![scanner scanString:@":" intoString:NULL]) {
            [scanner scanUpToString:@"," intoString:NULL];
            continue;
        }
        valueStop = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n,"];
        if ([scanner scanString:@"\"" intoString:NULL]) {
            [scanner scanUpToString:@"\"" intoString:&value];
            [scanner scanString:@"\"" intoString:NULL];
        } else {
            [scanner scanUpToCharactersFromSet:valueStop intoString:&value];
        }
        if (key != nil && value != nil)
            [params setObject:[self trim:value] forKey:[self trim:key]];
    }
    return params;
}

+ (NSString *)keyForAnyKey:(NSArray *)keys inParameters:(NSDictionary *)params
{
    unsigned int i;
    for (i = 0; i < [keys count]; i++) {
        NSString *key;
        key = [keys objectAtIndex:i];
        if ([params objectForKey:key] != nil)
            return key;
    }
    return nil;
}

+ (BOOL)partDeclaration:(NSString *)declaration partName:(NSString **)partName instrumentName:(NSString **)instrumentName
{
    NSString *trimmed;
    NSRange openParen;
    NSRange closeParen;

    if (partName != NULL)
        *partName = nil;
    if (instrumentName != NULL)
        *instrumentName = nil;

    trimmed = [self trim:declaration];
    if ([trimmed length] == 0)
        return NO;

    openParen = [trimmed rangeOfString:@"("];
    closeParen = [trimmed rangeOfString:@")" options:NSBackwardsSearch];
    if (openParen.location != NSNotFound && closeParen.location != NSNotFound && closeParen.location > openParen.location) {
        if (partName != NULL)
            *partName = [self trim:[trimmed substringToIndex:openParen.location]];
        if (instrumentName != NULL)
            *instrumentName = [self trim:[trimmed substringWithRange:NSMakeRange(openParen.location + 1, closeParen.location - openParen.location - 1)]];
    } else {
        if (partName != NULL)
            *partName = trimmed;
    }

    return partName == NULL || (*partName != nil && [*partName length] > 0);
}

+ (NSString *)instrumentNameInParameters:(NSDictionary *)params
{
    return [params objectForKey:[self keyForAnyKey:[NSArray arrayWithObjects:@"instrument", @"patch", @"synthPatch", @"synthpatch", @"program", @"programName", nil] inParameters:params]];
}

+ (void)applyInstrumentName:(NSString *)instrumentName channel:(int)channel score:(SPScore *)score
{
    if (instrumentName == nil || [instrumentName length] == 0)
        return;
    [score setProgram:[self programForInstrumentName:instrumentName] forChannel:channel];
}

+ (BOOL)string:(NSString *)text contains:(NSString *)needle
{
    return [text rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

+ (int)programForInstrumentName:(NSString *)instrumentName
{
    NSString *name;
    const char *s;
    char *endPtr;
    long numeric;

    name = [self trim:instrumentName];
    if ([name length] == 0)
        return 0;

    s = [name UTF8String];
    numeric = strtol(s, &endPtr, 10);
    if (endPtr != s && *endPtr == '\0') {
        if (numeric < 0)
            return 0;
        if (numeric > 127)
            return 127;
        return (int)numeric;
    }

    if ([self string:name contains:@"pluck"])
        return 24;
    if ([self string:name contains:@"piccolo"])
        return 72;
    if ([self string:name contains:@"flute"])
        return 73;
    if ([self string:name contains:@"recorder"])
        return 74;
    if ([self string:name contains:@"pan"])
        return 75;
    if ([self string:name contains:@"clarinet"])
        return 71;
    if ([self string:name contains:@"bassoon"])
        return 70;
    if ([self string:name contains:@"english horn"])
        return 69;
    if ([self string:name contains:@"oboe"])
        return 68;
    if ([self string:name contains:@"sax"])
        return 64;
    if ([self string:name contains:@"trumpet"])
        return 56;
    if ([self string:name contains:@"trombone"])
        return 57;
    if ([self string:name contains:@"tuba"])
        return 58;
    if ([self string:name contains:@"horn"])
        return 60;
    if ([self string:name contains:@"brass"])
        return 61;
    if ([self string:name contains:@"violin"])
        return 40;
    if ([self string:name contains:@"viola"])
        return 41;
    if ([self string:name contains:@"cello"])
        return 42;
    if ([self string:name contains:@"contrabass"] || [self string:name contains:@"double bass"])
        return 43;
    if ([self string:name contains:@"harp"])
        return 46;
    if ([self string:name contains:@"string"])
        return 48;
    if ([self string:name contains:@"choir"])
        return 52;
    if ([self string:name contains:@"voice"] || [self string:name contains:@"vocal"])
        return 53;
    if ([self string:name contains:@"organ"])
        return 19;
    if ([self string:name contains:@"harpsichord"])
        return 6;
    if ([self string:name contains:@"clav"])
        return 7;
    if ([self string:name contains:@"electric piano"])
        return 4;
    if ([self string:name contains:@"piano"])
        return 0;
    if ([self string:name contains:@"acoustic guitar"] || [self string:name contains:@"nylon"])
        return 24;
    if ([self string:name contains:@"steel guitar"])
        return 25;
    if ([self string:name contains:@"jazz guitar"])
        return 26;
    if ([self string:name contains:@"electric guitar"] || [self string:name contains:@"guitar"])
        return 27;
    if ([self string:name contains:@"fretless bass"])
        return 35;
    if ([self string:name contains:@"bass"])
        return 32;
    if ([self string:name contains:@"lead"])
        return 80;
    if ([self string:name contains:@"pad"])
        return 88;
    if ([self string:name contains:@"synth"])
        return 81;
    if ([self string:name contains:@"bell"])
        return 14;
    if ([self string:name contains:@"marimba"])
        return 12;
    if ([self string:name contains:@"xylophone"])
        return 13;
    if ([self string:name contains:@"vibraphone"])
        return 11;
    if ([self string:name contains:@"celesta"])
        return 8;

    return 0;
}

+ (int)midiKeyFromValue:(NSString *)value parameterName:(NSString *)parameterName variables:(NSDictionary *)variables ok:(BOOL *)ok
{
    double freq;
    double numeric;
    char *endPtr;
    BOOL isKeyNum;

    if (ok != NULL)
        *ok = NO;
    if (value == nil)
        return 60;

    isKeyNum = [parameterName isEqualToString:@"keyNum"];
    numeric = strtod([value UTF8String], &endPtr);
    if (endPtr != [value UTF8String] && *endPtr == '\0') {
        if (isKeyNum && numeric >= 0.0 && numeric < 128.0) {
            if (ok != NULL)
                *ok = YES;
            return (int)lrint(numeric);
        }
        if (numeric > 0.0) {
            int key;
            key = (int)lrint(69.0 + 12.0 * log(numeric / 440.0) / log(2.0));
            if (key < 0)
                key = 0;
            if (key > 127)
                key = 127;
            if (ok != NULL)
                *ok = YES;
            return key;
        }
    }

    freq = [self frequencyForPitch:value ok:ok];
    if (ok != NULL && *ok) {
        int key;
        key = (int)lrint(69.0 + 12.0 * log(freq / 440.0) / log(2.0));
        if (key < 0)
            key = 0;
        if (key > 127)
            key = 127;
        return key;
    }

    {
        BOOL exprOK;
        double valueAsNumber;
        valueAsNumber = [SPExpression evaluate:value variables:variables ok:&exprOK];
        if (exprOK) {
            if (isKeyNum) {
                if (valueAsNumber < 0.0)
                    valueAsNumber = 0.0;
                if (valueAsNumber > 127.0)
                    valueAsNumber = 127.0;
                if (ok != NULL)
                    *ok = YES;
                return (int)lrint(valueAsNumber);
            }
            if (valueAsNumber > 0.0) {
                int key;
                key = (int)lrint(69.0 + 12.0 * log(valueAsNumber / 440.0) / log(2.0));
                if (key < 0)
                    key = 0;
                if (key > 127)
                    key = 127;
                if (ok != NULL)
                    *ok = YES;
                return key;
            }
        }
    }
    return 60;
}

+ (double)frequencyForPitch:(NSString *)pitch ok:(BOOL *)ok
{
    NSString *lower;
    const char *s;
    int pc;
    int octave;
    char *endPtr;
    double semitones;
    double key;

    if (ok != NULL)
        *ok = NO;
    lower = [pitch lowercaseString];
    s = [lower UTF8String];
    if (*s == '\0')
        return 0.0;

    switch (*s) {
        case 'c': pc = 0; break;
        case 'd': pc = 2; break;
        case 'e': pc = 4; break;
        case 'f': pc = 5; break;
        case 'g': pc = 7; break;
        case 'a': pc = 9; break;
        case 'b': pc = 11; break;
        default: return 0.0;
    }
    s++;
    if (*s == 's' || *s == '#') {
        pc++;
        s++;
    } else if (*s == 'f') {
        pc--;
        s++;
    }
    octave = (int)strtol(s, &endPtr, 10);
    if (endPtr == s)
        return 0.0;
    semitones = 0.0;
    if (*endPtr == '+')
        semitones = strtod(endPtr + 1, NULL);
    else if (*endPtr == '-')
        semitones = -strtod(endPtr + 1, NULL);
    key = (octave + 1) * 12 + pc + semitones;
    if (ok != NULL)
        *ok = YES;
    return 440.0 * pow(2.0, (key - 69.0) / 12.0);
}

+ (int)partChannel:(NSString *)part channels:(NSMutableDictionary *)channels error:(NSString **)errorMessage
{
    NSNumber *number;
    int channel;

    number = [channels objectForKey:part];
    if (number != nil)
        return [number intValue];
    for (channel = 0; channel < 16; channel++) {
        if (channel == 9)
            continue;
        if ([[channels allValues] containsObject:[NSNumber numberWithInt:channel]])
            continue;
        [channels setObject:[NSNumber numberWithInt:channel] forKey:part];
        return channel;
    }
    if (errorMessage != NULL)
        *errorMessage = [NSString stringWithFormat:@"Too many parts. MIDI output supports 15 separate non-percussion channels."];
    return -1;
}

+ (NSMutableDictionary *)defaultsForPart:(NSString *)part defaults:(NSMutableDictionary *)defaults
{
    NSMutableDictionary *partDefaults;
    partDefaults = [defaults objectForKey:part];
    if (partDefaults == nil) {
        partDefaults = [NSMutableDictionary dictionary];
        [defaults setObject:partDefaults forKey:part];
    }
    return partDefaults;
}

+ (void)closeActiveNote:(SPActiveNote *)active atTime:(double)time score:(SPScore *)score
{
    double duration;
    SPNoteEvent *event;

    duration = time - [active start];
    if (duration <= 0.0)
        duration = 0.05;
    event = [[[SPNoteEvent alloc] initWithStart:[active start] duration:duration key:[active key] velocity:[active velocity] channel:[active channel]] autorelease];
    [score addEvent:event];
}

@end
