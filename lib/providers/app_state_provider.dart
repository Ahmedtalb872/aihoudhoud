import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../dummy_data/dummy_data.dart';
import '../core/supabase/auth_repository.dart';
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
  double _captainWalletBalance = 1250.0;
  double _captainTodayEarnings = 425.0;
  int _captainTripsCount = DummyData.dummyCaptain.user.tripsCount;
  final List<WalletTransaction> _captainTransactions = List.from(
    DummyData.dummyCaptainTransactions,
  );
  final Map<String, String> _captainDocsStatus = Map.from(
    DummyData.dummyCaptain.documentsStatus,
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

  // Chat state
  final List<Message> _chatMessages = List.from(DummyData.dummyMessages);

  // Trip history
  final List<Trip> _captainTripHistory = List.from(DummyData.dummyCaptainTrips);

  // Captain incoming request state: sourced live from the `rides` table
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
  double get captainWalletBalance => _captainWalletBalance;
  double get captainTodayEarnings => _captainTodayEarnings;
  int get captainTripsCount => _captainTripsCount;
  List<WalletTransaction> get captainTransactions => _captainTransactions;
  Map<String, String> get captainDocsStatus => _captainDocsStatus;

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
  void loginFromProfile(Map<String, dynamic> profile, String email) {
    _isLoggedIn = true;
    _userId = profile['id'] as String?;
    final String? fullName = profile['full_name'] as String?;
    final String? phone = profile['phone'] as String?;
    if (fullName != null && fullName.isNotEmpty) _captainName = fullName;
    if (phone != null && phone.isNotEmpty) _captainPhone = phone;
    _captainEmail = email;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _userId = null;
    _captainEmail = '';
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
  // sourced live from the `rides` table via Supabase Realtime).
  void _subscribeToPendingRides() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = Supabase.instance.client
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: true)
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

  void _maybeShowNextPendingRide() {
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }
    for (final row in _lastPendingRides) {
      final id = row['id'] as String;
      if (row['driver_id'] == null && !_ignoredRideIds.contains(id)) {
        _showPendingRide(row);
        return;
      }
    }
  }

  Future<void> _showPendingRide(Map<String, dynamic> row) async {
    final String rideId = row['id'] as String;
    String customerName = 'زبون جديد';
    String customerPhone = '';
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

    // The captain may have gone offline, or picked up another trip, while
    // the profile lookup above was in flight.
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }

    final pickupLat = (row['pickup_lat'] as num).toDouble();
    final pickupLng = (row['pickup_lng'] as num).toDouble();
    final dropLat = (row['dropoff_lat'] as num).toDouble();
    final dropLng = (row['dropoff_lng'] as num).toDouble();
    final distanceKm =
        Geolocator.distanceBetween(pickupLat, pickupLng, dropLat, dropLng) /
        1000;
    // No routing engine available yet: roughly estimate 2 minutes per km.
    final durationMin = (distanceKm * 2).round().clamp(1, 999);
    final price = (row['price_estimate'] as num?)?.toDouble() ?? 0.0;

    _countdownSeconds = 45;
    _incomingRequest = Trip(
      id: rideId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: row['pickup_address'] as String? ?? 'موقع الانطلاق',
      destinationLocation: row['dropoff_address'] as String?,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: dropLat,
      destLng: dropLng,
      distance: distanceKm,
      duration: durationMin,
      price: price,
      paymentMethod: 'نقداً',
      status: TripStatus.searching,
      carType: VehicleType.economy,
      isOpenRide: false,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      isRemote: true,
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
        if (_incomingRequest?.id == rideId) {
          _ignoredRideIds.add(rideId);
          _incomingRequest = null;
          notifyListeners();
          _maybeShowNextPendingRide();
        }
      }
    });
  }

  Future<void> acceptIncomingRequest() async {
    _countdownTimer?.cancel();
    final request = _incomingRequest;
    if (request == null) return;
    _incomingRequest = null;
    notifyListeners();

    if (request.isRemote) {
      final uid = _userId;
      if (uid == null) return;
      try {
        final claimed = await Supabase.instance.client
            .from('rides')
            .update({'driver_id': uid, 'status': 'accepted'})
            .eq('id', request.id)
            .eq('status', 'pending')
            .select();
        if (claimed.isEmpty) {
          // Another captain claimed it first; move on to the next request.
          _maybeShowNextPendingRide();
          return;
        }
      } catch (_) {
        _maybeShowNextPendingRide();
        return;
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
    );
    notifyListeners();
  }

  void ignoreIncomingRequest() {
    _countdownTimer?.cancel();
    if (_incomingRequest != null) {
      _ignoredRideIds.add(_incomingRequest!.id);
    }
    _incomingRequest = null;
    notifyListeners();
    _maybeShowNextPendingRide();
  }

  void captainArriveAtPickup() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
      _activeTrip!.status = TripStatus.arrived;
      notifyListeners();
    }
  }

  void captainStartActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.arrived) {
      _activeTrip!.status = TripStatus.started;
      if (_activeTrip!.isRemote) {
        _updateRemoteRideStatus(_activeTrip!.id, 'in_progress');
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
      notifyListeners();
    }
  }

  void captainCompleteActiveTrip() {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        !_activeTrip!.isOpenRide) {
      if (_activeTrip!.isRemote) {
        _updateRemoteRideStatus(_activeTrip!.id, 'completed');
      }
      _finalizeCompletedTrip(_activeTrip!.price);
    }
  }

  // Fire-and-forget: keeps the customer app's copy of the ride in sync.
  // Local captain state has already moved on by the time this resolves, so
  // failures here don't need to roll anything back - just log and continue.
  void _updateRemoteRideStatus(String rideId, String status) {
    Supabase.instance.client
        .from('rides')
        .update({'status': status})
        .eq('id', rideId)
        .catchError((_) {});
  }

  // Ends an open ride: there's no destination to arrive at, so the captain
  // decides when it's over and the fare is whatever the live meter shows.
  void captainCompleteOpenRide({double distanceKm = 0}) {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        _activeTrip!.isOpenRide) {
      final elapsedMinutes = (openRideElapsed.inSeconds / 60.0).round();
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
      );
      _finalizeCompletedTrip(openRideFare);
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
      _updateRemoteRideStatus(_activeTrip!.id, 'cancelled');
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
    );

    _captainTripHistory.insert(0, cancelledTrip);

    _activeTrip = null;
    _isSearching = false;
    _countdownTimer?.cancel();
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

  // Wallet operations
  void rechargeWallet(double amount, String method) {
    _captainWalletBalance += amount;
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_rch_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        type: TransactionType.charge,
        title: 'شحن رصيد الكابتن بواسطة $method',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    notifyListeners();
  }

  void withdrawCaptainEarnings(double amount) {
    if (amount <= _captainWalletBalance) {
      _captainWalletBalance -= amount;
      _captainTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_wdr_${DateTime.now().millisecondsSinceEpoch}',
          amount: amount,
          type: TransactionType.withdraw,
          title: 'سحب رصيد الأرباح إلى Bankily',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: false,
        ),
      );
      notifyListeners();
    }
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

  // Update Captain doc status
  void updateCaptainDoc(String docKey, String newStatus) {
    _captainDocsStatus[docKey] = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pendingRidesSubscription?.cancel();
    _openRideTicker?.cancel();
    super.dispose();
  }
}
