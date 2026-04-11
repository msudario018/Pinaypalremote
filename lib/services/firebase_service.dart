import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static const String _firebaseUrl =
      'https://pinaypal-backup-manager-default-rtdb.firebaseio.com/';
  static String? _currentUsername;

  static String? get currentUsername => _currentUsername;

  static void setCurrentUsername(String username) {
    _currentUsername = username;
  }

  // Backup command types
  static const String triggerFtpBackupCmd = 'trigger_ftp_backup';
  static const String triggerMailchimpBackupCmd = 'trigger_mailchimp_backup';
  static const String triggerSqlBackupCmd = 'trigger_sql_backup';
  static const String pauseBackupsCmd = 'pause_backups';
  static const String resumeBackupsCmd = 'resume_backups';
  static const String syncBackupFilesCmd = 'sync_backup_files';
  static const String deleteBackupFileCmd = 'delete_backup_file';

  static Future<bool> initialize() async {
    try {
      final response = await http.get(Uri.parse('$_firebaseUrl.json'));
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Initialization failed: $e');
      return false;
    }
  }

  static Future<bool> login(String username, String password) async {
    try {
      print('[FirebaseService] Attempting login for user: $username');

      // Debug: List all users to see what's in the database
      await debugListUsers();

      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username.json'),
      );

      print('[FirebaseService] Response status: ${response.statusCode}');

      bool loginSuccess = false;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[FirebaseService] User data: $data');

        if (data != null) {
          final storedPasswordHash = data['PasswordHash']?.toString();
          final salt = data['Salt']?.toString();

          // Check if user has hashed password (new system)
          if (storedPasswordHash != null && salt != null) {
            final computedHash = _hashPassword(password, salt);
            if (computedHash == storedPasswordHash) {
              setCurrentUsername(username);
              loginSuccess = true;
            } else {
              print('[FirebaseService] Password hash mismatch');
            }
          } else {
            // Fallback for users without password hash (existing users from PC app)
            // Check if user exists and has a simple password field or just allow login
            // For now, allow login if user exists (for testing/migration)
            print(
                '[FirebaseService] User exists without password hash, allowing login for migration');
            setCurrentUsername(username);
            loginSuccess = true;
          }
        } else {
          print('[FirebaseService] User data is null');
        }
      } else {
        print(
            '[FirebaseService] User not found (status: ${response.statusCode})');
      }

      // Record login history
      await recordLoginHistory(
        username: username,
        success: loginSuccess,
        deviceInfo: 'Flutter Mobile App',
      );

      return loginSuccess;
    } catch (e) {
      print('[FirebaseService] Login failed: $e');

      // Record failed login attempt
      await recordLoginHistory(
        username: username,
        success: false,
        deviceInfo: 'Flutter Mobile App',
      );

      return false;
    }
  }

  static Future<void> debugListUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map) {
          print(
              '[FirebaseService] All users in database: ${data.keys.toList()}');
        } else {
          print('[FirebaseService] No users found in database');
        }
      }
    } catch (e) {
      print('[FirebaseService] Failed to list users: $e');
    }
  }

  static Future<bool> verify2FA(String username, String code) async {
    try {
      print(
          '[FirebaseService] Verifying 2FA code for user: $username, code: $code');
      final response = await http.get(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[FirebaseService] 2FA data from Firebase: $data');

        // Check multiple possible field names for secret (prioritize PC app's SecretKey)
        final secret = data['SecretKey']?.toString() ??
            data['secretKey']?.toString() ??
            data['Secret']?.toString() ??
            data['secret']?.toString();

        final backupCodes = data['BackupCodes'] as List<dynamic>? ??
            data['backupCodes'] as List<dynamic>? ??
            [];

        if (secret != null) {
          print('[FirebaseService] Secret: $secret');
          print('[FirebaseService] Backup codes: $backupCodes');

          // Check backup codes first
          for (final backupCode in backupCodes) {
            if (backupCode.toString() == code) {
              print('[FirebaseService] Using backup code');
              // Remove used backup code
              final updatedCodes =
                  backupCodes.where((c) => c.toString() != code).toList();
              await http.patch(
                Uri.parse('$_firebaseUrl/2fa/$username.json'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'BackupCodes': updatedCodes}),
              );
              return true;
            }
          }

          // Verify TOTP code
          print('[FirebaseService] Verifying TOTP code');
          final isValid = _verifyTOTP(secret, code);
          print('[FirebaseService] TOTP verification result: $isValid');
          return isValid;
        }
      }
      return false;
    } catch (e) {
      print('[FirebaseService] 2FA verification failed: $e');
      return false;
    }
  }

  static Future<bool> is2FAEnabled(String username) async {
    try {
      print('[FirebaseService] Checking 2FA status for user: $username');
      final response = await http.get(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
      );

      print('[FirebaseService] 2FA response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[FirebaseService] 2FA data: $data');

        // Check multiple possible field names
        final isEnabled = data['isEnabled'] == true ||
            data['IsEnabled'] == true ||
            data['enabled'] == true ||
            data['Enabled'] == true;

        print('[FirebaseService] 2FA enabled: $isEnabled');
        return isEnabled;
      }
      print(
          '[FirebaseService] 2FA data not found (status: ${response.statusCode})');
      return false;
    } catch (e) {
      print('[FirebaseService] Check 2FA enabled failed: $e');
      return false;
    }
  }

  static bool _verifyTOTP(String secret, String code) {
    if (secret.isEmpty || code.length != 6) return false;

    try {
      final now = DateTime.now().toUtc();
      final unixTime = now.millisecondsSinceEpoch ~/ 1000;
      final timeStep = unixTime ~/ 30;

      print('[FirebaseService] Current time step: $timeStep');

      // Check current and adjacent time windows (for clock drift)
      for (int i = -1; i <= 1; i++) {
        final expectedCode = _generateTOTP(secret, timeStep + i);
        print(
            '[FirebaseService] Time step ${timeStep + i}: expected code = $expectedCode, input code = $code, match = ${expectedCode == code}');
        if (expectedCode == code) return true;
      }
      return false;
    } catch (e) {
      print('[FirebaseService] TOTP verification error: $e');
      return false;
    }
  }

  static String _generateTOTP(String secret, int timeStep) {
    // Base32 decode
    final key = _base32Decode(secret);
    if (key.isEmpty) return '';

    // Convert timeStep to 8-byte big-endian
    final timeBytes = List<int>.filled(8, 0);
    var temp = timeStep;
    for (int i = 7; i >= 0; i--) {
      timeBytes[i] = temp & 0xFF;
      temp >>= 8;
    }

    // HMAC-SHA1
    final hmac = _hmacSHA1(key, timeBytes);

    // Dynamic truncation
    final offset = hmac[hmac.length - 1] & 0x0F;
    final binary = ((hmac[offset] & 0x7F) << 24) |
        ((hmac[offset + 1] & 0xFF) << 16) |
        ((hmac[offset + 2] & 0xFF) << 8) |
        (hmac[offset + 3] & 0xFF);

    // 6-digit code
    final codeNum = binary % 1000000;
    return codeNum.toString().padLeft(6, '0');
  }

  static List<int> _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (cleaned.isEmpty) return [];

    final result = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (final char in cleaned.split('')) {
      final val = alphabet.indexOf(char);
      if (val < 0) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        result.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return result;
  }

  static List<int> _hmacSHA1(List<int> key, List<int> message) {
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(message);
    return digest.bytes;
  }

  static Future<Map<String, dynamic>?> getUserData(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get user data failed: $e');
      return null;
    }
  }

  static Future<bool> getBackupStatus(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/backup_status.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data != null;
      }
      return false;
    } catch (e) {
      print('[FirebaseService] Get backup status failed: $e');
      return false;
    }
  }

  static Future<bool> sendBackupCommand(String commandType,
      {String? data}) async {
    if (_currentUsername == null) return false;

    try {
      final commandData = {
        'type': commandType,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
        if (data != null) 'data': data,
      };

      final response = await http.post(
        Uri.parse('$_firebaseUrl/users/$_currentUsername/commands.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(commandData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Send backup command failed: $e');
      return false;
    }
  }

  static Future<bool> triggerFtpBackup() async {
    return await sendBackupCommand(triggerFtpBackupCmd);
  }

  static Future<bool> triggerMailchimpBackup() async {
    return await sendBackupCommand(triggerMailchimpBackupCmd);
  }

  static Future<bool> triggerSqlBackup() async {
    return await sendBackupCommand(triggerSqlBackupCmd);
  }

  static Future<bool> pauseBackups() async {
    return await sendBackupCommand(pauseBackupsCmd);
  }

  static Future<bool> resumeBackups() async {
    return await sendBackupCommand(resumeBackupsCmd);
  }

  static Future<bool> syncBackupFiles() async {
    return await sendBackupCommand(syncBackupFilesCmd);
  }

  static Future<bool> deleteBackupFile(String filePath) async {
    return await sendBackupCommand(deleteBackupFileCmd, data: filePath);
  }

  static Future<bool> saveBackupSchedule(Map<String, dynamic> schedule) async {
    try {
      final response = await http.put(
        Uri.parse('$_firebaseUrl/users/$_currentUsername/backup_schedule.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(schedule),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Save backup schedule failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getBackupSchedule() async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$_currentUsername/backup_schedule.json'),
      );
      if (response.statusCode == 200 && response.body != 'null') {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get backup schedule failed: $e');
      return null;
    }
  }

  static Future<bool> saveHealthThresholds(
      Map<String, dynamic> thresholds) async {
    try {
      final response = await http.put(
        Uri.parse(
            '$_firebaseUrl/users/$_currentUsername/health_thresholds.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(thresholds),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Save health thresholds failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getHealthThresholds() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_firebaseUrl/users/$_currentUsername/health_thresholds.json'),
      );
      if (response.statusCode == 200 && response.body != 'null') {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get health thresholds failed: $e');
      return null;
    }
  }

  static Future<bool> isPcAppOnline(String username) async {
    try {
      // Check connection status at /users/{username}/connection
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/connection.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final status = data['status']?.toString();
          final lastSeenStr = data['lastSeen']?.toString();

          if (status == 'online' && lastSeenStr != null) {
            final lastSeen = DateTime.parse(lastSeenStr);
            final now = DateTime.now();
            final difference = now.difference(lastSeen);

            // Consider PC online if status is 'online' and lastSeen within 30 seconds
            return difference.inSeconds < 30;
          }
        }
      }

      // Fallback: check LastUpdated in user data
      final userData = await getUserData(username);
      if (userData == null) return false;

      final lastUpdatedStr = userData['LastUpdated']?.toString();
      if (lastUpdatedStr == null) return false;

      final lastUpdated = DateTime.parse(lastUpdatedStr);
      final now = DateTime.now();
      final difference = now.difference(lastUpdated);

      // Consider PC online if updated within the last 15 minutes
      return difference.inMinutes < 15;
    } catch (e) {
      print('[FirebaseService] Check PC online status failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getPcStatus(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/connection.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get PC status failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBackupHealth(String username) async {
    try {
      // Read from system_status which contains last backup times
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/system_status.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          // Transform system_status data to match expected health structure
          final systemData = data as Map<String, dynamic>;
          return {
            'website':
                systemData['lastFtpBackup'] != 'Never' ? 'ok' : 'unknown',
            'sql': systemData['lastSqlBackup'] != 'Never' ? 'ok' : 'unknown',
            'mailchimp':
                systemData['lastMcBackup'] != 'Never' ? 'ok' : 'unknown',
            'website_last_backup':
                systemData['lastFtpBackup']?.toString() ?? '',
            'sql_last_backup': systemData['lastSqlBackup']?.toString() ?? '',
            'mailchimp_last_backup':
                systemData['lastMcBackup']?.toString() ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get backup health failed: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return (data as Map<String, dynamic>)
              .entries
              .map((e) => e.value as Map<String, dynamic>)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[FirebaseService] Get all users failed: $e');
      return [];
    }
  }

  static Future<bool> changeUsername(
      String currentUsername, String newUsername) async {
    try {
      print(
          '[FirebaseService] Attempting to change username from $currentUsername to $newUsername');

      // Get current user data
      final userData = await getUserData(currentUsername);
      if (userData == null) {
        print('[FirebaseService] User data not found');
        return false;
      }

      // Update username in user data
      userData['Username'] = newUsername;

      // Create new user entry
      final response = await http.put(
        Uri.parse('$_firebaseUrl/users/$newUsername.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      print(
          '[FirebaseService] Create new user response: ${response.statusCode}');

      if (response.statusCode != 200) return false;

      // Delete old entry
      final deleteResponse = await http
          .delete(Uri.parse('$_firebaseUrl/users/$currentUsername.json'));
      print(
          '[FirebaseService] Delete old user response: ${deleteResponse.statusCode}');

      // Update current username
      _currentUsername = newUsername;
      print('[FirebaseService] Username changed successfully');
      return true;
    } catch (e) {
      print('[FirebaseService] Change username failed: $e');
      return false;
    }
  }

  static Future<bool> changePassword(
      String username, String currentPassword, String newPassword) async {
    try {
      print('[FirebaseService] Attempting to change password for: $username');
      final userData = await getUserData(username);
      if (userData == null) {
        print('[FirebaseService] User data not found');
        return false;
      }

      // Verify current password
      final storedPasswordHash = userData['PasswordHash']?.toString();
      final salt = userData['Salt']?.toString();

      print(
          '[FirebaseService] Stored password hash: $storedPasswordHash, salt: $salt');

      if (storedPasswordHash != null && salt != null) {
        final computedHash = _hashPassword(currentPassword, salt);
        if (computedHash != storedPasswordHash) {
          print('[FirebaseService] Current password is incorrect');
          return false; // Current password is incorrect
        }
      } else {
        // Fallback for users without password hash (PC app users)
        // For now, just allow password change without verification
        print(
            '[FirebaseService] User has no password hash, allowing change without verification');
      }

      // Generate new salt and hash for new password
      final newSalt = _generateSalt();
      final newPasswordHash = _hashPassword(newPassword, newSalt);

      print('[FirebaseService] Generated new password hash');

      // Update password in Firebase
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/users/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'PasswordHash': newPasswordHash,
          'Salt': newSalt,
        }),
      );

      print(
          '[FirebaseService] Password change response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Change password failed: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> setup2FA(String username) async {
    try {
      // Generate a simple secret key
      const secret =
          'JBSWY3DPEHPK3PXP'; // In production, generate a real secret
      final backupCodes =
          List.generate(10, (index) => 'CODE-${index + 100000}');

      final response = await http.put(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'secret': secret,
          'backupCodes': backupCodes,
          'IsEnabled': false,
        }),
      );

      if (response.statusCode == 200) {
        return {'secret': secret, 'backupCodes': backupCodes};
      }
      return {};
    } catch (e) {
      print('[FirebaseService] Setup 2FA failed: $e');
      return {};
    }
  }

  static Future<bool> enable2FA(String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'IsEnabled': true}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Enable 2FA failed: $e');
      return false;
    }
  }

  static Future<bool> disable2FA(String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'IsEnabled': false}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Disable 2FA failed: $e');
      return false;
    }
  }

  static Future<bool> update2FASecret(String username, String secret) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/2fa/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'SecretKey': secret}),
      );
      print(
          '[FirebaseService] Update 2FA secret response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Update 2FA secret failed: $e');
      return false;
    }
  }

  static Future<bool> recordLoginHistory({
    required String username,
    required bool success,
    String? deviceInfo,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      print('[FirebaseService] Recording login history for user: $username');

      final timestamp = DateTime.now().toIso8601String();
      final deviceId = await _getDeviceId();

      final loginData = {
        'success': success,
        'deviceId': deviceId,
        'deviceInfo': deviceInfo ?? 'Unknown Device',
        'ipAddress': ipAddress ?? 'Unknown',
        'userAgent': userAgent ?? 'Unknown',
        'timestamp': timestamp,
      };

      final response = await http.put(
        Uri.parse('$_firebaseUrl/login_history/$username/$timestamp.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      );

      print(
          '[FirebaseService] Record login history response status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Record login history failed: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getLoginHistory(
      String username) async {
    try {
      print('[FirebaseService] Fetching login history for user: $username');
      final response = await http.get(
        Uri.parse('$_firebaseUrl/login_history/$username.json'),
      );

      print(
          '[FirebaseService] Login history response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[FirebaseService] Login history data: $data');

        if (data != null) {
          final history = (data as Map<String, dynamic>)
              .entries
              .map((e) => {
                    'timestamp': e.key,
                    ...Map<String, dynamic>.from(e.value as Map)
                  })
              .toList()
              .reversed
              .toList();

          print(
              '[FirebaseService] Parsed login history: ${history.length} entries');
          return history;
        }
      }
      print('[FirebaseService] No login history found');
      return [];
    } catch (e) {
      print('[FirebaseService] Get login history failed: $e');
      return [];
    }
  }

  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Generate a unique device ID
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      deviceId = base64Encode(bytes);
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  static Future<bool> saveRememberedDevice(String username) async {
    try {
      final deviceId = await _getDeviceId();
      final expirationDate =
          DateTime.now().add(const Duration(days: 30)).toIso8601String();

      print(
          '[FirebaseService] Saving remembered device: $deviceId for user: $username');

      final response = await http.put(
        Uri.parse('$_firebaseUrl/remembered_devices/$username/$deviceId.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': deviceId,
          'expirationDate': expirationDate,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      print('[FirebaseService] Save device response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Save remembered device failed: $e');
      return false;
    }
  }

  static Future<bool> isDeviceRemembered(String username) async {
    try {
      final deviceId = await _getDeviceId();

      print(
          '[FirebaseService] Checking if device is remembered: $deviceId for user: $username');

      final response = await http.get(
        Uri.parse('$_firebaseUrl/remembered_devices/$username/$deviceId.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final expirationDate =
              DateTime.parse(data['expirationDate'].toString());
          final now = DateTime.now();

          // Check if device is still valid (not expired)
          if (now.isBefore(expirationDate)) {
            print(
                '[FirebaseService] Device is still remembered (expires: $expirationDate)');
            return true;
          } else {
            // Device expired, remove it
            print(
                '[FirebaseService] Device remembered but expired, removing...');
            await http.delete(
              Uri.parse(
                  '$_firebaseUrl/remembered_devices/$username/$deviceId.json'),
            );
            return false;
          }
        }
      }

      print('[FirebaseService] Device not remembered');
      return false;
    } catch (e) {
      print('[FirebaseService] Check remembered device failed: $e');
      return false;
    }
  }

  static Future<bool> approveUser(String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/users/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Status': 'Active'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Approve user failed: $e');
      return false;
    }
  }

  static Future<bool> disableUser(String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/users/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Status': 'Disabled'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Disable user failed: $e');
      return false;
    }
  }

  static Future<bool> enableUser(String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/users/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Status': 'Active'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Enable user failed: $e');
      return false;
    }
  }

  static Future<bool> changeUserPassword(
      String username, String newPassword) async {
    try {
      final newSalt = _generateSalt();
      final newPasswordHash = _hashPassword(newPassword, newSalt);

      final response = await http.patch(
        Uri.parse('$_firebaseUrl/users/$username.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'PasswordHash': newPasswordHash,
          'Salt': newSalt,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Change user password failed: $e');
      return false;
    }
  }

  static Future<String?> generateInviteCode() async {
    try {
      final code = 'CODE-${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.put(
        Uri.parse('$_firebaseUrl/invite_codes/$code.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': _currentUsername,
          'is_used': false,
        }),
      );
      return response.statusCode == 200 ? code : null;
    } catch (e) {
      print('[FirebaseService] Generate invite code failed: $e');
      return null;
    }
  }

  static Future<bool> validateInviteCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/invite_codes/$code.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['is_used'] == false) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('[FirebaseService] Validate invite code failed: $e');
      return false;
    }
  }

  static Future<bool> useInviteCode(String code, String username) async {
    try {
      final response = await http.patch(
        Uri.parse('$_firebaseUrl/invite_codes/$code.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_used': true,
          'used_by': username,
          'used_at': DateTime.now().toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Use invite code failed: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getInviteCodes() async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/invite_codes.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return (data as Map<String, dynamic>)
              .entries
              .map((e) => e.value as Map<String, dynamic>)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[FirebaseService] Get invite codes failed: $e');
      return [];
    }
  }

  static Future<bool> deleteInviteCode(String code) async {
    try {
      final response = await http.delete(
        Uri.parse('$_firebaseUrl/invite_codes/$code.json'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Delete invite code failed: $e');
      return false;
    }
  }

  static Future<bool> uploadUserAvatar(
      String username, String base64Image) async {
    try {
      final response = await http.put(
        Uri.parse('$_firebaseUrl/users/$username/avatar.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Upload user avatar failed: $e');
      return false;
    }
  }

  static Future<String?> getUserAvatar(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/avatar.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map) {
          return data['image']?.toString();
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get user avatar failed: $e');
      return null;
    }
  }

  static Future<bool> removeUserAvatar(String username) async {
    try {
      final response = await http.delete(
        Uri.parse('$_firebaseUrl/users/$username/avatar.json'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[FirebaseService] Remove user avatar failed: $e');
      return false;
    }
  }

  static Future<String?> getUserRole(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final role = data['Role']?.toString();
          print('[FirebaseService] User role: $role');
          return role;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get user role failed: $e');
      return null;
    }
  }

  static Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('keep_me_logged_in');
    await prefs.remove('saved_username');
    _currentUsername = null;
    return true;
  }

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  static String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return base64Encode(utf8.encode(random));
  }

  // Backup Management Methods
  static Future<List<Map<String, dynamic>>> getBackupHistory(
      String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/backups.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          if (data is List) {
            return data.map((e) => e as Map<String, dynamic>).toList();
          } else if (data is Map) {
            return data.entries
                .map((e) => e.value as Map<String, dynamic>)
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('[FirebaseService] Get backup history failed: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getStorageUsage(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/storage.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get storage usage failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBackupProgress(
      String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/backup_progress.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get backup progress failed: $e');
      return null;
    }
  }

  static Future<bool> triggerBackup(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseUrl/users/$username/trigger_backup.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'triggeredBy': 'mobile_app',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('[FirebaseService] Trigger backup failed: $e');
      return false;
    }
  }

  static Future<bool> stopBackup(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_firebaseUrl/users/$username/stop_backup.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'triggeredBy': 'mobile_app',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      print('[FirebaseService] Stop backup failed: $e');
      return false;
    }
  }

  // Auto Scan Settings Methods
  static Future<Map<String, dynamic>?> getAutoScanSettings() async {
    final username = currentUsername;
    if (username == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/auto_scan.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get auto scan settings failed: $e');
      return null;
    }
  }

  static Future<bool> saveAutoScanSettings(Map<String, dynamic> settings) async {
    final username = currentUsername;
    if (username == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$_firebaseUrl/users/$username/auto_scan.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        print('[FirebaseService] Auto scan settings saved');
        return true;
      }
      return false;
    } catch (e) {
      print('[FirebaseService] Save auto scan settings failed: $e');
      return false;
    }
  }

  // System Monitoring Methods
  static Future<Map<String, dynamic>?> getSystemStats(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/system_stats.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('[FirebaseService] Get system stats failed: $e');
      return null;
    }
  }

  // Activity Feed Methods
  static Future<List<Map<String, dynamic>>> getActivityLog(
      String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/activity.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          if (data is List) {
            return data.map((e) => e as Map<String, dynamic>).toList();
          } else if (data is Map) {
            return data.entries
                .map((e) => e.value as Map<String, dynamic>)
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('[FirebaseService] Get activity log failed: $e');
      return [];
    }
  }

  // File Browser Methods
  static Future<List<Map<String, dynamic>>> getBackupFiles(
      String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_firebaseUrl/users/$username/backup_files.json'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          if (data is List) {
            return data.map((e) => e as Map<String, dynamic>).toList();
          } else if (data is Map) {
            return data.entries
                .map((e) => e.value as Map<String, dynamic>)
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('[FirebaseService] Get backup files failed: $e');
      return [];
    }
  }
}
