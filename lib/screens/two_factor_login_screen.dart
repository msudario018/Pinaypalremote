import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart';
import '../services/firebase_service.dart';

class TwoFactorLoginScreen extends StatefulWidget {
  const TwoFactorLoginScreen({super.key});

  @override
  State<TwoFactorLoginScreen> createState() => _TwoFactorLoginScreenState();
}

class _TwoFactorLoginScreenState extends State<TwoFactorLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  bool _show2FA = false;
  bool _rememberDevice = false;
  bool _keepMeLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final keepLoggedIn = prefs.getBool('keep_me_logged_in') ?? false;
    final savedUsername = prefs.getString('saved_username');

    if (keepLoggedIn && savedUsername != null) {
      // Auto-login logic could be added here
      // For now, just fill in the username field
      if (mounted) {
        _usernameController.text = savedUsername;
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final success = await FirebaseService.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        // Check if 2FA is enabled
        final is2FAEnabled =
            await FirebaseService.is2FAEnabled(_usernameController.text);

        if (is2FAEnabled) {
          // Check if device is remembered
          final isDeviceRemembered = await FirebaseService.isDeviceRemembered(
              _usernameController.text);

          if (isDeviceRemembered) {
            // Device is remembered, skip 2FA and go directly to main screen
            // Save keep me logged in preference
            if (_keepMeLoggedIn) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('keep_me_logged_in', true);
              await prefs.setString('saved_username', _usernameController.text);
            }

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) =>
                      MainScreen(username: _usernameController.text)),
            );
          } else {
            // Show 2FA form
            setState(() {
              _show2FA = true;
              _isLoading = false;
            });
          }
        } else {
          // 2FA not enabled, navigate directly to MainScreen
          // Save keep me logged in preference
          if (_keepMeLoggedIn) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('keep_me_logged_in', true);
            await prefs.setString('saved_username', _usernameController.text);
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => MainScreen(username: _usernameController.text)),
          );
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
      }
    }
  }

  Future<void> _verify2FA() async {
    setState(() => _isLoading = true);

    // Combine all 6 input fields into a single code
    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all 6 digits')),
        );
      }
      return;
    }

    final success =
        await FirebaseService.verify2FA(_usernameController.text, code);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Save device if checkbox is checked
        if (_rememberDevice) {
          await FirebaseService.saveRememberedDevice(_usernameController.text);
        }

        // Save keep me logged in preference
        if (_keepMeLoggedIn) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('keep_me_logged_in', true);
          await prefs.setString('saved_username', _usernameController.text);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => MainScreen(username: _usernameController.text)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid 2FA code')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _show2FA ? _build2FAForm() : _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App logo
        Image.asset(
          'assets/app_icon.png',
          width: 120,
          height: 120,
        ),
        const SizedBox(height: 32),
        Text(
          'PinayPal Remote',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure Backup Management',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter your username',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
        ),
      ],
    );
  }

  Widget _build2FAForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.security,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Two-Factor Authentication',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your 2FA code',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Checkbox(
              value: _rememberDevice,
              onChanged: (value) {
                setState(() => _rememberDevice = value ?? false);
              },
            ),
            const Text('Remember this device for 30 days'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 50,
              height: 60,
              child: TextField(
                controller: _codeControllers[index],
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    FocusScope.of(context).nextFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _verify2FA,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() => _show2FA = false);
          },
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
