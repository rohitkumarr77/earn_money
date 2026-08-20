import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/ad_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          if (user != null) ...[
            _ProfileTile(label: 'Name', value: user.name),
            _ProfileTile(label: 'Email', value: user.email),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('UPI ID'),
              subtitle: Text(user.upiId.isEmpty ? 'Not set' : user.upiId),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editUpi(context, user.upiId),
              ),
            ),
            const Divider(),
            const Text('Referral', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your referral code'),
                    const SizedBox(height: 8),
                    SelectableText(
                      user.myReferralCode.isEmpty ? '—' : user.myReferralCode,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                    ),
                    if (!user.referralCodeApplied) ...[
                      const SizedBox(height: 16),
                      const Text('Enter a friend\'s code (one time only)'),
                      const SizedBox(height: 8),
                      _ReferralCodeField(
                        onApply: (code) async {
                          final uid = context.read<UserProvider>().firebaseUser?.uid;
                          if (uid == null) return false;
                          return _firestore.applyReferralCode(uid, code);
                        },
                      ),
                    ] else if (user.referredBy != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Referred by: ${user.referredBy}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_bannerAd != null && _bannerAd!.response != null)
            SizedBox(
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                context.read<UserProvider>().signOut();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _editUpi(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit UPI ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'yourname@upi',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = context.read<UserProvider>().firebaseUser?.uid;
              if (uid != null && controller.text.trim().isNotEmpty) {
                await _firestore.updateUpiId(uid, controller.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

extension on BannerAd {
  get response => null;
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value.isEmpty ? '—' : value),
    );
  }
}

class _ReferralCodeField extends StatefulWidget {
  const _ReferralCodeField({required this.onApply});

  final Future<bool> Function(String code) onApply;

  @override
  State<_ReferralCodeField> createState() => _ReferralCodeFieldState();
}

class _ReferralCodeFieldState extends State<_ReferralCodeField> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Enter code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  final code = _controller.text.trim();
                  if (code.isEmpty) return;
                  setState(() => _loading = true);
                  final ok = await widget.onApply(code);
                  setState(() => _loading = false);
                  if (context.mounted) {
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Referral applied! You both got ₹2 (2000 points).')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid or already used referral code')),
                      );
                    }
                  }
                },
          child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply'),
        ),
      ],
    );
  }
}
