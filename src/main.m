#import <Foundation/Foundation.h>
#import "SPScoreParser.h"
#import "SPMIDIWriter.h"

static void usage(void)
{
    fprintf(stderr, "usage: scoreplayer file.score [--midi out.mid | --stdout] [--no-play]\n");
}

static BOOL commandExists(NSString *command)
{
    NSTask *task;
    int status;

    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/usr/bin/env"];
    [task setArguments:[NSArray arrayWithObjects:@"sh", @"-c", [NSString stringWithFormat:@"command -v %@ >/dev/null 2>&1", command], nil]];
    [task launch];
    [task waitUntilExit];
    status = [task terminationStatus];
    return status == 0;
}

static int runPlayer(NSString *midiPath)
{
    NSTask *task;
    NSArray *args;
    NSString *launchPath;

    launchPath = nil;
    args = nil;

    if (commandExists(@"open")) {
        launchPath = @"/usr/bin/env";
        args = [NSArray arrayWithObjects:@"open", midiPath, nil];
    } else if (commandExists(@"timidity")) {
        launchPath = @"/usr/bin/env";
        args = [NSArray arrayWithObjects:@"timidity", midiPath, nil];
    } else if (commandExists(@"fluidsynth")) {
        launchPath = @"/usr/bin/env";
        args = [NSArray arrayWithObjects:@"fluidsynth", @"-a", @"pulseaudio", midiPath, nil];
    }

    if (launchPath == nil) {
        fprintf(stderr, "No MIDI player found. Wrote %s\n", [midiPath fileSystemRepresentation]);
        return 2;
    }

    task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:launchPath];
    [task setArguments:args];
    [task launch];
    [task waitUntilExit];
    return [task terminationStatus];
}

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool;
    NSString *scorePath;
    NSString *midiPath;
    BOOL play;
    BOOL writeStdout;
    int i;
    SPScore *score;
    NSString *errorMessage;
    int result;

    pool = [[NSAutoreleasePool alloc] init];
    scorePath = nil;
    midiPath = nil;
    play = YES;
    writeStdout = NO;
    result = 0;

    for (i = 1; i < argc; i++) {
        NSString *arg;
        arg = [NSString stringWithUTF8String:argv[i]];
        if ([arg isEqualToString:@"--no-play"]) {
            play = NO;
        } else if ([arg isEqualToString:@"--midi"]) {
            if (i + 1 >= argc) {
                usage();
                [pool release];
                return 1;
            }
            i++;
            midiPath = [NSString stringWithUTF8String:argv[i]];
        } else if ([arg isEqualToString:@"--stdout"]) {
            writeStdout = YES;
            play = NO;
        } else if (scorePath == nil) {
            scorePath = arg;
        } else {
            usage();
            [pool release];
            return 1;
        }
    }

    if (scorePath == nil) {
        usage();
        [pool release];
        return 1;
    }

    if (writeStdout && midiPath != nil) {
        usage();
        [pool release];
        return 1;
    }

    if (!writeStdout && midiPath == nil) {
        NSString *base;
        base = [scorePath stringByDeletingPathExtension];
        midiPath = [base stringByAppendingPathExtension:@"mid"];
    }

    errorMessage = nil;
    score = [SPScoreParser parseFile:scorePath error:&errorMessage];
    if (score == nil || [[score events] count] == 0) {
        fprintf(stderr, "%s\n", errorMessage != nil ? [errorMessage UTF8String] : "Parse failed.");
        [pool release];
        return 1;
    }

    if (writeStdout) {
        NSData *midiData;
        midiData = [SPMIDIWriter dataForScore:score];
        [[NSFileHandle fileHandleWithStandardOutput] writeData:midiData];
    } else {
        if (![SPMIDIWriter writeScore:score toFile:midiPath error:&errorMessage]) {
            fprintf(stderr, "%s\n", errorMessage != nil ? [errorMessage UTF8String] : "MIDI write failed.");
            [pool release];
            return 1;
        }

        printf("Wrote %s (%lu notes, tempo %.2f)\n",
               [midiPath fileSystemRepresentation],
               (unsigned long)[[score events] count],
               [score tempo]);
    }

    if (play)
        result = runPlayer(midiPath);

    [pool release];
    return result;
}
