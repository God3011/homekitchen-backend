import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared/shared.dart';

/// Result of a checkout attempt.
enum PaymentOutcome { success, failed, cancelled }

/// Wraps `razorpay_flutter`'s event-callback API in a single awaitable call.
///
/// Flow: backend has already created the Razorpay order (via
/// `POST /payments/:orderId/razorpay-order`). We open the checkout sheet, and
/// on success verify the signature server-side (`POST /payments/verify`) so the
/// Payment row is marked captured. The webhook is a server-side backstop.
class PaymentService {
  final ApiClient _api;
  final Razorpay _razorpay = Razorpay();
  Completer<PaymentOutcome>? _completer;

  PaymentService(this._api) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  /// Opens checkout for an already-created Razorpay order and resolves once the
  /// user finishes (or the sheet errors/cancels).
  Future<PaymentOutcome> pay({
    required String keyId,
    required String razorpayOrderId,
    required int amountPaise,
    required String kitchenName,
    String? contactPhone,
  }) {
    _completer = Completer<PaymentOutcome>();
    _razorpay.open({
      'key': keyId,
      'order_id': razorpayOrderId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': kitchenName,
      'description': 'Homely order',
      if (contactPhone != null) 'prefill': {'contact': contactPhone},
    });
    return _completer!.future;
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    try {
      await _api.post('/payments/verify', body: {
        'razorpayOrderId': r.orderId,
        'razorpayPaymentId': r.paymentId,
        'razorpaySignature': r.signature,
      });
      _completer?.complete(PaymentOutcome.success);
    } catch (_) {
      // Payment went through on Razorpay's side but our verify failed; the
      // webhook will still capture it server-side. Treat as success for UX.
      _completer?.complete(PaymentOutcome.success);
    }
  }

  void _onError(PaymentFailureResponse r) {
    final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
    _completer?.complete(
        cancelled ? PaymentOutcome.cancelled : PaymentOutcome.failed);
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // External wallet selected — outcome arrives via success/error callbacks.
  }

  void dispose() => _razorpay.clear();
}
