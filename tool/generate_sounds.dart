// Saade (placeholder) sound effects code se banane wala script.
// Yeh awaazen hamari apni banayi hui hain, kisi ki copy nahi.
// Chalane ka tareeqa (project folder mein):  dart run tool/generate_sounds.dart
// Is se assets/audio/ mein .wav files ban jaati hain. Baad mein behtar sounds
// (maslan kenney.nl se) isi naam se rakh kar inhein badal sakte hain.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

void main(List<String> args) {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final force = args.contains('--force');
  final targets = args.where((a) => !a.startsWith('-')).toSet();

  final sounds = <String, ({List<double> samples, int rate})>{
    // Chhota "pop"
    'tap': (samples: tone(0.07, (t) => 880 - 300 * t, wave: sine, decay: 30), rate: sampleRate),
    // Engine ki "vroom"
    'bus_move': (samples: engine(0.38), rate: sampleRate),
    // Do neeche wali "bup bup" (rasta band)
    'blocked': (
      samples: join([
        tone(0.07, (_) => 170, wave: square, decay: 10, volume: 0.35),
        silence(0.03),
        tone(0.08, (_) => 140, wave: square, decay: 10, volume: 0.35),
      ]),
      rate: sampleRate,
    ),
    // Passenger baithne ki halki "plip"
    'board': (samples: tone(0.09, (t) => 620 + 500 * t, wave: sine, decay: 18), rate: sampleRate),
    // Bus rawana hone par chota sa khushgawar celebration chime
    'bus_depart': (samples: busDepartSound(rate: 44100), rate: 44100),
    // Jeet ki chadhti dhun
    'win': (
      samples: join([
        for (final f in [523.0, 659.0, 784.0])
          tone(0.11, (_) => f, wave: triangle, decay: 4),
        tone(0.4, (_) => 1047, wave: triangle, decay: 3),
      ]),
      rate: sampleRate,
    ),
    // Haar ki utarti dhun
    'fail': (
      samples: join([
        for (final f in [392.0, 330.0, 277.0])
          tone(0.16, (_) => f, wave: triangle, decay: 3),
        tone(0.4, (t) => 233 - 30 * t, wave: triangle, decay: 2.5),
      ]),
      rate: sampleRate,
    ),
    // Button ka "tik"
    'button': (samples: tone(0.045, (_) => 1300, wave: sine, decay: 60), rate: sampleRate),
    // Level start intro: dono roads se logon ka rush + chadhti marimba sparkle
    'level_start': (samples: levelStartSound(rate: 44100), rate: 44100),
    // Upar se gari girne par narm rubber bounce thump
    'car_land': (samples: carLandSound(rate: 44100), rate: 44100),
    // Check-in / Daily bonus / Spin / Garage gift reward: pop + chamakti celesta chime
    'gift': (samples: giftSound(rate: 44100), rate: 44100),
    // Background music: khushgawar choti dhun jo loop mein chalti hai
    'music': (samples: music(), rate: sampleRate),
  };

  sounds.forEach((name, data) {
    if (targets.isNotEmpty && !targets.contains(name)) return;
    final file = File('${dir.path}/$name.wav');
    if (!force && targets.isEmpty && file.existsSync()) {
      stdout.writeln('Mehfooz (mojood hai): ${file.path}');
      return;
    }
    file.writeAsBytesSync(toWav(data.samples, rate: data.rate));
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

/// Peak amplitude ko mehfooz had par set karne ke liye helper
List<double> _normalize(List<double> samples, {double peak = 0.80}) {
  var maxAbs = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > maxAbs) maxAbs = a;
  }
  if (maxAbs <= 1e-6) return samples;
  final scale = peak / maxAbs;
  return [for (final s in samples) s * scale];
}

/// Level start intro: dono side roads se rush + chadhti marimba sparkle
List<double> levelStartSound({int rate = 44100}) {
  const dur = 0.80;
  final total = (dur * rate).round();
  final out = List<double>.filled(total, 0);

  // 1) Airy stereo-feel crowd rush whoosh (0.00s - 0.46s)
  final rnd = math.Random(42);
  var lp = 0.0;
  var hpPrevIn = 0.0;
  var hpOut = 0.0;
  const whooshDur = 0.46;
  final whooshSamples = (whooshDur * rate).round();
  for (var i = 0; i < whooshSamples && i < total; i++) {
    final t = i / whooshSamples;
    final n = rnd.nextDouble() * 2 - 1;
    final fc = 280 + 1170 * math.sin(math.pi * t);
    final alpha = (2 * math.pi * fc / rate).clamp(0.01, 0.75);
    lp += alpha * (n - lp);
    hpOut = 0.98 * (hpOut + lp - hpPrevIn);
    hpPrevIn = lp;
    final env = math.pow(math.sin(math.pi * t), 1.3).toDouble();
    out[i] += hpOut * 0.42 * env;
  }

  // 2) Wood/marimba ascending droplets as queue fills the circle
  const notes = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50];
  for (var k = 0; k < notes.length; k++) {
    final startSec = 0.04 + k * 0.068;
    final f = notes[k];
    final s0 = (startSec * rate).round();
    const nDur = 0.16;
    final nCount = (nDur * rate).round();
    for (var i = 0; i < nCount && s0 + i < total; i++) {
      final lt = i / rate;
      final attack = math.min(1.0, lt / 0.004);
      final body = math.sin(2 * math.pi * f * lt) * math.exp(-22 * lt);
      final over =
          0.22 * math.sin(2 * math.pi * (f * 2.0) * lt) * math.exp(-42 * lt);
      final click =
          0.10 * math.sin(2 * math.pi * (f * 3.0) * lt) * math.exp(-95 * lt);
      out[s0 + i] += (body + over + click) * attack * 0.24;
    }
  }

  // 3) Soft cheerful finish chime
  const chimeStart = 0.44;
  final c0 = (chimeStart * rate).round();
  for (var i = 0; c0 + i < total; i++) {
    final lt = i / rate;
    final attack = math.min(1.0, lt / 0.012);
    final bell =
        0.55 * math.sin(2 * math.pi * 1046.50 * lt) +
        0.45 * math.sin(2 * math.pi * 1567.98 * lt);
    out[c0 + i] += bell * attack * math.exp(-10 * lt) * 0.16;
  }

  return _normalize(out, peak: 0.80);
}

/// Car touchdown sound: narm rubber-suspension thump aur chhota bounce tap
List<double> carLandSound({int rate = 44100}) {
  const dur = 0.15;
  final total = (dur * rate).round();
  final out = List<double>.filled(total, 0);
  final rnd = math.Random(19);

  var phase = 0.0;
  var lpNoise = 0.0;
  for (var i = 0; i < total; i++) {
    final t = i / rate;
    final freq = 48.0 + 127.0 * math.exp(-38 * t);
    phase += freq / rate;
    final thump = math.sin(2 * math.pi * phase) * math.exp(-26 * t);
    final click = math.sin(2 * math.pi * 340 * t) * math.exp(-110 * t);
    final n = rnd.nextDouble() * 2 - 1;
    lpNoise += 0.22 * (n - lpNoise);
    final slap = lpNoise * math.exp(-75 * t);
    final attack = math.min(1.0, t / 0.002);
    out[i] += (thump * 0.68 + click * 0.22 + slap * 0.30) * attack;
  }

  final b0 = (0.062 * rate).round();
  var bPhase = 0.0;
  for (var i = 0; b0 + i < total; i++) {
    final t = i / rate;
    final freq = 66.0 + 62.0 * math.exp(-42 * t);
    bPhase += freq / rate;
    final tap = math.sin(2 * math.pi * bPhase) * math.exp(-38 * t);
    out[b0 + i] += tap * 0.24;
  }

  return _normalize(out, peak: 0.78);
}

/// Bus depart sound: chota sa crisp celebration chime (ta-da-DING sparkle)
List<double> busDepartSound({int rate = 44100}) {
  const dur = 0.42;
  final total = (dur * rate).round();
  final out = List<double>.filled(total, 0);

  void addBellNote(
    double startSec,
    double freq,
    double amp, {
    double decay = 16,
  }) {
    final s0 = (startSec * rate).round();
    for (var i = 0; s0 + i < total; i++) {
      final t = i / rate;
      final attack = math.min(1.0, t / 0.0025);
      final fundamental = math.sin(2 * math.pi * freq * t) * math.exp(-decay * t);
      final harmonic2 =
          0.32 * math.sin(2 * math.pi * (freq * 2.0) * t) * math.exp(-34 * t);
      final strike =
          0.10 * math.sin(2 * math.pi * (freq * 3.0) * t) * math.exp(-75 * t);
      out[s0 + i] += (fundamental + harmonic2 + strike) * attack * amp;
    }
  }

  // Upbeat Major Triad Celebration Arpeggio: G5 -> B5 -> D6 -> G6 chord sparkle
  addBellNote(0.000, 783.99, 0.55, decay: 18);
  addBellNote(0.056, 987.77, 0.62, decay: 18);
  addBellNote(0.112, 1174.66, 0.72, decay: 16);
  addBellNote(0.168, 1567.98, 0.90, decay: 10);
  addBellNote(0.168, 987.77, 0.28, decay: 12);
  addBellNote(0.168, 1174.66, 0.30, decay: 12);

  // Akhiri 25ms narm fade-out taa ke zero click aaye
  final fadeSamples = (0.025 * rate).round();
  for (var i = 0; i < fadeSamples && i < total; i++) {
    final k = i / fadeSamples;
    out[total - fadeSamples + i] *= 0.5 * (1 + math.cos(math.pi * k));
  }

  return _normalize(out, peak: 0.84);
}

/// Gift reward sound: chhota pop-open + chamakti celesta prize chime (F-major sparkle)
List<double> giftSound({int rate = 44100}) {
  const dur = 0.72;
  final total = (dur * rate).round();
  final out = List<double>.filled(total, 0);

  // 1) Box khulne ka narm "pop" (0.00s - 0.06s)
  var popPhase = 0.0;
  final popSamples = (0.06 * rate).round();
  for (var i = 0; i < popSamples && i < total; i++) {
    final t = i / popSamples;
    final freq = 380.0 + 460.0 * t;
    popPhase += freq / rate;
    final env = math.sin(math.pi * t) * (1.0 - 0.35 * t);
    out[i] += math.sin(2 * math.pi * popPhase) * 0.28 * env;
  }

  // 2) Chamakti celesta / bell reward arpeggio: C5 -> F5 -> A5 -> C6 -> F6
  void addSparkle(
    double startSec,
    double freq,
    double amp, {
    double decay = 11,
  }) {
    final s0 = (startSec * rate).round();
    for (var i = 0; s0 + i < total; i++) {
      final t = i / rate;
      final attack = math.min(1.0, t / 0.004);
      final body = math.sin(2 * math.pi * freq * t) * math.exp(-decay * t);
      final over =
          0.26 * math.sin(2 * math.pi * (freq * 2.0) * t) * math.exp(-24 * t);
      final shimmer =
          0.08 * math.sin(2 * math.pi * (freq * 3.0) * t) * math.exp(-42 * t);
      out[s0 + i] += (body + over + shimmer) * attack * amp;
    }
  }

  addSparkle(0.025, 523.25, 0.42, decay: 15);
  addSparkle(0.085, 698.46, 0.48, decay: 14);
  addSparkle(0.145, 880.00, 0.56, decay: 13);
  addSparkle(0.205, 1046.50, 0.66, decay: 11);
  addSparkle(0.270, 1396.91, 0.85, decay: 6.5);
  addSparkle(0.270, 880.00, 0.28, decay: 7.5);
  addSparkle(0.270, 1046.50, 0.30, decay: 7.5);

  // Akhiri 30ms narm fade-out
  final fadeSamples = (0.030 * rate).round();
  for (var i = 0; i < fadeSamples && i < total; i++) {
    final k = i / fadeSamples;
    out[total - fadeSamples + i] *= 0.5 * (1 + math.cos(math.pi * k));
  }

  return _normalize(out, peak: 0.82);
}

/// 16-bit mono WAV file ke bytes
Uint8List toWav(List<double> samples, {int rate = sampleRate}) {
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
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
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
