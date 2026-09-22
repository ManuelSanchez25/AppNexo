import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexo/features/auth/data/google_auth_service.dart';

import 'google_sign_in_web_button.dart';

class GoogleSignInButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final Future<void> Function(GoogleSignInAccount account) onSignedIn;

  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onSignedIn,
    this.enabled = true,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final Future<void> _initializeFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFuture = GoogleAuthService.ensureInitialized().then((_) {
      _authSubscription = GoogleSignIn.instance.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: _showGoogleError,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      await _handleAccount(event.user);
    }
  }

  Future<void> _handleNativePress() async {
    try {
      final account = await GoogleAuthService.signIn();
      await _handleAccount(account);
    } catch (error) {
      _showGoogleError(error);
    }
  }

  Future<void> _handleAccount(GoogleSignInAccount account) async {
    if (_isLoading || !widget.enabled) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSignedIn(account);
    } catch (error) {
      _showGoogleError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGoogleError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceAll('Exception:', '').trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: const Text('Configura Google Sign-In'),
          );
        }

        if (kIsWeb && !GoogleSignIn.instance.supportsAuthenticate()) {
          if (!widget.enabled) {
            return OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: Text(widget.label),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 44,
                width: double.infinity,
                child: buildGoogleWebButton(),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          );
        }

        return OutlinedButton.icon(
          onPressed: widget.enabled && !_isLoading ? _handleNativePress : null,
          icon: const Icon(Icons.g_mobiledata_rounded),
          label: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.label),
        );
      },
    );
  }
}
