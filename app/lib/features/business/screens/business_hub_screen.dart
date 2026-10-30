import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_remote_media_image.dart';

const MethodChannel _kSakhiNativeChannel = MethodChannel('sakhi/native_actions');

Future<void> _launchWhatsAppNative({
  required BuildContext context,
  required String phone,
  required String message,
  required bool preferBusiness,
}) async {
  try {
    final ok = await _kSakhiNativeChannel.invokeMethod<bool>(
      'openWhatsAppChat',
      <String, dynamic>{
        'phone': phone,
        'message': message,
        'preferBusiness': preferBusiness,
      },
    );
    if (ok == true) return;
  } catch (_) {}

  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) digits = '91$digits';
  final encoded = Uri.encodeComponent(message);
  final fallbackUrl = digits.isNotEmpty
      ? 'https://api.whatsapp.com/send?phone=$digits&text=$encoded'
      : 'https://api.whatsapp.com/send?text=$encoded';
  try {
    final launched = await _kSakhiNativeChannel.invokeMethod<bool>(
      'openExternalUrl',
      <String, dynamic>{'url': fallbackUrl},
    );
    if (launched == true) return;
  } catch (_) {}

  try {
    await SharePlus.instance.share(ShareParams(text: '$message\n$fallbackUrl'));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: fallbackUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp link copied to clipboard.'),
        ),
      );
    }
  }
}

Future<void> _launchPhoneDialer(BuildContext context, String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return;
  try {
    await _kSakhiNativeChannel.invokeMethod<bool>(
      'dialNumber',
      <String, dynamic>{'number': cleaned},
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: cleaned));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number $cleaned copied to clipboard.')),
      );
    }
  }
}

Future<void> _launchExternalWebUrl(BuildContext context, String rawUrl) async {
  var url = rawUrl.trim();
  if (url.isEmpty) return;
  if (url.startsWith('@')) {
    url = 'https://instagram.com/${url.substring(1)}';
  } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
    if (url.contains('instagram.com') || url.contains('.')) {
      url = 'https://$url';
    } else {
      url = 'https://instagram.com/$url';
    }
  }
  try {
    await _kSakhiNativeChannel.invokeMethod<bool>(
      'openExternalUrl',
      <String, dynamic>{'url': url},
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link copied: $url')),
      );
    }
  }
}

Widget _buildBusinessMediaImage(
  String? source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  String fallbackAsset = AppAssets.businessArtisanStudio,
}) {
  final s = (source ?? '').trim();
  if (s.isEmpty) {
    return Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => Container(
        width: width,
        height: height,
        color: AppColors.businessChampagneBg,
        child: const Icon(
          Icons.storefront_rounded,
          color: AppColors.businessPlum,
          size: 32,
        ),
      ),
    );
  }
  final isRemote = s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('/api/v1/');
  if (isRemote) {
    return SakhiRemoteMediaImage(
      source: s,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => Image.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
  return Image.asset(
    s,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: fit,
    ),
  );
}

/// Curated boutique photography presets for entrepreneurs who want instant studio visuals.
const List<Map<String, String>> _kBoutiquePhotoPresets = <Map<String, String>>[
  {
    'label': 'Artisan Studio',
    'asset': AppAssets.businessArtisanStudio,
  },
  {
    'label': 'Community Hub',
    'asset': AppAssets.communityCircleGathering,
  },
  {
    'label': 'Wellness & Spa',
    'asset': AppAssets.wellnessMorningJournal,
  },
  {
    'label': 'Education & Coaching',
    'asset': AppAssets.educationCareerHubBanner,
  },
  {
    'label': 'Mindful Living',
    'asset': AppAssets.dailyRitualBreathingThumb,
  },
  {
    'label': 'Sunset Collection',
    'asset': AppAssets.eveningWalkSunset,
  },
];

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
    this.ownerAccountId,
    this.logoAsset,
    this.coverImage,
    this.mediaGallery = const <String>[],
    this.businessHours = const <String, dynamic>{},
    this.offersAndPosts = const <Map<String, dynamic>>[],
    this.contactPhone,
    this.contactPhoneMasked,
    this.hasPhoneConfigured = false,
    this.hidePhoneNumber = false,
    this.whatsappNumber,
    this.instagramHandle,
    this.websiteOrInstagram,
    this.distanceKm,
    this.verificationBadgeStatus = 'NONE',
    this.isFeatured = false,
    this.viewsCount = 0,
    this.reviewNotes,
  });

  final String id;
  final String businessCode;
  final String businessName;
  final String? ownerAccountId;
  final String category;
  final String city;
  final String priceRange;
  final String description;
  final String ownerDisplayName;
  final String serviceArea;
  final String? logoAsset;
  final String? coverImage;
  final List<String> mediaGallery;
  final Map<String, dynamic> businessHours;
  final List<Map<String, dynamic>> offersAndPosts;
  final bool isSaved;
  final bool isOwnBusiness;
  final bool isVerifiedWomanOwned;
  final String approvalStatus;
  final String verificationBadgeStatus;
  final bool isFeatured;
  final int savesCount;
  final int enquiriesCount;
  final int viewsCount;
  final List<Map<String, dynamic>> productsServices;
  final String? contactPhone;
  final String? contactPhoneMasked;
  final bool hasPhoneConfigured;
  final bool hidePhoneNumber;
  final String? whatsappNumber;
  final String? instagramHandle;
  final String? websiteOrInstagram;
  final double? distanceKm;
  final String? reviewNotes;

  bool get needsReview => approvalStatus.toUpperCase() == 'PENDING_APPROVAL';
  bool get isApproved =>
      approvalStatus.toUpperCase() == 'APPROVED' ||
      approvalStatus.toUpperCase() == 'VERIFIED';
  bool get isRejected => approvalStatus.toUpperCase() == 'REJECTED';
  bool get isSuspended => approvalStatus.toUpperCase() == 'SUSPENDED';

  bool get isOpenNow {
    final flag = businessHours['isOpenNow'];
    if (flag is bool) return flag;
    return true;
  }

  List<String> get allShowcaseImages {
    final result = <String>[];
    if (coverImage != null && coverImage!.trim().isNotEmpty) {
      result.add(coverImage!.trim());
    }
    for (final img in mediaGallery) {
      final clean = img.trim();
      if (clean.isNotEmpty && !result.contains(clean)) {
        result.add(clean);
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'businessCode': businessCode,
      'businessName': businessName,
      'ownerAccountId': ownerAccountId,
      'ownerDisplayName': ownerDisplayName,
      'category': category,
      'city': city,
      'serviceArea': serviceArea,
      'priceRange': priceRange,
      'description': description,
      'logoAsset': logoAsset,
      'coverImage': coverImage,
      'mediaGallery': mediaGallery,
      'businessHours': businessHours,
      'productsServices': productsServices,
      'offersAndPosts': offersAndPosts,
      'contactPhone': contactPhone,
      'contactPhoneMasked': contactPhoneMasked,
      'hasPhoneConfigured': hasPhoneConfigured,
      'hidePhoneNumber': hidePhoneNumber,
      'whatsappNumber': whatsappNumber,
      'instagramHandle': instagramHandle,
      'websiteOrInstagram': websiteOrInstagram,
      'isSaved': isSaved,
      'isOwnBusiness': isOwnBusiness,
      'isVerifiedWomanOwned': isVerifiedWomanOwned,
      'approvalStatus': approvalStatus,
      'verificationBadgeStatus': verificationBadgeStatus,
      'isFeatured': isFeatured,
      'savesCount': savesCount,
      'enquiriesCount': enquiriesCount,
      'viewsCount': viewsCount,
      'reviewNotes': reviewNotes,
    };
  }

  factory BusinessPageModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['productsServices'];
    final rawGallery = json['mediaGallery'];
    final rawOffers = json['offersAndPosts'];
    final rawHours = json['businessHours'];

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
      ownerAccountId: json['ownerAccountId']?.toString(),
      category: (json['category'] ?? 'Other').toString(),
      city: (json['city'] ?? '').toString(),
      priceRange: (json['priceRange'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      ownerDisplayName: (json['ownerDisplayName'] ?? 'Sakhi Entrepreneur')
          .toString(),
      serviceArea: (json['serviceArea'] ?? json['city'] ?? '').toString(),
      logoAsset: json['logoAsset']?.toString(),
      coverImage: json['coverImage']?.toString(),
      mediaGallery: rawGallery is List
          ? rawGallery
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      businessHours: rawHours is Map
          ? Map<String, dynamic>.from(rawHours)
          : const <String, dynamic>{},
      offersAndPosts: rawOffers is List
          ? rawOffers
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      isSaved: json['isSaved'] == true,
      isOwnBusiness: json['isOwnBusiness'] == true || json['isOwner'] == true,
      isVerifiedWomanOwned:
          json['isVerifiedWomanOwned'] == true ||
          json['verificationBadgeStatus'] == 'VERIFIED_WOMAN_OWNED',
      approvalStatus: (json['approvalStatus'] ?? 'PENDING_APPROVAL').toString(),
      verificationBadgeStatus:
          (json['verificationBadgeStatus'] ?? 'NONE').toString(),
      isFeatured: json['isFeatured'] == true,
      savesCount: countValue(json['savesCount']),
      enquiriesCount: countValue(json['enquiriesCount']),
      viewsCount: countValue(json['viewsCount']),
      productsServices: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .toList()
          : const <Map<String, dynamic>>[],
      contactPhone: json['contactPhone']?.toString(),
      contactPhoneMasked: json['contactPhoneMasked']?.toString(),
      hasPhoneConfigured: json['hasPhoneConfigured'] == true ||
          json['contactPhone'] != null ||
          json['contactPhoneMasked'] != null,
      hidePhoneNumber: json['hidePhoneNumber'] == true,
      whatsappNumber: json['whatsappNumber']?.toString(),
      instagramHandle: json['instagramHandle']?.toString(),
      websiteOrInstagram: json['websiteOrInstagram']?.toString(),
      distanceKm: distanceValue(json['distanceKm']),
      reviewNotes: json['reviewNotes']?.toString(),
    );
  }
}

/// WhatsApp / WhatsApp Business iOS 26 Liquid Glass Confirmation Bottom Sheet.
Future<void> showSakhiWhatsAppConfirmationSheet({
  required BuildContext context,
  required String recipientTitle,
  required String phoneOrWhatsapp,
  String? subtitle,
  String? initialMessage,
}) async {
  final msgCtrl = TextEditingController(
    text: initialMessage ??
        'Namaste! I discovered $recipientTitle on the Sakhi Women-Owned Business Directory and would love to enquire about your offerings.',
  );
  bool preferBusiness = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final inset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.94),
                        const Color(0xFFF3FBF6).withValues(alpha: 0.92),
                        const Color(0xFFFDF5FA).withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.96),
                      width: 1.5,
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: AppColors.textMuted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF25D366),
                                    Color(0xFF128C7E),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33128C7E),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Connect on WhatsApp',
                                    style: AppTypography.sectionTitle.copyWith(
                                      fontSize: 17.5,
                                    ),
                                  ),
                                  Text(
                                    subtitle ?? '$recipientTitle • $phoneOrWhatsapp',
                                    style: AppTypography.subtitle.copyWith(
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CHOOSE WHATSAPP APPLICATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    setSheetState(() => preferBusiness = false),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: !preferBusiness
                                        ? const Color(0xFFE7F9EE)
                                        : Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: !preferBusiness
                                          ? const Color(0xFF128C7E)
                                          : AppColors.borderSubtle,
                                      width: !preferBusiness ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_rounded,
                                        color: !preferBusiness
                                            ? const Color(0xFF128C7E)
                                            : AppColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'WhatsApp',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Personal Messenger',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    setSheetState(() => preferBusiness = true),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: preferBusiness
                                        ? const Color(0xFFE7F9EE)
                                        : Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: preferBusiness
                                          ? const Color(0xFF128C7E)
                                          : AppColors.borderSubtle,
                                      width: preferBusiness ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.storefront_rounded,
                                        color: preferBusiness
                                            ? const Color(0xFF128C7E)
                                            : AppColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'WA Business',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Business Account',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'PRE-FILLED INQUIRY MESSAGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: msgCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final text = msgCtrl.text.trim();
                                  Navigator.pop(sheetCtx);
                                  await _launchWhatsAppNative(
                                    context: context,
                                    phone: phoneOrWhatsapp,
                                    message: text,
                                    preferBusiness: preferBusiness,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF128C7E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Continue to WhatsApp ›',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class WomenBusinessHubScreen extends StatefulWidget {
  const WomenBusinessHubScreen({
    super.key,
    this.showBackButton = false,
    this.onBackTap,
    this.initialViewIndex = 0,
  });

  final bool showBackButton;
  final VoidCallback? onBackTap;
  final int initialViewIndex; // 0: Public Marketplace, 1: My Business Pages

  @override
  State<WomenBusinessHubScreen> createState() => _WomenBusinessHubScreenState();
}

class _WomenBusinessHubScreenState extends State<WomenBusinessHubScreen> {
  final _state = SakhiPrototypeState.instance;
  final _search = TextEditingController();
  final _cityFilterCtrl = TextEditingController();
  List<BusinessPageModel> _items = const [];
  List<BusinessPageModel> _myPages = const [];
  String _category = 'All';
  String _priceTierFilter = 'All';
  bool _savedOnly = false;
  int _activeViewIndex = 0; // 0: Marketplace Discovery, 1: My Business Pages
  bool _loading = true;
  bool _signedIn = false;
  int _unreadEnquiriesCount = 0;

  @override
  void initState() {
    super.initState();
    _activeViewIndex = widget.initialViewIndex;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _cityFilterCtrl.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner && mounted) setState(() => _loading = true);
    final signedIn = await _state.hasAuthenticatedSession();
    final publicFuture = _state.fetchBusinesses(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      category: _category,
      city: _cityFilterCtrl.text.trim().isEmpty
          ? null
          : _cityFilterCtrl.text.trim(),
      savedOnly: _savedOnly,
    );
    final ownerFuture = signedIn
        ? _state.fetchBusinesses(ownerOnly: true)
        : Future.value(const <Map<String, dynamic>>[]);
    final enquiriesFuture = signedIn
        ? _state.fetchBusinessEnquiries()
        : Future.value(const <Map<String, dynamic>>[]);

    final results = await Future.wait<List<Map<String, dynamic>>>([
      publicFuture,
      ownerFuture,
      enquiriesFuture,
    ]);
    if (!mounted) return;

    var publicModels = results[0]
        .map(BusinessPageModel.fromJson)
        .where((b) => b.isApproved)
        .toList();
    if (_priceTierFilter != 'All') {
      publicModels = publicModels
          .where((b) => b.priceRange.contains(_priceTierFilter))
          .toList();
    }
    final myModels = results[1]
        .map(BusinessPageModel.fromJson)
        .toList(growable: false);
    final enquiries = results[2];
    final unread = enquiries.where((e) {
      final isOwnerInbox = e['isOwnerInbox'] == true ||
          e['ownerAccountId'] == _state.currentUser.accountId;
      return isOwnerInbox
          ? e['unreadForOwner'] == true
          : e['unreadForSender'] == true;
    }).length;

    setState(() {
      _signedIn = signedIn;
      _items = publicModels;
      _myPages = myModels;
      _unreadEnquiriesCount = unread;
      _loading = false;
    });
  }

  Future<void> _createNewBusiness() async {
    if (!_signedIn) {
      _message('Sign in through Sakhi before creating a business page.');
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const BusinessRegistrationWizardScreen(
          forceCreateNew: true,
        ),
      ),
    );
    await _load(spinner: false);
    if (created == true && mounted) {
      setState(() => _activeViewIndex = 1);
    }
  }

  Future<void> _editBusiness(BusinessPageModel page) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BusinessRegistrationWizardScreen(
          initialBusiness: page.toJson(),
        ),
      ),
    );
    await _load(spinner: false);
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
    await _load(spinner: false);
  }

  void _handleBack() {
    if (widget.onBackTap != null) {
      widget.onBackTap!();
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'All',
      ..._state.cachedBusinessCategories,
    }.toList();
    final featuredItems = _items
        .where((b) => b.isFeatured || b.isVerifiedWomanOwned)
        .take(5)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Women-Owned Businesses'),
        backgroundColor: AppColors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        leading: (widget.showBackButton ||
                widget.onBackTap != null ||
                Navigator.of(context).canPop())
            ? IconButton(
                onPressed: _handleBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _inbox,
                tooltip: 'Enquiries & Customer Leads',
                icon: const Icon(Icons.inbox_outlined),
              ),
              if (_unreadEnquiriesCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sosRed,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$_unreadEnquiriesCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _createNewBusiness,
              tooltip: 'Create new business page',
              icon: const Icon(Icons.add_business_outlined),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.businessPlum,
        onRefresh: () => _load(spinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          children: [
            // Hero iOS 26 Liquid Glass Banner
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.businessLuxuryGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE6C88A),
                      width: 1.4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x165D196A),
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE6C88A),
                              ),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 28,
                              color: AppColors.businessPlum,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'SRS MODULE 6 • VERIFIED MARKETPLACE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.businessPlum,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Discover women-led businesses',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.businessPlum,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Browse verified women entrepreneurs, showcase portfolios, products & services, and connect via WhatsApp, Call, or In-App Enquiry. New pages stay private until approved by an administrator.',
                        style: TextStyle(
                          height: 1.4,
                          fontSize: 12.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _createNewBusiness,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.businessPlum,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_business_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              '+ Register New Business',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _inbox,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.businessPlum,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.88),
                              side: const BorderSide(
                                color: AppColors.businessPlum,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(
                              Icons.mark_chat_unread_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _unreadEnquiriesCount > 0
                                  ? 'Enquiry Center ($_unreadEnquiriesCount new)'
                                  : 'Enquiry Center',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // View Switcher: Marketplace Discovery vs My Business Pages
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeViewIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeViewIndex == 0
                              ? AppColors.businessPlum
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Public Marketplace (${_items.length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _activeViewIndex == 0
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeViewIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeViewIndex == 1
                              ? AppColors.businessPlum
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'My Business Pages (${_myPages.length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _activeViewIndex == 1
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_activeViewIndex == 1) ...[
              _buildMyBusinessPagesSection(),
            ] else ...[
              // Search + Filters
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search business, product, service or city...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_search.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                          icon: const Icon(Icons.clear_rounded, size: 18),
                        ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.92),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          categories.contains(_category) ? _category : 'All',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.92),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _category = value ?? 'All');
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _priceTierFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.92),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: '₹', child: Text('₹ Budget')),
                        DropdownMenuItem(value: '₹₹', child: Text('₹₹ Mid')),
                        DropdownMenuItem(
                          value: '₹₹₹',
                          child: Text('₹₹₹ Premium'),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _priceTierFilter = val ?? 'All');
                        _load(spinner: false);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Horizontal Category & Saved Filter Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _savedOnly,
                        label: const Text('Saved Bookmarks'),
                        avatar: Icon(
                          _savedOnly ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                          color: _savedOnly
                              ? Colors.white
                              : AppColors.businessPlum,
                        ),
                        selectedColor: AppColors.businessPlum,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _savedOnly
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        onSelected: (v) {
                          setState(() => _savedOnly = v);
                          _load();
                        },
                      ),
                    ),
                    ...categories.take(8).map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: _category == cat,
                              label: Text(cat),
                              selectedColor: AppColors.pastelLavender,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _category == cat
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppColors.businessPlum,
                              ),
                              onSelected: (_) {
                                setState(() => _category = cat);
                                _load();
                              },
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              if (featuredItems.isNotEmpty &&
                  _category == 'All' &&
                  _search.text.isEmpty &&
                  !_savedOnly) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: Color(0xFFB45309),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Featured & Verified Women Entrepreneurs',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: AppColors.businessPlum,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featuredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, idx) {
                      final fItem = featuredItems[idx];
                      return _FeaturedBusinessSpotlightCard(
                        item: fItem,
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => BusinessProfileDetailScreen(
                                  businessId: fItem.id,
                                  initialModel: fItem,
                                ),
                              ),
                            )
                            .then((_) => _load(spinner: false)),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _loading
                        ? 'Loading businesses…'
                        : '${_items.length} public listings',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (_myPages.any((p) => p.needsReview))
                    GestureDetector(
                      onTap: () => setState(() => _activeViewIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E6),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Text(
                          'Pending Review in My Pages ›',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ),
                ],
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
                  message:
                      'Try a different search. New pages appear after administrator approval.',
                )
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BusinessCard(
                      item: item,
                      onSave: _signedIn
                          ? () async {
                              await _state.toggleSaveBusiness(item.id);
                              await _load(spinner: false);
                            }
                          : () => _message('Sign in to save a listing.'),
                      onWhatsApp: () {
                        final targetPhone =
                            item.whatsappNumber ?? item.contactPhone ?? '';
                        showSakhiWhatsAppConfirmationSheet(
                          context: context,
                          recipientTitle: item.businessName,
                          phoneOrWhatsapp: targetPhone,
                        );
                      },
                      onCall: item.contactPhone != null &&
                              item.contactPhone!.trim().isNotEmpty
                          ? () => _launchPhoneDialer(
                                context,
                                item.contactPhone!,
                              )
                          : null,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMyBusinessPagesSection() {
    if (!_signedIn) {
      return const _BusinessEmpty(
        title: 'Sign in to manage your businesses',
        message:
            'Sign in to your verified Sakhi account to create business pages, track administrator approval, and respond to customer enquiries.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrepreneur Portfolio & Approval Tracker',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: AppColors.businessPlum,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You can register multiple women-owned businesses. Pages in Pending Review are visible only to you and Sakhi Administrators until approved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _createNewBusiness,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.businessPlum,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Page'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_myPages.isEmpty)
          _BusinessEmpty(
            title: 'You have not created a business page yet',
            message:
                'Launch your boutique, consulting practice, studio, or home enterprise with up to 3 showcase photos and direct WhatsApp & In-App customer enquiries.',
            actionLabel: '+ Create Your First Business Page',
            onAction: _createNewBusiness,
          )
        else
          ..._myPages.map(
            (page) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OwnerBusinessStatusCard(
                item: page,
                onEdit: () => _editBusiness(page),
                onOpenDetail: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => BusinessProfileDetailScreen(
                          businessId: page.id,
                          initialModel: page,
                        ),
                      ),
                    )
                    .then((_) => _load(spinner: false)),
                onOpenEnquiries: _inbox,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeaturedBusinessSpotlightCard extends StatelessWidget {
  const _FeaturedBusinessSpotlightCard({
    required this.item,
    required this.onTap,
  });

  final BusinessPageModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showcase = item.allShowcaseImages;
    final bannerSource = showcase.isNotEmpty
        ? showcase.first
        : AppAssets.businessArtisanStudio;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 256,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6C88A), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145D196A),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 92,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBusinessMediaImage(bannerSource),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF065F46).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified Woman-Owned',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.businessPlum,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} • ${item.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${item.ownerDisplayName} • ${item.priceRange.isEmpty ? "Custom Pricing" : item.priceRange}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w800,
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
}

class _OwnerBusinessStatusCard extends StatelessWidget {
  const _OwnerBusinessStatusCard({
    required this.item,
    required this.onEdit,
    required this.onOpenDetail,
    required this.onOpenEnquiries,
  });

  final BusinessPageModel item;
  final VoidCallback onEdit;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenEnquiries;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isApproved
        ? const Color(0xFF065F46)
        : item.isRejected || item.isSuspended
            ? AppColors.sosRed
            : const Color(0xFFB45309);
    final statusBg = item.isApproved
        ? const Color(0xFFD1FAE5)
        : item.isRejected || item.isSuspended
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFFEF3C7);
    final statusLabel = item.isApproved
        ? 'APPROVED & LIVE IN MARKETPLACE'
        : item.isRejected
            ? 'CHANGES REQUESTED / REJECTED'
            : item.isSuspended
                ? 'SUSPENDED BY ADMIN'
                : 'PENDING SUPER ADMIN APPROVAL';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.4),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x104A155B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: _buildBusinessMediaImage(
                    item.logoAsset ?? item.coverImage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.businessName,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.businessPlum,
                      ),
                    ),
                    Text(
                      '${item.category} • ${item.city} ${item.businessCode.isNotEmpty ? "• ${item.businessCode}" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3-Step Approval Progress Stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF8FC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                _StepDot(
                  label: '1. Submitted',
                  done: true,
                  active: false,
                ),
                Expanded(
                  child: Divider(
                    color: item.isApproved
                        ? const Color(0xFF065F46)
                        : const Color(0xFFF59E0B),
                    thickness: 2,
                  ),
                ),
                _StepDot(
                  label: '2. Admin Review',
                  done: item.isApproved,
                  active: item.needsReview,
                ),
                Expanded(
                  child: Divider(
                    color: item.isApproved
                        ? const Color(0xFF065F46)
                        : AppColors.borderSubtle,
                    thickness: 2,
                  ),
                ),
                _StepDot(
                  label: '3. Public Live',
                  done: item.isApproved,
                  active: item.isApproved,
                ),
              ],
            ),
          ),
          if (item.reviewNotes != null &&
              item.reviewNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Admin Note: ${item.reviewNotes}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniMetricBadge(
                icon: Icons.photo_library_outlined,
                label: '${item.allShowcaseImages.length} Photos',
              ),
              const SizedBox(width: 8),
              _MiniMetricBadge(
                icon: Icons.inventory_2_outlined,
                label: '${item.productsServices.length} Offerings',
              ),
              const SizedBox(width: 8),
              _MiniMetricBadge(
                icon: Icons.mark_chat_unread_outlined,
                label: '${item.enquiriesCount} Enquiries',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Page'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenEnquiries,
                  icon: const Icon(Icons.inbox_outlined, size: 16),
                  label: const Text('Leads'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenDetail,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.businessPlum,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF065F46)
        : active
            ? const Color(0xFFD97706)
            : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : active
                  ? Icons.timelapse_rounded
                  : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniMetricBadge extends StatelessWidget {
  const _MiniMetricBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.pastelLavender.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.businessPlum),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.businessPlum,
            ),
          ),
        ],
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
  int _activeGalleryIndex = 0;

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

  Future<void> _enquire({String? preselectedOffering}) async {
    final hasSession = await _state.hasAuthenticatedSession();
    if (!mounted) return;
    if (!hasSession) {
      _message('Sign in through Sakhi before sending an enquiry.');
      return;
    }
    final subject = TextEditingController(text: preselectedOffering ?? '');
    final message = TextEditingController(
      text: preselectedOffering != null && preselectedOffering.isNotEmpty
          ? 'Hi! I would like to enquire about "$preselectedOffering" and check availability & pricing.'
          : '',
    );
    final contactCtrl = TextEditingController();
    String preferredChannel = 'In-App Chat';

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.borderSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Send Business Enquiry',
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Sakhi profile (${_state.currentUser.displayName}) will be shared with the business owner so they can respond directly.',
                          style: AppTypography.subtitle.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: subject,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Subject or Product / Service',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: preferredChannel,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Reply Channel',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'In-App Chat',
                              child: Text('Sakhi In-App Enquiry Thread'),
                            ),
                            DropdownMenuItem(
                              value: 'WhatsApp',
                              child: Text('WhatsApp'),
                            ),
                            DropdownMenuItem(
                              value: 'Phone Call',
                              child: Text('Phone Call'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => preferredChannel = v);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: contactCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText:
                                'Your WhatsApp / Phone Number (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: message,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1500,
                          decoration: const InputDecoration(
                            labelText: 'Your Message *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.businessPlum,
                                ),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Send Enquiry'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || submit != true) {
      subject.dispose();
      message.dispose();
      contactCtrl.dispose();
      return;
    }
    final messageText = message.text.trim();
    final subjectText = subject.text.trim();
    final contactText = contactCtrl.text.trim();
    subject.dispose();
    message.dispose();
    contactCtrl.dispose();
    if (messageText.length < 2) {
      _message('Enter a message of at least two characters.');
      return;
    }
    final result = await _state.submitBusinessEnquiry(
      businessId: widget.businessId,
      message: messageText,
      subjectOrProduct: subjectText,
      preferredContactMethod: preferredChannel,
      customerPhoneOrWhatsapp: contactText,
    );
    if (!mounted) return;
    _message(
      result == null
          ? 'Enquiry could not be saved. Please retry.'
          : 'Enquiry sent to ${_item?.businessName ?? "business owner"}!',
    );
    await _load();
  }

  Future<void> _report() async {
    final hasSession = await _state.hasAuthenticatedSession();
    if (!mounted) return;
    if (!hasSession) {
      _message('Sign in to report a listing.');
      return;
    }
    const presetReasons = <String>[
      'Suspected fake or non-woman-owned business',
      'Fraudulent payment or scam request',
      'Misleading product/service photos',
      'Harassment or inappropriate communication',
      'Other policy violation',
    ];
    String selectedReason = presetReasons.first;
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report this listing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports go confidentially to Sakhi Role 5 Business & Trust moderators.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: presetReasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedReason = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Additional detail (optional)',
                    border: OutlineInputBorder(),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      details.dispose();
      return;
    }
    final detail = details.text.trim();
    details.dispose();
    if (submit != true) return;
    final ok = await _state.reportBusinessListing(
      businessId: widget.businessId,
      reason: selectedReason,
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
    final gallery = item?.allShowcaseImages ?? const <String>[];
    final hasWhatsApp = (item?.whatsappNumber ?? '').trim().isNotEmpty ||
        (item?.contactPhone ?? '').trim().isNotEmpty;
    final hasPhone = (item?.contactPhone ?? '').trim().isNotEmpty;
    final hasSocial = (item?.instagramHandle ?? '').trim().isNotEmpty ||
        (item?.websiteOrInstagram ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(item?.businessName ?? 'Business details'),
        backgroundColor: AppColors.scaffoldBackground,
        actions: [
          if (item != null && item.isOwnBusiness)
            IconButton(
              tooltip: 'Edit My Business Page',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessRegistrationWizardScreen(
                      initialBusiness: item.toJson(),
                    ),
                  ),
                );
                await _load();
              },
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
              children: [
                // Swipeable Showcase Photo Gallery + Hero Header Card
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.businessLuxuryGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE6C88A),
                      width: 1.4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x165D196A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                        child: SizedBox(
                          height: 210,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (gallery.isEmpty)
                                _buildBusinessMediaImage(
                                  AppAssets.businessArtisanStudio,
                                )
                              else
                                PageView.builder(
                                  itemCount: gallery.length,
                                  onPageChanged: (idx) => setState(
                                    () => _activeGalleryIndex = idx,
                                  ),
                                  itemBuilder: (context, idx) =>
                                      _buildBusinessMediaImage(gallery[idx]),
                                ),
                              if (gallery.length > 1)
                                Positioned(
                                  bottom: 10,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Photo ${_activeGalleryIndex + 1} of ${gallery.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 58,
                                    height: 58,
                                    child: _buildBusinessMediaImage(
                                      item.logoAsset ?? item.coverImage,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.businessName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.businessPlum,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.category} • ${item.city}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Founder: ${item.ownerDisplayName}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (item.isVerifiedWomanOwned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 15,
                                          color: Color(0xFF065F46),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Verified women-owned',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF065F46),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.isOpenNow
                                        ? '● Open for Enquiries'
                                        : '● By Appointment',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: item.isOpenNow
                                          ? const Color(0xFF065F46)
                                          : AppColors.businessPlum,
                                    ),
                                  ),
                                ),
                                if (item.priceRange.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Price: ${item.priceRange}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.needsReview && item.isOwnBusiness) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.hourglass_top_rounded,
                                      size: 18,
                                      color: Color(0xFFB45309),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Your page is awaiting administrator review. Only you can preview this page until approved.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
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
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Direct Multi-Channel Contact Action Bar (WhatsApp, Call, Enquire, Social)
                _BusinessDetailCard(
                  title: 'Connect Directly with ${item.businessName}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (hasWhatsApp)
                            FilledButton.icon(
                              onPressed: () {
                                final phone = item.whatsappNumber ??
                                    item.contactPhone ??
                                    '';
                                showSakhiWhatsAppConfirmationSheet(
                                  context: context,
                                  recipientTitle: item.businessName,
                                  phoneOrWhatsapp: phone,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF128C7E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(Icons.chat_rounded, size: 17),
                              label: const Text(
                                'WhatsApp Business',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          if (hasPhone)
                            OutlinedButton.icon(
                              onPressed: () => _launchPhoneDialer(
                                context,
                                item.contactPhone!,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.businessPlum,
                                side: const BorderSide(
                                  color: AppColors.businessPlum,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(Icons.call_outlined, size: 17),
                              label: const Text(
                                'Call Direct',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _enquire(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.businessPlum,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            icon: const Icon(Icons.mail_outline, size: 17),
                            label: const Text(
                              'Enquire in App',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (hasSocial)
                            OutlinedButton.icon(
                              onPressed: () => _launchExternalWebUrl(
                                context,
                                item.websiteOrInstagram ??
                                    item.instagramHandle ??
                                    '',
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text('Instagram / Web'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (gallery.length > 1)
                  _BusinessDetailCard(
                    title: 'Portfolio & Product Showcase (${gallery.length} Photos)',
                    child: SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: gallery.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) => GestureDetector(
                          onTap: () =>
                              setState(() => _activeGalleryIndex = idx),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _activeGalleryIndex == idx
                                      ? AppColors.businessPlum
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: _buildBusinessMediaImage(
                                gallery[idx],
                                width: 96,
                                height: 96,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                _BusinessDetailCard(
                  title: 'About',
                  child: Text(
                    item.description.isEmpty
                        ? 'No description provided.'
                        : item.description,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
                _BusinessDetailCard(
                  title: 'Service area, working hours and price',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area: ${item.serviceArea.isEmpty ? item.city : item.serviceArea}\nPrice: ${item.priceRange.isEmpty ? 'Not specified' : item.priceRange}',
                      ),
                      if (item.businessHours.isNotEmpty) ...[
                        const Divider(height: 18),
                        Text(
                          'Mon–Fri: ${item.businessHours['mondayToFriday'] ?? '10:00 AM – 7:00 PM'}\n'
                          'Saturday: ${item.businessHours['saturday'] ?? '10:00 AM – 5:00 PM'}\n'
                          'Sunday: ${item.businessHours['sunday'] ?? 'By Appointment'}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.productsServices.isNotEmpty)
                  _BusinessDetailCard(
                    title:
                        'Products and services (${item.productsServices.length})',
                    child: Column(
                      children: item.productsServices.map((p) {
                        final title =
                            (p['title'] ?? p['name'] ?? 'Service').toString();
                        final desc = (p['description'] ?? '').toString();
                        final price = p['price']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF9FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.businessPlum,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (price.isNotEmpty)
                                          Text(
                                            price,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _enquire(
                                          preselectedOffering: title,
                                        ),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Enquire About This ›',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                _BusinessDetailCard(
                  title: 'Contact & Verification Details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.contactPhone != null)
                        Text('Phone: ${item.contactPhone}'),
                      if (item.contactPhone == null &&
                          item.contactPhoneMasked != null)
                        Text(
                          'Phone: ${item.contactPhoneMasked} (Protected by owner privacy settings)',
                        ),
                      if (item.whatsappNumber != null &&
                          item.whatsappNumber!.isNotEmpty)
                        Text('WhatsApp: ${item.whatsappNumber}'),
                      if (item.instagramHandle != null &&
                          item.instagramHandle!.isNotEmpty)
                        Text('Instagram: ${item.instagramHandle}'),
                      if (item.websiteOrInstagram != null &&
                          item.websiteOrInstagram!.isNotEmpty)
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
                        onPressed: _busy ? null : () => _enquire(),
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
  const BusinessRegistrationWizardScreen({
    super.key,
    this.initialBusiness,
    this.forceCreateNew = false,
  });

  final Map<String, dynamic>? initialBusiness;
  final bool forceCreateNew;

  @override
  State<BusinessRegistrationWizardScreen> createState() =>
      _BusinessRegistrationWizardScreenState();
}

class _BusinessRegistrationWizardScreenState
    extends State<BusinessRegistrationWizardScreen> {
  final _state = SakhiPrototypeState.instance;
  final _form = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _name = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '₹500 – ₹2,500');
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _website = TextEditingController();
  final _monFriCtrl = TextEditingController(text: '10:00 AM – 7:00 PM');
  final _satCtrl = TextEditingController(text: '10:00 AM – 5:00 PM');
  final _sunCtrl = TextEditingController(text: 'By Appointment');

  String _category = 'Fashion and clothing';
  String? _businessId;
  String _logoAsset = AppAssets.businessArtisanStudio;
  String _coverImage = AppAssets.businessArtisanStudio;
  final List<String> _showcasePhotos = <String>[
    AppAssets.businessArtisanStudio,
  ];
  final List<Map<String, dynamic>> _offerings = <Map<String, dynamic>>[];

  bool _hidePhoneNumber = false;
  bool _requestVerifiedBadge = true;
  bool _uploadingMedia = false;
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
    _monFriCtrl.dispose();
    _satCtrl.dispose();
    _sunCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final signedIn = await _state.hasAuthenticatedSession();
    Map<String, dynamic>? business = widget.initialBusiness;
    if (business == null && !widget.forceCreateNew && signedIn) {
      // When not forced to create new, leave blank unless explicitly passed initialBusiness
      business = null;
    }
    if (!mounted) return;
    if (business != null) {
      _businessId = business['id']?.toString();
      _name.text = (business['businessName'] ?? '').toString();
      _city.text = (business['city'] ?? '').toString();
      _area.text = (business['serviceArea'] ?? '').toString();
      _description.text = (business['description'] ?? '').toString();
      _price.text = (business['priceRange'] ?? '₹500 – ₹2,500').toString();
      _phone.text = (business['contactPhone'] ?? '').toString();
      _whatsapp.text = (business['whatsappNumber'] ?? '').toString();
      _instagram.text = (business['instagramHandle'] ?? '').toString();
      _website.text = (business['websiteOrInstagram'] ?? '').toString();
      _hidePhoneNumber = business['hidePhoneNumber'] == true;
      if ((business['logoAsset'] ?? '').toString().trim().isNotEmpty) {
        _logoAsset = business['logoAsset'].toString().trim();
      }
      if ((business['coverImage'] ?? '').toString().trim().isNotEmpty) {
        _coverImage = business['coverImage'].toString().trim();
      }
      final rawGallery = business['mediaGallery'];
      if (rawGallery is List && rawGallery.isNotEmpty) {
        _showcasePhotos
          ..clear()
          ..addAll(rawGallery.map((e) => e.toString()).take(3));
      }
      final rawOfferings = business['productsServices'];
      if (rawOfferings is List) {
        _offerings
          ..clear()
          ..addAll(
            rawOfferings
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m)),
          );
      }
      final rawHours = business['businessHours'];
      if (rawHours is Map) {
        _monFriCtrl.text =
            (rawHours['mondayToFriday'] ?? '10:00 AM – 7:00 PM').toString();
        _satCtrl.text =
            (rawHours['saturday'] ?? '10:00 AM – 5:00 PM').toString();
        _sunCtrl.text = (rawHours['sunday'] ?? 'By Appointment').toString();
      }
      if (_state.cachedBusinessCategories.contains(business['category'])) {
        _category = business['category'].toString();
      }
    } else {
      _city.text = _state.currentUser.location.isNotEmpty
          ? _state.currentUser.location
          : 'Bengaluru';
    }
    setState(() {
      _signedIn = signedIn;
      _loading = false;
    });
  }

  Future<void> _pickAndUploadPhoto({
    required ImageSource source,
    required void Function(String mediaUrl) onUploaded,
  }) async {
    if (_uploadingMedia) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 86,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted || bytes.isEmpty) return;

      setState(() => _uploadingMedia = true);
      final res = await _state.uploadMediaFile(
        purpose: 'community_post',
        fileName: picked.name.isEmpty ? 'business_photo.jpg' : picked.name,
        fileBytes: bytes,
        contentType: 'image/jpeg',
      );
      if (!mounted) return;
      setState(() => _uploadingMedia = false);
      final uploadedUrl = res?['mediaUrl']?.toString() ?? '';
      if (uploadedUrl.isNotEmpty) {
        setState(() => onUploaded(uploadedUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business photo uploaded!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload photo. Try a studio preset below.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingMedia = false);
      }
    }
  }

  Future<void> _showAddOfferingDialog() async {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product or Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g., Custom Bridal Embroidery Blouse',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Price / Rate',
                  hintText: 'e.g., ₹1,250',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                  hintText: 'Materials, turnaround time, or details...',
                  border: OutlineInputBorder(),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.businessPlum,
            ),
            child: const Text('Add to Catalog'),
          ),
        ],
      ),
    );
    final t = titleCtrl.text.trim();
    final p = priceCtrl.text.trim();
    final d = descCtrl.text.trim();
    titleCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    if (added == true && t.isNotEmpty && mounted) {
      setState(() {
        _offerings.add(<String, dynamic>{
          'title': t,
          'price': p.isEmpty ? 'On Request' : p,
          'description': d,
        });
      });
    }
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
      'logoAsset': _logoAsset,
      'coverImage': _coverImage,
      'mediaGallery': _showcasePhotos.take(3).toList(),
      'productsServices': _offerings,
      'businessHours': <String, dynamic>{
        'mondayToFriday': _monFriCtrl.text.trim(),
        'saturday': _satCtrl.text.trim(),
        'sunday': _sunCtrl.text.trim(),
        'isOpenNow': true,
      },
      'requestVerificationBadge': _requestVerifiedBadge,
      if (_price.text.trim().isNotEmpty) 'priceRange': _price.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'contactPhone': _phone.text.trim(),
      if (_whatsapp.text.trim().isNotEmpty)
        'whatsappNumber': _whatsapp.text.trim(),
      if (_instagram.text.trim().isNotEmpty)
        'instagramHandle': _instagram.text.trim(),
      if (_website.text.trim().isNotEmpty)
        'websiteOrInstagram': _website.text.trim(),
      'hidePhoneNumber': _hidePhoneNumber,
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
          'Business page submitted! Track its live status under "My Business Pages" while our admin team reviews it.',
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
              message:
                  'A business page belongs to an authenticated Sakhi member account. Sign in to the hosted service, then return here.',
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.businessLuxuryGradient,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6C88A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.businessPlum,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'New listings stay private in "My Business Pages" until reviewed and approved by a Sakhi Administrator.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.businessPlum,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_uploadingMedia) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      color: AppColors.businessPlum,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // STEP 1: Brand Identity
                  const Text(
                    'STEP 1 • BRAND IDENTITY & LOCATION',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.businessPlum,
                    ),
                  ),
                  const SizedBox(height: 10),
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

                  const SizedBox(height: 18),
                  // STEP 2: Portfolio & Showcase Photos (Up to 3 Photos + Cover)
                  const Text(
                    'STEP 2 • SHOWCASE PHOTOS (UP TO 3 PORTFOLIO PHOTOS)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.businessPlum,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected Showcase Photos (${_showcasePhotos.length}/3)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _showcasePhotos.length >= 3
                                      ? null
                                      : () => _pickAndUploadPhoto(
                                            source: ImageSource.gallery,
                                            onUploaded: (url) {
                                              if (_showcasePhotos.length < 3) {
                                                _showcasePhotos.add(url);
                                                _coverImage =
                                                    _showcasePhotos.first;
                                              }
                                            },
                                          ),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Gallery'),
                                ),
                                TextButton.icon(
                                  onPressed: _showcasePhotos.length >= 3
                                      ? null
                                      : () => _pickAndUploadPhoto(
                                            source: ImageSource.camera,
                                            onUploaded: (url) {
                                              if (_showcasePhotos.length < 3) {
                                                _showcasePhotos.add(url);
                                                _coverImage =
                                                    _showcasePhotos.first;
                                              }
                                            },
                                          ),
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Camera'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 92,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _showcasePhotos.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              final img = _showcasePhotos[idx];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildBusinessMediaImage(
                                      img,
                                      width: 92,
                                      height: 92,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showcasePhotos.removeAt(idx);
                                          if (_showcasePhotos.isNotEmpty) {
                                            _coverImage = _showcasePhotos.first;
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Or tap a Sakhi Studio Preset to add to your 3 showcase photos:',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _kBoutiquePhotoPresets.map((preset) {
                            final asset = preset['asset']!;
                            final isSelected = _showcasePhotos.contains(asset);
                            return ActionChip(
                              avatar: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.add_photo_alternate_outlined,
                                size: 15,
                                color: AppColors.businessPlum,
                              ),
                              label: Text(
                                preset['label']!,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isSelected) {
                                    if (_showcasePhotos.length > 1) {
                                      _showcasePhotos.remove(asset);
                                    }
                                  } else if (_showcasePhotos.length < 3) {
                                    _showcasePhotos.add(asset);
                                  } else {
                                    _showcasePhotos[2] = asset;
                                  }
                                  _coverImage = _showcasePhotos.first;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // STEP 3: Products & Services Catalog + Working Hours
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STEP 3 • PRODUCTS & SERVICES CATALOG',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.businessPlum,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddOfferingDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('+ Add Offering'),
                      ),
                    ],
                  ),
                  if (_offerings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Text(
                        'Add products, packages, or consulting services with prices so customers can enquire about specific items.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  else
                    ..._offerings.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '${p['title']} • ${p['price']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text((p['description'] ?? '').toString()),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.sosRed,
                            ),
                            onPressed: () =>
                                setState(() => _offerings.removeAt(i)),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _monFriCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mon–Fri Hours',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _satCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Saturday Hours',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  // STEP 4: Contact Channels & Privacy Controls
                  const Text(
                    'STEP 4 • DIRECT CONTACT & PRIVACY SETTINGS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.businessPlum,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Contact phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _hidePhoneNumber,
                    activeThumbColor: AppColors.businessPlum,
                    title: const Text(
                      'Mask my phone number on public page',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Customers can still message you via Sakhi In-App Enquiries.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    onChanged: (v) => setState(() => _hidePhoneNumber = v),
                  ),
                  const SizedBox(height: 8),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _requestVerifiedBadge,
                    activeThumbColor: const Color(0xFF065F46),
                    title: const Text(
                      'Request "Verified Woman-Owned Business" Badge',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Issued by Sakhi Role 5 Business Admin upon reviewing your profile.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    onChanged: (v) =>
                        setState(() => _requestVerifiedBadge = v),
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
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
  int _tabIndex = 0; // 0: All, 1: Received (Customer Leads), 2: Sent by Me
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
    final myAccountId = _state.currentUser.accountId;
    final filteredRows = _rows.where((r) {
      final isOwnerInbox = r['isOwnerInbox'] == true ||
          (myAccountId.isNotEmpty && r['ownerAccountId'] == myAccountId);
      if (_tabIndex == 1) return isOwnerInbox;
      if (_tabIndex == 2) return !isOwnerInbox;
      return true;
    }).toList();

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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      ChoiceChip(
                        selected: _tabIndex == 0,
                        label: Text('All (${_rows.length})'),
                        onSelected: (_) => setState(() => _tabIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _tabIndex == 1,
                        label: const Text('Customer Leads'),
                        onSelected: (_) => setState(() => _tabIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        selected: _tabIndex == 2,
                        label: const Text('My Sent Enquiries'),
                        onSelected: (_) => setState(() => _tabIndex = 2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredRows.isEmpty
                      ? const _BusinessEmpty(
                          title: 'No enquiries yet',
                          message:
                              'Enquiries you send or receive from a business page will appear here with full customer profile details.',
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(spinner: false),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                            itemCount: filteredRows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = filteredRows[index];
                              final rawMessages = row['messages'];
                              final messages = rawMessages is List
                                  ? rawMessages
                                  : const [];
                              final latest = messages.isNotEmpty &&
                                      messages.last is Map
                                  ? messages.last as Map
                                  : const <String, dynamic>{};
                              final firstMsg = messages.isNotEmpty &&
                                      messages.first is Map
                                  ? messages.first as Map
                                  : const <String, dynamic>{};
                              final label =
                                  (row['subjectOrProduct'] ?? 'Business enquiry')
                                      .toString();
                              final business =
                                  (row['businessName'] ?? 'Business').toString();
                              final senderName = (row['senderDisplayName'] ??
                                      firstMsg['senderName'] ??
                                      'Sakhi Member')
                                  .toString();
                              final senderUsername = (row['senderUsername'] ??
                                      firstMsg['senderUsername'] ??
                                      '@member')
                                  .toString();
                              final preferredMethod =
                                  (firstMsg['preferredContactMethod'] ??
                                          'In-App')
                                      .toString();
                              final customerPhone =
                                  (firstMsg['customerPhoneOrWhatsapp'] ?? '')
                                      .toString();
                              final status =
                                  (row['status'] ?? 'OPEN').toString();
                              final isUnread = row['unreadForOwner'] == true ||
                                  row['unreadForSender'] == true;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isUnread
                                        ? AppColors.businessPlum
                                        : AppColors.borderSubtle,
                                    width: isUnread ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _open(row),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SakhiAvatar(
                                              imageAsset:
                                                  (firstMsg['senderAvatar'] ??
                                                          '')
                                                      .toString(),
                                              fallbackLabel: senderName,
                                              size: 40,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$senderName ($senderUsername)',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    'For: $business • Preferred: $preferredMethod',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: status == 'REPLIED'
                                                    ? const Color(0xFFD1FAE5)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: status == 'REPLIED'
                                                      ? const Color(0xFF065F46)
                                                      : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.businessChampagneBg,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Topic / Product: $label',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.businessPlum,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (latest['body'] ?? '').toString(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (customerPhone.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                onPressed: () =>
                                                    showSakhiWhatsAppConfirmationSheet(
                                                      context: context,
                                                      recipientTitle:
                                                          senderName,
                                                      phoneOrWhatsapp:
                                                          customerPhone,
                                                      initialMessage:
                                                          'Hi $senderName! Replying to your Sakhi enquiry regarding "$label" at $business.',
                                                    ),
                                                icon: const Icon(
                                                  Icons.chat_rounded,
                                                  size: 15,
                                                  color: Color(0xFF128C7E),
                                                ),
                                                label: const Text(
                                                  'WhatsApp Customer',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF128C7E),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _launchPhoneDialer(
                                                      context,
                                                      customerPhone,
                                                    ),
                                                icon: const Icon(
                                                  Icons.call_outlined,
                                                  size: 15,
                                                ),
                                                label: Text(
                                                  'Call $customerPhone',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
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
    final senderName = (_row['senderDisplayName'] ?? 'Sakhi Member').toString();
    final senderUsername = (_row['senderUsername'] ?? '').toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, inset + 16),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height - inset - 80).clamp(
          280.0,
          MediaQuery.sizeOf(context).height * .78,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_row['subjectOrProduct'] ?? 'Business enquiry').toString(),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              '${(_row['businessName'] ?? 'Business')} • Customer: $senderName ${senderUsername.isNotEmpty ? "($senderUsername)" : ""}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const Divider(height: 20),
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
                            '${m['senderName'] ?? 'Sakhi Member'} (${isOwner ? 'Business Owner' : 'Customer'})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: AppColors.businessPlum,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 3,
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
    required this.onWhatsApp,
    this.onCall,
  });

  final BusinessPageModel item;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onWhatsApp;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final location = item.serviceArea.isEmpty ? item.city : item.serviceArea;
    final showcase = item.allShowcaseImages;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.isVerifiedWomanOwned
              ? const Color(0xFFE6C88A)
              : AppColors.borderSubtle,
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x124A155B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: _buildBusinessMediaImage(
                        item.logoAsset ?? item.coverImage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.businessPlum,
                                ),
                              ),
                            ),
                            if (item.isVerifiedWomanOwned)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: AppColors.verifiedGreenText,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.category} • $location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Founder: ${item.ownerDisplayName} • ${item.priceRange.isEmpty ? "Flexible Pricing" : item.priceRange} • ${item.savesCount} saves',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSave,
                    tooltip: item.isSaved ? 'Unsave' : 'Save',
                    icon: Icon(
                      item.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: AppColors.businessPlum,
                    ),
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.8,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
              if (showcase.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: showcase.take(3).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildBusinessMediaImage(
                        showcase[idx],
                        width: 86,
                        height: 64,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF128C7E),
                        side: const BorderSide(color: Color(0xFF128C7E)),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 15),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (onCall != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onCall,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.businessPlum,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.call_outlined, size: 15),
                      label: const Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.businessPlum,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.storefront_outlined, size: 15),
                      label: const Text(
                        'View Page',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      elevation: 0,
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
  const _BusinessEmpty({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.businessPlum,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
