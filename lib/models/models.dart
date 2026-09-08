enum UserType { customer, captain }

enum VehicleType { economy, comfort, family }

enum TripStatus {
  pending,
  searching,
  accepted,
  enRoute,
  arrived,
  started,
  completed,
  cancelled,
}

enum TransactionType {
  charge,
  payment,
  refund,
  reward,
  withdraw,
  commission,
  transfer,
}

class AppUser {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final int tripsCount;
  final UserType type;
  final String avatar;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.tripsCount,
    required this.type,
    required this.avatar,
  });
}

class Vehicle {
  final String brand;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int seats;
  final VehicleType type;

  Vehicle({
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.seats,
    required this.type,
  });

  String get typeArabic {
    switch (type) {
      case VehicleType.economy:
        return 'إقتصادية';
      case VehicleType.comfort:
        return 'مريحة';
      case VehicleType.family:
        return 'عائلية';
    }
  }

  String get description {
    switch (type) {
      case VehicleType.economy:
        return 'سيارة عادية من 1 إلى 4 ركاب';
      case VehicleType.comfort:
        return 'سيارة أفضل وأكثر راحة من 1 إلى 4 ركاب';
      case VehicleType.family:
        return 'سيارة أكبر من 1 إلى 6 ركاب';
    }
  }
}

class CaptainDetails {
  final AppUser user;
  final Vehicle vehicle;
  final double acceptanceRate;
  final double cancellationRate;
  final Map<String, String> documentsStatus; // e.g. {'national_id': 'accepted'}

  CaptainDetails({
    required this.user,
    required this.vehicle,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.documentsStatus,
  });
}

class Trip {
  final String id;
  final String customerName;
  final String customerPhone;
  final String? captainName;
  final String? captainPhone;
  final String? captainAvatar;
  final String? vehiclePlate;
  final String? vehicleName;
  final String pickupLocation;
  // Null for open rides: no destination is known until the captain ends the trip.
  final String? destinationLocation;
  final double pickupLat;
  final double pickupLng;
  final double? destLat;
  final double? destLng;
  final double distance; // in km
  final int duration; // in minutes
  final double price;
  final String paymentMethod;
  TripStatus status;
  final VehicleType carType;
  final bool isOpenRide;
  final int openRideTimeout; // in seconds (30, 45, 60)
  final String date;
  final double? netEarnings;
  final double? commission;
  final String? cancellationReason;
  // True when this trip was claimed from a real customer request in the
  // `rides` Supabase table (as opposed to the local demo/browse flows), so
  // status changes should be written back to that row.
  final bool isRemote;
  // 'ride' (passenger) or 'delivery' (package, motorcycle captains only).
  // For a delivery trip, customerName/customerPhone hold the recipient's
  // details - the same contact fields the call/chat UI already uses.
  final String serviceType;
  final String? packageDescription;

  Trip({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.captainName,
    this.captainPhone,
    this.captainAvatar,
    this.vehiclePlate,
    this.vehicleName,
    required this.pickupLocation,
    this.destinationLocation,
    required this.pickupLat,
    required this.pickupLng,
    this.destLat,
    this.destLng,
    required this.distance,
    required this.duration,
    required this.price,
    required this.paymentMethod,
    required this.status,
    required this.carType,
    required this.isOpenRide,
    required this.openRideTimeout,
    required this.date,
    this.netEarnings,
    this.commission,
    this.cancellationReason,
    this.isRemote = false,
    this.serviceType = 'ride',
    this.packageDescription,
  });

  bool get isDelivery => serviceType == 'delivery';

  String get carTypeNameArabic {
    switch (carType) {
      case VehicleType.economy:
        return 'إقتصادية';
      case VehicleType.comfort:
        return 'مريحة';
      case VehicleType.family:
        return 'عائلية';
    }
  }

  String get statusArabic {
    switch (status) {
      case TripStatus.pending:
        return 'قيد الانتظار';
      case TripStatus.searching:
        return 'جاري البحث عن كابتن';
      case TripStatus.accepted:
        return 'تم قبول الطلب';
      case TripStatus.enRoute:
        return 'الكابتن في الطريق';
      case TripStatus.arrived:
        return 'وصل الكابتن';
      case TripStatus.started:
        return 'رحلة جارية';
      case TripStatus.completed:
        return 'مكتملة';
      case TripStatus.cancelled:
        return 'ملغاة';
    }
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String time;
  final bool isLocation;
  final double? latitude;
  final double? longitude;
  final bool isMe;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.time,
    this.isLocation = false,
    this.latitude,
    this.longitude,
    required this.isMe,
  });
}

class WalletTransaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String title;
  final String date;
  final bool isCredit;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.title,
    required this.date,
    required this.isCredit,
  });

  String get typeArabic {
    switch (type) {
      case TransactionType.charge:
        return 'شحن رصيد';
      case TransactionType.payment:
        return 'دفع رحلة';
      case TransactionType.refund:
        return 'استرجاع مبلغ';
      case TransactionType.reward:
        return 'مكافأة';
      case TransactionType.withdraw:
        return 'سحب أرباح';
      case TransactionType.commission:
        return 'خصم عمولة';
      case TransactionType.transfer:
        return 'تحويل رصيد';
    }
  }
}

// ---------------------------------------------------------------------
// Monthly captain subscription ("اشتراك شهري" - see the customer app's
// captain_subscriptions/captain_subscription_messages tables,
// 20260812000056/57). The customer side (browsing captains, negotiating,
// paying) already exists in app-driver-customer; these are the
// captain-facing counterparts, previously missing entirely from this app
// - a captain had no screen at all showing incoming subscription offers.
// ---------------------------------------------------------------------

enum SubscriptionStatus { negotiating, active, rejected, cancelled }

/// escrow: the app holds the customer's payment and releases the
/// captain's share in two halves (day 15/30). trusted: from the second
/// month onward, the customer can pay the captain directly and both sides
/// just confirm it happened in-app.
enum SubscriptionRenewalMode { escrow, trusted }

/// A monthly ride-with-this-customer arrangement, from the captain's side
/// (mirrors app-driver-customer's CaptainSubscription, with the customer's
/// identity instead of the captain's - a captain already knows their own
/// vehicle). One row per subscription thread; a captain can have several
/// at once, unlike a customer who's capped at one negotiation per captain
/// and one active subscription overall.
class CaptainSubscription {
  const CaptainSubscription({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.status,
    this.proposedPrice,
    this.proposedBy,
    this.agreedPrice,
    this.startedAt,
    this.expiresAt,
    this.payoutStatus,
    this.renewalMode = SubscriptionRenewalMode.escrow,
    this.cycleCount = 1,
    this.renewalWindowOpenedAt,
    this.customerConfirmedRenewalAt,
    this.captainConfirmedRenewalAt,
    this.paymentDispute = false,
    this.disputeReason,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final SubscriptionStatus status;
  final double? proposedPrice;
  final String? proposedBy;
  final double? agreedPrice;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? payoutStatus;
  final SubscriptionRenewalMode renewalMode;
  final int cycleCount;
  final DateTime? renewalWindowOpenedAt;
  final DateTime? customerConfirmedRenewalAt;
  final DateTime? captainConfirmedRenewalAt;
  final bool paymentDispute;
  final String? disputeReason;

  bool get isActive {
    final expiry = expiresAt;
    return status == SubscriptionStatus.active &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
  }

  bool get isNegotiating => status == SubscriptionStatus.negotiating;

  /// True once the customer has sent an offer this captain hasn't
  /// responded to yet with either an accept or a newer counter-offer of
  /// their own - what the incoming-offers list badges as needing a
  /// response.
  bool get hasPendingCustomerOffer =>
      isNegotiating && proposedPrice != null && proposedBy == 'customer';

  int? get daysRemaining {
    final expiry = expiresAt;
    if (expiry == null || !isActive) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  /// True once this cycle has expired in trusted mode and the app is
  /// waiting on this captain to confirm they were paid directly.
  bool get awaitingCaptainConfirmation =>
      status == SubscriptionStatus.active &&
      renewalMode == SubscriptionRenewalMode.trusted &&
      renewalWindowOpenedAt != null &&
      captainConfirmedRenewalAt == null;

  factory CaptainSubscription.fromJson(Map<String, dynamic> json) {
    final name = json['customer_name'] as String?;
    return CaptainSubscription(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: name == null || name.trim().isEmpty ? 'زبون' : name,
      customerPhone: json['customer_phone'] as String?,
      status: _statusFromString(json['status'] as String?),
      proposedPrice: (json['proposed_price'] as num?)?.toDouble(),
      proposedBy: json['proposed_by'] as String?,
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String).toLocal(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String).toLocal(),
      payoutStatus: json['payout_status'] as String?,
      renewalMode: (json['renewal_mode'] as String?) == 'trusted'
          ? SubscriptionRenewalMode.trusted
          : SubscriptionRenewalMode.escrow,
      cycleCount: (json['cycle_count'] as num?)?.toInt() ?? 1,
      renewalWindowOpenedAt: json['renewal_window_opened_at'] == null
          ? null
          : DateTime.parse(
              json['renewal_window_opened_at'] as String,
            ).toLocal(),
      customerConfirmedRenewalAt: json['customer_confirmed_renewal_at'] == null
          ? null
          : DateTime.parse(
              json['customer_confirmed_renewal_at'] as String,
            ).toLocal(),
      captainConfirmedRenewalAt: json['captain_confirmed_renewal_at'] == null
          ? null
          : DateTime.parse(
              json['captain_confirmed_renewal_at'] as String,
            ).toLocal(),
      paymentDispute: json['payment_dispute'] as bool? ?? false,
      disputeReason: json['dispute_reason'] as String?,
    );
  }

  static SubscriptionStatus _statusFromString(String? value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'rejected':
        return SubscriptionStatus.rejected;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'negotiating':
      default:
        return SubscriptionStatus.negotiating;
    }
  }
}

/// One chat bubble in a subscription negotiation thread (see
/// captain_subscription_messages, 20260812000056_captain_subscriptions.sql).
class SubscriptionMessage {
  const SubscriptionMessage({
    required this.id,
    required this.subscriptionId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    this.offerAmount,
    required this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String senderId;
  final String senderRole;
  final String body;
  final double? offerAmount;
  final DateTime createdAt;

  bool get isOffer => offerAmount != null;

  factory SubscriptionMessage.fromJson(Map<String, dynamic> json) {
    return SubscriptionMessage(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      body: json['body'] as String,
      offerAmount: (json['offer_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
