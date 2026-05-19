import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class PlanModel {
  final String id;
  final int amount;
  final String amountDisplay;
  final String description;
  final int durationDays;
  final String feature;

  PlanModel({
    required this.id,
    required this.amount,
    required this.amountDisplay,
    required this.description,
    required this.durationDays,
    required this.feature,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] ?? '',
      amount: json['amount'] ?? 0,
      amountDisplay: json['amountDisplay'] ?? '',
      description: json['description'] ?? '',
      durationDays: json['durationDays'] ?? 0,
      feature: json['feature'] ?? '',
    );
  }
}

class PremiumProvider extends ChangeNotifier {
  final ApiService _api;

  List<PlanModel> _plans = [];
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _error;
  String? _currentPlanId;

  // Current premium status (from backend)
  bool _isPremium = false;
  bool _isUnlimitedLikes = false;
  bool _isBoosted = false;
  DateTime? _premiumExpiresAt;
  DateTime? _unlimitedLikesExpiresAt;
  DateTime? _boostExpiresAt;

  PremiumProvider(this._api);

  List<PlanModel> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  String? get error => _error;
  String? get currentPlanId => _currentPlanId;
  bool get isPremium => _isPremium;
  bool get isUnlimitedLikes => _isUnlimitedLikes;
  bool get isBoosted => _isBoosted;
  DateTime? get premiumExpiresAt => _premiumExpiresAt;
  DateTime? get unlimitedLikesExpiresAt => _unlimitedLikesExpiresAt;
  DateTime? get boostExpiresAt => _boostExpiresAt;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.getPlans();
      _plans = (data['plans'] as List)
          .map((p) => PlanModel.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      final status = data['currentStatus'] as Map<String, dynamic>;
      _isPremium = status['isPremium'] == true;
      _isUnlimitedLikes = status['isUnlimitedLikes'] == true;
      _isBoosted = status['isBoosted'] == true;
      _premiumExpiresAt = status['premiumExpiresAt'] != null
          ? DateTime.tryParse(status['premiumExpiresAt'])
          : null;
      _unlimitedLikesExpiresAt = status['unlimitedLikesExpiresAt'] != null
          ? DateTime.tryParse(status['unlimitedLikesExpiresAt'])
          : null;
      _boostExpiresAt = status['boostExpiresAt'] != null
          ? DateTime.tryParse(status['boostExpiresAt'])
          : null;
    } catch (e) {
      _error = _extractError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a Razorpay order. Returns the full order payload (orderId, keyId, amount, etc.)
  Future<Map<String, dynamic>?> createOrder(String planId) async {
    _isPurchasing = true;
    _currentPlanId = planId;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.createPaymentOrder(planId);
      return data;
    } catch (e) {
      _error = _extractError(e);
      _isPurchasing = false;
      notifyListeners();
      return null;
    }
  }

  /// Verifies payment with backend and refreshes premium status.
  Future<bool> verifyAndActivate({
    required String orderId,
    required String paymentId,
    required String signature,
    required String planId,
  }) async {
    try {
      await _api.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        planId: planId,
      );
      _isPurchasing = false;
      await fetchPlans(); // refresh status
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isPurchasing = false;
      notifyListeners();
      return false;
    }
  }

  void setPurchasing(bool value) {
    _isPurchasing = value;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    final msg = e.toString();
    final match = RegExp(r'"message":"([^"]+)"').firstMatch(msg);
    return match?.group(1) ?? msg.replaceAll('Exception:', '').trim();
  }
}
