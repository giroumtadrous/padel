import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:padel/core/constants/app_colors.dart';
import 'package:padel/core/constants/app_constants.dart';
import 'package:padel/core/services/payment_proof_storage_service.dart';
import 'package:padel/core/widgets/app_button.dart';
import 'package:padel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:padel/features/auth/presentation/bloc/auth_state.dart';

class TopUpManualScreen extends StatefulWidget {
  final double amount;
  final String paymentMethod;

  const TopUpManualScreen({
    super.key,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<TopUpManualScreen> createState() => _TopUpManualScreenState();
}

class _TopUpManualScreenState extends State<TopUpManualScreen> {
  final PaymentProofStorageService _proofStorage = PaymentProofStorageService.instance;
  XFile? _proofImage;
  bool _uploading = false;

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final image = source == ImageSource.camera
          ? await _proofStorage.pickFromCamera()
          : await _proofStorage.pickFromGallery();
      if (image == null || !mounted) return;
      setState(() => _proofImage = image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a screenshot of the transfer.')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    setState(() => _uploading = true);

    try {
      final String bookingId = 'topup_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final proofUrl = await _proofStorage.uploadPaymentProof(
        image: _proofImage!,
        userId: user.uid,
        bookingId: bookingId,
      );

      // Write to wallet_topup_requests collection
      await FirebaseFirestore.instance.collection('wallet_topup_requests').doc(bookingId).set({
        'id': bookingId,
        'userId': user.uid,
        'userName': user.displayName,
        'amount': widget.amount,
        'paymentMethod': widget.paymentMethod,
        'screenshotUrl': proofUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Pop manual topup screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Top up request of EGP ${widget.amount.toInt()} submitted successfully! Admins will verify it soon.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = widget.paymentMethod == AppConstants.paymentVodafone ? 'Vodafone Cash' : 'InstaPay';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Top Up via $methodLabel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Top Up Amount: EGP ${widget.amount.toInt()}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please transfer EGP ${widget.amount.toInt()} using $methodLabel to the number/address provided by the court admin or support. After completing the transfer, upload the receipt screenshot below.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Screenshot area
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Screenshot proof',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    if (_proofImage == null)
                      Container(
                        height: 160,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'No screenshot selected yet',
                          style: TextStyle(color: AppColors.textHint, fontSize: 12),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FutureBuilder<Uint8List>(
                              future: _proofImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    height: 160,
                                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                                  );
                                }
                                return Image.memory(
                                  snapshot.data!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                              onPressed: _uploading ? null : () => setState(() => _proofImage = null),
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : () => _pickProofImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Take photo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : () => _pickProofImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Submit Request',
                isLoading: _uploading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
