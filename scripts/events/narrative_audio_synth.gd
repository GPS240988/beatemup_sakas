class_name NarrativeAudioSynth
extends RefCounted

## Síntese de áudio procedural arcade (WAV 8-bit mono, mix_rate 22050 Hz)
## Desacoplada do NarrativeDirector para responsabilidade única.

static func create_tone_wav(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var t: float = float(i) / 22050.0
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var wave: float = sin(t * freq * TAU)
		var val: float = (wave * volume * envelope) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav


static func create_noise_wav(duration: float, volume: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 22050
	var sample_count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var noise: float = randf_range(-1.0, 1.0)
		var val: float = (noise * volume) * 127.0 + 128.0
		data[i] = int(clamp(val, 0.0, 255.0))
	wav.data = data
	return wav


static func generate_effects_library() -> Dictionary:
	return {
		"deep_hum": create_tone_wav(55.0, 1.8, 0.45),
		"nostalgia": create_tone_wav(660.0, 0.35, 0.35),
		"glitch": create_noise_wav(0.08, 0.5),
		"advance": create_tone_wav(980.0, 0.06, 0.3)
	}

