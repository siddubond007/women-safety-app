import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/constants/mock_data.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/business/screens/business_hub_screen.dart';

class _DeferredModule6ApiClient extends BackendApiClient {
  _DeferredModule6ApiClient() : super(baseUrl: 'http://127.0.0.1:3001/api/v1');

  final Completer<Map<String, dynamic>> ownerBusinesses =
      Completer<Map<String, dynamic>>();
  final Completer<Map<String, dynamic>> enquiries =
      Completer<Map<String, dynamic>>();
  final Completer<void> requestsStarted = Completer<void>();
  int _requestCount = 0;

  @override
  Future<String?> readAccessToken() async => 'account-a-token';

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) {
    if (!authenticated) {
      throw StateError('Module 6 owner requests must be authenticated.');
    }
    _requestCount++;
    if (_requestCount == 2 && !requestsStarted.isCompleted) {
      requestsStarted.complete();
    }
    if (path == 'module2/businesses?ownerOnly=true') {
      return ownerBusinesses.future;
    }
    if (path == 'module2/businesses/enquiries/list') {
      return enquiries.future;
    }
    throw StateError('Unexpected Module 6 GET request: $path');
  }
}

void main() {
  test('late Module 6 business and enquiry responses cannot restore previous-account data', () async {
    final state = SakhiPrototypeState.instance;
    final api = _DeferredModule6ApiClient();
    state.configureApiClient(api);

    final ownerPagesRequest = state.fetchBusinesses(ownerOnly: true);
    final enquiriesRequest = state.fetchBusinessEnquiries();
    await api.requestsStarted.future;

    await state.clearAccountScopedData();

    api.ownerBusinesses.complete({
      'businesses': [
        <String, dynamic>{
          'id': 'account-a-business',
          'businessName': 'Account A private business',
          'isOwnBusiness': true,
        },
      ],
    });
    api.enquiries.complete({
      'enquiries': [
        <String, dynamic>{
          'id': 'account-a-enquiry',
          'message': 'Account A private enquiry',
        },
      ],
    });

    expect(await ownerPagesRequest, isEmpty);
    expect(await enquiriesRequest, isEmpty);
    expect(state.cachedBusinesses, isEmpty);
    expect(state.myBusinessPages, isEmpty);
    expect(state.myBusinessPage, isNull);
    expect(state.cachedBusinessEnquiries, isEmpty);
  });

  group('BusinessPageModel', () {
    test('maps a complete hosted API business listing', () {
      final model = BusinessPageModel.fromJson({
        'id': 'business-123',
        'businessCode': 'BUS-123',
        'businessName': 'Sakhi Studio',
        'category': 'Fashion and clothing',
        'city': 'Tirupati',
        'serviceArea': 'Tirupati and nearby towns',
        'priceRange': '₹500–₹2,500',
        'description': 'Handmade clothing and tailoring',
        'ownerDisplayName': 'A Sakhi Member',
        'approvalStatus': 'APPROVED',
        'isOwnBusiness': false,
        'isSaved': true,
        'isVerifiedWomanOwned': true,
        'savesCount': 12,
        'enquiriesCount': 4,
        'productsServices': [
          {
            'title': 'Custom blouse',
            'description': 'Made to measure',
            'price': '₹800',
          },
        ],
      });

      expect(model.id, 'business-123');
      expect(model.businessCode, 'BUS-123');
      expect(model.businessName, 'Sakhi Studio');
      expect(model.city, 'Tirupati');
      expect(model.serviceArea, 'Tirupati and nearby towns');
      expect(model.approvalStatus, 'APPROVED');
      expect(model.needsReview, isFalse);
      expect(model.isSaved, isTrue);
      expect(model.isVerifiedWomanOwned, isTrue);
      expect(model.savesCount, 12);
      expect(model.enquiriesCount, 4);
      expect(model.productsServices, hasLength(1));
      expect(model.productsServices.single['title'], 'Custom blouse');
    });

    test('fails closed to pending review when approval status is absent', () {
      final model = BusinessPageModel.fromJson({
        'id': 'business-pending',
        'businessName': 'Pending Listing',
        'category': 'Other',
        'city': 'Chennai',
        'description': 'A new listing',
      });

      expect(model.approvalStatus, 'PENDING_APPROVAL');
      expect(model.needsReview, isTrue);
      expect(model.isVerifiedWomanOwned, isFalse);
      expect(model.isOwnBusiness, isFalse);
      expect(model.isSaved, isFalse);
      expect(model.productsServices, isEmpty);
    });

    test('supports legacy name and owner response keys', () {
      final model = BusinessPageModel.fromJson({
        'id': 'business-legacy',
        'name': 'Legacy Listing',
        'isOwner': true,
        'category': 'Education',
        'city': 'Chennai',
        'approvalStatus': 'PENDING_APPROVAL',
      });

      expect(model.businessName, 'Legacy Listing');
      expect(model.isOwnBusiness, isTrue);
      expect(model.needsReview, isTrue);
    });

    test('handles nullable or malformed optional product data safely', () {
      final model = BusinessPageModel.fromJson({
        'id': 'business-sparse',
        'businessName': 'Sparse Listing',
        'category': 'Other',
        'city': 'Vijayawada',
        'productsServices': 'not-a-list',
        'savesCount': 'not-a-number',
        'enquiriesCount': null,
      });

      expect(model.productsServices, isEmpty);
      expect(model.savesCount, 0);
      expect(model.enquiriesCount, 0);
      expect(model.priceRange, isEmpty);
      expect(model.serviceArea, 'Vijayawada');
    });
  });
}
