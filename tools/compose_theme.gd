extends SceneTree
## Renders the shed's workout theme: a 20-bar rock loop in C minor at 112 BPM
## (a palm-muted chug, a stabbing intro riff, a brassy lead and a plain rock
## kit), written for this game and synthesised here so the same script always
## gives the same track. It writes a 16-bit WAV; encode that to the Ogg the
## game plays:
##
##     godot --headless --path . --script res://tools/compose_theme.gd -- <out.wav>
##     ffmpeg -y -i <out.wav> -c:a libvorbis -q:a 4 assets/audio/shed_theme.ogg
##
## The loop is seamless: tails that ring past the last bar are folded back
## over the first.

const RATE: int = 44100
const BPM: float = 112.0
const BARS: int = 20
## Eighth notes per bar.
const STEPS: int = 8

## Chord per bar: [bass midi note, minor?]. Bars 0-3 intro riff, 4-11 verse,
## 12-19 chorus.
const CHORDS: Array = [
	[36, true], [36, true], [36, true], [36, true],
	[36, true], [36, true], [32, false], [34, false],
	[36, true], [36, true], [32, false], [34, false],
	[32, false], [34, false], [36, true], [36, true],
	[32, false], [34, false], [39, false], [31, false],
]
## Intro riff hits: [bar, step, length in steps, guitar root midi].
const RIFF: Array = [
	[0, 0, 2, 48], [0, 3, 1, 51], [0, 4, 1, 48], [0, 6, 2, 46],
	[1, 0, 3, 44], [1, 3, 1, 46], [1, 4, 4, 48],
	[2, 0, 2, 48], [2, 3, 1, 51], [2, 4, 1, 48], [2, 6, 2, 46],
	[3, 0, 2, 44], [3, 2, 2, 46],
]
## Lead line: [bar, step, length in steps, midi].
const LEAD: Array = [
	[4, 0, 2, 67], [4, 3, 1, 67], [4, 4, 2, 70], [4, 6, 2, 72],
	[5, 0, 3, 75], [5, 3, 1, 74], [5, 4, 4, 72],
	[6, 0, 2, 72], [6, 2, 2, 75], [6, 4, 2, 68], [6, 6, 2, 72],
	[7, 0, 2, 74], [7, 2, 2, 77], [7, 4, 2, 74], [7, 6, 2, 70],
	[8, 0, 2, 67], [8, 3, 1, 67], [8, 4, 2, 70], [8, 6, 2, 72],
	[9, 0, 3, 75], [9, 3, 1, 77], [9, 4, 4, 79],
	[10, 0, 2, 75], [10, 2, 2, 72], [10, 4, 2, 75], [10, 6, 2, 77],
	[11, 0, 4, 74], [11, 4, 2, 77], [11, 6, 2, 79],
	[12, 0, 3, 80], [12, 3, 1, 79], [12, 4, 4, 75],
	[13, 0, 3, 77], [13, 3, 1, 75], [13, 4, 2, 74], [13, 6, 2, 70],
	[14, 0, 2, 72], [14, 2, 2, 75], [14, 4, 4, 79],
	[15, 0, 2, 79], [15, 2, 1, 80], [15, 3, 1, 79], [15, 4, 4, 75],
	[16, 0, 3, 80], [16, 3, 1, 82], [16, 4, 4, 84],
	[17, 0, 3, 82], [17, 3, 1, 80], [17, 4, 4, 77],
	[18, 0, 4, 79], [18, 4, 2, 75], [18, 6, 2, 79],
	[19, 0, 2, 74], [19, 2, 2, 77], [19, 4, 2, 74], [19, 6, 2, 71],
]

var step_seconds: float = 30.0 / BPM
var loop_samples: int = int(round(BARS * STEPS * step_seconds * RATE))
var mix := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: --script res://tools/compose_theme.gd -- <out.wav>")
		quit(1)
		return
	rng.seed = 20261020
	mix.resize(loop_samples + RATE * 3)
	_drums()
	_bass_and_guitar()
	_lead()
	var wav: AudioStreamWAV = _finish()
	var error: Error = wav.save_to_wav(args[0])
	print("%s: %.1f s, error %d" % [args[0], float(loop_samples) / RATE, error])
	quit(0 if error == OK else 1)


func _at(bar: int, step: float) -> float:
	return (bar * STEPS + step) * step_seconds


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# --- Drums -------------------------------------------------------------------


func _drums() -> void:
	for bar in range(BARS):
		var chorus: bool = bar >= 12
		if bar < 3:
			# Intro: the kick lands with every riff hit.
			for hit in RIFF:
				if hit[0] == bar:
					_kick(_at(bar, hit[1]), 1.0)
			_snare(_at(bar, 2), 0.5)
			_snare(_at(bar, 6), 0.5)
			continue
		if bar == 3:
			_kick(_at(bar, 0), 1.0)
			_kick(_at(bar, 2), 1.0)
			for i in range(8):
				_snare(_at(bar, 4.0 + i * 0.5), 0.35 + i * 0.08)
			continue
		if bar == 4 or bar == 12 or bar == 16:
			_crash(_at(bar, 0))
		for step in [0, 3, 4]:
			_kick(_at(bar, step), 1.0)
		if chorus:
			_kick(_at(bar, 7), 0.8)
		_snare(_at(bar, 2), 1.0)
		_snare(_at(bar, 6), 1.0)
		for step in range(STEPS):
			_hat(_at(bar, step), 0.8 if step % 2 == 0 else 0.5, chorus and step % 2 == 1)
		if bar == 11 or bar == 19:
			_snare(_at(bar, 7), 0.6)
			_snare(_at(bar, 7.5), 0.8)


func _kick(start: float, gain: float) -> void:
	var length: int = int(0.35 * RATE)
	var offset: int = int(start * RATE)
	var phase: float = 0.0
	for i in range(length):
		var t: float = float(i) / RATE
		phase += TAU * (48.0 + 110.0 * exp(-t * 28.0)) / RATE
		var click: float = rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.3
		mix[offset + i] += (sin(phase) * exp(-t * 9.0) + click) * 0.9 * gain


func _snare(start: float, gain: float) -> void:
	var length: int = int(0.25 * RATE)
	var offset: int = int(start * RATE)
	var last: float = 0.0
	for i in range(length):
		var t: float = float(i) / RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var bright: float = noise - last * 0.6
		last = noise
		var body: float = sin(TAU * 185.0 * t) * exp(-t * 30.0) * 0.5
		mix[offset + i] += (bright * exp(-t * 16.0) * 0.45 + body) * gain * 0.7


func _hat(start: float, gain: float, open: bool) -> void:
	var decay: float = 18.0 if open else 70.0
	var length: int = int((0.2 if open else 0.06) * RATE)
	var offset: int = int(start * RATE)
	var last: float = 0.0
	for i in range(length):
		var noise: float = rng.randf_range(-1.0, 1.0)
		var high: float = noise - last
		last = noise
		mix[offset + i] += high * exp(-float(i) / RATE * decay) * 0.09 * gain


func _crash(start: float) -> void:
	var length: int = int(1.8 * RATE)
	var offset: int = int(start * RATE)
	var last: float = 0.0
	for i in range(length):
		var noise: float = rng.randf_range(-1.0, 1.0)
		var high: float = noise - last * 0.2
		last = noise
		mix[offset + i] += high * exp(-float(i) / RATE * 2.6) * 0.12


# --- Bass and guitar ----------------------------------------------------------


func _bass_and_guitar() -> void:
	for hit in RIFF:
		var bar: int = hit[0]
		var start: float = _at(bar, hit[1])
		var seconds: float = hit[2] * step_seconds
		_guitar(hit[3], start, seconds * 0.95, 1.0, false)
		_bass(hit[3] - 12, start, seconds * 0.9, 1.0)
	for bar in range(4, BARS):
		var root: int = CHORDS[bar][0]
		var chorus: bool = bar >= 12
		for step in range(STEPS):
			var start: float = _at(bar, step)
			_bass(root, start, step_seconds * 0.85, 1.0 if step % 2 == 0 else 0.8)
			if not chorus:
				# Palm-muted chug, accented on the beat.
				_guitar(root + 12, start, step_seconds * 0.5, 0.8 if step % 2 == 0 else 0.6, true)
		if chorus:
			# Big open chords: a held half bar, then a pushed one.
			_guitar(root + 12, _at(bar, 0), step_seconds * 3.8, 1.0, false)
			_guitar(root + 12, _at(bar, 4), step_seconds * 3.8, 0.9, false)


func _bass(midi: int, start: float, seconds: float, gain: float) -> void:
	var hz: float = _hz(midi)
	var length: int = int(seconds * RATE)
	var offset: int = int(start * RATE)
	var low: float = 0.0
	for i in range(length):
		var t: float = float(i) / RATE
		var saw: float = 2.0 * fposmod(hz * t, 1.0) - 1.0
		low = lerpf(low, saw, 0.12)
		var envelope: float = minf(t * 300.0, 1.0) * minf((seconds - t) * 200.0, 1.0) * exp(-t * 2.0)
		mix[offset + i] += (low * 0.6 + sin(TAU * hz * t) * 0.5) * envelope * 0.32 * gain


## A distorted power chord (root, fifth, octave). Muted chugs are darker and
## shorter.
func _guitar(midi: int, start: float, seconds: float, gain: float, muted: bool) -> void:
	var notes: Array[float] = [_hz(midi), _hz(midi + 7), _hz(midi + 12)]
	var length: int = int((seconds + (0.02 if muted else 0.25)) * RATE)
	var offset: int = int(start * RATE)
	var smooth: float = 0.08 if muted else 0.22
	var low: float = 0.0
	for i in range(length):
		var t: float = float(i) / RATE
		var raw: float = 0.0
		for n in range(notes.size()):
			# Two slightly detuned saws per note thicken the chord.
			raw += 2.0 * fposmod(notes[n] * t, 1.0) - 1.0
			raw += 2.0 * fposmod(notes[n] * 1.004 * t + 0.3 * n, 1.0) - 1.0
		var drive: float = tanh(raw * 0.9)
		low = lerpf(low, drive, smooth)
		var release: float = clampf((seconds - t) / 0.05, 0.0, 1.0) if t > seconds - 0.05 else 1.0
		if t > seconds:
			release = exp(-(t - seconds) * 25.0) * (0.0 if muted else 1.0)
		var envelope: float = minf(t * 500.0, 1.0) * release * (exp(-t * 6.0) * 0.5 + 0.5 if muted else exp(-t * 0.8))
		mix[offset + i] += low * envelope * 0.26 * gain


# --- Lead ---------------------------------------------------------------------


func _lead() -> void:
	# A dotted-eighth echo gives the lead some room without washing the kit.
	var echo_seconds: float = step_seconds * 1.5
	for note in LEAD:
		var start: float = _at(note[0], note[1])
		var seconds: float = note[2] * step_seconds * 0.92
		var gain: float = 1.0 if note[0] >= 12 else 0.8
		_brass(note[3], start, seconds, gain)
		_brass(note[3], start + echo_seconds, seconds, gain * 0.22)


func _brass(midi: int, start: float, seconds: float, gain: float) -> void:
	var hz: float = _hz(midi)
	var length: int = int((seconds + 0.12) * RATE)
	var offset: int = int(start * RATE)
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	var low: float = 0.0
	for i in range(length):
		var t: float = float(i) / RATE
		# Vibrato creeps in on held notes.
		var vibrato: float = 1.0 + sin(TAU * 5.5 * t) * 0.006 * minf(t * 3.0, 1.0)
		phase_a = fposmod(phase_a + hz * vibrato / RATE, 1.0)
		phase_b = fposmod(phase_b + hz * vibrato * 1.006 / RATE, 1.0)
		var raw: float = (2.0 * phase_a - 1.0) + (1.0 if phase_b < 0.5 else -1.0) * 0.6
		# The filter opens on the attack, like a horn's blat.
		low = lerpf(low, raw, 0.08 + 0.25 * exp(-t * 10.0))
		var envelope: float = minf(t * 60.0, 1.0)
		if t > seconds:
			envelope *= exp(-(t - seconds) * 30.0)
		mix[offset + i] += low * envelope * 0.16 * gain


# --- Output -------------------------------------------------------------------


func _finish() -> AudioStreamWAV:
	# Fold anything past the loop end back onto the start.
	for i in range(loop_samples, mix.size()):
		mix[i - loop_samples] += mix[i]
	var peak: float = 0.0
	for i in range(loop_samples):
		peak = maxf(peak, absf(mix[i]))
	var data := PackedByteArray()
	data.resize(loop_samples * 2)
	for i in range(loop_samples):
		# Normalise, then a gentle soft clip keeps the drum peaks round.
		var value: float = tanh(mix[i] / peak * 1.4) / tanh(1.4) * 0.89
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
