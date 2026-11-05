import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Singleton session controller so an active meditation timer and 432Hz/528Hz
/// audio session continue uninterrupted when switching tabs or screens.
class _GuidedMeditationSessionController extends ChangeNotifier {
  static final _GuidedMeditationSessionController instance =
      _GuidedMeditationSessionController._();
  _GuidedMeditationSessionController._();

  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );

  int selectedMinutes = 7;
  int elapsedSeconds = 0;
  bool isPlaying = false;
  double volume = 0.75;
  Timer? _timer;

  int get totalSeconds => selectedMinutes * 60;

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      _timer?.cancel();
      isPlaying = false;
      notifyListeners();
      try {
        await _nativeChannel.invokeMethod('pauseMeditationAudio');
      } catch (_) {}
      return;
    }

    if (elapsedSeconds >= totalSeconds) {
      elapsedSeconds = 0;
    }
    isPlaying = true;
    notifyListeners();
    try {
      await _nativeChannel.invokeMethod('startMeditationAudio', {
        'durationMinutes': selectedMinutes,
        'volume': volume,
      });
    } catch (_) {}

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (elapsedSeconds + 1 >= totalSeconds) {
        timer.cancel();
        elapsedSeconds = totalSeconds;
        isPlaying = false;
        notifyListeners();
        unawaited(stopNativeAudio());
      } else {
        elapsedSeconds += 1;
        notifyListeners();
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
    isPlaying = false;
    notifyListeners();
    await stopNativeAudio();
    if (wasPlaying) {
      await togglePlayPause();
    }
  }

  Future<void> resetSession() async {
    _timer?.cancel();
    elapsedSeconds = 0;
    isPlaying = false;
    notifyListeners();
    await stopNativeAudio();
  }

  Future<void> seek(double fraction) async {
    elapsedSeconds = (fraction * totalSeconds).round().clamp(0, totalSeconds);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v;
    notifyListeners();
    if (isPlaying) {
      try {
        await _nativeChannel.invokeMethod('setMeditationVolume', {
          'volume': volume,
        });
      } catch (_) {}
    }
  }
}

class GuidedMeditationCard extends StatefulWidget {
  const GuidedMeditationCard({super.key});

  @override
  State<GuidedMeditationCard> createState() => _GuidedMeditationCardState();
}

class _GuidedMeditationCardState extends State<GuidedMeditationCard> {
  static const List<int> _presetMinutes = [5, 7, 11, 21];
  final _session = _GuidedMeditationSessionController.instance;

  String _formatMmSs(int seconds) {
    final clamped = seconds.clamp(0, 99999);
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _breathingPhaseLabel {
    if (!_session.isPlaying) {
      return 'Breathwork & 432Hz + 528Hz Harmonic Singing-Bowl Audio';
    }
    final cycleSec = _session.elapsedSeconds % 19;
    if (cycleSec < 4) return 'Inhale gently through your nose (4s)…';
    if (cycleSec < 11) return 'Hold breath calmly at your center (7s)…';
    return 'Exhale slowly & release tension (8s)…';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final progress = _session.totalSeconds > 0
            ? (_session.elapsedSeconds / _session.totalSeconds).clamp(0.0, 1.0)
            : 0.0;
        final remainingSeconds = (_session.totalSeconds - _session.elapsedSeconds)
            .clamp(0, _session.totalSeconds);

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
                    child: Image.asset(
                      AppAssets.guidedMeditationThumb,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.pastelLavender,
                        child: const Icon(
                          Icons.self_improvement_rounded,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guided Meditation',
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _session.isPlaying || _session.elapsedSeconds > 0
                              ? '${_session.isPlaying ? "Playing" : "Paused"} • ${_formatMmSs(_session.elapsedSeconds)} / ${_formatMmSs(_session.totalSeconds)} (-${_formatMmSs(remainingSeconds)})'
                              : '${_session.selectedMinutes} min • Live Audio & Timer',
                          style: AppTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _breathingPhaseLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subtitle.copyWith(fontSize: 11.5),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 10),
              // Interactive Seek Scrubber + Volume Control
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
                        : Icons.volume_up_rounded,
                    size: 16,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(
                    width: 68,
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
            ],
          ),
        );
      },
    );
  }
}
