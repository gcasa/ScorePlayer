# ScorePlayer

ScorePlayer converts a small text score format into a Standard MIDI file and,
by default, asks the host system to play the generated file.

The tool is written in Objective-C using Foundation. It builds on macOS with
Apple's Foundation framework, and on GNUstep systems when `gnustep-config` is
available.

## Build

```sh
make
```

This produces a `scoreplayer` executable in the project root.

To remove generated build outputs:

```sh
make clean
```

## Usage

```sh
./scoreplayer file.score [--midi out.mid] [--no-play]
```

Options:

- `--midi out.mid`: write MIDI output to the specified path. If omitted, the
  output path is the input file name with a `.mid` extension.
- `--no-play`: write the MIDI file without launching a player.

When playback is enabled, ScorePlayer tries the first available player in this
order:

1. `open` on macOS
2. `timidity`
3. `fluidsynth`

If no supported player is found, the MIDI file is still written.

## Score Format

A score is a semicolon-delimited text file. `// line comments` and
`/* block comments */` are ignored.

Supported top-level statements:

- `info tempo: 120`: set tempo in beats per minute. The default is `60`.
- `var name = expression`: define a numeric variable.
- `part piano, bass`: predeclare parts. Each part is mapped to a MIDI channel.
- `BEGIN` and `END`: delimit playable score events.

Inside `BEGIN` and `END`:

- `t expression`: set the current beat position.
- `t +expression`: advance the current beat position.
- `part(duration) keyNum: 60, velocity: 90`: add a note at the current time.
- `part(duration) freq: c4, amp: 0.8`: add a note using a pitch or frequency.
- `part(noteUpdate) ...`: set default note parameters for a part.
- `part(noteOn tag) ...` and `part(noteOff tag)`: start and stop a tagged note.

Expressions support numbers, variables, parentheses, and `+`, `-`, `*`, `/`.

Pitch values may be:

- MIDI key numbers with `keyNum`, from `0` to `127`
- Frequencies in hertz with `freq`, `freq0`, or `freq1`
- Pitch names such as `c4`, `cs4`, `c#4`, `bf3`, or `a4`

Velocity can be set directly with `velocity: 1` through `velocity: 127`, or
derived from `amp: 0.0` through `amp: 1.0`.

## Example

Create `example.score`:

```text
info tempo: 120;
var beat = 1;
part lead, bass;

BEGIN;
lead(noteUpdate) velocity: 96;
bass(noteUpdate) velocity: 72;

t 0;
lead(beat) freq: c4;
bass(beat * 2) keyNum: 36;

t +beat;
lead(beat) freq: e4;

t +beat;
lead(beat) freq: g4;

t +beat;
lead(noteOn hold) freq: c5, amp: 0.7;
t +2;
lead(noteOff hold);
END;
```

Convert it without launching a player:

```sh
./scoreplayer example.score --midi example.mid --no-play
```

Successful output looks like:

```text
Wrote example.mid (5 notes, tempo 120.00)
```

## Notes

ScorePlayer writes a single-track, type-0 MIDI file at 480 pulses per quarter
note. MIDI channel 10, the percussion channel, is skipped when assigning parts.
