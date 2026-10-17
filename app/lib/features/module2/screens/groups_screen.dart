import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../module2_models.dart';
import '../module2_state.dart';
import '../widgets/module2_feature_widgets.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _tab = 0;
  final TextEditingController _search = TextEditingController();
  bool _loading = false;

  Module2State? get _state => _stateCache;
  Module2State? _stateCache;

  @override
  void initState() {
    super.initState();
    _stateCache = _findState();
    _refresh();
  }

  Module2State? _findState() => null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = _stateCache;
    if (state == null) return;
    setState(() => _loading = true);
    await Future.wait([
      state.loadGroups(),
      state.loadGroups(mine: true),
      state.loadEvents(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return const Module2EmptyPanel(
      icon: Icons.groups_outlined,
      title: 'Group services are loading',
      message: 'The group screen requires the authenticated Module 2 state.',
    );
  }
}
