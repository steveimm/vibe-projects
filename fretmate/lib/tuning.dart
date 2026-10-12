import 'dart:math' as math;

const minimumTuningNote = 24; // C1
const maximumTuningNote = 84; // C6
const _noteNames = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];

class GuitarString {
  const GuitarString(this.number, this.midiNote);

  final int number;
  final int midiNote;

  String get note => _noteNames[midiNote % 12];
  int get octave => midiNote ~/ 12 - 1;
  double get frequency => 440.0 * math.pow(2, (midiNote - 69) / 12);
  String get label => '$note$octave';
}

class TuningPreset {
  const TuningPreset(this.name, this.notes);

  final String name;
  final List<int> notes;

  List<GuitarString> get strings =>
      List.unmodifiable([for (var i = 0; i < notes.length; i++) GuitarString(6 - i, notes[i])]);
  String get noteSummary => strings.map((string) => string.note).join();
}

// Six-string presets, low to high. Source: Peterson Guided Tuning Manual.
// https://www.petersontuners.com/media/pdf/Guided%20Tuning%20Manual.pdf
const tuningPresets = [
  TuningPreset('Standard tuning', [40, 45, 50, 55, 59, 64]),
  TuningPreset('Drop D', [38, 45, 50, 55, 59, 64]),
  TuningPreset('Double Drop D', [38, 45, 50, 55, 59, 62]),
  TuningPreset('Drop C♯', [37, 44, 49, 54, 58, 63]),
  TuningPreset('Drop C', [36, 43, 48, 53, 57, 62]),
  TuningPreset('Drop B', [35, 42, 47, 52, 56, 61]),
  TuningPreset('Drop B♭', [34, 41, 46, 51, 55, 60]),
  TuningPreset('Drop A', [33, 40, 45, 50, 54, 59]),
  TuningPreset('E♭ standard', [39, 44, 49, 54, 58, 63]),
  TuningPreset('D standard', [38, 43, 48, 53, 57, 62]),
  TuningPreset('C♯ standard', [37, 42, 47, 52, 56, 61]),
  TuningPreset('C standard', [36, 41, 46, 51, 55, 60]),
  TuningPreset('B standard', [35, 40, 45, 50, 54, 59]),
  TuningPreset('A standard', [33, 38, 43, 48, 52, 57]),
  TuningPreset('DADGAD', [38, 45, 50, 55, 57, 62]),
  TuningPreset('Open D', [38, 45, 50, 54, 57, 62]),
  TuningPreset('Open G', [38, 43, 50, 55, 59, 62]),
  TuningPreset('Open C', [36, 43, 48, 55, 60, 64]),
  TuningPreset('Open E', [40, 47, 52, 56, 59, 64]),
  TuningPreset('Open A', [40, 45, 52, 57, 61, 64]),
  TuningPreset('Open D minor', [38, 45, 50, 53, 57, 62]),
  TuningPreset('Open G minor', [38, 43, 50, 55, 58, 62]),
  TuningPreset('Open C minor', [36, 43, 48, 55, 60, 63]),
  TuningPreset('Open E minor', [40, 47, 52, 55, 59, 64]),
  TuningPreset('Nashville', [52, 57, 62, 67, 59, 64]),
  TuningPreset('New standard', [36, 43, 50, 57, 64, 67]),
];

final standardStrings = tuningPresets.first.strings;

TuningPreset? matchingTuning(List<GuitarString> strings) {
  for (final preset in tuningPresets) {
    if (preset.notes.length == strings.length &&
        preset.notes.indexed.every((entry) => entry.$2 == strings[entry.$1].midiNote)) {
      return preset;
    }
  }
  return null;
}

double centsBetween(double frequency, double target) => 1200 * math.log(frequency / target) / math.ln2;

GuitarString nearestString(double frequency, {List<GuitarString>? strings}) =>
    (strings ?? standardStrings).reduce((a, b) {
      return centsBetween(frequency, a.frequency).abs() < centsBetween(frequency, b.frequency).abs() ? a : b;
    });
