#import "SPDirectPlayer.h"

#if defined(__APPLE__)
#import <AVFoundation/AVFoundation.h>
#endif

@implementation SPDirectPlayer

+ (BOOL)playMIDIFile:(NSString *)path error:(NSString **)errorMessage
{
#if defined(__APPLE__)
    NSURL *url;
    NSURL *soundBankURL;
    NSError *error;
    AVMIDIPlayer *player;

    url = [NSURL fileURLWithPath:path];
    soundBankURL = [NSURL fileURLWithPath:@"/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"];
    error = nil;
    player = nil;

    @try {
        player = [[AVMIDIPlayer alloc] initWithContentsOfURL:url soundBankURL:soundBankURL error:&error];
    }
    @catch (NSException *exception) {
        if (errorMessage != NULL)
            *errorMessage = [NSString stringWithFormat:@"Direct MIDI playback failed: %@.", [exception reason]];
        return NO;
    }

    if (player == nil) {
        if (errorMessage != NULL)
            *errorMessage = [NSString stringWithFormat:@"Direct MIDI playback failed: %@.", [error localizedDescription]];
        return NO;
    }

    [player prepareToPlay];
    [player play:nil];
    while ([player isPlaying])
        [NSThread sleepForTimeInterval:0.05];
    [player release];
    return YES;
#else
    (void)path;
    if (errorMessage != NULL)
        *errorMessage = @"Direct MIDI playback is only available on macOS.";
    return NO;
#endif
}

@end
