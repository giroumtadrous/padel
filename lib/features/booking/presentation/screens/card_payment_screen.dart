import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/utils/card_formatters.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';
import 'package:padel/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:padel/features/booking/presentation/bloc/booking_event.dart';
import 'package:padel/features/booking/presentation/bloc/booking_state.dart';

/// Card details entry, reached from [BookingConfirmScreen] when "Card" is
/// selected. Confirmation itself is dispatched from here, but success
/// navigation is handled by BookingConfirmScreen's own listener underneath
/// (still mounted on the nav stack) — this screen only needs to surface
/// errors locally, since a SnackBar on the screen beneath wouldn't be seen.
class CardPaymentScreen extends StatefulWidget {
  final String venueName;
  final String courtName;
  final bool useLoyaltyDiscount;

  const CardPaymentScreen({
    super.key,
    required this.venueName,
    required this.courtName,
    required this.useLoyaltyDiscount,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cvvFocus = FocusNode();
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _cvvFocus.addListener(() => setState(() => _showBack = _cvvFocus.hasFocus));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    context.read<BookingBloc>().add(ConfirmBooking(
          userId: authState.user.uid,
          venueName: widget.venueName,
          courtName: widget.courtName,
          paymentMethod: AppConstants.paymentCard,
          useLoyaltyDiscount: widget.useLoyaltyDiscount,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Card Details')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCardPreview(),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cardholder Name',
                      hintText: 'John Doe',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Cardholder name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _numberCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardNumberFormatter(),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      hintText: '4111 2222 3333 4444',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(' ', '');
                      if (digits.length < 16) return 'Enter a valid 16-digit card number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _expiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            CardExpiryFormatter(),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Expiry',
                            hintText: 'MM/YY',
                            prefixIcon: Icon(Icons.date_range_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 5 || !v.contains('/')) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _cvvCtrl,
                          focusNode: _cvvFocus,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            hintText: '***',
                            prefixIcon: Icon(Icons.security_rounded),
                          ),
                          validator: (v) =>
                              (v == null || v.length < 3) ? 'Invalid' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BlocBuilder<BookingBloc, BookingState>(
                    builder: (context, state) => AppButton(
                      label: 'Pay & Confirm',
                      isLoading: state is BookingInProgress,
                      onPressed: () => _submit(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview() {
    final digits = _numberCtrl.text;
    final formatted = List.generate(16, (i) => i < digits.length ? digits[i] : '•').join();
    final spaced = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      spaced.write(formatted[i]);
      if ((i + 1) % 4 == 0 && i != formatted.length - 1) spaced.write(' ');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 190,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _showBack ? _buildCardBack() : _buildCardFront(spaced.toString()),
    );
  }

  Widget _buildCardFront(String number) {
    final name = _nameCtrl.text.trim();
    final expiry = _expiryCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'PADEL PRO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
        ),
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CARDHOLDER',
                      style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    name.isEmpty ? 'YOUR NAME' : name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('EXPIRES',
                    style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(expiry.isEmpty ? 'MM/YY' : expiry,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardBack() {
    final cvv = _cvvCtrl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 36, color: Colors.black),
        const SizedBox(height: 16),
        Container(
          height: 30,
          color: const Color(0xFFFFD700),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            cvv.isEmpty ? '***' : '*' * cvv.length,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
