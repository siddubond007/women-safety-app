import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';

class BusinessPageModel {
  const BusinessPageModel({
    required this.id,
    required this.businessName,
    required this.category,
    required this.city,
    required this.priceRange,
    required this.description,
    required this.ownerDisplayName,
    required this.serviceArea,
    required this.isSaved,
    required this.isOwnBusiness,
    required this.isVerifiedWomanOwned,
    required this.approvalStatus,
    required this.savesCount,
    required this.enquiriesCount,
    required this.productsServices,
    this.businessCode = '',
    this.contactPhone,
    this.contactPhoneMasked,
    this.whatsappNumber,
    this.instagramHandle,
    this.websiteOrInstagram,
    this.distanceKm,
  });

  final String id;
  final String businessCode;
  final String businessName;
  final String category;
  final String city;
  final String priceRange;
  final String description;
  final String ownerDisplayName;
  final String serviceArea;
  final bool isSaved;
  final bool isOwnBusiness;
  final bool isVerifiedWomanOwned;
  final String approvalStatus;
  final int savesCount;
  final int enquiriesCount;
  final List<Map<String, dynamic>> productsServices;
  final String? contactPhone;
  final String? contactPhoneMasked;
  final String? whatsappNumber;
  final String? instagramHandle;
  final String? websiteOrInstagram;
  final double? distanceKm;

  bool get needsReview => approvalStatus.toUpperCase() == 'PENDING_APPROVAL';

  factory BusinessPageModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productsServices'];

    int countValue(Object? value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    double? distanceValue(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    return BusinessPageModel(
      id: (json['id'] ?? json['businessId'] ?? '').toString(),
      businessCode: (json['businessCode'] ?? '').toString(),
      businessName: (json['businessName'] ?? json['name'] ?? 'Business')
          .toString(),
      category: (json['category'] ?? 'Other').toString(),
      city: (json['city'] ?? '').toString(),
      priceRange: (json['priceRange'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      ownerDisplayName: (json['ownerDisplayName'] ?? 'Sakhi Entrepreneur')
          .toString(),
      serviceArea: (json['serviceArea'] ?? json['city'] ?? '').toString(),
      isSaved: json['isSaved'] == true,
      isOwnBusiness: json['isOwnBusiness'] == true || json['isOwner'] == true,
      isVerifiedWomanOwned:
          json['isVerifiedWomanOwned'] == true ||
          json['verificationBadgeStatus'] == 'VERIFIED_WOMAN_OWNED',
      approvalStatus: (json['approvalStatus'] ?? 'PENDING_APPROVAL').toString(),
      savesCount: countValue(json['savesCount']),
      enquiriesCount: countValue(json['enquiriesCount']),
      productsServices: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList()
          : const <Map<String, dynamic>>[],
      contactPhone: json['contactPhone']?.toString(),
      contactPhoneMasked: json['contactPhoneMasked']?.toString(),
      whatsappNumber: json['whatsappNumber']?.toString(),
      instagramHandle: json['instagramHandle']?.toString(),
      websiteOrInstagram: json['websiteOrInstagram']?.toString(),
      distanceKm: distanceValue(json['distanceKm']),
    );
  }
}

class WomenBusinessHubScreen extends StatefulWidget {
  const WomenBusinessHubScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  State<WomenBusinessHubScreen> createState() => _WomenBusinessHubScreenState();
}

class _WomenBusinessHubScreenState extends State<WomenBusinessHubScreen> {
  final _state = SakhiPrototypeState.instance;
  final _search = TextEditingController();
  List<BusinessPageModel> _items = const [];
  String _category = 'All';
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner && mounted) setState(() => _loading = true);
    final signedIn = await _state.hasAuthenticatedSession();
    final rows = await _state.fetchBusinesses(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      category: _category,
    );
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _items = rows.map(BusinessPageModel.fromJson).toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (!_signedIn) {
      _message('Sign in through Sakhi before creating a business page.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BusinessRegistrationWizardScreen(),
      ),
    );
    await _load();
  }

  Future<void> _inbox() async {
    if (!_signedIn) {
      _message('Sign in to view business enquiries.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BusinessEnquiryInboxScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'All',
      ..._state.cachedBusinessCategories,
    }.toList();
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Women-Owned Businesses'),
        backgroundColor: AppColors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        leading: widget.showBackButton
            ? IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _inbox,
            tooltip: 'Enquiries',
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            onPressed: _create,
            tooltip: 'Create business page',
            icon: const Icon(Icons.add_business_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.businessLuxuryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    size: 34,
                    color: AppColors.businessPlum,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Discover women-led businesses',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.businessPlum,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Browse public listings, products and services, then contact businesses directly. New pages stay private until reviewed.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search business, service or city',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: categories.contains(_category) ? _category : 'All',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() => _category = value ?? 'All');
                _load();
              },
            ),
            const SizedBox(height: 16),
            Text(
              _loading
                  ? 'Loading businesses…'
                  : '${_items.length} public listings',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const _BusinessEmpty(
                title: 'No public listings yet',
                message: 'Try a different search. New pages appear after administrator approval.',
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BusinessCard(
                    item: item,
                    onSave: _signedIn
                        ? () async {
                            await _state.toggleSaveBusiness(item.id);
                            await _load(spinner: false);
                          }
                        : () => _message('Sign in to save a listing.'),
                    onTap: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => BusinessProfileDetailScreen(
                              businessId: item.id,
                              initialModel: item,
                            ),
                          ),
                        )
                        .then((_) => _load(spinner: false)),
                  ),
                ),
              ),
            if (!_signedIn)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Public browsing is available without sign-in. Saving, enquiries and registration require a Sakhi account.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BusinessProfileDetailScreen extends StatefulWidget {
  const BusinessProfileDetailScreen({
    super.key,
    required this.businessId,
    this.initialModel,
  });
  final String businessId;
  final BusinessPageModel? initialModel;

  @override
  State<BusinessProfileDetailScreen> createState() =>
      _BusinessProfileDetailScreenState();
}

class _BusinessProfileDetailScreenState
    extends State<BusinessProfileDetailScreen> {
  final _state = SakhiPrototypeState.instance;
  BusinessPageModel? _item;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initialModel;
    _load();
  }

  Future<void> _load() async {
    final data = await _state.fetchBusinessDetail(widget.businessId);
    if (mounted && data != null) {
      setState(() => _item = BusinessPageModel.fromJson(data));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _enquire() async {
    final hasSession = await _state.hasAuthenticatedSession();
    if (!mounted) return;
    if (!hasSession) {
      _message('Sign in through Sakhi before sending an enquiry.');
      return;
    }
    final subject = TextEditingController();
    final message = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send business enquiry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subject,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Subject or product (optional)',
                ),
              ),
              TextField(
                controller: message,
                minLines: 3,
                maxLines: 6,
                maxLength: 1500,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (!mounted || submit != true) {
      subject.dispose();
      message.dispose();
      return;
    }
    final messageText = message.text.trim();
    final subjectText = subject.text.trim();
    subject.dispose();
    message.dispose();
    if (messageText.length < 2) {
      _message('Enter a message of at least two characters.');
      return;
    }
    final result = await _state.submitBusinessEnquiry(
      businessId: widget.businessId,
      message: messageText,
      subjectOrProduct: subjectText,
    );
    if (!mounted) return;
    _message(
      result == null
          ? 'Enquiry could not be saved. Please retry.'
          : 'Enquiry sent.',
    );
  }

  Future<void> _report() async {
    final hasSession = await _state.hasAuthenticatedSession();
    if (!mounted) return;
    if (!hasSession) {
      _message('Sign in to report a listing.');
      return;
    }
    final reason = TextEditingController();
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this listing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reason,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              TextField(
                controller: details,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Additional detail (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    );
    if (!mounted) {
      reason.dispose();
      details.dispose();
      return;
    }
    final why = reason.text.trim();
    final detail = details.text.trim();
    reason.dispose();
    details.dispose();
    if (submit != true) return;
    if (why.length < 3) {
      _message('Give a report reason of at least three characters.');
      return;
    }
    final ok = await _state.reportBusinessListing(
      businessId: widget.businessId,
      reason: why,
      details: detail,
    );
    if (!mounted) return;
    _message(
      ok ? 'Report submitted to Trust & Safety.' : 'Report could not be sent.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Business details'),
        backgroundColor: AppColors.scaffoldBackground,
        actions: [
          IconButton(
            onPressed: _report,
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report',
          ),
        ],
      ),
      body: item == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.businessLuxuryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 32,
                        color: AppColors.businessPlum,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.businessName,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: AppColors.businessPlum,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.category} • ${item.city}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Owner: ${item.ownerDisplayName}'),
                      if (item.distanceKm != null)
                        Text('${item.distanceKm!.toStringAsFixed(1)} km away'),
                      if (item.isVerifiedWomanOwned)
                        const Chip(
                          label: Text('Verified women-owned'),
                          avatar: Icon(
                            Icons.verified,
                            color: AppColors.verifiedGreenText,
                          ),
                        ),
                      if (item.needsReview && item.isOwnBusiness)
                        const Text(
                          'Your page is awaiting administrator review.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _BusinessDetailCard(
                  title: 'About',
                  child: Text(
                    item.description.isEmpty
                        ? 'No description provided.'
                        : item.description,
                  ),
                ),
                _BusinessDetailCard(
                  title: 'Service area and price',
                  child: Text(
                    'Area: ${item.serviceArea.isEmpty ? item.city : item.serviceArea}\nPrice: ${item.priceRange.isEmpty ? 'Not specified' : item.priceRange}',
                  ),
                ),
                if (item.productsServices.isNotEmpty)
                  _BusinessDetailCard(
                    title: 'Products and services',
                    child: Column(
                      children: item.productsServices
                          .map(
                            (p) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.businessPlum,
                              ),
                              title: Text(
                                (p['title'] ?? p['name'] ?? 'Service')
                                    .toString(),
                              ),
                              subtitle: Text(
                                (p['description'] ?? '').toString(),
                              ),
                              trailing: p['price'] == null
                                  ? null
                                  : Text(p['price'].toString()),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                _BusinessDetailCard(
                  title: 'Contact',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.contactPhone != null)
                        Text('Phone: ${item.contactPhone}'),
                      if (item.contactPhone == null &&
                          item.contactPhoneMasked != null)
                        Text('Phone: ${item.contactPhoneMasked}'),
                      if (item.whatsappNumber != null)
                        Text('WhatsApp: ${item.whatsappNumber}'),
                      if (item.instagramHandle != null)
                        Text('Instagram: ${item.instagramHandle}'),
                      if (item.websiteOrInstagram != null)
                        Text('Website / social: ${item.websiteOrInstagram}'),
                      if (item.contactPhone == null &&
                          item.whatsappNumber == null &&
                          item.instagramHandle == null &&
                          item.websiteOrInstagram == null)
                        const Text(
                          'No public contact details. Send an enquiry to start a conversation.',
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await _state.toggleSaveBusiness(item.id);
                                await _load();
                                if (mounted) setState(() => _busy = false);
                              },
                        icon: Icon(
                          item.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        label: Text(item.isSaved ? 'Saved' : 'Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _enquire,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Enquire'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.businessPlum,
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

class BusinessRegistrationWizardScreen extends StatefulWidget {
  const BusinessRegistrationWizardScreen({super.key});

  @override
  State<BusinessRegistrationWizardScreen> createState() =>
      _BusinessRegistrationWizardScreenState();
}

class _BusinessRegistrationWizardScreenState
    extends State<BusinessRegistrationWizardScreen> {
  final _state = SakhiPrototypeState.instance;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _website = TextEditingController();
  String _category = 'Fashion and clothing';
  String? _businessId;
  bool _loading = true;
  bool _saving = false;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _area.dispose();
    _description.dispose();
    _price.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final signedIn = await _state.hasAuthenticatedSession();
    Map<String, dynamic>? business;
    if (signedIn) {
      final records = await _state.fetchBusinesses(ownerOnly: true);
      business = records.isNotEmpty ? records.first : _state.myBusinessPage;
    }
    if (!mounted) return;
    if (business != null) {
      _businessId = business['id']?.toString();
      _name.text = (business['businessName'] ?? '').toString();
      _city.text = (business['city'] ?? '').toString();
      _area.text = (business['serviceArea'] ?? '').toString();
      _description.text = (business['description'] ?? '').toString();
      _price.text = (business['priceRange'] ?? '').toString();
      _phone.text = (business['contactPhone'] ?? '').toString();
      _whatsapp.text = (business['whatsappNumber'] ?? '').toString();
      _instagram.text = (business['instagramHandle'] ?? '').toString();
      _website.text = (business['websiteOrInstagram'] ?? '').toString();
      if (_state.cachedBusinessCategories.contains(business['category'])) {
        _category = business['category'].toString();
      }
    }
    setState(() {
      _signedIn = signedIn;
      _loading = false;
    });
  }

  String? _required(String? value, {int minimum = 2}) {
    if ((value ?? '').trim().length < minimum) {
      return 'Enter at least $minimum characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final hasSession = await _state.hasAuthenticatedSession();
    if (!mounted) return;
    if (!hasSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in before submitting a business page.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'businessName': _name.text.trim(),
      'category': _category,
      'city': _city.text.trim(),
      'serviceArea': _area.text.trim().isEmpty
          ? _city.text.trim()
          : _area.text.trim(),
      'description': _description.text.trim(),
      if (_price.text.trim().isNotEmpty) 'priceRange': _price.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'contactPhone': _phone.text.trim(),
      if (_whatsapp.text.trim().isNotEmpty)
        'whatsappNumber': _whatsapp.text.trim(),
      if (_instagram.text.trim().isNotEmpty)
        'instagramHandle': _instagram.text.trim(),
      if (_website.text.trim().isNotEmpty)
        'websiteOrInstagram': _website.text.trim(),
      'hidePhoneNumber': false,
    };
    final result = await _state.createOrUpdateBusiness(
      data,
      businessId: _businessId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The page could not be saved. Check your connection and retry.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Business page saved. It will be visible to everyone after administrator approval.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _state.cachedBusinessCategories;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          _businessId == null ? 'Create business page' : 'Edit business page',
        ),
        backgroundColor: AppColors.scaffoldBackground,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_signedIn
          ? const _BusinessEmpty(
              title: 'Sign-in required',
              message: 'A business page belongs to an authenticated Sakhi member account. Sign in to the hosted service, then return here.',
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'New listings stay private until reviewed by an administrator.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    maxLength: 160,
                    validator: _required,
                    decoration: const InputDecoration(
                      labelText: 'Business name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(_category)
                        ? _category
                        : categories.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? categories.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _city,
                    maxLength: 80,
                    validator: _required,
                    decoration: const InputDecoration(
                      labelText: 'City / base location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _area,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Service area (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    validator: (v) => _required(v, minimum: 5),
                    decoration: const InputDecoration(
                      labelText: 'About your business',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _price,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Price range (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Contact phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _whatsapp,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp number (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instagram,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Instagram handle (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'Website or social link (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : (_businessId == null
                                ? 'Submit for review'
                                : 'Save changes'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.businessPlum,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class BusinessEnquiryInboxScreen extends StatefulWidget {
  const BusinessEnquiryInboxScreen({super.key});

  @override
  State<BusinessEnquiryInboxScreen> createState() =>
      _BusinessEnquiryInboxScreenState();
}

class _BusinessEnquiryInboxScreenState
    extends State<BusinessEnquiryInboxScreen> {
  final _state = SakhiPrototypeState.instance;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner && mounted) setState(() => _loading = true);
    final signedIn = await _state.hasAuthenticatedSession();
    final rows = signedIn
        ? await _state.fetchBusinessEnquiries()
        : <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BusinessEnquiryThread(enquiry: row),
    );
    if (changed == true) await _load(spinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Business enquiries'),
        backgroundColor: AppColors.scaffoldBackground,
        actions: [
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_signedIn
          ? const _BusinessEmpty(
              title: 'Sign-in required',
              message: 'Your enquiry inbox is private to your Sakhi account.',
            )
          : _rows.isEmpty
          ? const _BusinessEmpty(
              title: 'No enquiries yet',
              message: 'Enquiries you send or receive from a business page will appear here.',
            )
          : RefreshIndicator(
              onRefresh: () => _load(spinner: false),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final rawMessages = row['messages'];
                  final messages = rawMessages is List ? rawMessages : const [];
                  final latest = messages.isNotEmpty && messages.last is Map
                      ? messages.last as Map
                      : const <String, dynamic>{};
                  final label = (row['subjectOrProduct'] ?? 'Business enquiry')
                      .toString();
                  final business = (row['businessName'] ?? 'Business')
                      .toString();
                  final status = (row['status'] ?? 'OPEN').toString();
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.businessChampagneBg,
                        child: Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.businessPlum,
                        ),
                      ),
                      title: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '$business • $status\n${(latest['body'] ?? '').toString()}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(row),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _BusinessEnquiryThread extends StatefulWidget {
  const _BusinessEnquiryThread({required this.enquiry});
  final Map<String, dynamic> enquiry;

  @override
  State<_BusinessEnquiryThread> createState() => _BusinessEnquiryThreadState();
}

class _BusinessEnquiryThreadState extends State<_BusinessEnquiryThread> {
  final _state = SakhiPrototypeState.instance;
  final _reply = TextEditingController();
  late Map<String, dynamic> _row;
  bool _sending = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _row = Map<String, dynamic>.from(widget.enquiry);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final updated = await _state.replyToBusinessEnquiry(
      enquiryId: (_row['id'] ?? '').toString(),
      message: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply could not be saved.')),
      );
      return;
    }
    _reply.clear();
    setState(() {
      _row = updated;
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = _row['messages'];
    final messages = raw is List
        ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, inset + 16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_row['subjectOrProduct'] ?? 'Business enquiry').toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              (_row['businessName'] ?? 'Business').toString(),
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final isOwner = m['senderRole'] == 'BUSINESS_OWNER';
                  return Align(
                    alignment: isOwner
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? AppColors.pastelLavender
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (m['senderName'] ?? 'Sakhi Member').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text((m['body'] ?? '').toString()),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.businessPlum,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context, _changed),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.item,
    required this.onTap,
    required this.onSave,
  });
  final BusinessPageModel item;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final location = item.serviceArea.isEmpty ? item.city : item.serviceArea;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        leading: const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.businessChampagneBg,
          child: Icon(Icons.storefront_rounded, color: AppColors.businessPlum),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.businessName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (item.isVerifiedWomanOwned)
              const Icon(
                Icons.verified,
                size: 16,
                color: AppColors.verifiedGreenText,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${item.category} • $location\n${item.priceRange} • ${item.savesCount} saves',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: onSave,
          tooltip: item.isSaved ? 'Unsave' : 'Save',
          icon: Icon(
            item.isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: AppColors.businessPlum,
          ),
        ),
      ),
    );
  }
}

class _BusinessDetailCard extends StatelessWidget {
  const _BusinessDetailCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.businessPlum,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _BusinessEmpty extends StatelessWidget {
  const _BusinessEmpty({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 44,
              color: AppColors.businessPlum,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
