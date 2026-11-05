// Saade (placeholder) sound effects code se banane wala script.
// Yeh awaazen hamari apni banayi hui hain, kisi ki copy nahi.
// Chalane ka tareeqa (project folder mein):  dart run tool/generate_sounds.dart
// Is se assets/audio/ mein .wav files ban jaati hain. Baad mein behtar sounds
// (maslan kenney.nl se) isi naam se rakh kar inhein badal sakte hain.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);

  final sounds = <String, List<double>>{
    // Chhota "pop"
    'tap': tone(0.07, (t) => 880 - 300 * t, wave: sine, decay: 30),
    // Engine ki "vroom"
    'bus_move': engine(0.38),
    // Do neeche wali "bup bup" (rasta band)
    'blocked': join([
      tone(0.07, (_) => 170, wave: square, decay: 10, volume: 0.35),
      silence(0.03),
      tone(0.08, (_) => 140, wave: square, decay: 10, volume: 0.35),
    ]),
    // Passenger baithne ki halki "plip"
    'board': tone(0.09, (t) => 620 + 500 * t, wave: sine, decay: 18),
    // Bus ka horn "beep-beep"
    'bus_depart': join([
      chord(0.12, [415, 523], volume: 0.3),
      silence(0.05),
      chord(0.18, [415, 523], volume: 0.3),
    ]),
    // Jeet ki chadhti dhun
    'win': join([
      for (final f in [523.0, 659.0, 784.0])
        tone(0.11, (_) => f, wave: triangle, decay: 4),
      tone(0.4, (_) => 1047, wave: triangle, decay: 3),
    ]),
    // Haar ki utarti dhun
    'fail': join([
      for (final f in [392.0, 330.0, 277.0])
        tone(0.16, (_) => f, wave: triangle, decay: 3),
      tone(0.4, (t) => 233 - 30 * t, wave: triangle, decay: 2.5),
    ]),
    // Button ka "tik"
    'button': tone(0.045, (_) => 1300, wave: sine, decay: 60),
    // Background music: khushgawar choti dhun jo loop mein chalti hai
    'music': music(),
  };

  sounds.forEach((name, samples) {
    final file = File('${dir.path}/$name.wav');
    file.writeAsBytesSync(toWav(samples));
    stdout.writeln('Bani: ${file.path}');
  });
}

typedef Wave = double Function(double phase);

/// Halki, khush dhun (8 bars, 112 BPM). Melody + bass + halki taal. Loop ke qabil.
List<double> music() {
  const bpm = 112.0;
  const beat = 60 / bpm;
  // Chords: C - Am - F - G (do dafa)
  const chords = [
    [261.6, 329.6, 392.0],
    [220.0, 261.6, 329.6],
    [174.6, 220.0, 261.6],
    [196.0, 246.9, 293.7],
  ];
  const bass = [130.8, 110.0, 87.3, 98.0];
  // Har bar mein 8 aadhe-beat notes (0 = khamoshi), chord ke suron se bani melody
  const melody = [
    [523.3, 0, 659.3, 587.3, 523.3, 0, 392.0, 440.0],
    [440.0, 0, 523.3, 440.0, 392.0, 0, 329.6, 392.0],
    [349.2, 0, 440.0, 523.3, 587.3, 0, 523.3, 440.0],
    [392.0, 0, 493.9, 587.3, 659.3, 587.3, 493.9, 0],
  ];
  final bars = 8;
  final total = (bars * 4 * beat * sampleRate).round();
  final out = List<double>.filled(total, 0);

  void addNote(
    double start,
    double dur,
    double f,
    double vol,
    Wave w, {
    double decay = 3,
  }) {
    if (f <= 0) return;
    final s0 = (start * sampleRate).round();
    final n = (dur * sampleRate).round();
    var phase = 0.0;
    for (var i = 0; i < n && s0 + i < total; i++) {
      final t = i / sampleRate;
      phase += f / sampleRate;
      final attack = math.min(1.0, i / (sampleRate * 0.01));
      final release = math.min(1.0, (n - i) / (sampleRate * 0.03));
      out[s0 + i] += w(phase) * vol * attack * release * math.exp(-decay * t);
    }
  }

  for (var bar = 0; bar < bars; bar++) {
    final c = bar % 4;
    final t0 = bar * 4 * beat;
    // Bass: har beat par
    for (var b = 0; b < 4; b++) {
      addNote(t0 + b * beat, beat * 0.9, bass[c], 0.16, triangle, decay: 2);
    }
    // Chord: beat 2 aur 4 par halka "chhamak"
    for (final b in [1, 3]) {
      for (final f in chords[c]) {
        addNote(t0 + b * beat, beat * 0.5, f, 0.045, sine, decay: 5);
      }
    }
    // Melody
    for (var k = 0; k < 8; k++) {
      addNote(
        t0 + k * beat / 2,
        beat * 0.48,
        melody[c][k].toDouble(),
        0.11,
        triangle,
        decay: 4,
      );
    }
    // Halki taal (noise "chik" har aadhe beat par)
    final rnd = math.Random(bar);
    for (var k = 0; k < 8; k++) {
      final s0 = ((t0 + k * beat / 2) * sampleRate).round();
      for (var i = 0; i < 700 && s0 + i < total; i++) {
        out[s0 + i] += (rnd.nextDouble() * 2 - 1) * 0.03 * math.exp(-i / 120);
      }
    }
  }
  return out;
}

double sine(double p) => math.sin(2 * math.pi * p);
double square(double p) => (p % 1) < 0.5 ? 0.6 : -0.6;
double triangle(double p) => 1 - 4 * ((p % 1) - 0.5).abs();

/// Ek tone: [freq] waqt (0..1) ke hisaab se badal sakti hai
List<double> tone(
  double seconds,
  double Function(double t) freq, {
  Wave wave = sine,
  double decay = 6,
  double volume = 0.5,
}) {
  final n = (seconds * sampleRate).round();
  final out = List<double>.filled(n, 0);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / n;
    phase += freq(t) / sampleRate;
    final attack = math.min(1.0, i / (sampleRate * 0.005));
    out[i] = wave(phase) * volume * attack * math.exp(-decay * t * seconds * 4);
  }
  return out;
}

List<double> chord(double seconds, List<double> freqs, {double volume = 0.3}) {
  final parts = [
    for (final f in freqs)
      tone(seconds, (_) => f, wave: square, decay: 1, volume: volume),
  ];
  return [
    for (var i = 0; i < parts.first.length; i++)
      parts.fold<double>(0, (s, p) => s + p[i]) / freqs.length * 1.4,
  ];
}

List<double> engine(double seconds) {
  final n = (seconds * sampleRate).round();
  final rnd = math.Random(7);
  final out = List<double>.filled(n, 0);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / n;
    phase += (70 + 90 * t) / sampleRate;
    final saw = 2 * (phase % 1) - 1;
    final noise = rnd.nextDouble() * 2 - 1;
    final env = math.sin(math.pi * t);
    out[i] = (saw * 0.35 + noise * 0.08) * env;
  }
  return out;
}

List<double> silence(double seconds) =>
    List<double>.filled((seconds * sampleRate).round(), 0);

List<double> join(List<List<double>> parts) => [for (final p in parts) ...p];

/// 16-bit mono WAV file ke bytes
Uint8List toWav(List<double> samples) {
  final dataLen = samples.length * 2;
  final b = ByteData(44 + dataLen);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + dataLen, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, dataLen, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}
