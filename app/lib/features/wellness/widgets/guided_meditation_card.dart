import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_wellness_illustrations.dart';
import '../../auth/backend_api_client.dart';

/// Pure-Dart RFC 6234 SHA-256 implementation used to verify downloaded
/// meditation audio tracks before atomic cache promotion without external deps.
class SakhiSha256 {
  static const List<int> _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  static String hexDigest(Uint8List data) {
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final bitLen = data.length * 8;
    final padLen = ((56 - (data.length + 1) % 64) + 64) % 64;
    final padded = Uint8List(data.length + 1 + padLen + 8);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(padded.length - 8, (bitLen >>> 32) & 0xffffffff, Endian.big);
    bd.setUint32(padded.length - 4, bitLen & 0xffffffff, Endian.big);

    final w = List<int>.filled(64, 0);
    for (var offset = 0; offset < padded.length; offset += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + i * 4, Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ ((w[i - 15] & 0xffffffff) >>> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ ((w[i - 2] & 0xffffffff) >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    String hex32(int v) => (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return '${hex32(h0)}${hex32(h1)}${hex32(h2)}${hex32(h3)}'
        '${hex32(h4)}${hex32(h5)}${hex32(h6)}${hex32(h7)}';
  }
}

class SakhiVoiceProfileOption {
  const SakhiVoiceProfileOption({
    required this.voiceId,
    required this.displayName,
    required this.accentLabel,
    required this.toneDescription,
    required this.edgeTtsVoiceName,
    required this.locale,
    required this.speechRate,
    required this.pitch,
    required this.samplePrompt,
  });

  final String voiceId;
  final String displayName;
  final String accentLabel;
  final String toneDescription;
  final String edgeTtsVoiceName;
  final String locale;
  final double speechRate;
  final double pitch;
  final String samplePrompt;
}

class SakhiWellnessTrackOption {
  const SakhiWellnessTrackOption({
    required this.trackId,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.fallbackSynthIndex,
    this.requiresHeadphonesNote = false,
  });

  final String trackId;
  final String title;
  final String category;
  final String categoryLabel;
  final int fallbackSynthIndex;
  final bool requiresHeadphonesNote;
}

class SakhiCachedAudioEntry {
  SakhiCachedAudioEntry({
    required this.trackId,
    required this.filePath,
    required this.byteSize,
    required this.sha256,
    required this.cachedAtEpochMs,
    required this.lastAccessedEpochMs,
  });

  final String trackId;
  final String filePath;
  final int byteSize;
  final String sha256;
  final int cachedAtEpochMs;
  int lastAccessedEpochMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trackId': trackId,
    'filePath': filePath,
    'byteSize': byteSize,
    'sha256': sha256,
    'cachedAtEpochMs': cachedAtEpochMs,
    'lastAccessedEpochMs': lastAccessedEpochMs,
  };

  factory SakhiCachedAudioEntry.fromJson(Map<String, dynamic> map) {
    return SakhiCachedAudioEntry(
      trackId: (map['trackId'] ?? '').toString(),
      filePath: (map['filePath'] ?? '').toString(),
      byteSize: (map['byteSize'] as num?)?.toInt() ?? 0,
      sha256: (map['sha256'] ?? '').toString(),
      cachedAtEpochMs: (map['cachedAtEpochMs'] as num?)?.toInt() ?? 0,
      lastAccessedEpochMs: (map['lastAccessedEpochMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Singleton session controller so an active meditation timer, spoken voice
/// narration, remote-cached soundscape, and user preferences stay synchronized
/// across the Wellness Hub, Meditation Studio, and Breathing Studio.
class GuidedMeditationSessionController extends ChangeNotifier {
  static final GuidedMeditationSessionController instance =
      GuidedMeditationSessionController._();

  GuidedMeditationSessionController._() {
    _voiceInitialization = _configureVoiceEngine();
    unawaited(loadSavedPreferences());
  }

  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _prefsStorageKey = 'sakhi.wellness.preferences.v1';
  static const String _cacheIndexStorageKey = 'sakhi.wellness.audio_cache.v1';

  // Bounded LRU Cache limits (Section 4.3)
  static const int maxCachedTracks = 6;
  static const int maxCacheBytes = 15 * 1024 * 1024; // 15 MB
  static const int cacheTtlMs = 7 * 24 * 60 * 60 * 1000; // 7 days

  /// The 5 User-Approved Neural Guidance Voices (Section 4.1)
  static const List<SakhiVoiceProfileOption> approvedVoiceOptions = [
    SakhiVoiceProfileOption(
      voiceId: 'V22',
      displayName: 'Elizabeth • Poised Sleep & Meditation',
      accentLabel: 'US Poised Neural',
      toneDescription: 'Slow, warm, poised meditation and sleep guide (-14% rate, -2Hz pitch)',
      edgeTtsVoiceName: 'en-US-ElizabethNeural',
      locale: 'en-US',
      speechRate: 0.37,
      pitch: 0.94,
      samplePrompt:
          'Welcome to your Sakhi sanctuary. Allow your shoulders to soften, and let your hands rest comfortably.',
    ),
    SakhiVoiceProfileOption(
      voiceId: 'V24',
      displayName: 'Clara • Warm Evening Reset',
      accentLabel: 'Canadian Warm Neural',
      toneDescription: 'Gentle, reassuring evening relaxation guide (-14% rate, -2Hz pitch)',
      edgeTtsVoiceName: 'en-CA-ClaraNeural',
      locale: 'en-CA',
      speechRate: 0.37,
      pitch: 0.95,
      samplePrompt:
          'Breathe in gently through your nose... hold that calm warmth inside... and release slowly.',
    ),
    SakhiVoiceProfileOption(
      voiceId: 'V26',
      displayName: 'Sonia • Deep Calm Grounding',
      accentLabel: 'British Calm Neural',
      toneDescription: 'Deep, grounded mindfulness counselor (-14% rate, -2Hz pitch)',
      edgeTtsVoiceName: 'en-GB-SoniaNeural',
      locale: 'en-GB',
      speechRate: 0.37,
      pitch: 0.93,
      samplePrompt:
          'Notice the quiet stillness beneath your thoughts. You are safe, supported, and at peace.',
    ),
    SakhiVoiceProfileOption(
      voiceId: 'V30',
      displayName: 'Emily • Gentle Sanctuary',
      accentLabel: 'Irish Soft Neural',
      toneDescription: 'Lyrical, unhurried breathwork & comfort guide (-14% rate, -1Hz pitch)',
      edgeTtsVoiceName: 'en-IE-EmilyNeural',
      locale: 'en-IE',
      speechRate: 0.38,
      pitch: 0.96,
      samplePrompt:
          'With every exhale, allow any remaining tension to melt away into quiet stillness.',
    ),
    SakhiVoiceProfileOption(
      voiceId: 'V01',
      displayName: 'Neerja • Expressive Warm Counselor',
      accentLabel: 'Indian English Neural',
      toneDescription: 'Warm, empathetic Indian English wellness guide (-8% rate, natural pitch)',
      edgeTtsVoiceName: 'en-IN-NeerjaExpressiveNeural',
      locale: 'en-IN',
      speechRate: 0.40,
      pitch: 0.98,
      samplePrompt:
          'Welcome to Sakhi. Take a slow, comforting breath in, and let your body rest with ease.',
    ),
  ];

  static const Map<String, String> musicCategories = <String, String>{
    'ALL': 'Choose for me (Random Peaceful Track)',
    'SOLFEGGIO_MEDITATION': 'Solfeggio & Harmonic Frequencies (432 Hz / 528 Hz)',
    'SINGING_BOWLS_HARMONICS': 'Tibetan Singing Bowls & Temple Chimes',
    'BINAURAL_BREATHWORK': 'Gentle Binaural Breathwork Waves (Headphones Optional)',
    'NATURE_RAIN_FOREST': 'Monsoon Rain, Forest & Bamboo Stream',
    'OCEAN_COASTAL_WAVES': 'Midnight Ocean Surf & Coastal Breeze',
    'SLEEP_EVENING_AMBIENCE': 'Starlight Sleep & Warm Night Sanctuary',
    'WARM_PELVIC_COMFORT': 'Warm Pelvic Comfort & Cramp Soothing Pads',
  };

  /// Curated representative catalog mapping into the 42 backend tracks (`M01`–`M42`)
  static const List<SakhiWellnessTrackOption> remoteTrackCatalog = [
    SakhiWellnessTrackOption(
      trackId: 'M01',
      title: '432 Hz Miracle of Mind Stillness',
      category: 'SOLFEGGIO_MEDITATION',
      categoryLabel: 'Solfeggio & Harmonics',
      fallbackSynthIndex: 0,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M03',
      title: '528 Hz Warm Heart Restoration',
      category: 'SOLFEGGIO_MEDITATION',
      categoryLabel: 'Solfeggio & Harmonics',
      fallbackSynthIndex: 1,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M08',
      title: '852 Hz Quiet Intuition & Clarity',
      category: 'SOLFEGGIO_MEDITATION',
      categoryLabel: 'Solfeggio & Harmonics',
      fallbackSynthIndex: 2,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M10',
      title: 'Theta 6 Hz Deep Meditation Binaural',
      category: 'BINAURAL_BREATHWORK',
      categoryLabel: 'Binaural Breathwork',
      fallbackSynthIndex: 4,
      requiresHeadphonesNote: true,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M14',
      title: 'Himalayan Singing Bowl Sanctuary',
      category: 'SINGING_BOWLS_HARMONICS',
      categoryLabel: 'Singing Bowls',
      fallbackSynthIndex: 3,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M19',
      title: 'Soft Monsoon Rain on Lotus Leaves',
      category: 'NATURE_RAIN_FOREST',
      categoryLabel: 'Nature & Rain',
      fallbackSynthIndex: 1,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M24',
      title: 'Misty Cedar Forest & Morning Stream',
      category: 'NATURE_RAIN_FOREST',
      categoryLabel: 'Nature & Rain',
      fallbackSynthIndex: 2,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M27',
      title: 'Calm Arabian Sea Evening Tide',
      category: 'OCEAN_COASTAL_WAVES',
      categoryLabel: 'Ocean Waves',
      fallbackSynthIndex: 2,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M33',
      title: 'Warm Pelvic & Cramp Comfort Pad',
      category: 'WARM_PELVIC_COMFORT',
      categoryLabel: 'Pelvic Comfort',
      fallbackSynthIndex: 0,
    ),
    SakhiWellnessTrackOption(
      trackId: 'M38',
      title: 'Velvet Starlight Deep Sleep Drone',
      category: 'SLEEP_EVENING_AMBIENCE',
      categoryLabel: 'Evening Sleep',
      fallbackSynthIndex: 4,
    ),
  ];

  static const List<String> soundscapeTitles = [
    '432 Hz Warm Harmonic Drone',
    'Soft Major-7th Ambient Pad',
    'Open-Fifth Gentle Swell Drone',
    'Pentatonic Harmonic Fifths',
    'Low-Frequency Restorative Hum',
  ];

  static const List<Map<String, String>> meditationPrograms = [
    {
      'id': 'miracle_of_mind',
      'title': 'Miracle of Mind • Inner Stillness',
      'subtitle': 'Breath awareness, mental space & gentle self-observation',
    },
    {
      'id': 'body_scan',
      'title': 'Full-Body Tension Release Scan',
      'subtitle': 'Progressive relaxation from crown to toes',
    },
    {
      'id': 'period_comfort',
      'title': 'Warm Pelvic & Cramp Comfort',
      'subtitle': 'Soothing breath & warmth visualization for menstrual ease',
    },
    {
      'id': 'deep_sleep',
      'title': 'Evening Rest & Deep Sleep Reset',
      'subtitle': 'Slow vagal toning & quiet starlight stillness',
    },
  ];

  final BackendApiClient _apiClient = BackendApiClient();

  int selectedMinutes = 7;
  int elapsedSeconds = 0;
  bool isPlaying = false;
  double volume = 0.68; // Ambient music volume
  double voiceVolume = 0.92; // Spoken guidance volume
  bool voiceGuidanceEnabled = true;
  bool ambientMusicEnabled = true;
  int selectedTrackIndex = 0;
  int selectedProgramIndex = 0;

  // Section 4 Preferences & Remote Download State
  bool onboardingCompleted = false;
  String selectedVoiceId = 'V22';
  String musicSelectionMode = 'CHOOSE_FOR_ME'; // CHOOSE_FOR_ME | CATEGORY | EXPLICIT_TRACK
  String preferredMusicCategory = 'ALL';
  String selectedRemoteTrackId = 'M01';
  String? lastPlayedTrackId;

  bool isPreparingAudio = false;
  double downloadProgress = 0.0;
  String? preparingStatusText;
  String? activeLocalAudioFilePath;
  final Map<String, SakhiCachedAudioEntry> _lruCache =
      <String, SakhiCachedAudioEntry>{};

  String currentSpokenPrompt =
      'Tap Play when you are ready. Choose your preferred voice guide, duration, and peaceful soundscape below.';

  Timer? _timer;
  final FlutterTts _tts = FlutterTts();
  late Future<void> _voiceInitialization;
  int _lastSpokenMilestoneSecond = -1;

  int get totalSeconds => selectedMinutes * 60;

  SakhiVoiceProfileOption get currentVoiceProfile =>
      approvedVoiceOptions.firstWhere(
        (v) => v.voiceId == selectedVoiceId,
        orElse: () => approvedVoiceOptions.first,
      );

  SakhiWellnessTrackOption get currentTrackOption =>
      remoteTrackCatalog.firstWhere(
        (t) => t.trackId == selectedRemoteTrackId,
        orElse: () => remoteTrackCatalog[selectedTrackIndex % remoteTrackCatalog.length],
      );

  int get cachedTrackCount => _lruCache.length;

  int get cachedTotalBytes =>
      _lruCache.values.fold<int>(0, (sum, e) => sum + e.byteSize);

  Future<void> loadSavedPreferences() async {
    try {
      final raw = await _storage.read(key: _prefsStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _applyPreferenceMap(decoded);
        }
      }
      final rawCache = await _storage.read(key: _cacheIndexStorageKey);
      if (rawCache != null && rawCache.isNotEmpty) {
        final decodedCache = jsonDecode(rawCache);
        if (decodedCache is List) {
          for (final item in decodedCache) {
            if (item is Map<String, dynamic>) {
              final entry = SakhiCachedAudioEntry.fromJson(item);
              final file = File(entry.filePath);
              if (entry.trackId.isEmpty || !file.existsSync()) continue;
              if (DateTime.now().millisecondsSinceEpoch - entry.cachedAtEpochMs >= cacheTtlMs) {
                try { await file.delete(); } catch (_) {}
                continue;
              }
              try {
                final bytes = await file.readAsBytes();
                final valid = bytes.length == entry.byteSize &&
                    entry.sha256.length == 64 &&
                    SakhiSha256.hexDigest(bytes) == entry.sha256;
                if (valid) {
                  _lruCache[entry.trackId] = entry;
                } else {
                  await file.delete();
                }
              } catch (_) {
                try { await file.delete(); } catch (_) {}
              }
            }
          }
        }
      }
    } catch (_) {}

    // Best-effort sync from backend if authenticated
    try {
      final token = await _apiClient.readAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await _apiClient.get(
          'module2/wellness/preferences',
          authenticated: true,
        );
        final prefMap = response['preferences'];
        if (prefMap is Map<String, dynamic>) {
          _applyPreferenceMap(prefMap);
          await _persistLocalPreferences();
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void _applyPreferenceMap(Map<String, dynamic> map) {
    final voice = (map['selectedVoiceId'] ?? '').toString();
    if (approvedVoiceOptions.any((v) => v.voiceId == voice)) {
      selectedVoiceId = voice;
    }
    final mode = (map['musicSelectionMode'] ?? '').toString();
    if (mode == 'CHOOSE_FOR_ME' ||
        mode == 'CATEGORY' ||
        mode == 'EXPLICIT_TRACK') {
      musicSelectionMode = mode;
    }
    final cat = (map['preferredCategory'] ?? '').toString();
    if (cat.isNotEmpty && musicCategories.containsKey(cat)) {
      preferredMusicCategory = cat;
    }
    final track = (map['selectedTrackId'] ?? '').toString();
    if (track.isNotEmpty) {
      selectedRemoteTrackId = track;
    }
    if (map['onboardingCompleted'] == true) {
      onboardingCompleted = true;
    }
    if (map['voiceGuidanceEnabled'] is bool) {
      voiceGuidanceEnabled = map['voiceGuidanceEnabled'] as bool;
    }
    if (map['ambientMusicEnabled'] is bool) {
      ambientMusicEnabled = map['ambientMusicEnabled'] as bool;
    }
    if (map['voiceVolume'] is num) {
      voiceVolume = (map['voiceVolume'] as num).toDouble().clamp(0.0, 1.0);
    }
    if (map['musicVolume'] is num) {
      volume = (map['musicVolume'] as num).toDouble().clamp(0.0, 1.0);
    }
    if (map['defaultDurationMinutes'] is num) {
      selectedMinutes = (map['defaultDurationMinutes'] as num).toInt().clamp(1, 60);
    }
  }

  Future<void> _persistLocalPreferences() async {
    try {
      await _storage.write(
        key: _prefsStorageKey,
        value: jsonEncode(<String, Object?>{
          'selectedVoiceId': selectedVoiceId,
          'musicSelectionMode': musicSelectionMode,
          'preferredCategory': preferredMusicCategory,
          'selectedTrackId': selectedRemoteTrackId,
          'onboardingCompleted': onboardingCompleted,
          'voiceGuidanceEnabled': voiceGuidanceEnabled,
          'ambientMusicEnabled': ambientMusicEnabled,
          'voiceVolume': voiceVolume,
          'musicVolume': volume,
          'defaultDurationMinutes': selectedMinutes,
        }),
      );
    } catch (_) {}
  }

  Future<void> saveWellnessPreferences({
    required String voiceId,
    required String selectionMode,
    required String category,
    String? explicitTrackId,
    bool markOnboardingComplete = true,
  }) async {
    selectedVoiceId = voiceId;
    musicSelectionMode = selectionMode;
    preferredMusicCategory = category;
    if (explicitTrackId != null && explicitTrackId.isNotEmpty) {
      selectedRemoteTrackId = explicitTrackId;
    }
    if (markOnboardingComplete) {
      onboardingCompleted = true;
    }
    _voiceInitialization = _configureVoiceEngine();
    notifyListeners();
    await _persistLocalPreferences();

    try {
      final token = await _apiClient.readAccessToken();
      if (token != null && token.isNotEmpty) {
        await _apiClient.put(
          'module2/wellness/preferences',
          authenticated: true,
          body: <String, Object?>{
            'selectedVoiceId': selectedVoiceId,
            'musicSelectionMode': musicSelectionMode,
            'preferredCategory': preferredMusicCategory,
            'selectedTrackId': selectedRemoteTrackId,
            'voiceGuidanceEnabled': voiceGuidanceEnabled,
            'ambientMusicEnabled': ambientMusicEnabled,
            'voiceVolume': voiceVolume,
            'musicVolume': volume,
            'defaultDurationMinutes': selectedMinutes,
            'onboardingCompleted': onboardingCompleted,
          },
        );
      }
    } catch (_) {}
  }

  Future<void> previewVoiceProfile(String voiceId) async {
    final option = approvedVoiceOptions.firstWhere(
      (v) => v.voiceId == voiceId,
      orElse: () => approvedVoiceOptions.first,
    );
    selectedVoiceId = option.voiceId;
    await _configureVoiceEngine();
    try {
      await _tts.stop();
      await _tts.setVolume(voiceVolume);
      await _tts.speak(option.samplePrompt);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _configureVoiceEngine() async {
    final profile = currentVoiceProfile;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          const [],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } catch (_) {}
    }

    try {
      final dynamic voices = await _tts.getVoices;
      if (voices is List) {
        Map<dynamic, dynamic>? matchedVoice;
        final targetLocalePrefix = profile.locale.toLowerCase();
        for (final raw in voices) {
          if (raw is Map) {
            final name = (raw['name'] ?? '').toString().toLowerCase();
            final locale = (raw['locale'] ?? '')
                .toString()
                .replaceAll('_', '-')
                .toLowerCase();
            final isFemaleHint =
                name.contains('female') ||
                name.contains('elizabeth') ||
                name.contains('clara') ||
                name.contains('sonia') ||
                name.contains('emily') ||
                name.contains('neerja') ||
                name.contains('veena') ||
                name.contains('samantha') ||
                name.contains('ava') ||
                name.contains('karen') ||
                name.contains('en-in-x-end') ||
                name.contains('en-us-x-sfg');
            if (locale.startsWith(targetLocalePrefix) && isFemaleHint) {
              matchedVoice = raw;
              break;
            }
          }
        }
        if (matchedVoice != null) {
          await _tts.setVoice({
            'name': matchedVoice['name'].toString(),
            'locale': matchedVoice['locale'].toString(),
          });
        } else {
          await _tts.setLanguage(profile.locale);
        }
      }
    } catch (_) {}

    try {
      await _tts.setSpeechRate(profile.speechRate);
      await _tts.setPitch(profile.pitch);
      await _tts.setVolume(voiceVolume);
    } catch (_) {}
  }

  /// Resolves a track according to user preferences (explicit track, category,
  /// or non-repeating "Choose for me"), downloads it to a bounded local LRU
  /// cache before playback starts, verifies SHA-256 + byte length, and returns
  /// the local file path (or null if offline fallback synth should be used).
  Future<String?> _prepareSessionTrackBeforePlayback() async {
    if (!ambientMusicEnabled) return null;

    var chosenTrack = currentTrackOption;
    if (musicSelectionMode == 'CHOOSE_FOR_ME' ||
        musicSelectionMode == 'CATEGORY') {
      final pool = remoteTrackCatalog.where((t) {
        if (musicSelectionMode == 'CATEGORY' &&
            preferredMusicCategory != 'ALL') {
          return t.category == preferredMusicCategory;
        }
        return true;
      }).toList();
      final nonRepeating = pool
          .where((t) => t.trackId != lastPlayedTrackId)
          .toList();
      final candidates = nonRepeating.isNotEmpty ? nonRepeating : pool;
      if (candidates.isNotEmpty) {
        chosenTrack =
            candidates[math.Random().nextInt(candidates.length)];
      }
    }

    selectedRemoteTrackId = chosenTrack.trackId;
    lastPlayedTrackId = chosenTrack.trackId;
    selectedTrackIndex = chosenTrack.fallbackSynthIndex;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = _lruCache[chosenTrack.trackId];
    if (existing != null &&
        (nowMs - existing.cachedAtEpochMs) < cacheTtlMs &&
        File(existing.filePath).existsSync() &&
        File(existing.filePath).lengthSync() > 1024) {
      try {
        final cachedBytes = await File(existing.filePath).readAsBytes();
        final cacheValid = cachedBytes.length == existing.byteSize &&
            existing.sha256.length == 64 &&
            SakhiSha256.hexDigest(cachedBytes) == existing.sha256;
        if (cacheValid) {
          existing.lastAccessedEpochMs = nowMs;
          activeLocalAudioFilePath = existing.filePath;
          await _persistCacheIndex();
          return existing.filePath;
        }
        await File(existing.filePath).delete();
      } catch (_) {}
      _lruCache.remove(chosenTrack.trackId);
      await _persistCacheIndex();
    }

    isPreparingAudio = true;
    downloadProgress = 0.08;
    preparingStatusText =
        'Preparing your meditation • Downloading ${chosenTrack.title}...';
    notifyListeners();

    try {
      // Ask the backend to resolve and record the selected track first. This
      // gives the client the authoritative byte length and checksum for either
      // the configured CDN object or the deterministic local fallback.
      final prepared = await _apiClient.post(
        'module2/wellness/prepare-session',
        authenticated: true,
        body: <String, Object?>{
          'experienceType': 'MEDITATION',
          'selectionMode': 'EXPLICIT',
          'requestedTrackId': chosenTrack.trackId,
          'requestedCategory': chosenTrack.category,
        },
      );
      final preparedTrack = prepared['track'];
      if (preparedTrack is! Map<String, dynamic> ||
          preparedTrack['trackId']?.toString() != chosenTrack.trackId) {
        throw StateError('The backend did not prepare the requested wellness track.');
      }
      final expectedSha256 = preparedTrack['streamSha256Checksum']?.toString().toLowerCase();
      final expectedByteSize = (preparedTrack['streamByteSize'] as num?)?.toInt();
      if (expectedSha256 == null ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSha256) ||
          expectedByteSize == null || expectedByteSize < 1024) {
        throw StateError('The backend wellness track metadata is incomplete.');
      }

      final result = await _apiClient.downloadBinary(
        'module2/wellness/audio-tracks/${chosenTrack.trackId}/stream',
        authenticated: true,
        onProgress: (received, total) {
          if (total > 0) {
            downloadProgress = (received / total).clamp(0.1, 0.95);
            notifyListeners();
          }
        },
      );

      if (result.bytes.length < 1024) {
        throw StateError('Downloaded track is smaller than minimum valid audio size.');
      }

      final computedSha256 = SakhiSha256.hexDigest(result.bytes);
      final responseSha256 = result.sha256Header?.trim().toLowerCase();
      if (result.bytes.length != expectedByteSize ||
          responseSha256 != expectedSha256 ||
          computedSha256 != expectedSha256) {
        throw StateError('Downloaded audio does not match the prepared catalogue byte length and SHA-256 checksum.');
      }
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sakhi_wellness_audio_cache',
      );
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final ext = (result.contentType ?? '').contains('wav') ? 'wav' : 'mp3';
      final partFile = File(
        '${cacheDir.path}/${chosenTrack.trackId}_$nowMs.part',
      );
      final finalFile = File(
        '${cacheDir.path}/${chosenTrack.trackId}.$ext',
      );

      await partFile.writeAsBytes(result.bytes, flush: true);
      // Verify written file matches expected byte length and SHA-256
      final verifyBytes = await partFile.readAsBytes();
      if (verifyBytes.length != result.bytes.length ||
          SakhiSha256.hexDigest(verifyBytes) != computedSha256) {
        try {
          await partFile.delete();
        } catch (_) {}
        throw StateError('Audio file checksum verification failed.');
      }

      if (finalFile.existsSync()) {
        try {
          await finalFile.delete();
        } catch (_) {}
      }
      await partFile.rename(finalFile.path);

      _lruCache[chosenTrack.trackId] = SakhiCachedAudioEntry(
        trackId: chosenTrack.trackId,
        filePath: finalFile.path,
        byteSize: result.bytes.length,
        sha256: computedSha256,
        cachedAtEpochMs: nowMs,
        lastAccessedEpochMs: nowMs,
      );
      activeLocalAudioFilePath = finalFile.path;
      await _enforceLruBounds(protectedTrackId: chosenTrack.trackId);
      await _persistCacheIndex();

      downloadProgress = 1.0;
      isPreparingAudio = false;
      preparingStatusText = null;
      notifyListeners();
      return finalFile.path;
    } catch (_) {
      // Offline or local dev server not reachable: fall back cleanly to built-in polyphonic synth
      isPreparingAudio = false;
      downloadProgress = 0.0;
      preparingStatusText = null;
      activeLocalAudioFilePath = null;
      notifyListeners();
      return null;
    }
  }

  Future<void> _enforceLruBounds({String? protectedTrackId}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Remove expired entries first
    final expiredIds = _lruCache.values
        .where(
          (e) =>
              e.trackId != protectedTrackId &&
              (nowMs - e.cachedAtEpochMs) >= cacheTtlMs,
        )
        .map((e) => e.trackId)
        .toList();
    for (final id in expiredIds) {
      final removed = _lruCache.remove(id);
      if (removed != null) {
        try {
          final f = File(removed.filePath);
          if (f.existsSync()) await f.delete();
        } catch (_) {}
      }
    }

    // Enforce maxEntries and maxCacheBytes via LRU eviction
    while (_lruCache.length > maxCachedTracks ||
        cachedTotalBytes > maxCacheBytes) {
      final evictable = _lruCache.values
          .where((e) => e.trackId != protectedTrackId)
          .toList()
        ..sort(
          (a, b) => a.lastAccessedEpochMs.compareTo(b.lastAccessedEpochMs),
        );
      if (evictable.isEmpty) break;
      final victim = evictable.first;
      _lruCache.remove(victim.trackId);
      try {
        final f = File(victim.filePath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _persistCacheIndex() async {
    try {
      await _storage.write(
        key: _cacheIndexStorageKey,
        value: jsonEncode(_lruCache.values.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// User-facing action to clear all downloaded meditation audio files (Section 4.3)
  Future<void> clearDownloadedMusicCache() async {
    final activePath = isPlaying ? activeLocalAudioFilePath : null;
    final keys = _lruCache.keys.toList();
    for (final key in keys) {
      final entry = _lruCache[key];
      if (entry == null) continue;
      if (activePath != null && entry.filePath == activePath) continue;
      _lruCache.remove(key);
      try {
        final f = File(entry.filePath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await _persistCacheIndex();
    notifyListeners();
  }

  String _scriptCueForSecond(int sec) {
    final programId = meditationPrograms[selectedProgramIndex]['id'];
    if (sec == 0) {
      if (programId == 'period_comfort') {
        return 'Welcome to Warm Pelvic and Cramp Comfort. Rest one hand gently over your lower abdomen, soften your shoulders, and allow your eyelids to close.';
      }
      if (programId == 'body_scan') {
        return 'Welcome to your Full-Body Tension Release meditation. Sit or lie down comfortably, unclench your jaw, and take a slow, welcoming breath in.';
      }
      if (programId == 'deep_sleep') {
        return 'Welcome to Evening Rest and Deep Sleep Reset. Let the weight of your body sink softly into your cushion or bed as the day comes to a peaceful close.';
      }
      return 'Welcome to Miracle of Mind Inner Stillness. Sit comfortably with a gentle, upright spine, rest your hands softly in your lap, and let your eyes close.';
    }
    if (sec == 18) {
      return 'Bring your attention to the natural flow of your breath. You do not need to force anything. Simply notice the cool air entering your nostrils, and the warm air leaving.';
    }
    if (sec == 42) {
      if (programId == 'period_comfort') {
        return 'With every exhale, imagine a soothing golden warmth spreading across your lower back and pelvis, softening every muscle fiber.';
      }
      return 'Notice the gentle space between your thoughts and your breath. Thoughts may drift by like clouds in a wide sky—let them pass without following them.';
    }
    if (sec == 75) {
      return 'Relax your forehead, soften the corners of your eyes, drop your shoulders away from your ears, and let your belly rise and fall with ease.';
    }
    if (sec == 120) {
      return 'Rest in quiet stillness for the next few breaths. Whenever your mind wanders, kindly guide your awareness back to the centre of your chest.';
    }
    if (sec > 120 && sec % 60 == 0 && sec < totalSeconds - 20) {
      final cues = [
        'Breathe in calm clarity… and breathe out any remaining restlessness. You are safe, grounded, and present in this moment.',
        'Allow your exhalation to be slightly longer than your inhalation, inviting your nervous system into deeper stillness.',
        'Notice the quiet stillness beneath the surface of your thoughts. Rest effortlessly in this calm inner space.',
      ];
      return cues[(sec ~/ 60) % cues.length];
    }
    if (sec == totalSeconds - 15 && totalSeconds >= 60) {
      return 'Begin to deepen your breath gently. Notice the sounds around you, wiggle your fingers slowly, and carry this calm stillness with you.';
    }
    return '';
  }

  Future<void> _speakCueIfNeeded(int second, {bool forceIntro = false}) async {
    final cue = _scriptCueForSecond(forceIntro ? 0 : second);
    if (cue.isEmpty) return;
    if (!forceIntro && _lastSpokenMilestoneSecond == second) return;
    _lastSpokenMilestoneSecond = second;
    currentSpokenPrompt = cue;
    notifyListeners();

    if (!voiceGuidanceEnabled || !isPlaying) return;
    try {
      await _voiceInitialization;
      if (!voiceGuidanceEnabled || !isPlaying) return;
      await _tts.setVolume(voiceVolume);
      await _tts.stop();
      await _tts.speak(cue);
    } catch (_) {}
  }

  Future<void> _speakCompletion() async {
    const closing =
        'Your guided meditation session is complete. Take a gentle breath in, and open your eyes whenever you feel ready.';
    currentSpokenPrompt = closing;
    notifyListeners();
    if (!voiceGuidanceEnabled) return;
    try {
      await _voiceInitialization;
      await _tts.setVolume(voiceVolume);
      await _tts.stop();
      await _tts.speak(closing);
    } catch (_) {}
  }

  Future<void> stopVoice() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    if (isPreparingAudio) return;
    if (isPlaying) {
      _timer?.cancel();
      isPlaying = false;
      notifyListeners();
      await stopVoice();
      try {
        await _nativeChannel.invokeMethod('pauseMeditationAudio');
      } catch (_) {}
      return;
    }

    if (elapsedSeconds >= totalSeconds) {
      elapsedSeconds = 0;
      _lastSpokenMilestoneSecond = -1;
    }

    String? localFilePath;
    if (ambientMusicEnabled) {
      localFilePath = await _prepareSessionTrackBeforePlayback();
    }

    isPlaying = true;
    notifyListeners();

    if (ambientMusicEnabled) {
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
          if (localFilePath != null) 'localFilePath': localFilePath,
        });
      } catch (_) {}
    }

    unawaited(
      _speakCueIfNeeded(elapsedSeconds, forceIntro: elapsedSeconds < 15),
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (elapsedSeconds + 1 >= totalSeconds) {
        timer.cancel();
        elapsedSeconds = totalSeconds;
        isPlaying = false;
        notifyListeners();
        unawaited(stopNativeAudio());
        unawaited(_speakCompletion());
      } else {
        elapsedSeconds += 1;
        notifyListeners();
        unawaited(_speakCueIfNeeded(elapsedSeconds));
      }
    });
  }

  Future<void> stopNativeAudio() async {
    try {
      await _nativeChannel.invokeMethod('stopMeditationAudio');
    } catch (_) {}
  }

  Future<void> selectDuration(int minutes) async {
    if (selectedMinutes == minutes) return;
    _timer?.cancel();
    final wasPlaying = isPlaying;
    selectedMinutes = minutes;
    elapsedSeconds = 0;
    _lastSpokenMilestoneSecond = -1;
    isPlaying = false;
    notifyListeners();
    await stopVoice();
    await stopNativeAudio();
    if (wasPlaying) {
      await togglePlayPause();
    }
  }

  Future<void> selectSoundscapeTrack(int trackIdx) async {
    final normalized = trackIdx % soundscapeTitles.length;
    selectedTrackIndex = normalized;
    final mappedTrackIds = ['M01', 'M19', 'M27', 'M14', 'M38'];
    selectedRemoteTrackId = mappedTrackIds[normalized];
    musicSelectionMode = 'EXPLICIT_TRACK';
    notifyListeners();
    unawaited(_persistLocalPreferences());
    if (isPlaying && ambientMusicEnabled) {
      final localPath = await _prepareSessionTrackBeforePlayback();
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
          if (localPath != null) 'localFilePath': localPath,
        });
      } catch (_) {}
    }
  }

  Future<void> selectRemoteTrackById(String trackId) async {
    final option = remoteTrackCatalog.firstWhere(
      (t) => t.trackId == trackId,
      orElse: () => remoteTrackCatalog.first,
    );
    selectedRemoteTrackId = option.trackId;
    selectedTrackIndex = option.fallbackSynthIndex;
    musicSelectionMode = 'EXPLICIT_TRACK';
    notifyListeners();
    unawaited(_persistLocalPreferences());
    if (isPlaying && ambientMusicEnabled) {
      final localPath = await _prepareSessionTrackBeforePlayback();
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
          if (localPath != null) 'localFilePath': localPath,
        });
      } catch (_) {}
    }
  }

  Future<void> selectProgram(int programIdx) async {
    selectedProgramIndex = programIdx.clamp(0, meditationPrograms.length - 1);
    _lastSpokenMilestoneSecond = -1;
    notifyListeners();
    if (isPlaying) {
      await _speakCueIfNeeded(0, forceIntro: true);
    } else {
      currentSpokenPrompt =
          '${meditationPrograms[selectedProgramIndex]['title']} — ${meditationPrograms[selectedProgramIndex]['subtitle']}';
      notifyListeners();
    }
  }

  Future<void> toggleVoiceGuidance() async {
    voiceGuidanceEnabled = !voiceGuidanceEnabled;
    notifyListeners();
    unawaited(_persistLocalPreferences());
    if (!voiceGuidanceEnabled) {
      await stopVoice();
    } else if (isPlaying) {
      await _speakCueIfNeeded(elapsedSeconds, forceIntro: true);
    }
  }

  Future<void> toggleAmbientMusic() async {
    ambientMusicEnabled = !ambientMusicEnabled;
    notifyListeners();
    unawaited(_persistLocalPreferences());
    if (!ambientMusicEnabled) {
      await stopNativeAudio();
    } else if (isPlaying) {
      final localPath = await _prepareSessionTrackBeforePlayback();
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
          if (localPath != null) 'localFilePath': localPath,
        });
      } catch (_) {}
    }
  }

  Future<void> resetSession() async {
    _timer?.cancel();
    elapsedSeconds = 0;
    _lastSpokenMilestoneSecond = -1;
    isPlaying = false;
    isPreparingAudio = false;
    preparingStatusText = null;
    currentSpokenPrompt =
        'Session reset. Tap Play whenever you are ready to begin your guided meditation.';
    notifyListeners();
    await stopVoice();
    await stopNativeAudio();
  }

  Future<void> seek(double fraction) async {
    elapsedSeconds = (fraction * totalSeconds).round().clamp(0, totalSeconds);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    if (isPlaying && ambientMusicEnabled) {
      try {
        await _nativeChannel.invokeMethod('setMeditationVolume', {
          'volume': volume,
        });
      } catch (_) {}
    }
  }

  Future<void> setVoiceVolume(double v) async {
    voiceVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _tts.setVolume(voiceVolume);
    } catch (_) {}
  }
}

/// First-Use Onboarding Wizard & Settings Sheet for Meditation & Breathing
/// (Section 4.1, 4.2, 4.3, 4.4)
class SakhiWellnessOnboardingWizardSheet extends StatefulWidget {
  const SakhiWellnessOnboardingWizardSheet({
    super.key,
    this.isFirstUseWizard = false,
  });

  final bool isFirstUseWizard;

  static Future<void> show(
    BuildContext context, {
    bool isFirstUseWizard = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakhiWellnessOnboardingWizardSheet(
        isFirstUseWizard: isFirstUseWizard,
      ),
    );
  }

  @override
  State<SakhiWellnessOnboardingWizardSheet> createState() =>
      _SakhiWellnessOnboardingWizardSheetState();
}

class _SakhiWellnessOnboardingWizardSheetState
    extends State<SakhiWellnessOnboardingWizardSheet> {
  final _session = GuidedMeditationSessionController.instance;
  int _step = 0;
  late String _voiceId;
  late String _musicMode;
  late String _category;
  late String _trackId;

  @override
  void initState() {
    super.initState();
    _voiceId = _session.selectedVoiceId;
    _musicMode = _session.musicSelectionMode;
    _category = _session.preferredMusicCategory;
    _trackId = _session.selectedRemoteTrackId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFDF7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.self_improvement_rounded,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isFirstUseWizard
                      ? 'Personalize Your Wellness Sanctuary (Step ${_step + 1}/3)'
                      : 'Voice & Meditation Soundscape Settings',
                  style: AppTypography.sectionTitle,
                ),
              ),
              IconButton(
                onPressed: () {
                  _session.stopVoice();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Relaxation & mindfulness disclaimer: Sakhi audio sessions are designed for calm relaxation and breath pacing, not medical diagnosis or treatment. Stereo headphones are optional and recommended only for binaural tracks.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: _buildStepContent(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () async {
                    if (_step < 2) {
                      setState(() => _step++);
                      return;
                    }
                    await _session.saveWellnessPreferences(
                      voiceId: _voiceId,
                      selectionMode: _musicMode,
                      category: _category,
                      explicitTrackId: _trackId,
                      markOnboardingComplete: true,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    _step < 2
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    _step < 2 ? 'Next Step' : 'Save My Sanctuary Preferences',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Choose Your Natural Women’s Guidance Voice',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap any of the 5 approved neural voices below to select it, or tap Preview to hear a calm sample.',
            style: AppTypography.subtitle,
          ),
          const SizedBox(height: 10),
          for (final v in GuidedMeditationSessionController.approvedVoiceOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _voiceId = v.voiceId),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _voiceId == v.voiceId
                        ? const Color(0xFFF3E8FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _voiceId == v.voiceId
                          ? AppColors.primaryPurple
                          : AppColors.borderSubtle,
                      width: _voiceId == v.voiceId ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _voiceId == v.voiceId
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v.displayName} (${v.voiceId})',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${v.accentLabel} • ${v.toneDescription}',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _voiceId = v.voiceId);
                          _session.previewVoiceProfile(v.voiceId);
                        },
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                        label: const Text('Preview'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. How Should Sakhi Pick Your Meditation Music?',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Choose for me (Non-repeating Random)'),
                selected: _musicMode == 'CHOOSE_FOR_ME',
                onSelected: (_) => setState(() {
                  _musicMode = 'CHOOSE_FOR_ME';
                  _category = 'ALL';
                }),
              ),
              ChoiceChip(
                label: const Text('By Preferred Category'),
                selected: _musicMode == 'CATEGORY',
                onSelected: (_) => setState(() => _musicMode = 'CATEGORY'),
              ),
              ChoiceChip(
                label: const Text('Specific Track (M01–M42)'),
                selected: _musicMode == 'EXPLICIT_TRACK',
                onSelected: (_) => setState(() => _musicMode = 'EXPLICIT_TRACK'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_musicMode == 'CATEGORY' || _musicMode == 'CHOOSE_FOR_ME') ...[
            const Text(
              'Preferred Soundscape Category:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final entry
                in GuidedMeditationSessionController.musicCategories.entries)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                value: entry.key,
                groupValue: _category,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _category = val;
                      _musicMode = val == 'ALL' ? 'CHOOSE_FOR_ME' : 'CATEGORY';
                    });
                  }
                },
              ),
          ],
          if (_musicMode == 'EXPLICIT_TRACK') ...[
            const Text(
              'Select Curated Track:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final t in GuidedMeditationSessionController.remoteTrackCatalog)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${t.trackId} • ${t.title}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  t.requiresHeadphonesNote
                      ? '${t.categoryLabel} • Stereo headphones optional'
                      : t.categoryLabel,
                  style: const TextStyle(fontSize: 11.5),
                ),
                value: t.trackId,
                groupValue: _trackId,
                onChanged: (val) {
                  if (val != null) setState(() => _trackId = val);
                },
              ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. On-Demand Audio Cache & Storage',
          style: AppTypography.cardTitle,
        ),
        const SizedBox(height: 6),
        const Text(
          'To keep the Sakhi app lightweight, meditation music tracks are downloaded on-demand before your session starts and cached locally (up to 6 recent tracks / 15 MB max, 7-day auto-expiry).',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, color: AppColors.primaryPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cached tracks: ${_session.cachedTrackCount} / ${GuidedMeditationSessionController.maxCachedTracks} '
                  '(${(_session.cachedTotalBytes / 1024).toStringAsFixed(0)} KB)',
                  style: AppTypography.bodyMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await _session.clearDownloadedMusicCache();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Clear Cache'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GuidedMeditationCard extends StatefulWidget {
  final VoidCallback? onOpenFullStudio;

  const GuidedMeditationCard({super.key, this.onOpenFullStudio});

  @override
  State<GuidedMeditationCard> createState() => _GuidedMeditationCardState();
}

class _GuidedMeditationCardState extends State<GuidedMeditationCard> {
  static const List<int> _presetMinutes = [5, 7, 11, 21];
  final _session = GuidedMeditationSessionController.instance;

  String _formatMmSs(int seconds) {
    final clamped = seconds.clamp(0, 99999);
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final progress = _session.totalSeconds > 0
            ? (_session.elapsedSeconds / _session.totalSeconds).clamp(0.0, 1.0)
            : 0.0;
        final remainingSeconds =
            (_session.totalSeconds - _session.elapsedSeconds).clamp(
              0,
              _session.totalSeconds,
            );
        final activeTrack = _session.currentTrackOption.title;
        final activeVoice = _session.currentVoiceProfile.displayName.split(' • ').first;
        final activeProgram =
            GuidedMeditationSessionController.meditationPrograms[_session
                .selectedProgramIndex]['title']!;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.wellnessBannerGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: AppSpacing.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            AppAssets.guidedMeditationThumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: AppColors.pastelLavender),
                          ),
                          Container(
                            color: Colors.white.withValues(alpha: 0.72),
                            child: const Center(
                              child: SakhiGentleWomanIllustration(
                                pose: SakhiWomanPose.meditationLotus,
                                size: 62,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeProgram,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _session.isPreparingAudio
                              ? (_session.preparingStatusText ??
                                    'Preparing your meditation...')
                              : _session.isPlaying || _session.elapsedSeconds > 0
                              ? '${_session.isPlaying ? "Playing" : "Paused"} • ${_formatMmSs(_session.elapsedSeconds)} / ${_formatMmSs(_session.totalSeconds)} (-${_formatMmSs(remainingSeconds)})'
                              : '${_session.selectedMinutes} min • Voice: $activeVoice + $activeTrack',
                          style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _session.currentSpokenPrompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Voice & Music Settings',
                    onPressed: () => SakhiWellnessOnboardingWizardSheet.show(
                      context,
                      isFirstUseWizard: false,
                    ),
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  if (_session.elapsedSeconds > 0)
                    IconButton(
                      tooltip: 'Reset timer',
                      onPressed: _session.resetSession,
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: AppColors.primaryPurple,
                        size: 20,
                      ),
                    ),
                  GestureDetector(
                    onTap: () async {
                      if (!_session.onboardingCompleted) {
                        await SakhiWellnessOnboardingWizardSheet.show(
                          context,
                          isFirstUseWizard: true,
                        );
                      }
                      await _session.togglePlayPause();
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: _session.isPreparingAudio
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _session.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                  ),
                ],
              ),
              if (_session.isPreparingAudio) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _session.downloadProgress > 0
                      ? _session.downloadProgress
                      : null,
                  backgroundColor: Colors.white,
                  color: AppColors.primaryPurple,
                ),
              ],
              const SizedBox(height: 10),
              // Soundscape Track Selector Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: Icon(
                        _session.voiceGuidanceEnabled
                            ? Icons.record_voice_over_rounded
                            : Icons.voice_over_off_rounded,
                        size: 15,
                        color: _session.voiceGuidanceEnabled
                            ? Colors.white
                            : AppColors.primaryPurple,
                      ),
                      backgroundColor: _session.voiceGuidanceEnabled
                          ? AppColors.primaryPurple
                          : Colors.white,
                      label: Text(
                        _session.voiceGuidanceEnabled
                            ? 'Voice: $activeVoice'
                            : 'Voice Muted',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _session.voiceGuidanceEnabled
                              ? Colors.white
                              : AppColors.primaryPurple,
                        ),
                      ),
                      onPressed: _session.toggleVoiceGuidance,
                    ),
                    const SizedBox(width: 6),
                    for (
                      var i = 0;
                      i <
                          GuidedMeditationSessionController
                              .soundscapeTitles
                              .length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            GuidedMeditationSessionController
                                .soundscapeTitles[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _session.selectedTrackIndex == i
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          selected: _session.selectedTrackIndex == i,
                          selectedColor: const Color(0xFFD63E85),
                          backgroundColor: Colors.white.withValues(alpha: 0.88),
                          onSelected: (_) => _session.selectSoundscapeTrack(i),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Selectable 5, 7, 11, 21 Minute Duration Pills
              Row(
                children: [
                  const Text(
                    'Session:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final mins in _presetMinutes) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _session.selectDuration(mins),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _session.selectedMinutes == mins
                                  ? AppColors.primaryPurple
                                  : Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _session.selectedMinutes == mins
                                    ? AppColors.primaryPurple
                                    : AppColors.borderSubtle,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$mins min',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _session.selectedMinutes == mins
                                    ? Colors.white
                                    : AppColors.primaryPurple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Interactive Seek Scrubber + Ambient Volume Control
              Row(
                children: [
                  Text(
                    _formatMmSs(_session.elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: progress,
                        activeColor: AppColors.primaryPurple,
                        inactiveColor: AppColors.borderSubtle,
                        onChanged: (val) => _session.seek(val),
                      ),
                    ),
                  ),
                  Text(
                    _formatMmSs(_session.totalSeconds),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _session.volume <= 0.05
                        ? Icons.volume_off_rounded
                        : Icons.music_note_rounded,
                    size: 16,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(
                    width: 64,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _session.volume,
                        activeColor: AppColors.primaryPurple,
                        inactiveColor: AppColors.borderSubtle,
                        onChanged: (v) => _session.setVolume(v),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onOpenFullStudio != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onOpenFullStudio,
                    icon: const Icon(Icons.open_in_full_rounded, size: 15),
                    label: const Text(
                      'Open Full Guided Meditation & Breathing Hub',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
