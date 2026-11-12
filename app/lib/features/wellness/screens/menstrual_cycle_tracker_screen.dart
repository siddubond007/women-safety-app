import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../models/menstrual_cycle_models.dart';

/// Module 7 (SRS Section 9.1–9.5): Women's Menstrual Cycle Tracker
/// Provides interactive calendar, period start/end logging, rolling-average
/// predictions, irregularity detection, daily symptom/mood/energy/hydration logs,
/// discreet notifications, educational articles & FAQs, clinical export, and
/// one-tap complete health data deletion.
class MenstrualCycleTrackerScreen extends StatefulWidget {
  final int initialTabIndex;

  const MenstrualCycleTrackerScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MenstrualCycleTrackerScreen> createState() =>
      _MenstrualCycleTrackerScreenState();
}

class _MenstrualCycleTrackerScreenState
    extends State<MenstrualCycleTrackerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MenstrualCycleController _controller =
      MenstrualCycleController.instance;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late String _selectedDateIso;
  int? _draftCustomCycleDays;

  // Daily check-in form state
  String _dailyFlow = 'None';
  String _dailyCramps = 'None';
  String _dailyMood = 'Calm';
  int _dailyEnergy = 3;
  final Set<String> _dailySymptoms = <String>{};
  bool _dailyIsPms = false;
  int _dailyHydration = 6;
  double _dailySleepHours = 7.5;
  final TextEditingController _dailyNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _selectedDateIso = CyclePredictionEngine.formatIsoDate(DateTime.now());
    _controller.initialize().then((_) {
      if (mounted) {
        _loadDailyFormForDate(_selectedDateIso);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dailyNotesController.dispose();
    super.dispose();
  }

  void _loadDailyFormForDate(String isoDate) {
    final existing = _controller.dailyLogForDate(isoDate);
    setState(() {
      _selectedDateIso = isoDate;
      if (existing != null) {
        _dailyFlow = existing.flowIntensity ?? 'None';
        _dailyCramps = existing.crampsSeverity ?? 'None';
        _dailyMood = existing.mood ?? 'Calm';
        _dailyEnergy = existing.energyLevel ?? 3;
        _dailySymptoms
          ..clear()
          ..addAll(existing.symptoms);
        _dailyIsPms = existing.isPmsWindow;
        _dailyHydration = existing.hydrationGlasses;
        _dailySleepHours = existing.sleepHours ?? 7.5;
        _dailyNotesController.text = existing.personalNotes ?? '';
      } else {
        _dailyFlow = _controller.isLoggedPeriodDay(isoDate) ? 'Medium' : 'None';
        _dailyCramps = 'None';
        _dailyMood = 'Calm';
        _dailyEnergy = 3;
        _dailySymptoms.clear();
        _dailyIsPms = _controller.isPmsWindowDay(isoDate);
        _dailyHydration = 6;
        _dailySleepHours = 7.5;
        _dailyNotesController.clear();
      }
    });
  }

  Future<void> _openPeriodLogSheet({MenstrualCycleEntry? existing}) async {
    var startIso = existing?.startDate ?? _selectedDateIso;
    var endIso =
        existing?.endDate ??
        CyclePredictionEngine.addDaysIso(
          startIso,
          _controller.preferences.averagePeriodDuration - 1,
        );
    var flow = existing?.flowIntensity ?? 'Medium';
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.pastelPink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.water_drop_rounded,
                              color: Color(0xFFD63E85),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'Log Period Start & End Dates'
                                  : 'Edit Recorded Period Cycle',
                              style: AppTypography.sectionTitle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate:
                                      CyclePredictionEngine.parseIsoDate(
                                        startIso,
                                      ),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    startIso =
                                        CyclePredictionEngine.formatIsoDate(
                                          picked,
                                        );
                                    if (endIso.compareTo(startIso) < 0) {
                                      endIso =
                                          CyclePredictionEngine.addDaysIso(
                                            startIso,
                                            _controller
                                                    .preferences
                                                    .averagePeriodDuration -
                                                1,
                                          );
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text('Start: $startIso'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate:
                                      CyclePredictionEngine.parseIsoDate(
                                        endIso,
                                      ),
                                  firstDate:
                                      CyclePredictionEngine.parseIsoDate(
                                        startIso,
                                      ),
                                  lastDate:
                                      CyclePredictionEngine.parseIsoDate(
                                        startIso,
                                      ).add(const Duration(days: 14)),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    endIso =
                                        CyclePredictionEngine.formatIsoDate(
                                          picked,
                                        );
                                  });
                                }
                              },
                              icon: const Icon(Icons.event_available_rounded, size: 16),
                              label: Text('End: $endIso'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Typical Flow Intensity',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MenstrualCycleController.supportedFlows.map((
                          f,
                        ) {
                          return SakhiChip(
                            label: f,
                            isSelected: flow == f,
                            onTap: () => setSheetState(() => flow = f),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'Private Cycle Notes (optional)',
                          hintText:
                              'e.g., Travel week, mild cramps on Day 1–2…',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD63E85),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _controller.upsertCycle(
                            cycleId: existing?.id,
                            startDate: startIso,
                            endDate: endIso,
                            flowIntensity: flow,
                            notes: notesCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            existing == null
                                ? 'Period dates saved to your private tracker 🌸'
                                : 'Cycle entry updated.',
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          existing == null
                              ? 'Save Period Dates'
                              : 'Update Cycle Entry',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveDailyCheckIn() async {
    await _controller.upsertDailyLog(
      logDate: _selectedDateIso,
      flowIntensity: _dailyFlow,
      crampsSeverity: _dailyCramps,
      mood: _dailyMood,
      energyLevel: _dailyEnergy,
      symptoms: _dailySymptoms.toList(),
      isPmsWindow: _dailyIsPms,
      hydrationGlasses: _dailyHydration,
      sleepHours: _dailySleepHours,
      personalNotes: _dailyNotesController.text.trim(),
    );
    if (!mounted) return;
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Saved daily wellness check-in for $_selectedDateIso 🌸',
    );
  }

  void _openArticleReader(MenstrualHealthArticle article) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pastelLavender,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${article.category} • ${article.readTime}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(article.title, style: AppTypography.sectionTitle),
              const SizedBox(height: 10),
              Text(
                article.summary,
                style: AppTypography.bodyRegular.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              Text(
                'Key Takeaways',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...article.keyTakeaways.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Color(0xFFD63E85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTypography.bodyRegular.copyWith(
                            fontSize: 13.2,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFBCFE8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.medical_information_outlined,
                      color: Color(0xFFD63E85),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.clinicalNote,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.38,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Source: ${article.sourceOrganization} (${article.sourceUrl})',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportClinicalDataSheet() async {
    var includeSummary = true;
    var includeHistory = true;
    var includeSymptoms = true;
    var maxCycles = 12;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final report = _controller.generateClinicalExportReport();
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Export Personal Cycle Summary (PDF)',
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose which sections to include in your formatted PDF document before sharing with your gynecologist or saving to files:',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Cycle Summary'),
                      selected: includeSummary,
                      onSelected: (v) => setSheetState(() => includeSummary = v),
                    ),
                    FilterChip(
                      label: const Text('Period History'),
                      selected: includeHistory,
                      onSelected: (v) => setSheetState(() => includeHistory = v),
                    ),
                    FilterChip(
                      label: const Text('Symptom Logs'),
                      selected: includeSymptoms,
                      onSelected: (v) => setSheetState(() => includeSymptoms = v),
                    ),
                    ChoiceChip(
                      label: Text('Last $maxCycles cycles'),
                      selected: true,
                      onSelected: (_) => setSheetState(() {
                        maxCycles = maxCycles == 6 ? 12 : (maxCycles == 12 ? 24 : 6);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 210),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      report,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.2,
                        height: 1.38,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: report));
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Clinical summary copied to clipboard.',
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Copy Text'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                        ),
                        onPressed: () async {
                          final pdfBytes = _controller.generateClinicalSummaryPdfBytes(
                            maxCycles: maxCycles,
                            includeCycleSummary: includeSummary,
                            includeCycleHistory: includeHistory,
                            includeDailySymptoms: includeSymptoms,
                          );
                          Navigator.pop(ctx);
                          await SharePlus.instance.share(
                            ShareParams(
                              files: [
                                XFile.fromData(
                                  pdfBytes,
                                  mimeType: 'application/pdf',
                                  name: 'Sakhi_Menstrual_Cycle_Summary.pdf',
                                ),
                              ],
                              subject: 'Sakhi Menstrual Cycle Clinical Summary (PDF)',
                              text: 'Attached is my formatted Sakhi Menstrual Cycle Summary PDF.',
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                        label: const Text('Export Formatted PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAllHealthData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Menstrual Health Data?'),
        content: const Text(
          'This permanently deletes all recorded period cycles, daily symptom logs, and custom cycle preferences from both the cloud database and your device’s encrypted storage. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.deleteAllPersonalTrackingData();
    if (!mounted) return;
    _loadDailyFormForDate(_selectedDateIso);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'All personal menstrual tracking data has been permanently deleted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFDF7FA),
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD63E85), Color(0xFF7B228E)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menstrual Cycle Tracker',
                        style: AppTypography.appBarTitle.copyWith(fontSize: 17),
                      ),
                      Text(
                        'Private & Encrypted Health Vault',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10.5,
                          color: const Color(0xFFD63E85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Export Clinical Summary',
                onPressed: _exportClinicalDataSheet,
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.primaryPurple,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelColor: const Color(0xFFD63E85),
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: const Color(0xFFD63E85),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.calendar_month_rounded, size: 18),
                  text: 'Calendar',
                ),
                Tab(
                  icon: Icon(Icons.edit_calendar_rounded, size: 18),
                  text: 'Daily Log',
                ),
                Tab(
                  icon: Icon(Icons.insights_rounded, size: 18),
                  text: 'Insights',
                ),
                Tab(
                  icon: Icon(Icons.shield_moon_outlined, size: 18),
                  text: 'Care & Privacy',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCalendarAndPredictionsTab(),
              _buildDailyCheckInTab(),
              _buildHistoryAndInsightsTab(),
              _buildCareFaqsAndPrivacyTab(),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 1: CYCLE & CALENDAR
  // ===========================================================================
  Widget _buildCalendarAndPredictionsTab() {
    final p = _controller.predictions;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        14,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Phase & Next Period Estimate Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5A1868),
                  Color(0xFFA82368),
                  Color(0xFFE03E7A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29A82368),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _controller.lastSyncMessage ??
                                'Owner-Isolated Health Vault',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        p.regularityStatus,
                        style: const TextStyle(
                          color: Color(0xFFA82368),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.currentCycleDay != null && p.currentCycleDay! > 0
                                ? 'Day ${p.currentCycleDay}'
                                : 'Start',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'of ~${p.averageCycleLength}d',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.currentPhase,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.nextPeriodStart != null
                                ? (p.daysUntilNextPeriod != null &&
                                          p.daysUntilNextPeriod! >= 0
                                      ? 'Estimated next period in ${p.daysUntilNextPeriod} days (${p.nextPeriodStart})'
                                      : 'Estimated period window: ${p.nextPeriodStart} to ${p.nextPeriodEnd}')
                                : 'Tap "Log Period Dates" below to record your last period and calculate upcoming estimates.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFA82368),
                        ),
                        onPressed: () => _openPeriodLogSheet(),
                        icon: const Icon(Icons.water_drop_rounded, size: 17),
                        label: const Text(
                          'Log Period Dates',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.favorite_border_rounded, size: 17),
                        label: const Text(
                          'Log Symptoms',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Quick Window Estimates Row (Next Period, Ovulation, Fertile Window, PMS)
          Row(
            children: [
              Expanded(
                child: _EstimateMiniCard(
                  icon: Icons.calendar_today_rounded,
                  label: 'Next Period (Est.)',
                  value: p.nextPeriodStart ?? 'Log cycle',
                  sublabel: '${p.averagePeriodDuration}d avg duration',
                  accentColor: const Color(0xFFD63E85),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EstimateMiniCard(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Fertile Window (Est.)',
                  value:
                      p.fertileWindowStart != null && p.fertileWindowEnd != null
                      ? '${p.fertileWindowStart!.substring(5)} → ${p.fertileWindowEnd!.substring(5)}'
                      : _controller.preferences.fertilityTrackingEnabled
                      ? 'Log cycle'
                      : 'Hidden',
                  sublabel: p.estimatedOvulationDate != null
                      ? 'Ovulation ~${p.estimatedOvulationDate}'
                      : 'Estimate only • Not contraception',
                  accentColor: AppColors.primaryPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2B. Personal Cycle Length (24 / 26 / 28+ Days) & Reminder Lead-Time Card
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.pastelPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFFD63E85),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cycle Prediction Mode (${p.averageCycleLength} Days)',
                            style: AppTypography.cardTitle,
                          ),
                          Text(
                            p.predictionBasisLabel,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Automatic (History)'),
                        selected: !_controller.preferences.useCustomCycleLength,
                        selectedColor: AppColors.pastelLavender,
                        onSelected: (_) {
                          _controller.updatePreferences(
                            _controller.preferences.copyWith(
                              useCustomCycleLength: false,
                            ),
                          );
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Switched to Automatic history-based cycle prediction.',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Custom Cycle Length'),
                        selected: _controller.preferences.useCustomCycleLength,
                        selectedColor: AppColors.pastelPink,
                        onSelected: (_) {
                          _controller.updatePreferences(
                            _controller.preferences.copyWith(
                              useCustomCycleLength: true,
                            ),
                          );
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Switched to Custom manual cycle length (${_controller.preferences.averageCycleLength} days).',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [24, 26, 28, 30, 32].map((days) {
                    final isSelected =
                        _controller.preferences.averageCycleLength == days;
                    return SakhiChip(
                      label: '$days Days',
                      isSelected: isSelected,
                      onTap: () {
                        _controller.updatePreferences(
                          _controller.preferences.copyWith(
                            averageCycleLength: days,
                            useCustomCycleLength: true,
                          ),
                        );
                        SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Updated your personal cycle length to $days days.',
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final effectiveDays = (_draftCustomCycleDays ??
                            _controller.preferences.averageCycleLength)
                        .clamp(21, 40);
                    return Row(
                      children: [
                        const Text(
                          'Custom (21–40d):',
                          style: AppTypography.caption,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Decrease cycle length by 1 day',
                          onPressed: effectiveDays > 21
                              ? () {
                                  final next = (effectiveDays - 1).clamp(21, 40);
                                  setState(() => _draftCustomCycleDays = null);
                                  _controller.updatePreferences(
                                    _controller.preferences.copyWith(
                                      averageCycleLength: next,
                                      useCustomCycleLength: true,
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFFD63E85),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: effectiveDays.toDouble(),
                            min: 21,
                            max: 40,
                            divisions: 19,
                            label: '$effectiveDays days',
                            activeColor: const Color(0xFFD63E85),
                            onChanged: (val) {
                              setState(() {
                                _draftCustomCycleDays = val.round().clamp(21, 40);
                              });
                            },
                            onChangeEnd: (val) {
                              final committed = val.round().clamp(21, 40);
                              setState(() => _draftCustomCycleDays = null);
                              _controller.updatePreferences(
                                _controller.preferences.copyWith(
                                  averageCycleLength: committed,
                                  useCustomCycleLength: true,
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Increase cycle length by 1 day',
                          onPressed: effectiveDays < 40
                              ? () {
                                  final next = (effectiveDays + 1).clamp(21, 40);
                                  setState(() => _draftCustomCycleDays = null);
                                  _controller.updatePreferences(
                                    _controller.preferences.copyWith(
                                      averageCycleLength: next,
                                      useCustomCycleLength: true,
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFFD63E85),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${effectiveDays}d',
                            textAlign: TextAlign.end,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD63E85),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Discreet Period Reminder Lead Time:',
                        style: AppTypography.caption,
                      ),
                    ),
                    ...[1, 2, 3].map((leadDays) {
                      final active =
                          _controller.preferences.periodReminderDaysBefore ==
                          leadDays;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('${leadDays}d before'),
                          selected: active,
                          onSelected: (_) {
                            _controller.updatePreferences(
                              _controller.preferences.copyWith(
                                periodReminderDaysBefore: leadDays,
                                notificationsEnabled: true,
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Interactive Monthly Cycle Calendar
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month - 1,
                        );
                      }),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _monthYearLabel(_focusedMonth),
                        textAlign: TextAlign.center,
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _focusedMonth = DateTime(now.year, now.month);
                        });
                        _loadDailyFormForDate(
                          CyclePredictionEngine.formatIsoDate(now),
                        );
                      },
                      child: const Text('Today'),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                        );
                      }),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map(
                        (d) => Expanded(
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _buildMonthGrid(_focusedMonth),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: const [
                    _CalendarLegendDot(
                      color: Color(0xFFD63E85),
                      label: 'Logged Period',
                    ),
                    _CalendarLegendDot(
                      color: Color(0xFFFFB3D1),
                      label: 'Estimated Period',
                    ),
                    _CalendarLegendDot(
                      color: Color(0xFFD8B4FE),
                      label: 'Fertile Window (Est.)',
                    ),
                    _CalendarLegendDot(
                      color: Color(0xFFF59E0B),
                      label: 'Ovulation (Est.)',
                    ),
                    _CalendarLegendDot(
                      color: Color(0xFF0D9488),
                      label: 'Symptom Log',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Selected Date Summary & Action Bar
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected Date: $_selectedDateIso',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Check-In'),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final log = _controller.dailyLogForDate(_selectedDateIso);
                    final isPeriod = _controller.isLoggedPeriodDay(
                      _selectedDateIso,
                    );
                    final isPred = _controller.isPredictedPeriodDay(
                      _selectedDateIso,
                    );
                    final isFert = _controller.isFertileWindowDay(
                      _selectedDateIso,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isPeriod)
                              _StatusBadge(
                                label: 'Logged Period Day',
                                color: const Color(0xFFD63E85),
                              ),
                            if (!isPeriod && isPred)
                              _StatusBadge(
                                label: 'Estimated Period Window',
                                color: const Color(0xFFBE185D),
                              ),
                            if (isFert)
                              _StatusBadge(
                                label: _controller.isOvulationDay(_selectedDateIso)
                                    ? 'Estimated Ovulation Day'
                                    : 'Fertile Window Estimate',
                                color: AppColors.primaryPurple,
                              ),
                            if (log?.mood != null)
                              _StatusBadge(
                                label: 'Mood: ${log!.mood}',
                                color: const Color(0xFF0D9488),
                              ),
                            if (log != null && log.hydrationGlasses > 0)
                              _StatusBadge(
                                label: '${log.hydrationGlasses} glasses water',
                                color: const Color(0xFF0284C7),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log != null
                              ? 'Symptoms: ${log.symptoms.isEmpty ? "None" : log.symptoms.join(", ")} • Cramps: ${log.crampsSeverity ?? "None"}${log.personalNotes != null && log.personalNotes!.isNotEmpty ? "\nNote: ${log.personalNotes}" : ""}'
                              : 'No symptoms or notes logged for $_selectedDateIso yet. Tap Check-In to record flow, cramps, mood, hydration, or notes.',
                          style: AppTypography.subtitle.copyWith(fontSize: 12.4),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2C. Period Pain Help & Cramp Relief Quick Hub (Friend Review Requirement)
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.healing_rounded,
                        color: Color(0xFFBE185D),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period Pain Help & Health Articles',
                            style: AppTypography.cardTitle,
                          ),
                          const Text(
                            'Doctor-informed cramp relief: heat therapy, gentle yoga, hydration, rest & when to see a gynecologist.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _tabController.animateTo(3),
                      child: const Text('All Guides'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...sakhiMenstrualHealthArticles.take(3).map((article) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openArticleReader(article),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.primaryPurple,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.title,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${article.category} • ${article.readTime}',
                                    style: AppTypography.caption.copyWith(
                                      color: const Color(0xFFD63E85),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primaryPurple,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 5. Phase-Personalized Wellness Suggestions (SRS 9.3)
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.spa_rounded,
                      color: Color(0xFFD63E85),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Personalised Wellness Suggestions',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...p.personalizedSuggestions.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTypography.bodyRegular.copyWith(
                              fontSize: 12.8,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 6. Mandatory Medical & Contraceptive Disclaimer Banner (SRS 9.3 & 9.5)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFBCFE8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  color: Color(0xFFBE185D),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Medical & Wellness Disclaimer: Cycle, ovulation, and fertility-window predictions are mathematical estimates for informational wellness tracking only — not medical diagnoses or guarantees. Fertility estimates must NEVER be used as contraception. Consult a qualified gynecologist for medical advice.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthYearLabel(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Widget _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Mon = 0 .. Sun = 6
    final totalCells = leadingBlanks + daysInMonth;
    final todayIso = CyclePredictionEngine.formatIsoDate(DateTime.now());

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        if (index < leadingBlanks) {
          return const SizedBox.shrink();
        }
        final dayNum = index - leadingBlanks + 1;
        final iso = CyclePredictionEngine.formatIsoDate(
          DateTime(month.year, month.month, dayNum),
        );
        final isSelected = iso == _selectedDateIso;
        final isToday = iso == todayIso;
        final isLoggedPeriod = _controller.isLoggedPeriodDay(iso);
        final isPredPeriod =
            !isLoggedPeriod && _controller.isPredictedPeriodDay(iso);
        final isOvulation = _controller.isOvulationDay(iso);
        final isFertile =
            !isLoggedPeriod &&
            !isPredPeriod &&
            _controller.isFertileWindowDay(iso);
        final hasDailyLog = _controller.dailyLogForDate(iso) != null;

        Color bg = Colors.white;
        Color fg = AppColors.textPrimary;
        Border? border;

        if (isLoggedPeriod) {
          bg = const Color(0xFFD63E85);
          fg = Colors.white;
        } else if (isPredPeriod) {
          bg = const Color(0xFFFFE4F0);
          fg = const Color(0xFF9D174D);
          border = Border.all(color: const Color(0xFFF472B6), width: 1.4);
        } else if (isOvulation) {
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFF92400E);
          border = Border.all(color: const Color(0xFFF59E0B), width: 1.6);
        } else if (isFertile) {
          bg = const Color(0xFFF3E8FF);
          fg = AppColors.primaryPurple;
          border = Border.all(color: const Color(0xFFC084FC), width: 1.2);
        }

        if (isSelected) {
          border = Border.all(color: AppColors.primaryPurple, width: 2.4);
        } else if (isToday && border == null) {
          border = Border.all(color: AppColors.primaryPurple, width: 1.4);
        }

        return GestureDetector(
          onTap: () => _loadDailyFormForDate(iso),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontWeight: isSelected || isToday || isLoggedPeriod
                        ? FontWeight.w900
                        : FontWeight.w600,
                    fontSize: 12.5,
                    color: fg,
                  ),
                ),
                if (isOvulation)
                  const Positioned(
                    top: 2,
                    right: 3,
                    child: Text('✦', style: TextStyle(fontSize: 9)),
                  ),
                if (hasDailyLog)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isLoggedPeriod
                            ? Colors.white
                            : const Color(0xFF0D9488),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: DAILY LOG & SYMPTOMS
  // ===========================================================================
  Widget _buildDailyCheckInTab() {
    final existingLog = _controller.dailyLogForDate(_selectedDateIso);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        14,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SakhiCard(
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFFD63E85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logging for $_selectedDateIso',
                        style: AppTypography.cardTitle,
                      ),
                      Text(
                        'Record flow intensity, cramps, mood, energy, hydration & notes',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: CyclePredictionEngine.parseIsoDate(
                        _selectedDateIso,
                      ),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) {
                      _loadDailyFormForDate(
                        CyclePredictionEngine.formatIsoDate(picked),
                      );
                    }
                  },
                  child: const Text('Change Date'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Flow & Cramps
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flow Intensity',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      ['None', ...MenstrualCycleController.supportedFlows].map((
                        f,
                      ) {
                        return SakhiChip(
                          label: f,
                          isSelected: _dailyFlow == f,
                          onTap: () => setState(() => _dailyFlow = f),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Cramps Severity',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MenstrualCycleController.supportedCramps.map((c) {
                    return SakhiChip(
                      label: c,
                      isSelected: _dailyCramps == c,
                      onTap: () => setState(() => _dailyCramps = c),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Mood & Energy
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Today',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MenstrualCycleController.supportedMoods.map((m) {
                    return SakhiChip(
                      label: m,
                      isSelected: _dailyMood == m,
                      onTap: () => setState(() => _dailyMood = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Energy Level ($_dailyEnergy / 5)',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(5, (index) {
                        final level = index + 1;
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _dailyEnergy = level),
                          icon: Icon(
                            level <= _dailyEnergy
                                ? Icons.bolt_rounded
                                : Icons.bolt_outlined,
                            color: level <= _dailyEnergy
                                ? const Color(0xFFF59E0B)
                                : AppColors.textMuted,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Symptoms & PMS toggle
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical & Emotional Symptoms',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MenstrualCycleController.supportedSymptoms.map((s) {
                    final selected = _dailySymptoms.contains(s);
                    return SakhiChip(
                      label: s,
                      isSelected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _dailySymptoms.remove(s);
                        } else {
                          _dailySymptoms.add(s);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _dailyIsPms,
                  activeThumbColor: const Color(0xFFD63E85),
                  title: const Text(
                    'Mark as PMS Symptom Window',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: const Text(
                    'Helps track premenstrual patterns across cycles',
                    style: AppTypography.caption,
                  ),
                  onChanged: (v) => setState(() => _dailyIsPms = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Hydration, Sleep & Personal Notes
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_drink_rounded,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hydration ($_dailyHydration / 8 glasses)',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _dailyHydration > 0
                          ? () => setState(() => _dailyHydration--)
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                      ),
                      onPressed: _dailyHydration < 20
                          ? () => setState(() => _dailyHydration++)
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.bedtime_outlined,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sleep: ${_dailySleepHours.toStringAsFixed(1)} hrs',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _dailySleepHours,
                        min: 3.0,
                        max: 12.0,
                        divisions: 18,
                        activeColor: AppColors.primaryPurple,
                        onChanged: (v) => setState(() => _dailySleepHours = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dailyNotesController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Private Personal Notes',
                    hintText:
                        'Write private wellness notes, cravings, or questions for your doctor…',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (existingLog != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sosRed,
                    side: const BorderSide(color: AppColors.sosRed),
                    minimumSize: const Size(120, 50),
                  ),
                  onPressed: () async {
                    await _controller.deleteDailyLog(
                      existingLog.id,
                      _selectedDateIso,
                    );
                    if (!mounted) return;
                    _loadDailyFormForDate(_selectedDateIso);
                    SakhiDialogs.showPrototypeSnackbar(
                      context,
                      'Deleted daily entry for $_selectedDateIso.',
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD63E85),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _saveDailyCheckIn,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'Save Daily Wellness Check-In',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: HISTORY & CYCLE IRREGULARITIES
  // ===========================================================================
  Widget _buildHistoryAndInsightsTab() {
    final p = _controller.predictions;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        14,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cycle Length & Irregularity Analysis',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    _StatusBadge(
                      label: p.regularityStatus,
                      color: p.hasIrregularity
                          ? const Color(0xFFD97706)
                          : const Color(0xFF0D9488),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricBox(
                        label: 'Avg Cycle Length',
                        value: '${p.averageCycleLength} days',
                        sub: 'Typical: 21–35d',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Avg Period Duration',
                        value: '${p.averagePeriodDuration} days',
                        sub: 'Typical: 2–7d',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricBox(
                        label: 'Cycle Variation',
                        value: '${p.cycleVariationDays} days',
                        sub: p.cycleVariationDays <= 7
                            ? 'Within normal'
                            : 'Elevated shift',
                      ),
                    ),
                  ],
                ),
                if (p.hasIrregularity && p.irregularityReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p.irregularityReason!} Consider exporting your cycle summary below if you wish to discuss pattern shifts with a gynecologist.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Recorded Menstrual Cycles (${_controller.cycles.length})',
                style: AppTypography.sectionTitle.copyWith(fontSize: 16),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _openPeriodLogSheet(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add Cycle'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_controller.cycles.isEmpty)
            SakhiCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 40,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No menstrual cycles recorded yet',
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Add Cycle" to record your recent period start and end dates. You can edit or delete any entry at any time.',
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle,
                  ),
                ],
              ),
            )
          else
            ..._controller.cycles.map((cycle) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SakhiCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.pastelPink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: Color(0xFFD63E85),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cycle.startDate} → ${cycle.endDate ?? "Ongoing"}',
                              style: AppTypography.cardTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Flow: ${cycle.flowIntensity} • Duration: ${cycle.periodDurationDays ?? p.averagePeriodDuration} days${cycle.cycleLengthDays != null ? " • Cycle: ${cycle.cycleLengthDays}d" : ""}',
                              style: AppTypography.caption,
                            ),
                            if (cycle.notes != null &&
                                cycle.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                cycle.notes!,
                                style: AppTypography.bodyRegular.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit cycle entry',
                        onPressed: () => _openPeriodLogSheet(existing: cycle),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete cycle entry',
                        onPressed: () async {
                          await _controller.deleteCycle(cycle.id);
                          if (!mounted) return;
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Deleted cycle starting ${cycle.startDate}.',
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppColors.sosRed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: CARE, FAQs & PRIVACY
  // ===========================================================================
  Widget _buildCareFaqsAndPrivacyTab() {
    final prefs = _controller.preferences;
    final p = _controller.predictions;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        14,
        AppSpacing.screenPaddingH,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Privacy Guarantee & Discreet Reminders Card (SRS 9.4)
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_rounded,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reproductive Privacy & Discreet Alerts',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your menstrual logs are encrypted and strictly isolated to your account. They are never shown on your public profile, social wall, analytics, or the Web Admin Panel.',
                  style: AppTypography.caption.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: prefs.notificationsEnabled,
                  activeThumbColor: const Color(0xFFD63E85),
                  title: const Text(
                    'Enable Cycle & Wellness Reminders',
                    style: AppTypography.bodyMedium,
                  ),
                  onChanged: (v) => _controller.updatePreferences(
                    prefs.copyWith(notificationsEnabled: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: prefs.discreetNotifications,
                  activeThumbColor: const Color(0xFF0D9488),
                  title: const Text(
                    'Use Discreet Lock-Screen Wording (Default)',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: Text(
                    'Preview: "${p.discreetNotificationPreview}"',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (v) => _controller.updatePreferences(
                    prefs.copyWith(discreetNotifications: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: prefs.fertilityTrackingEnabled,
                  activeThumbColor: AppColors.primaryPurple,
                  title: const Text(
                    'Show Estimated Fertile & Ovulation Window',
                    style: AppTypography.bodyMedium,
                  ),
                  subtitle: const Text(
                    'Estimates only — never use as contraception',
                    style: AppTypography.caption,
                  ),
                  onChanged: (v) => _controller.updatePreferences(
                    prefs.copyWith(fertilityTrackingEnabled: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: prefs.pmsTrackingEnabled,
                  activeThumbColor: AppColors.primaryPurple,
                  title: const Text(
                    'Show PMS Window & Self-Care Reminders',
                    style: AppTypography.bodyMedium,
                  ),
                  onChanged: (v) => _controller.updatePreferences(
                    prefs.copyWith(pmsTrackingEnabled: v),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: prefs.hydrationReminderEnabled,
                  activeThumbColor: const Color(0xFF0284C7),
                  title: const Text(
                    'Daily Hydration & Rest Reminders',
                    style: AppTypography.bodyMedium,
                  ),
                  onChanged: (v) => _controller.updatePreferences(
                    prefs.copyWith(hydrationReminderEnabled: v),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Educational Articles (SRS 9.3)
          Text(
            'Educational Articles',
            style: AppTypography.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...sakhiMenstrualHealthArticles.map((article) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SakhiCard(
                onTap: () => _openArticleReader(article),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.pastelLavender,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(article.title, style: AppTypography.cardTitle),
                          const SizedBox(height: 3),
                          Text(
                            '${article.category} • ${article.readTime}',
                            style: AppTypography.caption.copyWith(
                              color: const Color(0xFFD63E85),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryPurple,
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // 3. Menstrual Health FAQs (SRS 9.3)
          Text(
            'Menstrual Health & Privacy FAQs',
            style: AppTypography.sectionTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          SakhiCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: sakhiMenstrualHealthFaqs.map((faq) {
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 6),
                  title: Text(
                    faq.question,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.2,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                  children: [
                    Text(
                      faq.answer,
                      style: AppTypography.bodyRegular.copyWith(
                        fontSize: 12.8,
                        height: 1.42,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // 4. Data Export & Permanent Deletion (SRS 9.2 & 9.4)
          SakhiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your Personal Health Data Controls',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  'Export your cycle history for a gynecologist consultation or permanently delete all personal tracking records at any time.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _exportClinicalDataSheet,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Export Clinical Summary & JSON Archive',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sosRed,
                    side: const BorderSide(color: AppColors.sosRed),
                  ),
                  onPressed: _confirmDeleteAllHealthData,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text(
                    'Delete All Personal Tracking Data',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateMiniCard extends StatelessWidget {
  const _EstimateMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sublabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(fontSize: 10.8),
          ),
        ],
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryPurple,
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
