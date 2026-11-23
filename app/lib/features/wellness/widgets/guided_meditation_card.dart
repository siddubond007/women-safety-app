import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_wellness_illustrations.dart';

/// Singleton session controller so an active meditation timer, spoken voice
/// narration, and peaceful polyphonic soundscape continue uninterrupted when
/// switching tabs or opening the full-screen Guided Meditation Studio.
class GuidedMeditationSessionController extends ChangeNotifier {
  static final GuidedMeditationSessionController instance =
      GuidedMeditationSessionController._();
  GuidedMeditationSessionController._() {
    _voiceInitialization = _configureVoiceEngine();
  }

  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );

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

  int selectedMinutes = 7;
  int elapsedSeconds = 0;
  bool isPlaying = false;
  double volume = 0.68; // Ambient music volume
  double voiceVolume = 0.92; // Spoken guidance volume
  bool voiceGuidanceEnabled = true;
  bool ambientMusicEnabled = true;
  int selectedTrackIndex = 0;
  int selectedProgramIndex = 0;
  String currentSpokenPrompt =
      'Tap Play when you are ready. Choose your preferred meditation guide, duration, and peaceful soundscape below.';

  Timer? _timer;
  final FlutterTts _tts = FlutterTts();
  late final Future<void> _voiceInitialization;
  int _lastSpokenMilestoneSecond = -1;

  int get totalSeconds => selectedMinutes * 60;

  Future<void> _configureVoiceEngine() async {
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
        Map<dynamic, dynamic>? preferredVoice;
        for (final raw in voices) {
          if (raw is Map) {
            final name = (raw['name'] ?? '').toString().toLowerCase();
            final locale = (raw['locale'] ?? '')
                .toString()
                .replaceAll('_', '-')
                .toLowerCase();
            final isEnglish =
                locale.startsWith('en-in') ||
                locale.startsWith('en-gb') ||
                locale.startsWith('en-us');
            final isFemaleHint =
                name.contains('female') ||
                name.contains('veena') ||
                name.contains('lekha') ||
                name.contains('isha') ||
                name.contains('samantha') ||
                name.contains('ava') ||
                name.contains('karen') ||
                name.contains('en-in-x-end') ||
                name.contains('en-in-x-ena') ||
                name.contains('en-us-x-sfg');
            if (isEnglish && isFemaleHint) {
              preferredVoice = raw;
              if (locale.startsWith('en-in')) break;
            }
          }
        }
        if (preferredVoice != null) {
          await _tts.setVoice({
            'name': preferredVoice['name'].toString(),
            'locale': preferredVoice['locale'].toString(),
          });
        } else {
          await _tts.setLanguage('en-IN');
        }
      }
    } catch (_) {}

    try {
      await _tts.setSpeechRate(0.39);
      await _tts.setPitch(0.96);
      await _tts.setVolume(voiceVolume);
    } catch (_) {}
  }

  String _scriptCueForSecond(int sec) {
    final programId = meditationPrograms[selectedProgramIndex]['id'];
    if (sec == 0) {
      if (programId == 'period_comfort') {
        return 'Welcome to Warm Pelvic and Cramp Comfort. Rest one hand gently over your lower abdomen, soften your shoulders, and allow your eyelids to close.';
      }
      if (programId == 'body_scan') {
        return 'Welcome to your Full-Body Tension Release meditation. Sit or lie down comfortably, unClench your jaw, and take a slow, welcoming breath in.';
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
    isPlaying = true;
    notifyListeners();

    if (ambientMusicEnabled) {
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
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
    notifyListeners();
    if (isPlaying && ambientMusicEnabled) {
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
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
    if (!voiceGuidanceEnabled) {
      await stopVoice();
    } else if (isPlaying) {
      await _speakCueIfNeeded(elapsedSeconds, forceIntro: true);
    }
  }

  Future<void> toggleAmbientMusic() async {
    ambientMusicEnabled = !ambientMusicEnabled;
    notifyListeners();
    if (!ambientMusicEnabled) {
      await stopNativeAudio();
    } else if (isPlaying) {
      try {
        await _nativeChannel.invokeMethod('startMeditationAudio', {
          'durationMinutes': selectedMinutes,
          'volume': volume,
          'trackIndex': selectedTrackIndex,
        });
      } catch (_) {}
    }
  }

  Future<void> resetSession() async {
    _timer?.cancel();
    elapsedSeconds = 0;
    _lastSpokenMilestoneSecond = -1;
    isPlaying = false;
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
        final activeTrack = GuidedMeditationSessionController
            .soundscapeTitles[_session.selectedTrackIndex];
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
                          _session.isPlaying || _session.elapsedSeconds > 0
                              ? '${_session.isPlaying ? "Playing" : "Paused"} • ${_formatMmSs(_session.elapsedSeconds)} / ${_formatMmSs(_session.totalSeconds)} (-${_formatMmSs(remainingSeconds)})'
                              : '${_session.selectedMinutes} min • Spoken Voice + $activeTrack',
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
                    onTap: _session.togglePlayPause,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
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
                            ? 'Voice Guide On'
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
