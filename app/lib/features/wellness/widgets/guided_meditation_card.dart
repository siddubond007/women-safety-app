import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class GuidedMeditationCard extends StatefulWidget {
  const GuidedMeditationCard({super.key});

  @override
  State<GuidedMeditationCard> createState() => _GuidedMeditationCardState();
}

class _GuidedMeditationCardState extends State<GuidedMeditationCard> {
  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );
  static const List<int> _presetMinutes = [5, 7, 11, 21];

  int _selectedMinutes = 7;
  int _elapsedSeconds = 0;
  bool _isPlaying = false;
  double _volume = 0.75;
  Timer? _timer;

  int get _totalSeconds => _selectedMinutes * 60;

  String _formatMmSs(int seconds) {
    final clamped = seconds.clamp(0, 99999);
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _breathingPhaseLabel {
    if (!_isPlaying) return 'Breathwork & 432Hz + 528Hz Harmonic Singing-Bowl Audio';
    final cycleSec = _elapsedSeconds % 19;
    if (cycleSec < 4) return 'Inhale gently through your nose (4s)…';
    if (cycleSec < 11) return 'Hold breath calmly at your center (7s)…';
    return 'Exhale slowly & release tension (8s)…';
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
      try {
        await _nativeChannel.invokeMethod('pauseMeditationAudio');
      } catch (_) {}
      return;
    }

    if (_elapsedSeconds >= _totalSeconds) {
      _elapsedSeconds = 0;
    }
    setState(() => _isPlaying = true);
    try {
      await _nativeChannel.invokeMethod('startMeditationAudio', {
        'durationMinutes': _selectedMinutes,
        'volume': _volume,
      });
    } catch (_) {}

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_elapsedSeconds + 1 >= _totalSeconds) {
        timer.cancel();
        setState(() {
          _elapsedSeconds = _totalSeconds;
          _isPlaying = false;
        });
        unawaited(_stopNativeAudio());
      } else {
        setState(() => _elapsedSeconds += 1);
      }
    });
  }

  Future<void> _stopNativeAudio() async {
    try {
      await _nativeChannel.invokeMethod('stopMeditationAudio');
    } catch (_) {}
  }

  Future<void> _selectDuration(int minutes) async {
    if (_selectedMinutes == minutes) return;
    _timer?.cancel();
    final wasPlaying = _isPlaying;
    setState(() {
      _selectedMinutes = minutes;
      _elapsedSeconds = 0;
      _isPlaying = false;
    });
    await _stopNativeAudio();
    if (wasPlaying && mounted) {
      await _togglePlayPause();
    }
  }

  Future<void> _resetSession() async {
    _timer?.cancel();
    setState(() {
      _elapsedSeconds = 0;
      _isPlaying = false;
    });
    await _stopNativeAudio();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_stopNativeAudio());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0
        ? (_elapsedSeconds / _totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final remainingSeconds = (_totalSeconds - _elapsedSeconds).clamp(
      0,
      _totalSeconds,
    );

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
                      _isPlaying || _elapsedSeconds > 0
                          ? '${_isPlaying ? "Playing" : "Paused"} • ${_formatMmSs(_elapsedSeconds)} / ${_formatMmSs(_totalSeconds)} (-${_formatMmSs(remainingSeconds)})'
                          : '$_selectedMinutes min • Live Audio & Timer',
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
              if (_elapsedSeconds > 0)
                IconButton(
                  tooltip: 'Reset timer',
                  onPressed: _resetSession,
                  icon: const Icon(
                    Icons.replay_rounded,
                    color: AppColors.primaryPurple,
                    size: 20,
                  ),
                ),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                      onTap: () => _selectDuration(mins),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedMinutes == mins
                              ? AppColors.primaryPurple
                              : Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _selectedMinutes == mins
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
                            color: _selectedMinutes == mins
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
                _formatMmSs(_elapsedSeconds),
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
                    onChanged: (val) {
                      setState(() {
                        _elapsedSeconds = (val * _totalSeconds).round();
                      });
                    },
                  ),
                ),
              ),
              Text(
                _formatMmSs(_totalSeconds),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _volume <= 0.05
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
                    value: _volume,
                    activeColor: AppColors.primaryPurple,
                    inactiveColor: AppColors.borderSubtle,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      if (_isPlaying) {
                        unawaited(
                          _nativeChannel.invokeMethod('setMeditationVolume', {
                            'volume': v,
                          }),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
