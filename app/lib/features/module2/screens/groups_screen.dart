import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../../../core/widgets/sakhi_search_field.dart';
import '../module2_models.dart';
import '../module2_scope.dart';
import '../module2_state.dart';
import '../widgets/module2_feature_widgets.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final TextEditingController _search = TextEditingController();
  Module2State? _state;
  late int _tab;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2).toInt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Module2Scope.of(context).state;
    if (!identical(_state, next)) {
      _state = next;
      _refresh();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = _state;
    if (state == null) return;
    setState(() => _loading = true);
    await Future.wait([
      state.loadGroups(query: _search.text),
      state.loadGroups(mine: true, query: _search.text),
      state.loadEvents(query: _search.text),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchData(String query) async {
    final state = _state;
    if (state == null) return;
    await Future.wait([
      state.loadGroups(query: query),
      state.loadGroups(mine: true, query: query),
      state.loadEvents(query: query),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final items = _tab == 1 ? state.myGroups : state.discoverGroups;
        return Module2PageBody(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Module2PageTitle('Groups & Events', subtitle: 'Join verified communities and take part in local events'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _tabChip('Discover', 0),
                const SizedBox(width: 8),
                _tabChip('My Groups', 1),
                const SizedBox(width: 8),
                _tabChip('Events', 2),
              ]),
            ),
            const SizedBox(height: 12),
            SakhiSearchField(
              hintText: _tab == 2 ? 'Search events...' : 'Search groups...',
              controller: _search,
              onChanged: (_) {},
              onSubmitted: _searchData,
              onClear: () {
                _search.clear();
                _searchData('');
              },
            ),
            const SizedBox(height: 12),
            if (_tab == 1)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _createGroup(context, state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create group'),
                ),
              ),
            if (_loading || state.isLoadingMembers)
              const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
            if (!_loading && _tab != 2 && items.isEmpty)
              Module2EmptyPanel(
                icon: Icons.groups_outlined,
                title: _tab == 1 ? 'You have not created or joined a group' : 'No discoverable groups yet',
                message: _tab == 1
                    ? 'Create a group for your community or join an existing verified-member group.'
                    : 'Groups appear here after members create them. Private groups are visible only to members who have a membership request or an active membership.',
                actionLabel: _tab == 1 ? 'Create group' : 'Refresh',
                onAction: _tab == 1 ? () => _createGroup(context, state) : _refresh,
              ),
            if (_tab != 2)
              ...items.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GroupCard(
                  group: group,
                  onJoin: () => _joinLeave(state, group),
                  onCreateEvent: group.isOwner ? () => _createEvent(context, state, group) : null,
                ),
              )),
            if (_tab == 2 && state.upcomingEvents.isEmpty && !_loading)
              const Module2EmptyPanel(
                icon: Icons.event_available_outlined,
                title: 'No upcoming events',
                message: 'Upcoming published events from active groups will appear here. Group owners and moderators can create an event from My Groups.',
              ),
            if (_tab == 2)
              ...state.upcomingEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventCard(
                  event: event,
                  onRegister: () async {
                    final success = await state.registerForEvent(event, register: !event.isRegistered);
                    if (mounted && !success) _message(state.errorMessage ?? 'Event registration could not be changed.');
                  },
                ),
              )),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(state.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
            ],
          ]),
        );
      },
    );
  }

  Widget _tabChip(String label, int index) => SakhiChip(
    label: label,
    isSelected: _tab == index,
    onTap: () async {
      setState(() => _tab = index);
      if (index == 2) {
        await _state?.loadEvents(query: _search.text);
      } else {
        await _state?.loadGroups(mine: index == 1, query: _search.text);
      }
    },
  );

  Future<void> _joinLeave(Module2State state, Module2Group group) async {
    final isMember = group.membershipStatus == 'ACTIVE' || group.membershipStatus == 'PENDING';
    final success = isMember
        ? await state.leaveGroup(group)
        : await state.joinGroup(group);
    if (mounted && !success) _message(state.errorMessage ?? 'Group membership could not be changed.');
  }

  Future<void> _createGroup(BuildContext context, Module2State state) async {
    final name = TextEditingController();
    final description = TextEditingController();
    var visibility = 'VERIFIED_MEMBERS';
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Create a group'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Group name *')),
              const SizedBox(height: 9),
              TextField(controller: description, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                initialValue: visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: const [
                  DropdownMenuItem(value: 'VERIFIED_MEMBERS', child: Text('Verified members')),
                  DropdownMenuItem(value: 'PRIVATE', child: Text('Private · request to join')),
                ],
                onChanged: (value) => setDialogState(() { if (value != null) visibility = value; }),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (submit == true && name.text.trim().length >= 2) {
      final success = await state.createGroup(name: name.text, description: description.text, visibility: visibility);
      if (mounted) _message(success ? 'Group created.' : (state.errorMessage ?? 'Group could not be created.'));
      if (success) setState(() => _tab = 1);
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _createEvent(BuildContext context, Module2State state, Module2Group group) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final city = TextEditingController();
    DateTime startsAt = DateTime.now().add(const Duration(days: 2));
    DateTime endsAt = DateTime.now().add(const Duration(days: 2, hours: 1));
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Create event · ${group.name}'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 160, decoration: const InputDecoration(labelText: 'Event title *')),
              const SizedBox(height: 8),
              TextField(controller: description, maxLength: 3000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 8),
              TextField(controller: city, maxLength: 100, decoration: const InputDecoration(labelText: 'City / general location (optional)')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starts'),
                subtitle: Text(startsAt.toLocal().toString().split('.').first),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: startsAt, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
                  if (time == null) return;
                  setDialogState(() => startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  if (!endsAt.isAfter(startsAt)) setDialogState(() => endsAt = startsAt.add(const Duration(hours: 1)));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ends'),
                subtitle: Text(endsAt.toLocal().toString().split('.').first),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: endsAt, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endsAt));
                  if (time == null) return;
                  setDialogState(() => endsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Publish event')),
          ],
        ),
      ),
    );
    if (submit == true) {
      final success = await state.createEvent(
        groupId: group.id,
        title: title.text,
        description: description.text,
        locationCity: city.text,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      if (mounted) _message(success ? 'Event published.' : (state.errorMessage ?? 'Event could not be published.'));
      if (success) setState(() => _tab = 2);
    }
    title.dispose();
    description.dispose();
    city.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onJoin, required this.onCreateEvent});

  final Module2Group group;
  final VoidCallback onJoin;
  final VoidCallback? onCreateEvent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.borderSubtle)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 43, height: 43, decoration: const BoxDecoration(color: AppColors.pastelLavender, shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: AppColors.primaryPurple)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(group.name, style: AppTypography.cardTitle),
          const SizedBox(height: 2),
          Text('${group.memberCount} members · ${group.visibility == 'PRIVATE' ? 'Private' : 'Verified members'}', style: AppTypography.subtitle),
        ])),
      ]),
      if ((group.description ?? '').isNotEmpty) ...[
        const SizedBox(height: 9),
        Text(group.description!, style: AppTypography.bodyRegular.copyWith(fontSize: 13)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(group.membershipStatus == 'PENDING' ? 'Membership request pending' : (group.isOwner ? 'You own this group' : '${group.upcomingEventsCount} upcoming events'), style: AppTypography.subtitle)),
        if (onCreateEvent != null)
          TextButton(onPressed: onCreateEvent, child: const Text('Create event')),
        const SizedBox(width: 5),
        OutlinedButton(
          onPressed: onJoin,
          child: Text(
            group.isOwner
                ? 'Archive'
                : group.membershipStatus == 'PENDING'
                    ? 'Cancel request'
                    : group.membershipStatus == 'ACTIVE'
                        ? 'Leave'
                        : 'Join',
          ),
        ),
      ]),
    ]),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onRegister});

  final Module2Event event;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final start = event.startsAt?.toLocal();
    final timeLabel = start == null ? 'Upcoming' : '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year} · ${TimeOfDay.fromDateTime(start).format(context)}';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.pastelPeach, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.event_available_rounded, color: AppColors.amberAccent)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, style: AppTypography.cardTitle),
            Text(event.groupName, style: AppTypography.subtitle),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(timeLabel, style: AppTypography.subtitle),
        if (event.locationCity?.isNotEmpty == true) Text(event.locationCity!, style: AppTypography.subtitle),
        const SizedBox(height: 7),
        Text(event.description, style: AppTypography.bodyRegular.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('${event.registrationCount} registered', style: AppTypography.subtitle)),
          OutlinedButton(onPressed: onRegister, child: Text(event.isRegistered ? 'Cancel registration' : 'Register')),
        ]),
      ]),
    );
  }
}
