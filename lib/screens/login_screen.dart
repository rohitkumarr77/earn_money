import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Earn Money',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to spin, earn points and withdraw',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 48),
                _GoogleSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<UserProvider>();
      final cred = await provider.signInWithGoogle();
      if (cred == null && mounted) {
        setState(() => _loading = false);
        return;
      }
    } on PlatformException catch (e) {
      String errorMessage = _getErrorMessage(e);
      if (mounted) setState(() => _error = errorMessage);
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getFirebaseErrorMessage(e);
      if (mounted) setState(() => _error = errorMessage);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'An unexpected error occurred. Please try again.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _getErrorMessage(PlatformException e) {
    if (e.code == 'sign_in_failed') {
      // Check for ApiException: 10 (DEVELOPER_ERROR)
      if (e.message?.contains('ApiException: 10') == true) {
        return 'Google Sign-In configuration error. Please check your app settings.';
      }
      // Check for network errors
      if (e.message?.contains('network') == true || e.message?.contains('Network') == true) {
        return 'Network error. Please check your internet connection.';
      }
      return 'Sign-in failed. Please try again.';
    }
    return e.message ?? 'An error occurred during sign-in.';
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered with another account.';
      case 'invalid-email':
        return 'Invalid email address. Please check your email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      // case 'operation-not-allowed':
      //   return 'This sign-in method is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    return Column(
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: _loading ? null : () => _signIn(),
          icon: _loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login),
          label: Text(_loading ? 'Signing in...' : 'Sign in with Google'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }
}
