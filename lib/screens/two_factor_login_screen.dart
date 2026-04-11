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
      // Check if 2FA is enabled
      final is2FAEnabled = await FirebaseService.is2FAEnabled(savedUsername);

      if (is2FAEnabled) {
        // Check if device is remembered
        final isDeviceRemembered =
            await FirebaseService.isDeviceRemembered(savedUsername);

        if (isDeviceRemembered) {
          // Device is remembered, auto-login and skip 2FA
          if (mounted) {
            FirebaseService.setCurrentUsername(savedUsername);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MainScreen(username: savedUsername),
              ),
            );
          }
        } else {
          // 2FA enabled but device not remembered, fill username and show 2FA
          if (mounted) {
            _usernameController.text = savedUsername;
            setState(() {
              _show2FA = true;
            });
          }
        }
      } else {
        // 2FA not enabled, auto-login directly
        if (mounted) {
          FirebaseService.setCurrentUsername(savedUsername);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainScreen(username: savedUsername),
            ),
          );
        }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF3A0C57), const Color(0xFF1B052A)]
                : [const Color(0xFF83509F), const Color(0xFF50246C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _show2FA ? _build2FAForm() : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: isDark
          ? const Color(0xFF3A0C57).withValues(alpha: 0.9)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF83509F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.backup,
                      size: 40,
                      color: Color(0xFF83509F),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PinayPal',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF83509F),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Backup Manager',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF50246C).withValues(alpha: 0.5)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF50246C).withValues(alpha: 0.5)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _keepMeLoggedIn,
                  onChanged: (value) {
                    setState(() => _keepMeLoggedIn = value ?? false);
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF83509F);
                    }
                    return null;
                  }),
                ),
                const Text('Keep me logged in'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF83509F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2FAForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: isDark
          ? const Color(0xFF3A0C57).withValues(alpha: 0.9)
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF83509F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.security,
                size: 40,
                color: Color(0xFF83509F),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Two-Factor Authentication',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF83509F),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your 2FA code',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Checkbox(
                  value: _rememberDevice,
                  onChanged: (value) {
                    setState(() => _rememberDevice = value ?? false);
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF83509F);
                    }
                    return null;
                  }),
                ),
                const Expanded(
                  child: Text('Remember this device for 30 days'),
                ),
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
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF50246C).withValues(alpha: 0.5)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF83509F),
                          width: 2,
                        ),
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
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _verify2FA,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF83509F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _show2FA = false);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF83509F),
              ),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
