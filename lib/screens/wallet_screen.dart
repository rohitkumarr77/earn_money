import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';
import '../services/firestore_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (_, __) => setState(() {}),
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final points = user?.points ?? 0;
    final rupees = points / 1000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Balance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$points points',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '≈ ₹${rupees.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '100 points = ₹1',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openWithdraw(
              context,
              user?.points ?? 0,
              user?.upiId ?? '',
              context.read<FirestoreService>(),
            ),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Withdraw'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          if (_bannerAd != null && _bannerAd!.response != null)
            SizedBox(
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  void _openWithdraw(BuildContext context, int points, String currentUpi, FirestoreService firestore) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WithdrawForm(
        maxRupees: points ~/ 100,
        currentUpiId: currentUpi,
        onSubmit: (upiId, amountRupees) async {
          final uid = parentContext.read<UserProvider>().firebaseUser?.uid;
          if (uid == null) {
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                const SnackBar(content: Text('Please sign in again')),
              );
            }
            return;
          }
          try {
            final deducted = await firestore.deductPointsForWithdrawal(uid, amountRupees);
            if (!deducted) {
              if (parentContext.mounted) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Insufficient balance')),
                );
              }
              return;
            }
            await firestore.createWithdrawalRequest(uid: uid, upiId: upiId, amountRupees: amountRupees);
            if (ctx.mounted) Navigator.pop(ctx);
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                const SnackBar(content: Text('Withdrawal request submitted')),
              );
            }
          } catch (e) {
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(content: Text('Withdraw failed: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
  }
}

extension on BannerAd {
  get response => null;
}

class _WithdrawForm extends StatefulWidget {
  const _WithdrawForm({
    required this.maxRupees,
    required this.currentUpiId,
    required this.onSubmit,
  });

  final int maxRupees;
  final String currentUpiId;
  final Future<void> Function(String upiId, int amountRupees) onSubmit;

  @override
  State<_WithdrawForm> createState() => _WithdrawFormState();
}

class _WithdrawFormState extends State<_WithdrawForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _upiController;
  late TextEditingController _amountController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController(text: widget.currentUpiId);
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final upi = _upiController.text.trim();
      final amount = int.tryParse(_amountController.text.trim()) ?? 0;
      await widget.onSubmit(upi, amount);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Withdraw',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'yourname@upi',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter UPI ID';
                return null;
              },
              readOnly: _isSubmitting,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                hintText: 'Min ₹10',
                border: const OutlineInputBorder(),
                suffixText: 'Max: ₹${widget.maxRupees}',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                final n = int.tryParse(v.trim());
                if (n == null || n < 10) return 'Minimum ₹10';
                if (n > widget.maxRupees) return 'Max ₹${widget.maxRupees}';
                return null;
              },
              readOnly: _isSubmitting,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }
}
