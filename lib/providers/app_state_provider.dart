import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../dummy_data/dummy_data.dart';
import '../core/supabase/auth_repository.dart';

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

  // Chat state
  final List<Message> _chatMessages = List.from(DummyData.dummyMessages);

  // Trip history
  final List<Trip> _captainTripHistory = List.from(DummyData.dummyCaptainTrips);

  // Captain incoming request state (when captain is online, show mock incoming requests)
  Trip? _incomingRequest;
  Timer? _incomingRequestTimer;

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

  // Hydrate state from a Supabase `profiles` row after a real sign-in/sign-up.
  // Callers are responsible for verifying profile['user_type'] == 'captain'
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
    _countdownTimer?.cancel();
    _incomingRequestTimer?.cancel();
    notifyListeners();
    AuthRepository().signOut().catchError((_) {});
  }

  // Captain Switch Online/Offline
  void toggleCaptainOnline() {
    _isCaptainOnline = !_isCaptainOnline;
    if (!_isCaptainOnline) {
      _incomingRequest = null;
      _incomingRequestTimer?.cancel();
    } else {
      // Simulate an incoming request after 5 seconds if online
      _startSimulatedIncomingRequest();
    }
    notifyListeners();
  }

  // Used when a captain accepts a ride browsed from the open trips list.
  void requestTrip({
    required String customerName,
    required String customerPhone,
    required String pickup,
    required String destination,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
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

  // Captain Trip Booking Lifecycle (incoming requests while online)
  void _startSimulatedIncomingRequest() {
    _incomingRequestTimer?.cancel();
    _incomingRequestTimer = Timer(const Duration(seconds: 4), () {
      if (_isCaptainOnline && _activeTrip == null && _incomingRequest == null) {
        _countdownSeconds = 45;
        _incomingRequest = Trip(
          id: 'trip_incoming_${DateTime.now().millisecondsSinceEpoch}',
          customerName: 'فاطمة منت محمد',
          customerPhone: '+22247777777',
          pickupLocation: 'تفرغ زينة (سوبرماركت النخيل)',
          destinationLocation: 'تيارت (كارفور عين الطلح)',
          pickupLat: 18.1065,
          pickupLng: -15.9664,
          destLat: 18.1255,
          destLng: -15.9288,
          distance: 6.8,
          duration: 15,
          price: 220.0,
          paymentMethod: 'نقداً',
          status: TripStatus.searching,
          carType: VehicleType.economy,
          isOpenRide: true,
          openRideTimeout: 45,
          date: DateTime.now().toString().substring(0, 16),
        );
        notifyListeners();

        // Count down for captain accept
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_countdownSeconds > 0) {
            _countdownSeconds--;
            notifyListeners();
          } else {
            timer.cancel();
            _incomingRequest = null;
            notifyListeners();
          }
        });
      }
    });
  }

  void acceptIncomingRequest() {
    _countdownTimer?.cancel();
    if (_incomingRequest != null) {
      _activeTrip = Trip(
        id: _incomingRequest!.id,
        customerName: _incomingRequest!.customerName,
        customerPhone: _incomingRequest!.customerPhone,
        captainName: _captainName,
        captainPhone: _captainPhone,
        vehicleName:
            '${DummyData.dummyCaptain.vehicle.brand} ${DummyData.dummyCaptain.vehicle.model} ${DummyData.dummyCaptain.vehicle.year}',
        vehiclePlate: DummyData.dummyCaptain.vehicle.plate,
        pickupLocation: _incomingRequest!.pickupLocation,
        destinationLocation: _incomingRequest!.destinationLocation,
        pickupLat: _incomingRequest!.pickupLat,
        pickupLng: _incomingRequest!.pickupLng,
        destLat: _incomingRequest!.destLat,
        destLng: _incomingRequest!.destLng,
        distance: _incomingRequest!.distance,
        duration: _incomingRequest!.duration,
        price: _incomingRequest!.price,
        paymentMethod: _incomingRequest!.paymentMethod,
        status: TripStatus.accepted,
        carType: _incomingRequest!.carType,
        isOpenRide: _incomingRequest!.isOpenRide,
        openRideTimeout: _incomingRequest!.openRideTimeout,
        date: _incomingRequest!.date,
      );
      _incomingRequest = null;
      notifyListeners();
    }
  }

  void ignoreIncomingRequest() {
    _countdownTimer?.cancel();
    _incomingRequest = null;
    notifyListeners();
    // Simulate another request later
    _startSimulatedIncomingRequest();
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
      notifyListeners();
    }
  }

  void captainCompleteActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.started) {
      _activeTrip!.status = TripStatus.completed;

      // Calculate earnings (85% net, 15% commission)
      double price = _activeTrip!.price;
      double commission = double.parse((price * 0.15).toStringAsFixed(1));
      double net = price - commission;

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
          title: 'صافي أرباح رحلة إلى ${_activeTrip!.destinationLocation}',
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
          title: 'عمولة رحلة إلى ${_activeTrip!.destinationLocation}',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: false,
        ),
      );

      notifyListeners();
    }
  }

  void confirmCaptainSummary() {
    _activeTrip = null;
    notifyListeners();
    // Ready for next request if online
    if (_isCaptainOnline) {
      _startSimulatedIncomingRequest();
    }
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
    _incomingRequestTimer?.cancel();
    super.dispose();
  }
}
