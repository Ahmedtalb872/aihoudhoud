import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../dummy_data/dummy_data.dart';
import '../core/supabase/auth_repository.dart';
import '../core/supabase/auth_exception.dart';
import '../core/services/new_trip_alert.dart';

class AppStateProvider extends ChangeNotifier {
  // Auth state
  bool _isLoggedIn = false;
  String? _userId;
  String _captainEmail = '';

  // Captain state
  bool _isCaptainOnline = false;
  String _captainName = DummyData.dummyCaptain.user.name;
  String _captainPhone = DummyData.dummyCaptain.user.phone;
  // 'car' or 'motorcycle' - derived from captains.vehicle_type at login
  // (motorcycle is just another value of that same column, not a separate
  // one). Only motorcycle captains can see/toggle delivery requests.
  String _vehicleCategory = 'car';
  bool _deliveryModeEnabled = false;
  double _captainWalletBalance = 1250.0;
  double _captainTodayEarnings = 425.0;
  int _captainTripsCount = DummyData.dummyCaptain.user.tripsCount;
  final List<WalletTransaction> _captainTransactions = List.from(
    DummyData.dummyCaptainTransactions,
  );

  // Active Trip states
  Trip? _activeTrip;
  Timer? _countdownTimer;
  int _countdownSeconds = 45;
  bool _isSearching = false;

  // Open ride live meter: flat 100 MRU covers the first 3 km. The 50
  // MRU/minute counter only starts once the captain either exceeds 3 km, or
  // sits idle (no GPS movement) for more than 5 minutes - not from second one.
  static const double openRideBaseFare = 100.0;
  static const double openRidePerMinuteRate = 50.0;
  static const double openRideFreeDistanceKm = 3.0;
  static const Duration openRideIdleThreshold = Duration(minutes: 5);
  DateTime? _openRideStartTime;
  DateTime? _openRideLastMovementTime;
  DateTime? _openRideMeterActivatedAt;
  double _openRideDistanceKm = 0.0;
  Timer? _openRideTicker;

  // Nudges the captain every couple of minutes to complete whatever step of
  // the active trip they're currently on, so a step doesn't get forgotten.
  Timer? _stepReminderTicker;
  DateTime? _tripStepStartedAt;

  // Chat state
  final List<Message> _chatMessages = List.from(DummyData.dummyMessages);

  // Trip history
  final List<Trip> _captainTripHistory = List.from(DummyData.dummyCaptainTrips);

  // Captain incoming request state: sourced live from the `trips` table
  // (real requests created by the customer app), while the captain is online.
  Trip? _incomingRequest;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingRidesSubscription;
  List<Map<String, dynamic>> _lastPendingRides = [];
  final Set<String> _ignoredRideIds = {};

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String get captainEmail => _captainEmail;

  bool get isCaptainOnline => _isCaptainOnline;
  String get captainName => _captainName;
  String get captainPhone => _captainPhone;
  String get vehicleCategory => _vehicleCategory;
  bool get isMotorcycleCaptain => _vehicleCategory == 'motorcycle';
  bool get deliveryModeEnabled => _deliveryModeEnabled;
  double get captainWalletBalance => _captainWalletBalance;
  double get captainTodayEarnings => _captainTodayEarnings;
  int get captainTripsCount => _captainTripsCount;
  List<WalletTransaction> get captainTransactions => _captainTransactions;

  Trip? get activeTrip => _activeTrip;
  int get countdownSeconds => _countdownSeconds;
  bool get isSearching => _isSearching;
  List<Message> get chatMessages => _chatMessages;

  List<Trip> get captainTripHistory => _captainTripHistory;

  Trip? get incomingRequest => _incomingRequest;

  Duration get openRideElapsed => _openRideStartTime == null
      ? Duration.zero
      : DateTime.now().difference(_openRideStartTime!);

  bool get isOpenRideMeterActive => _openRideMeterActivatedAt != null;

  // Time shown on the live "الوقت" stat: stays at zero until the meter
  // actually activates (>3km or >5min idle), so nothing appears to be
  // ticking/billing before that threshold is really met.
  Duration get openRideMeterElapsed => _openRideMeterActivatedAt == null
      ? Duration.zero
      : DateTime.now().difference(_openRideMeterActivatedAt!);

  double get openRideFare {
    if (_openRideMeterActivatedAt == null) return openRideBaseFare;
    final minutesSinceActivation =
        DateTime.now().difference(_openRideMeterActivatedAt!).inSeconds /
        60.0;
    return openRideBaseFare + minutesSinceActivation * openRidePerMinuteRate;
  }

  // Called whenever fresh GPS movement is reported, and once a second while
  // idle, so idle time (not just distance) can trigger the meter.
  void _checkOpenRideMeterActivation() {
    if (_openRideMeterActivatedAt != null) return;
    if (_openRideDistanceKm > openRideFreeDistanceKm) {
      _openRideMeterActivatedAt = DateTime.now();
      return;
    }
    if (_openRideLastMovementTime != null &&
        DateTime.now().difference(_openRideLastMovementTime!) >
            openRideIdleThreshold) {
      _openRideMeterActivatedAt = DateTime.now();
    }
  }

  // Reported by OpenRideActiveScreen on every real GPS position update.
  void updateOpenRideDistance(double totalDistanceKm) {
    _openRideDistanceKm = totalDistanceKm;
    _openRideLastMovementTime = DateTime.now();
    _checkOpenRideMeterActivation();
    notifyListeners();
  }

  // Hydrate state from a Supabase `profiles` row after a real sign-in/sign-up.
  // Callers are responsible for verifying profile['role'] == 'captain'
  // before calling this, since this app only serves captains.
  void loginFromProfile(
    Map<String, dynamic> profile,
    String email, {
    Map<String, dynamic>? captain,
  }) {
    _isLoggedIn = true;
    _userId = profile['id'] as String?;
    final String? fullName = profile['full_name'] as String?;
    final String? phone = profile['phone'] as String?;
    if (fullName != null && fullName.isNotEmpty) _captainName = fullName;
    if (phone != null && phone.isNotEmpty) _captainPhone = phone;
    _captainEmail = email;
    if (captain != null) {
      // Motorcycle isn't a separate column - it's just another value of
      // captains.vehicle_type (alongside economy/comfort/family for cars).
      _vehicleCategory = captain['vehicle_type'] == 'motorcycle'
          ? 'motorcycle'
          : 'car';
      _deliveryModeEnabled = captain['accepts_delivery'] as bool? ?? false;
    }
    notifyListeners();
  }

  // Re-hydrates an in-progress trip after the app process was killed and
  // relaunched mid-trip - active-trip state otherwise only lives here in
  // memory, so without this the captain would land back on the dashboard
  // with no sign their trip still exists, even though nothing changed
  // server-side. Call after loginFromProfile for an approved captain.
  Future<void> restoreActiveTripIfAny() async {
    final uid = _userId;
    if (uid == null || _activeTrip != null) return;
    try {
      final row = await AuthRepository().getActiveTripForCaptain(uid);
      if (row == null) return;
      await _hydrateActiveTripFromRow(row);
    } catch (_) {
      // Best-effort - worst case the captain has to be told to check their
      // trips manually; nothing here should block app startup.
    }
  }

  Future<void> _hydrateActiveTripFromRow(Map<String, dynamic> row) async {
    final tripId = row['id'] as String;
    String customerName = 'الزبون';
    String customerPhone = '';
    if (row['customer_id'] != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', row['customer_id'])
            .single();
        final name = profile['full_name'] as String?;
        final phone = profile['phone'] as String?;
        if (name != null && name.isNotEmpty) customerName = name;
        if (phone != null && phone.isNotEmpty) customerPhone = phone;
      } catch (_) {
        // Fall back to the generic label if the profile can't be read.
      }
    }
    if (customerPhone.isEmpty) {
      final guestPhone = row['guest_customer_phone'] as String?;
      if (guestPhone != null && guestPhone.isNotEmpty) {
        customerPhone = guestPhone;
      }
    }

    final serviceType = row['service_type'] as String? ?? 'ride';
    final isDelivery = serviceType == 'delivery';
    String? packageDescription;
    if (isDelivery) {
      final recipientName = row['recipient_name'] as String?;
      final recipientPhone = row['recipient_phone'] as String?;
      if (recipientName != null && recipientName.isNotEmpty) {
        customerName = recipientName;
      }
      if (recipientPhone != null && recipientPhone.isNotEmpty) {
        customerPhone = recipientPhone;
      }
      packageDescription = row['package_description'] as String?;
    }

    final pickupLat = (row['pickup_lat'] as num).toDouble();
    final pickupLng = (row['pickup_lng'] as num).toDouble();
    final destLat = (row['destination_lat'] as num?)?.toDouble();
    final destLng = (row['destination_lng'] as num?)?.toDouble();
    final isOpenRide = row['trip_type'] == 'open';

    final distanceKm = (row['distance_km'] as num?)?.toDouble() ?? 0.0;
    final durationMin =
        (row['estimated_duration_minutes'] as num?)?.toInt() ?? 0;
    final price = (row['estimated_price'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = row['payment_method'] == 'wallet'
        ? 'محفظة الهدهد'
        : 'نقداً';
    final vehicleType = switch (row['vehicle_type']) {
      'comfort' => VehicleType.comfort,
      'family' => VehicleType.family,
      _ => VehicleType.economy,
    };

    _activeTrip = Trip(
      id: tripId,
      customerName: customerName,
      customerPhone: customerPhone,
      captainName: _captainName,
      captainPhone: _captainPhone,
      pickupLocation: row['pickup_address'] as String? ?? 'موقع الانطلاق',
      destinationLocation: row['destination_address'] as String?,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distanceKm,
      duration: durationMin,
      price: isOpenRide ? openRideBaseFare : price,
      paymentMethod: paymentMethod,
      status: _mapDbTripStatus(row['status'] as String?),
      carType: vehicleType,
      isOpenRide: isOpenRide,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      isRemote: true,
      serviceType: serviceType,
      packageDescription: packageDescription,
    );
    _startStepReminder();
    notifyListeners();
  }

  TripStatus _mapDbTripStatus(String? dbStatus) {
    switch (dbStatus) {
      case 'arrived':
        return TripStatus.arrived;
      case 'in_progress':
      case 'boarded':
        return TripStatus.started;
      default:
        return TripStatus.accepted;
    }
  }

  // Reflects an edit made from CaptainEditInfoScreen locally, without a
  // full re-login: the display name shown in the drawer/profile header.
  void updateCaptainDisplayName(String name) {
    if (name.isEmpty) return;
    _captainName = name;
    notifyListeners();
  }

  // Reflects a vehicle-category change made from CaptainEditInfoScreen
  // locally. Switching away from motorcycle also turns delivery mode off
  // locally (the server-side accepts_delivery flag is irrelevant anyway
  // once vehicle_type isn't 'motorcycle', since both the RPC and RLS check
  // it - this just keeps the UI in sync without an extra round trip).
  void updateVehicleCategoryLocally(String vehicleType) {
    _vehicleCategory = vehicleType == 'motorcycle' ? 'motorcycle' : 'car';
    if (_vehicleCategory != 'motorcycle') _deliveryModeEnabled = false;
    notifyListeners();
  }

  // Motorcycle captains can opt in/out of receiving delivery requests
  // alongside their normal passenger requests. Has no effect for car
  // captains, who never see delivery requests regardless of this flag.
  void toggleDeliveryMode() {
    if (!isMotorcycleCaptain) return;
    _deliveryModeEnabled = !_deliveryModeEnabled;
    notifyListeners();
    if (_userId != null) {
      AuthRepository().setAcceptsDelivery(_userId!, _deliveryModeEnabled);
    }
  }

  void logout() {
    _isLoggedIn = false;
    _userId = null;
    _captainEmail = '';
    _vehicleCategory = 'car';
    _deliveryModeEnabled = false;
    _activeTrip = null;
    _isSearching = false;
    _isCaptainOnline = false;
    _countdownTimer?.cancel();
    _unsubscribeFromPendingRides();
    _openRideTicker?.cancel();
    _openRideStartTime = null;
    _openRideLastMovementTime = null;
    _openRideMeterActivatedAt = null;
    _openRideDistanceKm = 0.0;
    notifyListeners();
    AuthRepository().signOut().catchError((_) {});
  }

  // Captain Switch Online/Offline
  void toggleCaptainOnline() {
    _isCaptainOnline = !_isCaptainOnline;
    if (!_isCaptainOnline) {
      _incomingRequest = null;
      _countdownTimer?.cancel();
      _unsubscribeFromPendingRides();
    } else {
      _subscribeToPendingRides();
    }
    if (_userId != null) {
      AuthRepository().setCaptainOnline(_userId!, _isCaptainOnline);
    }
    notifyListeners();
  }

  // Used when a captain accepts a ride browsed from the open trips list.
  // Open rides have no destination: the customer didn't specify one, and the
  // final fare is metered live once the trip starts (see openRideFare).
  void requestTrip({
    required String customerName,
    required String customerPhone,
    required String pickup,
    String? destination,
    required double pickupLat,
    required double pickupLng,
    double? destLat,
    double? destLng,
    required double distance,
    required int duration,
    required double price,
    required VehicleType carType,
    required bool isOpenRide,
    required int timeoutSeconds,
    required String paymentMethod,
  }) {
    _isSearching = true;
    _countdownSeconds = timeoutSeconds;

    _activeTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickup,
      destinationLocation: destination,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distance,
      duration: duration,
      price: price,
      paymentMethod: paymentMethod,
      status: TripStatus.searching,
      carType: carType,
      isOpenRide: isOpenRide,
      openRideTimeout: timeoutSeconds,
      date: DateTime.now().toString().substring(0, 16),
    );

    notifyListeners();

    // Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();

        // Auto-accept trip simulation at 35 seconds (10s passed) if the countdown is running
        if (timeoutSeconds - _countdownSeconds == 8) {
          _simulateCaptainAccepted();
        }
      } else {
        // Countdown expired without acceptance
        timer.cancel();
        _isSearching = false;
        if (_activeTrip != null &&
            _activeTrip!.status == TripStatus.searching) {
          _activeTrip!.status = TripStatus.pending; // Expired/Pending
        }
        notifyListeners();
      }
    });
  }

  // Simulator helper: marks the just-requested open ride as accepted
  void _simulateCaptainAccepted() {
    _countdownTimer?.cancel();
    _isSearching = false;
    if (_activeTrip != null) {
      _activeTrip = Trip(
        id: _activeTrip!.id,
        customerName: _activeTrip!.customerName,
        customerPhone: _activeTrip!.customerPhone,
        captainName: _captainName,
        captainPhone: _captainPhone,
        vehicleName:
            '${DummyData.dummyCaptain.vehicle.brand} ${DummyData.dummyCaptain.vehicle.model} ${DummyData.dummyCaptain.vehicle.year}',
        vehiclePlate: DummyData.dummyCaptain.vehicle.plate,
        pickupLocation: _activeTrip!.pickupLocation,
        destinationLocation: _activeTrip!.destinationLocation,
        pickupLat: _activeTrip!.pickupLat,
        pickupLng: _activeTrip!.pickupLng,
        destLat: _activeTrip!.destLat,
        destLng: _activeTrip!.destLng,
        distance: _activeTrip!.distance,
        duration: _activeTrip!.duration,
        price: _activeTrip!.price,
        paymentMethod: _activeTrip!.paymentMethod,
        status: TripStatus.accepted,
        carType: _activeTrip!.carType,
        isOpenRide: _activeTrip!.isOpenRide,
        openRideTimeout: _activeTrip!.openRideTimeout,
        date: _activeTrip!.date,
      );
      notifyListeners();

      // Simulate the captain's progress toward pickup:
      // accepted -> enRoute (after 4s) -> arrived (after 9s)
      Timer(const Duration(seconds: 4), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
          _activeTrip!.status = TripStatus.enRoute;
          notifyListeners();
        }
      });

      Timer(const Duration(seconds: 9), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.enRoute) {
          _activeTrip!.status = TripStatus.arrived;
          notifyListeners();
        }
      });
    }
  }

  // Captain Trip Booking Lifecycle (real incoming requests while online,
  // sourced live from the `trips` table via Supabase Realtime - this is
  // the table the customer app actually writes to; `rides` is unused).
  void _subscribeToPendingRides() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = Supabase.instance.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .order('requested_at', ascending: true)
        .listen((rows) {
          _lastPendingRides = rows;
          _maybeShowNextPendingRide();
        });
  }

  void _unsubscribeFromPendingRides() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = null;
    _lastPendingRides = [];
    _ignoredRideIds.clear();
  }

  bool _isIgnoredByMe(Map<String, dynamic> row) {
    final ignoredBy = row['ignored_by'];
    final uid = _userId;
    if (uid == null || ignoredBy is! List) return false;
    return ignoredBy.contains(uid);
  }

  void _maybeShowNextPendingRide() {
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }
    for (final row in _lastPendingRides) {
      final id = row['id'] as String;
      final serviceType = row['service_type'] as String? ?? 'ride';
      // Delivery requests only ever reach a motorcycle captain who has
      // opted in - a car captain (or one with delivery mode off) skips
      // past them entirely, no matter their online status.
      if (serviceType == 'delivery' &&
          !(isMotorcycleCaptain && _deliveryModeEnabled)) {
        continue;
      }
      if (row['captain_id'] == null &&
          !_ignoredRideIds.contains(id) &&
          !_isIgnoredByMe(row)) {
        _showPendingRide(row);
        return;
      }
    }
  }

  Future<void> _showPendingRide(Map<String, dynamic> row) async {
    final String tripId = row['id'] as String;
    String customerName = 'زبون جديد';
    String customerPhone = '';
    if (row['customer_id'] != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', row['customer_id'])
            .single();
        final name = profile['full_name'] as String?;
        final phone = profile['phone'] as String?;
        if (name != null && name.isNotEmpty) customerName = name;
        if (phone != null && phone.isNotEmpty) customerPhone = phone;
      } catch (_) {
        // Fall back to the generic label if the profile can't be read.
      }
    }
    // Guest customers (no account) have their number on the trip itself.
    if (customerPhone.isEmpty) {
      final guestPhone = row['guest_customer_phone'] as String?;
      if (guestPhone != null && guestPhone.isNotEmpty) {
        customerPhone = guestPhone;
      }
    }

    final serviceType = row['service_type'] as String? ?? 'ride';
    final isDelivery = serviceType == 'delivery';
    String? packageDescription;
    if (isDelivery) {
      // A delivery's contact is the recipient, not the sender - reuse the
      // same customerName/customerPhone fields the call/chat UI already
      // reads, so nothing downstream needs to know the difference.
      final recipientName = row['recipient_name'] as String?;
      final recipientPhone = row['recipient_phone'] as String?;
      if (recipientName != null && recipientName.isNotEmpty) {
        customerName = recipientName;
      }
      if (recipientPhone != null && recipientPhone.isNotEmpty) {
        customerPhone = recipientPhone;
      }
      packageDescription = row['package_description'] as String?;
    }

    // The captain may have gone offline, or picked up another trip, while
    // the profile lookup above was in flight.
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }

    final pickupLat = (row['pickup_lat'] as num).toDouble();
    final pickupLng = (row['pickup_lng'] as num).toDouble();
    final destLat = (row['destination_lat'] as num?)?.toDouble();
    final destLng = (row['destination_lng'] as num?)?.toDouble();
    final isOpenRide = row['trip_type'] == 'open';

    double distanceKm = (row['distance_km'] as num?)?.toDouble() ?? 0.0;
    if (distanceKm == 0.0 && destLat != null && destLng != null) {
      distanceKm =
          Geolocator.distanceBetween(pickupLat, pickupLng, destLat, destLng) /
          1000;
    }
    int durationMin = (row['estimated_duration_minutes'] as num?)?.toInt() ?? 0;
    if (durationMin == 0) {
      // No routing engine available: roughly estimate 2 minutes per km.
      durationMin = (distanceKm * 2).round().clamp(1, 999);
    }
    final price = (row['estimated_price'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = row['payment_method'] == 'wallet'
        ? 'محفظة الهدهد'
        : 'نقداً';
    final vehicleType = switch (row['vehicle_type']) {
      'comfort' => VehicleType.comfort,
      'family' => VehicleType.family,
      _ => VehicleType.economy,
    };

    _countdownSeconds = 45;
    _incomingRequest = Trip(
      id: tripId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: row['pickup_address'] as String? ?? 'موقع الانطلاق',
      destinationLocation: row['destination_address'] as String?,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distanceKm,
      duration: durationMin,
      price: isOpenRide ? openRideBaseFare : price,
      paymentMethod: paymentMethod,
      status: TripStatus.searching,
      carType: vehicleType,
      isOpenRide: isOpenRide,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      isRemote: true,
      serviceType: serviceType,
      packageDescription: packageDescription,
    );
    notifyListeners();
    NewTripAlert.play(
      customerName: customerName,
      pickup: _incomingRequest!.pickupLocation,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (_incomingRequest?.id == tripId) {
          _ignoredRideIds.add(tripId);
          _markIgnoredOnServer(row);
          _incomingRequest = null;
          notifyListeners();
          _maybeShowNextPendingRide();
        }
      }
    });
  }

  // Appends this captain to the trip's `ignored_by` array so it doesn't
  // resurface for them again, without claiming it for anyone else.
  void _markIgnoredOnServer(Map<String, dynamic> row) {
    final uid = _userId;
    if (uid == null) return;
    final current = (row['ignored_by'] as List?)?.cast<String>() ?? [];
    if (current.contains(uid)) return;
    Supabase.instance.client
        .from('trips')
        .update({
          'ignored_by': [...current, uid],
        })
        .eq('id', row['id'])
        .catchError((_) {});
  }

  // Returns an Arabic error message on failure (e.g. someone else claimed
  // the trip first, or the captain went offline in the meantime) so the UI
  // can show it - null means the trip was accepted successfully.
  Future<String?> acceptIncomingRequest() async {
    _countdownTimer?.cancel();
    final request = _incomingRequest;
    if (request == null) return null;
    _incomingRequest = null;
    notifyListeners();

    if (request.isRemote) {
      final uid = _userId;
      if (uid == null) return null;
      try {
        // Atomic, server-checked claim: captain_accept_trip() re-verifies
        // the captain is approved/online (and, for a delivery, a motorcycle
        // captain with accepts_delivery on) before handing the trip over -
        // it raises if someone else claimed it first or the captain isn't
        // eligible, either of which just means moving on to the next one.
        await AuthRepository().acceptTrip(request.id);
      } on AppAuthException catch (e) {
        _maybeShowNextPendingRide();
        return e.message;
      } catch (_) {
        _maybeShowNextPendingRide();
        return 'تعذر قبول الطلب، حاول مرة أخرى.';
      }
    }

    _activeTrip = Trip(
      id: request.id,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      captainName: _captainName,
      captainPhone: _captainPhone,
      vehicleName:
          '${DummyData.dummyCaptain.vehicle.brand} ${DummyData.dummyCaptain.vehicle.model} ${DummyData.dummyCaptain.vehicle.year}',
      vehiclePlate: DummyData.dummyCaptain.vehicle.plate,
      pickupLocation: request.pickupLocation,
      destinationLocation: request.destinationLocation,
      pickupLat: request.pickupLat,
      pickupLng: request.pickupLng,
      destLat: request.destLat,
      destLng: request.destLng,
      distance: request.distance,
      duration: request.duration,
      price: request.price,
      paymentMethod: request.paymentMethod,
      status: TripStatus.accepted,
      carType: request.carType,
      isOpenRide: request.isOpenRide,
      openRideTimeout: request.openRideTimeout,
      date: request.date,
      isRemote: request.isRemote,
      serviceType: request.serviceType,
      packageDescription: request.packageDescription,
    );
    _startStepReminder();
    notifyListeners();
    return null;
  }

  void ignoreIncomingRequest() {
    _countdownTimer?.cancel();
    if (_incomingRequest != null) {
      final id = _incomingRequest!.id;
      _ignoredRideIds.add(id);
      if (_incomingRequest!.isRemote) {
        final row = _lastPendingRides.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['id'] == id,
          orElse: () => null,
        );
        if (row != null) _markIgnoredOnServer(row);
      }
    }
    _incomingRequest = null;
    notifyListeners();
    _maybeShowNextPendingRide();
  }

  void captainArriveAtPickup() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
      _activeTrip!.status = TripStatus.arrived;
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'arrived',
          extra: {'arrived_at': DateTime.now().toIso8601String()},
        );
      }
      _startStepReminder();
      notifyListeners();
    }
  }

  void captainStartActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.arrived) {
      _activeTrip!.status = TripStatus.started;
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          _activeTrip!.isOpenRide ? 'boarded' : 'in_progress',
          extra: {
            if (_activeTrip!.isOpenRide)
              'boarded_at': DateTime.now().toIso8601String()
            else
              'started_at': DateTime.now().toIso8601String(),
          },
        );
      }
      if (_activeTrip!.isOpenRide) {
        _openRideStartTime = DateTime.now();
        _openRideLastMovementTime = DateTime.now();
        _openRideMeterActivatedAt = null;
        _openRideDistanceKm = 0.0;
        _openRideTicker?.cancel();
        _openRideTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          _checkOpenRideMeterActivation();
          notifyListeners();
        });
      }
      _startStepReminder();
      notifyListeners();
    }
  }

  // The captain enters what was actually collected from the customer in
  // cash, which may differ from the estimated fare shown during the trip.
  void captainCompleteActiveTrip({required double amountPaid}) {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        !_activeTrip!.isOpenRide) {
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'completed',
          extra: {
            'completed_at': DateTime.now().toIso8601String(),
            'final_price': amountPaid,
          },
        );
      }
      _stopStepReminder();
      _finalizeCompletedTrip(amountPaid);
    }
  }

  // Fire-and-forget: keeps the customer app's copy of the trip in sync.
  // Local captain state has already moved on by the time this resolves, so
  // failures here don't need to roll anything back - just log and continue.
  void _updateRemoteTripStatus(
    String tripId,
    String status, {
    Map<String, dynamic>? extra,
  }) {
    Supabase.instance.client
        .from('trips')
        .update({'status': status, ...?extra})
        .eq('id', tripId)
        .catchError((_) {});
  }

  void _startStepReminder() {
    _stepReminderTicker?.cancel();
    _tripStepStartedAt = DateTime.now();
    _stepReminderTicker = Timer.periodic(const Duration(minutes: 2), (_) {
      final trip = _activeTrip;
      if (trip == null ||
          trip.status == TripStatus.completed ||
          trip.status == TripStatus.cancelled) {
        _stopStepReminder();
        return;
      }
      // While actually driving to the destination, don't nag to finish the
      // trip before the estimated trip time has even passed - only "did you
      // arrive"/"did the customer board" steps should chase every 2 minutes
      // regardless of estimate, since those should happen quickly.
      if (trip.status == TripStatus.started && !trip.isOpenRide) {
        final elapsed = _tripStepStartedAt == null
            ? Duration.zero
            : DateTime.now().difference(_tripStepStartedAt!);
        if (elapsed < Duration(minutes: trip.duration)) return;
      }
      NewTripAlert.playStepReminder(_stepReminderMessage());
    });
  }

  void _stopStepReminder() {
    _stepReminderTicker?.cancel();
    _stepReminderTicker = null;
    _tripStepStartedAt = null;
  }

  String _stepReminderMessage() {
    final trip = _activeTrip;
    if (trip == null) return 'لا تنسَ إكمال خطوات المشوار الحالي.';
    final isDelivery = trip.isDelivery;
    switch (trip.status) {
      case TripStatus.accepted:
        return isDelivery
            ? 'لا تنسَ التوجه إلى نقطة الاستلام وتحديث حالة الطلب.'
            : 'لا تنسَ التوجه إلى نقطة الانطلاق وتحديث حالة الطلب.';
      case TripStatus.arrived:
        return isDelivery
            ? 'اضغط "تم استلام الطرد" لمتابعة التوصيل.'
            : 'اضغط "بدء الرحلة الجارية" لمتابعة المشوار.';
      case TripStatus.started:
        return isDelivery
            ? 'اضغط "تم التسليم" فور تسليم الطرد للزبون.'
            : 'اضغط "إنهاء الرحلة بنجاح" فور الوصول للوجهة.';
      default:
        return 'لا تنسَ إكمال خطوات المشوار الحالي.';
    }
  }

  // Ends an open ride: there's no destination to arrive at, so the captain
  // decides when it's over and the fare is whatever the live meter shows.
  void captainCompleteOpenRide({
    double distanceKm = 0,
    required double amountPaid,
  }) {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        _activeTrip!.isOpenRide) {
      final elapsedMinutes = (openRideElapsed.inSeconds / 60.0).round();
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'completed',
          extra: {
            'completed_at': DateTime.now().toIso8601String(),
            'final_price': amountPaid,
            'traveled_distance_km': distanceKm,
          },
        );
      }
      _activeTrip = Trip(
        id: _activeTrip!.id,
        customerName: _activeTrip!.customerName,
        customerPhone: _activeTrip!.customerPhone,
        captainName: _activeTrip!.captainName,
        captainPhone: _activeTrip!.captainPhone,
        captainAvatar: _activeTrip!.captainAvatar,
        vehicleName: _activeTrip!.vehicleName,
        vehiclePlate: _activeTrip!.vehiclePlate,
        pickupLocation: _activeTrip!.pickupLocation,
        destinationLocation: _activeTrip!.destinationLocation,
        pickupLat: _activeTrip!.pickupLat,
        pickupLng: _activeTrip!.pickupLng,
        destLat: _activeTrip!.destLat,
        destLng: _activeTrip!.destLng,
        distance: distanceKm,
        duration: elapsedMinutes,
        price: _activeTrip!.price,
        paymentMethod: _activeTrip!.paymentMethod,
        status: _activeTrip!.status,
        carType: _activeTrip!.carType,
        isOpenRide: _activeTrip!.isOpenRide,
        openRideTimeout: _activeTrip!.openRideTimeout,
        date: _activeTrip!.date,
        isRemote: _activeTrip!.isRemote,
        serviceType: _activeTrip!.serviceType,
        packageDescription: _activeTrip!.packageDescription,
      );
      _stopStepReminder();
      _finalizeCompletedTrip(amountPaid);
      _openRideTicker?.cancel();
      _openRideTicker = null;
      _openRideStartTime = null;
      _openRideLastMovementTime = null;
      _openRideMeterActivatedAt = null;
      _openRideDistanceKm = 0.0;
    }
  }

  void _finalizeCompletedTrip(double price) {
    _activeTrip!.status = TripStatus.completed;

    // Calculate earnings (85% net, 15% commission)
    double commission = double.parse((price * 0.15).toStringAsFixed(1));
    double net = price - commission;
    String destinationLabel = _activeTrip!.destinationLocation ?? 'مشوار مفتوح';

    Trip finishedTrip = Trip(
      id: _activeTrip!.id,
      customerName: _activeTrip!.customerName,
      customerPhone: _activeTrip!.customerPhone,
      pickupLocation: _activeTrip!.pickupLocation,
      destinationLocation: _activeTrip!.destinationLocation,
      pickupLat: _activeTrip!.pickupLat,
      pickupLng: _activeTrip!.pickupLng,
      destLat: _activeTrip!.destLat,
      destLng: _activeTrip!.destLng,
      distance: _activeTrip!.distance,
      duration: _activeTrip!.duration,
      price: price,
      paymentMethod: _activeTrip!.paymentMethod,
      status: TripStatus.completed,
      carType: _activeTrip!.carType,
      isOpenRide: _activeTrip!.isOpenRide,
      openRideTimeout: _activeTrip!.openRideTimeout,
      date: _activeTrip!.date,
      netEarnings: net,
      commission: commission,
      isRemote: _activeTrip!.isRemote,
      serviceType: _activeTrip!.serviceType,
      packageDescription: _activeTrip!.packageDescription,
    );

    _captainTripHistory.insert(0, finishedTrip);

    _captainWalletBalance += net;
    _captainTodayEarnings += net;
    _captainTripsCount += 1;

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        amount: net,
        type: TransactionType.charge,
        title: 'صافي أرباح رحلة إلى $destinationLabel',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_comm_${DateTime.now().millisecondsSinceEpoch}',
        amount: commission,
        type: TransactionType.commission,
        title: 'عمولة رحلة إلى $destinationLabel',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: false,
      ),
    );

    notifyListeners();
  }

  // Captain cancels an already-accepted trip (before or during it), with a
  // reason recorded for the trip history.
  void captainCancelActiveTrip(String reason) {
    if (_activeTrip == null) return;

    if (_activeTrip!.isRemote) {
      _updateRemoteTripStatus(
        _activeTrip!.id,
        'cancelled',
        extra: {
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_by': 'captain',
          'cancellation_reason': reason,
        },
      );
    }

    final cancelledTrip = Trip(
      id: _activeTrip!.id,
      customerName: _activeTrip!.customerName,
      customerPhone: _activeTrip!.customerPhone,
      captainName: _activeTrip!.captainName,
      captainPhone: _activeTrip!.captainPhone,
      captainAvatar: _activeTrip!.captainAvatar,
      vehicleName: _activeTrip!.vehicleName,
      vehiclePlate: _activeTrip!.vehiclePlate,
      pickupLocation: _activeTrip!.pickupLocation,
      destinationLocation: _activeTrip!.destinationLocation,
      pickupLat: _activeTrip!.pickupLat,
      pickupLng: _activeTrip!.pickupLng,
      destLat: _activeTrip!.destLat,
      destLng: _activeTrip!.destLng,
      distance: _activeTrip!.distance,
      duration: _activeTrip!.duration,
      price: _activeTrip!.price,
      paymentMethod: _activeTrip!.paymentMethod,
      status: TripStatus.cancelled,
      carType: _activeTrip!.carType,
      isOpenRide: _activeTrip!.isOpenRide,
      openRideTimeout: _activeTrip!.openRideTimeout,
      date: _activeTrip!.date,
      cancellationReason: reason,
      isRemote: _activeTrip!.isRemote,
      serviceType: _activeTrip!.serviceType,
      packageDescription: _activeTrip!.packageDescription,
    );

    _captainTripHistory.insert(0, cancelledTrip);

    _activeTrip = null;
    _isSearching = false;
    _countdownTimer?.cancel();
    _stopStepReminder();
    _openRideTicker?.cancel();
    _openRideTicker = null;
    _openRideStartTime = null;
    _openRideLastMovementTime = null;
    _openRideMeterActivatedAt = null;
    _openRideDistanceKm = 0.0;
    notifyListeners();

    // Ready for the next request if still online
    _maybeShowNextPendingRide();
  }

  void confirmCaptainSummary() {
    _activeTrip = null;
    notifyListeners();
    // Ready for next request if online
    _maybeShowNextPendingRide();
  }

  // Reflects a successful WalletRepository.redeemGiftCredits() call: the
  // redemption itself already happened server-side, this just updates the
  // locally-tracked wallet balance/history to match.
  void creditWalletFromGiftRedemption(double amount) {
    _captainWalletBalance += amount;
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_gift_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        type: TransactionType.reward,
        title: 'تحويل من مكافأتي',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    notifyListeners();
  }

  // Messaging / Chatting with the customer on the active trip
  void sendChatMessage(String content) {
    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'cap_1',
      senderName: _captainName,
      content: content,
      time: 'الآن',
      isMe: true,
    );
    _chatMessages.add(newMessage);
    notifyListeners();

    // Mock an automatic reply from the customer after 2 seconds
    Timer(const Duration(seconds: 2), () {
      final replyMessage = Message(
        id: 'msg_rep_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'cust_1',
        senderName: _activeTrip?.customerName ?? 'الزبون',
        content: 'بإذن الله، أنا في مكان الاتفاق.',
        time: 'الآن',
        isMe: false,
      );
      _chatMessages.add(replyMessage);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pendingRidesSubscription?.cancel();
    _openRideTicker?.cancel();
    _stepReminderTicker?.cancel();
    super.dispose();
  }
}
