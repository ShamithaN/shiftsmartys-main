// lib/screens/login.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:local_auth/local_auth.dart'; // IMPORT 1: Biometrics
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // IMPORT 2: Secure Storage
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/screens/employee/empOnboard.dart';
import 'package:shiftsmart/screens/forgot_password.dart';
import 'package:shiftsmart/services/auth_service.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/bottomnavbar.dart';
import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
import 'package:shiftsmart/widgets/loginBackground.dart';

class Login extends StatefulWidget {
  final bool promptBiometric; // NEW: Parameter to trigger auto-prompt

  const Login({super.key, this.promptBiometric = false});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final AuthService _authService = AuthService();

  // NEW: Initialize Secure Storage and Local Auth
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscureText = true;
  bool _canCheckBiometrics = false; // To hide button if device doesn't support it
  
  // NEW: Track which biometric types are available
  bool _hasFaceID = false;
  bool _hasFingerprint = false;
  String _biometricLabel = "Biometrics"; // Dynamic label
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    disableFullScreen();
    _checkBiometricAvailability(); // Check if device supports biometrics
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- UPDATED: Check which biometric types are available ---
  Future<void> _checkBiometricAvailability() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _canCheckBiometrics = false;
        });
        return;
      }

      // Get the list of available biometric types
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      // Check if we have credentials saved previously
      String? savedEmail = await _storage.read(key: 'login_email');
      String? savedPass = await _storage.read(key: 'login_pass');

      setState(() {
        // Check for Face ID (iOS) or Face recognition (Android)
        _hasFaceID = availableBiometrics.contains(BiometricType.face);
        
        // Check for Fingerprint (Touch ID on iOS, Fingerprint on Android)
        _hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint);
        
        // Set dynamic label based on available biometrics
        if (_hasFaceID && _hasFingerprint) {
          _biometricLabel = "Face ID / Fingerprint";
        } else if (_hasFaceID) {
          _biometricLabel = "Face ID";
        } else if (_hasFingerprint) {
          _biometricLabel = "Fingerprint";
        } else {
          _biometricLabel = "Biometrics";
        }

        // Only show biometric button if hardware supports it AND we have saved credentials
        _canCheckBiometrics =
            canAuthenticate && 
            (_hasFaceID || _hasFingerprint) && 
            savedEmail != null && 
            savedPass != null;
      });

      // NEW: Trigger auto-prompt if requested and legitimate
      if (widget.promptBiometric && _canCheckBiometrics) {
         // Slight delay to ensure UI is built and not jarring
         Future.delayed(const Duration(milliseconds: 500), () {
           if (mounted) _performBiometricLogin();
         });
      }

      print("Available biometrics: $availableBiometrics");
      print("Face ID: $_hasFaceID, Fingerprint: $_hasFingerprint");
    } catch (e) {
      print("Biometric check failed: $e");
      setState(() {
        _canCheckBiometrics = false;
      });
    }
  }

  // --- UPDATED: Dynamic icon based on available biometric ---
  IconData _getBiometricIcon() {
    if (_hasFaceID && _hasFingerprint) {
      // If both are available, show fingerprint icon as default
      return Icons.fingerprint_rounded;
    } else if (_hasFaceID) {
      // Only Face ID available
      return Icons.face_rounded;
    } else if (_hasFingerprint) {
      // Only Fingerprint available
      return Icons.fingerprint_rounded;
    } else {
      // Fallback
      return Icons.lock_person_rounded;
    }
  }

  // --- UPDATED: Show Biometric Consent Dialog with dynamic content ---
  Future<void> _showBiometricConsentDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon - Dynamic based on available biometric
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getBiometricIcon(),
                    color: const Color(0xFF2979FF),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  "Enable Biometric Login?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Message - Dynamic based on available biometric
                Text(
                  "Would you like to use $_biometricLabel to login quickly and securely?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 25),
                
                // Buttons Row
                Row(
                  children: [
                    // No Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          // Don't proceed with biometric login
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.grey,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "No",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Yes Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _performBiometricLogin(); // Proceed with biometric login
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2979FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Yes",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- NEW: Handle Biometric Login Tap (Shows Dialog First) ---
  Future<void> _handleBiometricLogin() async {
    await _showBiometricConsentDialog();
  }

  // --- UPDATED: Perform Actual Biometric Authentication with dynamic message ---
  Future<void> _performBiometricLogin() async {
    try {
      // 1. Check if biometrics are available
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        _showStylishDialog(
          "Not Available",
          "Biometric authentication is not available on this device.",
        );
        return;
      }

      // 2. Attempt biometric authentication with dynamic message
      String authMessage = 'Please authenticate to login to ShiftSmart';
      if (_hasFaceID && !_hasFingerprint) {
        authMessage = 'Please use Face ID to login to ShiftSmart';
      } else if (_hasFingerprint && !_hasFaceID) {
        authMessage = 'Please use your fingerprint to login to ShiftSmart';
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: authMessage,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        // User canceled or authentication failed
        return;
      }

      // 3. If authenticated, retrieve saved credentials
      String? savedEmail = await _storage.read(key: 'login_email');
      String? savedPass = await _storage.read(key: 'login_pass');

      if (savedEmail == null || savedPass == null) {
        _showStylishDialog(
          "No Saved Credentials",
          "Please login with email and password first.",
        );
        return;
      }

      // 4. Auto-fill the fields (optional - for visual feedback)
      _emailController.text = savedEmail;
      _passwordController.text = savedPass;

      // 5. Trigger the login process
      await _handleEmailPasswordLogin(isBiometric: true);
    } on PlatformException catch (e) {
      String errorMsg = "Authentication error: ${e.message}";
      if (e.code == 'NotAvailable') {
        errorMsg = "Biometric authentication is not available.";
      } else if (e.code == 'NotEnrolled') {
        errorMsg = "No biometrics enrolled. Please set up $_biometricLabel in your device settings.";
      }
      _showStylishDialog("Authentication Failed", errorMsg);
    } catch (e) {
      _showStylishDialog(
        "Error",
        "An error occurred during biometric authentication: $e",
      );
    }
  }

  // --- CUSTOM STYLISH DIALOG ---
  void _showStylishDialog(String title, String message, {bool isError = true}) {
    IconData icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    Color color = isError ? Colors.red : Colors.green;

    if (title == "Connection Error") {
      icon = Icons.wifi_off_rounded;
      color = Colors.orange;
    } else if (title == "Login Failed" || title == "Input Error") {
      icon = Icons.lock_person_outlined;
      color = Colors.redAccent;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Okay",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- MAIN LOGIN LOGIC (Modified to accept Biometric trigger) ---
  Future<void> _handleEmailPasswordLogin({bool isBiometric = false}) async {
    // 1. Validate Form Inputs (Skip validation if Biometric, as fields might be autofilled)
    if (!isBiometric) {
      if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
        _showStylishDialog("Input Error", "Please fix the errors in the form.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      final loginResponse = await _authService.login(email, password);

      if (loginResponse == null) {
        _showStylishDialog(
          "Connection Error",
          "Unable to connect to server. Check internet.",
        );
        return;
      }

      bool isSuccess =
          loginResponse['message'] == "Login successful" ||
          loginResponse['message'] ==
              "Login with temporary password successful";
      bool isOnboarding = loginResponse["onboardingRequired"] == true;

      if (!isSuccess && !isOnboarding) {
        String backendMsg =
            loginResponse['message'] ??
            "Incorrect email or password. Please try again.";
        if (backendMsg.contains("Login failed") ||
            backendMsg.contains("Unexpected character")) {
          _showStylishDialog(
            "Login Failed",
            "Incorrect email or password. Please try again.",
          );
        } else {
          _showStylishDialog("Login Failed", backendMsg);
        }
        return;
      }

      // --- SUCCESS: SAVE CREDENTIALS FOR NEXT TIME ---
      // We save these securely so biometrics can use them later
      await _storage.write(key: 'login_email', value: email);
      await _storage.write(key: 'login_pass', value: password);
      
      // Re-check biometric availability after successful login
      // This ensures the biometric button appears on next launch
      await _checkBiometricAvailability();
      // ----------------------------------------------

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', email);

      if (isOnboarding) {
        final int? idToPass =
            loginResponse["employeeId"] ?? loginResponse["userId"];
        final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
        Map<String, dynamic>? existingProfile;

        if (onboardingMode == "resubmission" && idToPass != null) {
          existingProfile = await _authService.fetchRejectedProfileData(
            idToPass,
          );
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Emponboard(
              email: email,
              existingProfile: existingProfile,
              employeeId: idToPass,
            ),
          ),
        );
        return;
      }

      final exchangeResponse = await _authService.exchangePasswordForToken(
        email,
        password,
      );

      if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
        _showStylishDialog(
          "Authentication Failed",
          "Could not verify credentials.",
        );
        return;
      }

      await prefs.setString('appToken', exchangeResponse['appToken']);

      int? userId = exchangeResponse["userId"];
      String role = exchangeResponse["userRole"] ?? "Employee";
      await prefs.setInt('userId', userId!);
      await prefs.setString('userRole', role);

      final fullProfile = await _authService.fetchFullEmployeeProfile(email);

      if (fullProfile != null) {
        await prefs.setInt('employeeId', fullProfile['EmployeeId']);
        await prefs.setString(
          'userName',
          "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
        );

        final userProfile = {
          "userId": userId,
          "employeeId": fullProfile["EmployeeId"],
          "firstName": fullProfile["FirstName"] ?? "",
          "middleName": fullProfile["MiddleName"] ?? "",
          "lastName": fullProfile["LastName"] ?? "",
          "gender": fullProfile["Gender"] ?? "",
          "email": fullProfile["Email"] ?? "",
          "mobileNumber": fullProfile["MobileNumber"] ?? "",
          "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
          "street": fullProfile["Street"] ?? "",
          "city": fullProfile["City"] ?? "",
          "state": fullProfile["State"] ?? "",
          "postalCode": fullProfile["PostalCode"] ?? "",
          "country": fullProfile["Country"] ?? "",
          "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
          "jobRole": fullProfile["JobRole"] ?? "",
          "userRole": role,
          "profilePicture": fullProfile["ProfilePicture"] ?? "",
          "bankAccountName": fullProfile["BankAccountName"] ?? "",
          "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
          "bankBSB": fullProfile["BankBSB"] ?? "",
          "bankName": fullProfile["BankName"] ?? "",
          "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
        };

        if (mounted) {
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setUserProfile(userProfile);
        }

        try {
          final notificationService = NotificationService();
          await notificationService.initializeFCM(
            employeeId: fullProfile["EmployeeId"],
            userTag: "user_${fullProfile["EmployeeId"]}",
          );
        } catch (fcmError) {
          print("FCM Init Warning: $fcmError");
        }
      } else {
        _showStylishDialog("Profile Error", "Could not load user profile.");
        return;
      }

      if (!mounted) return;
      if (role == "Manager") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Bottomnavbar(selectedIndex: 0),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
        );
      }
    } catch (e) {
      String errorStr = e.toString();
      if (errorStr.contains("Login failed") ||
          errorStr.contains("Unexpected character")) {
        _showStylishDialog("Login Failed", "Incorrect email or password.");
      } else {
        _showStylishDialog(
          "System Error",
          "An unexpected error occurred: $errorStr",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.5;
    final paddingUnit = size.width * 0.03;

    return Scaffold(
      backgroundColor: const Color(0xFF2F3846),
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(paddingUnit * 2),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      Image(
                        image: const AssetImage('assets/logo.png'),
                        width: logoSize,
                        height: logoSize,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(
                                136,
                                42,
                                41,
                                41,
                              ).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Email Field
                                const Text(
                                  "Email",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 32, 32, 32),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "username@gmail.com",
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    const emailRegex =
                                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
                                    if (!RegExp(emailRegex).hasMatch(value)) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),

                                // Password Field
                                const Text(
                                  "Password",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscureText,
                                  enabled: !_isLoading,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 17, 17, 17),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Password",
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureText = !_obscureText,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const ForgotPasswordScreen(),
                                              ),
                                            );
                                          },
                                    child: const Text(
                                      "Forgot Password?",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),

                                // Login Button
                                Center(
                                  child: SizedBox(
                                    width: size.width * 0.7,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleEmailPasswordLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2979FF,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFF2979FF,
                                        ).withOpacity(0.6),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Text(
                                              "Log In",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                // --- UPDATED: Dynamic Biometric Button ---
                                if (_canCheckBiometrics && !_isLoading) ...[
                                  const SizedBox(height: 20),
                                  Center(
                                    child: IconButton(
                                      iconSize: 45,
                                      onPressed: _handleBiometricLogin,
                                      icon: Icon(
                                        _getBiometricIcon(),
                                        color: Colors.white,
                                      ),
                                      tooltip: "Login with $_biometricLabel",
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      "Tap to use $_biometricLabel",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}










// // lib/screens/login.dart
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // For PlatformException
// import 'package:local_auth/local_auth.dart'; // IMPORT 1: Biometrics
// import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // IMPORT 2: Secure Storage
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/screens/forgot_password.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();

//   // NEW: Initialize Secure Storage and Local Auth
//   final _storage = const FlutterSecureStorage();
//   final LocalAuthentication _localAuth = LocalAuthentication();

//   // Controllers
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   // State
//   bool _isLoading = false;
//   bool _obscureText = true;
//   bool _canCheckBiometrics =
//       false; // To hide button if device doesn't support it
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//     _checkBiometricAvailability(); // Check if device supports FaceID
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   // --- NEW: Check if Biometrics is available on device ---
//   Future<void> _checkBiometricAvailability() async {
//     try {
//       final bool canAuthenticateWithBiometrics =
//           await _localAuth.canCheckBiometrics;
//       final bool canAuthenticate =
//           canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

//       // Check if we have credentials saved previously
//       String? savedEmail = await _storage.read(key: 'login_email');
//       String? savedPass = await _storage.read(key: 'login_pass');

//       setState(() {
//         // Only show FaceID button if hardware supports it AND we have data to login with
//         _canCheckBiometrics =
//             canAuthenticate && savedEmail != null && savedPass != null;
//       });
//     } catch (e) {
//       print("Biometric check failed: $e");
//     }
//   }

//   // --- NEW: Show Biometric Consent Dialog ---
//   Future<void> _showBiometricConsentDialog() async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap a button
//       builder: (BuildContext context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           elevation: 16,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 10,
//                   offset: Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Icon
//                 Container(
//                   padding: const EdgeInsets.all(15),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF2979FF).withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(
//                     Icons.fingerprint_rounded,
//                     color: Color(0xFF2979FF),
//                     size: 50,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
                
//                 // Title
//                 const Text(
//                   "Enable Biometric Login?",
//                   style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 12),
                
//                 // Message
//                 const Text(
//                   "Would you like to use Face ID or Fingerprint to login quickly and securely?",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 15,
//                     color: Colors.black54,
//                     height: 1.5,
//                   ),
//                 ),
//                 const SizedBox(height: 25),
                
//                 // Buttons Row
//                 Row(
//                   children: [
//                     // No Button
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: () {
//                           Navigator.of(context).pop(); // Close dialog
//                           // Don't proceed with biometric login
//                         },
//                         style: OutlinedButton.styleFrom(
//                           side: const BorderSide(
//                             color: Colors.grey,
//                             width: 1.5,
//                           ),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         child: const Text(
//                           "No",
//                           style: TextStyle(
//                             color: Colors.grey,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
                    
//                     // Yes Button
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           Navigator.of(context).pop(); // Close dialog
//                           _performBiometricLogin(); // Proceed with biometric login
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF2979FF),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         child: const Text(
//                           "Yes",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // --- NEW: Handle Biometric Login Tap (Shows Dialog First) ---
//   Future<void> _handleBiometricLogin() async {
//     await _showBiometricConsentDialog();
//   }

//   // --- NEW: Perform Actual Biometric Authentication ---
//   Future<void> _performBiometricLogin() async {
//     try {
//       // 1. Check if biometrics are available
//       final bool canAuthenticateWithBiometrics =
//           await _localAuth.canCheckBiometrics;
//       final bool canAuthenticate =
//           canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

//       if (!canAuthenticate) {
//         _showStylishDialog(
//           "Not Available",
//           "Biometric authentication is not available on this device.",
//         );
//         return;
//       }

//       // 2. Attempt biometric authentication
//       final bool didAuthenticate = await _localAuth.authenticate(
//         localizedReason: 'Please authenticate to login to ShiftSmart',
//         options: const AuthenticationOptions(
//           stickyAuth: true,
//           biometricOnly: true,
//         ),
//       );

//       if (!didAuthenticate) {
//         // User canceled or authentication failed
//         return;
//       }

//       // 3. If authenticated, retrieve saved credentials
//       String? savedEmail = await _storage.read(key: 'login_email');
//       String? savedPass = await _storage.read(key: 'login_pass');

//       if (savedEmail == null || savedPass == null) {
//         _showStylishDialog(
//           "No Saved Credentials",
//           "Please login with email and password first.",
//         );
//         return;
//       }

//       // 4. Auto-fill the fields (optional - for visual feedback)
//       _emailController.text = savedEmail;
//       _passwordController.text = savedPass;

//       // 5. Trigger the login process
//       await _handleEmailPasswordLogin(isBiometric: true);
//     } on PlatformException catch (e) {
//       String errorMsg = "Authentication error: ${e.message}";
//       if (e.code == 'NotAvailable') {
//         errorMsg = "Biometric authentication is not available.";
//       } else if (e.code == 'NotEnrolled') {
//         errorMsg = "No biometrics enrolled. Please set up Face ID or Fingerprint.";
//       }
//       _showStylishDialog("Authentication Failed", errorMsg);
//     } catch (e) {
//       _showStylishDialog(
//         "Error",
//         "An error occurred during biometric authentication: $e",
//       );
//     }
//   }

//   // --- CUSTOM STYLISH DIALOG ---
//   void _showStylishDialog(String title, String message, {bool isError = true}) {
//     IconData icon = isError ? Icons.error_outline : Icons.check_circle_outline;
//     Color color = isError ? Colors.red : Colors.green;

//     if (title == "Connection Error") {
//       icon = Icons.wifi_off_rounded;
//       color = Colors.orange;
//     } else if (title == "Login Failed" || title == "Input Error") {
//       icon = Icons.lock_person_outlined;
//       color = Colors.redAccent;
//     }

//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           elevation: 16,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 10,
//                   offset: Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(15),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(icon, color: color, size: 40),
//                 ),
//                 const SizedBox(height: 20),
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   message,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     color: Colors.black54,
//                     height: 1.4,
//                   ),
//                 ),
//                 const SizedBox(height: 25),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: const Text(
//                       "Okay",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // --- MAIN LOGIN LOGIC (Modified to accept Biometric trigger) ---
//   Future<void> _handleEmailPasswordLogin({bool isBiometric = false}) async {
//     // 1. Validate Form Inputs (Skip validation if Biometric, as fields might be autofilled)
//     if (!isBiometric) {
//       if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//         _showStylishDialog("Input Error", "Please fix the errors in the form.");
//         return;
//       }
//     }

//     setState(() {
//       _isLoading = true;
//     });

//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     try {
//       final loginResponse = await _authService.login(email, password);

//       if (loginResponse == null) {
//         _showStylishDialog(
//           "Connection Error",
//           "Unable to connect to server. Check internet.",
//         );
//         return;
//       }

//       bool isSuccess =
//           loginResponse['message'] == "Login successful" ||
//           loginResponse['message'] ==
//               "Login with temporary password successful";
//       bool isOnboarding = loginResponse["onboardingRequired"] == true;

//       if (!isSuccess && !isOnboarding) {
//         String backendMsg =
//             loginResponse['message'] ??
//             "Incorrect email or password. Please try again.";
//         if (backendMsg.contains("Login failed") ||
//             backendMsg.contains("Unexpected character")) {
//           _showStylishDialog(
//             "Login Failed",
//             "Incorrect email or password. Please try again.",
//           );
//         } else {
//           _showStylishDialog("Login Failed", backendMsg);
//         }
//         return;
//       }

//       // --- SUCCESS: SAVE CREDENTIALS FOR NEXT TIME ---
//       // We save these securely so FaceID can use them later
//       await _storage.write(key: 'login_email', value: email);
//       await _storage.write(key: 'login_pass', value: password);
//       // ----------------------------------------------

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);

//       if (isOnboarding) {
//         final int? idToPass =
//             loginResponse["employeeId"] ?? loginResponse["userId"];
//         final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
//         Map<String, dynamic>? existingProfile;

//         if (onboardingMode == "resubmission" && idToPass != null) {
//           existingProfile = await _authService.fetchRejectedProfileData(
//             idToPass,
//           );
//         }

//         if (!mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => Emponboard(
//               email: email,
//               existingProfile: existingProfile,
//               employeeId: idToPass,
//             ),
//           ),
//         );
//         return;
//       }

//       final exchangeResponse = await _authService.exchangePasswordForToken(
//         email,
//         password,
//       );

//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         _showStylishDialog(
//           "Authentication Failed",
//           "Could not verify credentials.",
//         );
//         return;
//       }

//       await prefs.setString('appToken', exchangeResponse['appToken']);

//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Employee";
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);

//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString(
//           'userName',
//           "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//         );

//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(
//             context,
//             listen: false,
//           ).setUserProfile(userProfile);
//         }

//         try {
//           final notificationService = NotificationService();
//           await notificationService.initializeFCM(
//             employeeId: fullProfile["EmployeeId"],
//             userTag: "user_${fullProfile["EmployeeId"]}",
//           );
//         } catch (fcmError) {
//           print("FCM Init Warning: $fcmError");
//         }
//       } else {
//         _showStylishDialog("Profile Error", "Could not load user profile.");
//         return;
//       }

//       if (!mounted) return;
//       if (role == "Manager") {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const Bottomnavbar(selectedIndex: 0),
//           ),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//         );
//       }
//     } catch (e) {
//       String errorStr = e.toString();
//       if (errorStr.contains("Login failed") ||
//           errorStr.contains("Unexpected character")) {
//         _showStylishDialog("Login Failed", "Incorrect email or password.");
//       } else {
//         _showStylishDialog(
//           "System Error",
//           "An unexpected error occurred: $errorStr",
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;

//     return Scaffold(
//       backgroundColor: const Color(0xFF2F3846),
//       body: Stack(
//         children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   autovalidateMode: AutovalidateMode.onUserInteraction,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: const AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(
//                                 136,
//                                 42,
//                                 41,
//                                 41,
//                               ).withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                     fontSize: 28,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 20),

//                                 // Email Field
//                                 const Text(
//                                   "Email",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _emailController,
//                                   keyboardType: TextInputType.emailAddress,
//                                   enabled: !_isLoading,
//                                   style: const TextStyle(
//                                     color: Color.fromARGB(255, 32, 32, 32),
//                                   ),
//                                   decoration: InputDecoration(
//                                     hintText: "username@gmail.com",
//                                     hintStyle: const TextStyle(
//                                       color: Colors.grey,
//                                     ),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                       255,
//                                       255,
//                                       255,
//                                       255,
//                                     ),
//                                     border: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                   ),
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty)
//                                       return 'Please enter an email';
//                                     const emailRegex =
//                                         r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                                     if (!RegExp(emailRegex).hasMatch(value))
//                                       return 'Please enter a valid email address';
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 15),

//                                 // Password Field
//                                 const Text(
//                                   "Password",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _passwordController,
//                                   obscureText: _obscureText,
//                                   enabled: !_isLoading,
//                                   style: const TextStyle(
//                                     color: Color.fromARGB(255, 17, 17, 17),
//                                   ),
//                                   decoration: InputDecoration(
//                                     hintText: "Password",
//                                     hintStyle: const TextStyle(
//                                       color: Colors.grey,
//                                     ),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                       255,
//                                       255,
//                                       255,
//                                       255,
//                                     ),
//                                     border: OutlineInputBorder(
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     suffixIcon: IconButton(
//                                       icon: Icon(
//                                         _obscureText
//                                             ? Icons.visibility_off
//                                             : Icons.visibility,
//                                         color: Colors.grey,
//                                       ),
//                                       onPressed: () => setState(
//                                         () => _obscureText = !_obscureText,
//                                       ),
//                                     ),
//                                   ),
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty)
//                                       return 'Please enter your password';
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 10),

//                                 // Forgot Password Link
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: _isLoading
//                                         ? null
//                                         : () {
//                                             Navigator.push(
//                                               context,
//                                               MaterialPageRoute(
//                                                 builder: (context) =>
//                                                     const ForgotPasswordScreen(),
//                                               ),
//                                             );
//                                           },
//                                     child: const Text(
//                                       "Forgot Password?",
//                                       style: TextStyle(color: Colors.white70),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),

//                                 // Login Button
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     height: 50,
//                                     child: ElevatedButton(
//                                       onPressed: _isLoading
//                                           ? null
//                                           : _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: const Color(
//                                           0xFF2979FF,
//                                         ),
//                                         disabledBackgroundColor: const Color(
//                                           0xFF2979FF,
//                                         ).withOpacity(0.6),
//                                         padding: EdgeInsets.zero,
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             10,
//                                           ),
//                                         ),
//                                       ),
//                                       child: _isLoading
//                                           ? const SizedBox(
//                                               width: 24,
//                                               height: 24,
//                                               child: CircularProgressIndicator(
//                                                 color: Colors.white,
//                                                 strokeWidth: 2.5,
//                                               ),
//                                             )
//                                           : const Text(
//                                               "Log In",
//                                               style: TextStyle(
//                                                 fontSize: 16,
//                                                 color: Colors.white,
//                                               ),
//                                             ),
//                                     ),
//                                   ),
//                                 ),

//                                 // --- NEW: Biometric Button (Only shows if supported & credentials exist) ---
//                                 if (_canCheckBiometrics && !_isLoading) ...[
//                                   const SizedBox(height: 20),
//                                   Center(
//                                     child: IconButton(
//                                       iconSize: 45,
//                                       onPressed: _handleBiometricLogin,
//                                       icon: const Icon(
//                                         Icons.fingerprint_rounded,
//                                         color: Colors.white,
//                                       ),
//                                       // Or use Icons.face_rounded if you prefer
//                                       tooltip:
//                                           "Login with Face ID / Fingerprint",
//                                     ),
//                                   ),
//                                   const Center(
//                                     child: Text(
//                                       "Tap to use Biometrics",
//                                       style: TextStyle(
//                                         color: Colors.white70,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }






















// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:local_auth/local_auth.dart'; // Added for Face ID/Touch ID
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:provider/provider.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';
 
// class Login extends StatefulWidget {
//   const Login({super.key});
 
//   @override
//   State<Login> createState() => _LoginState();
// }
 
// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();
//   final LocalAuthentication _localAuth = LocalAuthentication(); // Added for biometric
 
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
 
//   // State variables
//   bool _isLoading = false;
//   bool _obscureText = true;
//   final _formKey = GlobalKey<FormState>();
  
//   // Biometric state variables
//   bool _canUseBiometric = false;
//   bool _isBiometricEnabled = false;
//   bool _showBiometricButton = false;
//   bool _showLoginForm = false; // NEW: Control login form visibility
 
//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//     _checkBiometricAvailability(); // Check biometric availability on startup
//   }
 
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   // --- BIOMETRIC AVAILABILITY CHECK ---
//   Future<void> _checkBiometricAvailability() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Check if device can use biometric authentication
//       final canCheckBiometrics = await _localAuth.canCheckBiometrics;
//       final isDeviceSupported = await _localAuth.isDeviceSupported();
      
//       // Check if user has previously logged in successfully
//       final hasLoggedInBefore = prefs.getString('lastBiometricEmail') != null;
      
//       // Check if the last biometric login is still valid (within 1 hour)
//       final lastLoginTime = prefs.getInt('lastBiometricLoginTime');
//       final isSessionValid = lastLoginTime != null && 
//           DateTime.now().millisecondsSinceEpoch - lastLoginTime < 3600000; // 1 hour
      
//       setState(() {
//         _canUseBiometric = canCheckBiometrics && isDeviceSupported;
//         _isBiometricEnabled = hasLoggedInBefore;
//         _showBiometricButton = _canUseBiometric && _isBiometricEnabled && isSessionValid;
//       });
      
//       // Auto-fill email if biometric is available
//       if (_showBiometricButton) {
//         final savedEmail = prefs.getString('lastBiometricEmail');
//         if (savedEmail != null) {
//           _emailController.text = savedEmail;
//         }

//         // SHOW CONFIRMATION POPUP IMMEDIATELY WHEN LOGIN PAGE LOADS
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (mounted) {
//             Future.delayed(const Duration(milliseconds: 300), () {
//               if (mounted) {
//                 _showBiometricConfirmationPopup();
//               }
//             });
//           }
//         });
//       } else {
//         // If biometric not available, show login form immediately
//         setState(() {
//           _showLoginForm = true;
//         });
//       }
      
//     } catch (e) {
//       print("Error checking biometric availability: $e");
//       // Show login form if error occurs
//       setState(() {
//         _showLoginForm = true;
//       });
//     }
//   }

//   // --- SHOW BIOMETRIC CONFIRMATION POPUP ---
//   void _showBiometricConfirmationPopup() {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // User must choose an option
//       builder: (BuildContext dialogContext) {
//         return Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           elevation: 16,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 10,
//                   offset: Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Icon Bubble
//                 Container(
//                   padding: const EdgeInsets.all(15),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Icon(
//                     Icons.fingerprint,
//                     color: Colors.blue,
//                     size: 48,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 // Title
//                 const Text(
//                   "Quick Login Available",
//                   style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 // Message
//                 const Text(
//                   "Do you want to use Face ID or Touch ID to login quickly?",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 15,
//                     color: Colors.black54,
//                     height: 1.4,
//                   ),
//                 ),
//                 const SizedBox(height: 25),
//                 // Buttons Row
//                 Row(
//                   children: [
//                     // No Button - Show password login
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: () {
//                           Navigator.pop(dialogContext); // Close dialog
//                           setState(() {
//                             _showLoginForm = true; // Show email/password form
//                           });
//                         },
//                         style: OutlinedButton.styleFrom(
//                           side: const BorderSide(color: Colors.grey),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         child: const Text(
//                           "No",
//                           style: TextStyle(
//                             color: Colors.grey,
//                             fontSize: 15,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     // Yes Button - Use Face ID
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           Navigator.pop(dialogContext); // Close dialog first
//                           _handleBiometricLogin(); // Then trigger Face ID
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.blue,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         child: const Text(
//                           "Yes",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 15,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // --- BIOMETRIC LOGIN HANDLER ---
//   Future<void> _handleBiometricLogin() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Check if session is still valid (within 1 hour)
//       final lastLoginTime = prefs.getInt('lastBiometricLoginTime');
//       if (lastLoginTime == null || 
//           DateTime.now().millisecondsSinceEpoch - lastLoginTime >= 3600000) {
//         setState(() {
//           _isLoading = false;
//           _showBiometricButton = false;
//           _showLoginForm = true; // Show password form
//         });
//         _showStylishDialog(
//           "Session Expired",
//           "Your biometric session has expired. Please login with your password.",
//         );
//         return;
//       }
      
//       // Trigger Face ID/Touch ID/Fingerprint prompt
//       final authenticated = await _localAuth.authenticate(
//         localizedReason: 'Authenticate to login to ShiftSmart',
//         options: const AuthenticationOptions(
//           stickyAuth: true,
//           biometricOnly: true,
//         ),
//       );

//       if (!authenticated) {
//         setState(() {
//           _isLoading = false;
//           _showLoginForm = true; // Show password form if cancelled
//         });
//         return;
//       }

//       // Retrieve saved credentials after successful biometric authentication
//       final savedEmail = prefs.getString('lastBiometricEmail');
//       final savedToken = prefs.getString('appToken');
//       final savedUserId = prefs.getInt('userId');
//       final savedRole = prefs.getString('userRole');

//       if (savedEmail == null || savedToken == null || savedUserId == null) {
//         setState(() {
//           _isLoading = false;
//           _showBiometricButton = false;
//           _showLoginForm = true;
//         });
//         _showStylishDialog(
//           "Session Error",
//           "Your session has expired. Please login with your password.",
//         );
//         return;
//       }

//       // Fetch fresh profile data
//       final fullProfile = await _authService.fetchFullEmployeeProfile(savedEmail);

//       if (fullProfile != null) {
//         // Update user provider with latest data
//         final userProfile = {
//           "userId": savedUserId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": savedRole ?? "Employee",
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(context, listen: false)
//               .setUserProfile(userProfile);
//         }

//         // Navigate to appropriate screen based on role
//         if (mounted) {
//           if (savedRole == "Manager") {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                   builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//             );
//           } else {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//             );
//           }
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//           _showLoginForm = true;
//         });
//         _showStylishDialog(
//           "Profile Error",
//           "Could not load your profile. Please login again with your password.",
//         );
//       }

//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _showLoginForm = true; // Show password form on error
//       });
//       // Only show error dialog if it's not a user cancellation
//       if (!e.toString().contains('User canceled') && 
//           !e.toString().contains('UserCancel') &&
//           !e.toString().contains('NotAvailable')) {
//         _showStylishDialog(
//           "Biometric Error",
//           "An error occurred during biometric authentication. Please use your password to login.",
//         );
//       }
//       print("Biometric Login Exception: $e");
//     }
//   }
 
//   // --- CUSTOM STYLISH DIALOG ---
//   void _showStylishDialog(String title, String message, {bool isError = true}) {
//     IconData icon = isError ? Icons.error_outline : Icons.check_circle_outline;
//     Color color = isError ? Colors.red : Colors.green;
 
//     // Custom styling based on the error title for better UX
//     if (title == "Connection Error") {
//       icon = Icons.wifi_off_rounded;
//       color = Colors.orange;
//     } else if (title == "Login Failed" || title == "Input Error") {
//       icon = Icons.lock_person_outlined;
//       color = Colors.redAccent;
//     } else if (title == "Account Pending" || title == "Awaiting Approval") {
//       icon = Icons.hourglass_empty_rounded;
//       color = Colors.orange;
//     } else if (title == "Onboarding Required") {
//       icon = Icons.assignment_outlined;
//       color = Colors.blue;
//     } else if (title == "Session Expired" || title == "Session Error") {
//       icon = Icons.timer_off_outlined;
//       color = Colors.orange;
//     } else if (title == "Authentication Failed") {
//       icon = Icons.fingerprint;
//       color = Colors.redAccent;
//     } else if (title == "Biometric Error") {
//       icon = Icons.error_outline;
//       color = Colors.red;
//     }
 
//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           elevation: 16,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 10,
//                   offset: Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Icon Bubble
//                 Container(
//                   padding: const EdgeInsets.all(15),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     icon,
//                     color: color,
//                     size: 40,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 // Title
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 // Message
//                 Text(
//                   message,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     color: Colors.black54,
//                     height: 1.4,
//                   ),
//                 ),
//                 const SizedBox(height: 25),
//                 // Button
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: const Text(
//                       "Okay",
//                       style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
 
//   // --- LOGIN LOGIC ---
//   Future<void> _handleEmailPasswordLogin() async {
//     // 1. Local Validation
//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       _showStylishDialog("Input Error",
//           "Please check that your email and password are correct.");
//       return;
//     }
 
//     // 2. Start Spinner
//     setState(() {
//       _isLoading = true;
//     });
 
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();
 
//     try {
//       // -----------------------------------------------------------------
//       // STEP 1: Call the LOGIN endpoint
//       // -----------------------------------------------------------------
//       final loginResponse = await _authService.login(email, password);
 
//       // -----------------------------------------------------------------
//       // ERROR HANDLING (CRITICAL FIX FOR 500 ERROR)
//       // -----------------------------------------------------------------
//       if (loginResponse == null || loginResponse.containsKey('Message')) {
//         String rawError = loginResponse?['Message'] ?? "";
 
//         if (rawError.contains("Login failed") ||
//             rawError.contains("Unexpected character")) {
//           _showStylishDialog(
//               "Login Failed", "Incorrect email or password. Please try again.");
//         } else if (rawError.contains("SocketException")) {
//           _showStylishDialog("Connection Error",
//               "Cannot reach the server. Check your internet.");
//         } else {
//           _showStylishDialog("System Error", rawError);
//         }
//         return;
//       }
 
//       // -----------------------------------------------------------------
//       // CRITICAL WORKFLOW CHECK: Account Status Validation
//       // -----------------------------------------------------------------
//       if (loginResponse.containsKey('accountStatus')) {
//         String accountStatus = loginResponse['accountStatus'] ?? "";
        
//         if (accountStatus == "pending" || accountStatus == "waiting_approval") {
//           _showStylishDialog(
//             "Awaiting Approval",
//             "Your profile has been submitted and is awaiting admin approval. You will receive a notification once your account is activated. Please check your email for updates.",
//           );
//           return;
//         }
//       }
 
//       // Check success message
//       if (loginResponse['message'] != "Login successful" &&
//           loginResponse['message'] != "Login with temporary password successful") {
//         _showStylishDialog("Login Issue",
//             loginResponse['message'] ?? "Unknown error occurred.");
//         return;
//       }
 
//       // -----------------------------------------------------------------
//       // STEP 2: Check if onboarding is required
//       // -----------------------------------------------------------------
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);
 
//       final bool onboardingRequired = loginResponse["onboardingRequired"] ?? false;
//       final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
//       final bool isTemporaryPassword = loginResponse['message'] == "Login with temporary password successful";
 
//       if (onboardingRequired) {
//         Map<String, dynamic>? existingProfile;
 
//         if (onboardingMode == "initial" || isTemporaryPassword) {
//           if (!mounted) return;
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Emponboard(
//                 email: email,
//                 rejectionReason: null,
//                 existingProfile: null,
//               ),
//             ),
//           );
//           return;
//         }
        
//         else if (onboardingMode == "resubmission") {
//           final int? employeeId = loginResponse["employeeId"];
//           if (employeeId != null) {
//             existingProfile = await _authService.fetchRejectedProfileData(employeeId);
//             if (existingProfile == null) {
//               _showStylishDialog("Error", "Could not load your previous profile data. Please contact support.");
//               return;
//             }
//           } else {
//             _showStylishDialog("Error", "Account ID missing. Please contact support.");
//             return;
//           }
 
//           if (!mounted) return;
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Emponboard(
//                 email: email,
//                 rejectionReason: loginResponse['rejectionReason'],
//                 existingProfile: existingProfile,
//               ),
//             ),
//           );
//           return;
//         }
        
//         else {
//           _showStylishDialog(
//             "Registration Pending",
//             "Your registration is being processed. Please wait for admin approval before logging in again.",
//           );
//           return;
//         }
//       }
 
//       // -----------------------------------------------------------------
//       // STEP 3: Normal login flow (account is approved and active)
//       // -----------------------------------------------------------------
      
//       // Exchange temporary/regular password for session token
//       final exchangeResponse = await _authService.exchangePasswordForToken(email, password);
//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         _showStylishDialog("Auth Error", "Session token missing. Please try logging in again.");
//         return;
//       }

//       // Save token to SharedPreferences
//       await prefs.setString('appToken', exchangeResponse['appToken']);
 
//       // Fetch user details
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Unknown";
 
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);
 
//       // Fetch complete employee profile
//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);
 
//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString('userName',
//             "${fullProfile["FirstName"]} ${fullProfile["LastName"]}");

//         // --- SAVE BIOMETRIC CREDENTIALS AFTER SUCCESSFUL PASSWORD LOGIN ---
//         await prefs.setString('lastBiometricEmail', email);
//         await prefs.setInt('lastBiometricLoginTime', DateTime.now().millisecondsSinceEpoch);
//         print("Biometric credentials saved for future login");
 
//         // Build user profile object
//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };
 
//         // Set user profile in provider
//         if (!mounted) return;
//         Provider.of<UserProvider>(context, listen: false)
//             .setUserProfile(userProfile);
 
//         // Initialize push notifications
//         final notificationService = NotificationService();
//         await notificationService.initializeFCM(
//           employeeId: fullProfile["EmployeeId"],
//           userTag: "user_${fullProfile["EmployeeId"]}",
//         );
//       } else {
//         _showStylishDialog("Profile Error", "We couldn't load your profile. Please try again.");
//         return;
//       }
 
//       // -----------------------------------------------------------------
//       // STEP 4: Navigate to appropriate home screen
//       // -----------------------------------------------------------------
//       if (!mounted) return;
//       if (role == "Manager") {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => EmpBottomnavbar()),
//         );
//       }
//     } catch (e) {
//       // General error handling
//       String errorStr = e.toString();
//       _showStylishDialog(
//           "App Error", "An unexpected error occurred: $errorStr\n\nPlease try again or contact support.");
//     } finally {
//       // Stop loading spinner
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
 
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;
 
//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   autovalidateMode: AutovalidateMode.onUserInteraction,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
                      
//                       // Only show login form after user interaction or if biometric not available
//                       if (_showLoginForm) ...[
//                         ClipRRect(
//                           borderRadius: BorderRadius.circular(20),
//                           child: BackdropFilter(
//                             filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                             child: Container(
//                               padding: const EdgeInsets.all(20),
//                               decoration: BoxDecoration(
//                                 color: const Color.fromARGB(136, 42, 41, 41)
//                                     .withOpacity(0.6),
//                                 borderRadius: BorderRadius.circular(20),
//                                 border: Border.all(color: Colors.white),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.2),
//                                     spreadRadius: 2,
//                                     blurRadius: 8,
//                                     offset: const Offset(0, 4),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     "Login",
//                                     style: TextStyle(
//                                         fontSize: 28,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.white),
//                                   ),
//                                   const SizedBox(height: 20),

//                                   // --- BIOMETRIC LOGIN BUTTON (Optional) ---
//                                   if (_showBiometricButton) ...[
//                                     Center(
//                                       child: Column(
//                                         children: [
//                                           IconButton(
//                                             onPressed: _isLoading ? null : _handleBiometricLogin,
//                                             icon: const Icon(
//                                               Icons.fingerprint,
//                                               size: 64,
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 8),
//                                           const Text(
//                                             "Login with Face ID / Touch ID",
//                                             style: TextStyle(
//                                               color: Colors.white70,
//                                               fontSize: 14,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 20),
//                                           const Row(
//                                             children: [
//                                               Expanded(
//                                                   child: Divider(
//                                                       color: Colors.white38,
//                                                       thickness: 1)),
//                                               Padding(
//                                                 padding: EdgeInsets.symmetric(horizontal: 8.0),
//                                                 child: Text("Or use password",
//                                                     style: TextStyle(color: Colors.white)),
//                                               ),
//                                               Expanded(
//                                                   child: Divider(
//                                                       color: Colors.white38,
//                                                       thickness: 1)),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 20),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
   
//                                   // Email Field
//                                   Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const Text(
//                                         "Email",
//                                         style: TextStyle(
//                                             color: Colors.white, fontSize: 16),
//                                       ),
//                                       const SizedBox(height: 5),
//                                       TextFormField(
//                                         controller: _emailController,
//                                         keyboardType: TextInputType.emailAddress,
//                                         enabled: !_isLoading,
//                                         style: const TextStyle(
//                                             color:
//                                                 Color.fromARGB(255, 32, 32, 32)),
//                                         decoration: InputDecoration(
//                                           hintText: "username@gmail.com",
//                                           hintStyle:
//                                               const TextStyle(color: Colors.grey),
//                                           filled: true,
//                                           fillColor: const Color.fromARGB(
//                                               255, 255, 255, 255),
//                                           border: OutlineInputBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(12),
//                                           ),
//                                         ),
//                                         validator: (value) {
//                                           if (value == null || value.isEmpty) {
//                                             return 'Email is required';
//                                           }
//                                           if (!value.contains('@') ||
//                                               !value.contains('.')) {
//                                             return 'Please enter a valid email';
//                                           }
//                                           return null;
//                                         },
//                                       ),
//                                     ],
//                                   ),
   
//                                   const SizedBox(height: 15),
   
//                                   // Password Field
//                                   Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const Text(
//                                         "Password",
//                                         style: TextStyle(
//                                             color: Colors.white, fontSize: 16),
//                                       ),
//                                       const SizedBox(height: 5),
//                                       TextFormField(
//                                         controller: _passwordController,
//                                         obscureText: _obscureText,
//                                         enabled: !_isLoading,
//                                         style: const TextStyle(
//                                             color:
//                                                 Color.fromARGB(255, 17, 17, 17)),
//                                         decoration: InputDecoration(
//                                           hintText: "Password",
//                                           hintStyle:
//                                               const TextStyle(color: Colors.grey),
//                                           filled: true,
//                                           fillColor: const Color.fromARGB(
//                                               255, 255, 255, 255),
//                                           border: OutlineInputBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(12),
//                                           ),
//                                           suffixIcon: IconButton(
//                                             icon: Icon(
//                                               _obscureText
//                                                   ? Icons.visibility_off
//                                                   : Icons.visibility,
//                                               color: Colors.grey,
//                                             ),
//                                             onPressed: () {
//                                               setState(() {
//                                                 _obscureText = !_obscureText;
//                                               });
//                                             },
//                                           ),
//                                         ),
//                                         validator: (value) {
//                                           if (value == null || value.isEmpty) {
//                                             return 'Password is required';
//                                           }
//                                           return null;
//                                         },
//                                       ),
//                                     ],
//                                   ),
   
//                                   const SizedBox(height: 10),
//                                   Align(
//                                     alignment: Alignment.centerLeft,
//                                     child: TextButton(
//                                       onPressed: _isLoading
//                                           ? null
//                                           : () {
//                                               // TODO: Implement forgot password functionality
//                                             },
//                                       child: const Text(
//                                         "Forgot Password?",
//                                         style: TextStyle(color: Colors.white70),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 15),
   
//                                   // Login Button
//                                   Center(
//                                     child: SizedBox(
//                                       width: size.width * 0.7,
//                                       height: 50,
//                                       child: ElevatedButton(
//                                         onPressed: _isLoading
//                                             ? null
//                                             : _handleEmailPasswordLogin,
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor:
//                                               const Color(0xFF2979FF),
//                                           disabledBackgroundColor:
//                                               const Color(0xFF2979FF)
//                                                   .withOpacity(0.6),
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(10),
//                                           ),
//                                         ),
//                                         child: _isLoading
//                                             ? const SizedBox(
//                                                 width: 24,
//                                                 height: 24,
//                                                 child: CircularProgressIndicator(
//                                                   color: Colors.white,
//                                                   strokeWidth: 2.5,
//                                                 ),
//                                               )
//                                             : const Text(
//                                                 "Log In",
//                                                 style: TextStyle(
//                                                     fontSize: 16,
//                                                     color: Colors.white,
//                                                     fontWeight: FontWeight.bold),
//                                               ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(height: 15),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// }























// // lib/screens/login.dart
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:provider/provider.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';
 
// class Login extends StatefulWidget {
//   const Login({super.key});
 
//   @override
//   State<Login> createState() => _LoginState();
// }
 
// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();
 
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
 
//   // State variables
//   bool _isLoading = false;
//   bool _obscureText = true;
//   final _formKey = GlobalKey<FormState>();
 
//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//   }
 
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
 
//   // --- CUSTOM STYLISH DIALOG ---
//   void _showStylishDialog(String title, String message, {bool isError = true}) {
//     IconData icon = isError ? Icons.error_outline : Icons.check_circle_outline;
//     Color color = isError ? Colors.red : Colors.green;
 
//     // Custom styling based on the error title for better UX
//     if (title == "Connection Error") {
//       icon = Icons.wifi_off_rounded;
//       color = Colors.orange;
//     } else if (title == "Login Failed" || title == "Input Error") {
//       icon = Icons.lock_person_outlined;
//       color = Colors.redAccent;
//     }
 
//     showDialog(
//       context: context,
//       builder: (context) {
//         return Dialog(
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           elevation: 16,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 10,
//                   offset: Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Icon Bubble
//                 Container(
//                   padding: const EdgeInsets.all(15),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     icon,
//                     color: color,
//                     size: 40,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 // Title
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 // Message
//                 Text(
//                   message,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     color: Colors.black54,
//                     height: 1.4,
//                   ),
//                 ),
//                 const SizedBox(height: 25),
//                 // Button
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: color,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       padding: const EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: const Text(
//                       "Okay",
//                       style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
 
//   // --- LOGIN LOGIC ---
//   Future<void> _handleEmailPasswordLogin() async {
//     // 1. Local Validation
//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       _showStylishDialog("Input Error",
//           "Please check that your email and password are correct.");
//       return;
//     }
 
//     // 2. Start Spinner
//     setState(() {
//       _isLoading = true;
//     });
 
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();
 
//     try {
//       // -----------------------------------------------------------------
//       // STEP 1: Call the LOGIN endpoint
//       // -----------------------------------------------------------------
//       final loginResponse = await _authService.login(email, password);
 
//       // -----------------------------------------------------------------
//       // ERROR HANDLING (CRITICAL FIX FOR 500 ERROR)
//       // -----------------------------------------------------------------
//       if (loginResponse == null || loginResponse.containsKey('Message')) {
//         String rawError = loginResponse?['Message'] ?? "";
 
//         // ** THE FIX **
//         // The server returns 500 and text "Login failed." which causes a FormatException.
//         // We detect this specific pattern and show a friendly message.
//         if (rawError.contains("Login failed") ||
//             rawError.contains("Unexpected character")) {
//           // Treat "500 FormatException: Login failed" as Wrong Password
//           _showStylishDialog(
//               "Login Failed", "Incorrect email or password. Please try again.");
//         } else if (rawError.contains("SocketException")) {
//           _showStylishDialog("Connection Error",
//               "Cannot reach the server. Check your internet.");
//         } else {
//           // Fallback for other errors
//           _showStylishDialog("System Error", rawError);
//         }
//         return;
//       }
 
//       // Check success message explicitly
//       if (loginResponse['message'] != "Login successful" &&
//           loginResponse['message'] !=
//               "Login with temporary password successful") {
//         _showStylishDialog("Login Issue",
//             loginResponse['message'] ?? "Unknown error occurred.");
//         return;
//       }
 
//       // -----------------------------------------------------------------
//       // STEP 2: SUCCESS - Save Data
//       // -----------------------------------------------------------------
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);
 
//       // Check Onboarding
//       final bool onboardingRequired =
//           loginResponse["onboardingRequired"] ?? false;
//       final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
 
//       if (onboardingRequired) {
//         Map<String, dynamic>? existingProfile;
 
//         if (onboardingMode == "resubmission") {
//           final int? employeeId = loginResponse["employeeId"];
//           if (employeeId != null) {
//             existingProfile =
//                 await _authService.fetchRejectedProfileData(employeeId);
//             if (existingProfile == null) {
//               _showStylishDialog("Error", "Could not load profile data.");
//               return;
//             }
//           } else {
//             _showStylishDialog("Error", "Account ID missing.");
//             return;
//           }
//         }
 
//         if (!mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => Emponboard(
//               email: email,
//               rejectionReason: loginResponse['rejectionReason'],
//               existingProfile: existingProfile,
//             ),
//           ),
//         );
//         return;
//       }
 
//       // Exchange Token
//       final exchangeResponse =
//           await _authService.exchangePasswordForToken(email, password);
//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         _showStylishDialog("Auth Error", "Session token missing.");
//         return;
//       }
 
//       // Fetch Full Profile
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Unknown";
 
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);
 
//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);
 
//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString('userName',
//             "${fullProfile["FirstName"]} ${fullProfile["LastName"]}");
 
//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };
 
//         if (!mounted) return;
//         Provider.of<UserProvider>(context, listen: false)
//             .setUserProfile(userProfile);
 
//         final notificationService = NotificationService();
//         await notificationService.initializeFCM(
//           employeeId: fullProfile["EmployeeId"],
//           userTag: "user_${fullProfile["EmployeeId"]}",
//         );
//       } else {
//         _showStylishDialog("Profile Error", "We couldn't load your profile.");
//         return;
//       }
 
//       // Navigate
//       if (!mounted) return;
//       if (role == "Manager") {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => EmpBottomnavbar()),
//         );
//       }
//     } catch (e) {
//       // General Crash Handling
//       String errorStr = e.toString();
//       _showStylishDialog(
//           "App Error", "An unexpected error occurred: $errorStr");
//     } finally {
//       // 3. Stop Spinner (Always runs)
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
 
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;
 
//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   autovalidateMode: AutovalidateMode.onUserInteraction,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(136, 42, 41, 41)
//                                   .withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white),
//                                 ),
//                                 const SizedBox(height: 20),
 
//                                 // Email Field
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text(
//                                       "Email",
//                                       style: TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                     const SizedBox(height: 5),
//                                     TextFormField(
//                                       controller: _emailController,
//                                       keyboardType: TextInputType.emailAddress,
//                                       enabled: !_isLoading,
//                                       style: const TextStyle(
//                                           color:
//                                               Color.fromARGB(255, 32, 32, 32)),
//                                       decoration: InputDecoration(
//                                         hintText: "username@gmail.com",
//                                         hintStyle:
//                                             const TextStyle(color: Colors.grey),
//                                         filled: true,
//                                         fillColor: const Color.fromARGB(
//                                             255, 255, 255, 255),
//                                         border: OutlineInputBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(12),
//                                         ),
//                                       ),
//                                       validator: (value) {
//                                         if (value == null || value.isEmpty) {
//                                           return 'Email is required';
//                                         }
//                                         // Simple regex for email validation
//                                         if (!value.contains('@') ||
//                                             !value.contains('.')) {
//                                           return 'Please enter a valid email';
//                                         }
//                                         return null;
//                                       },
//                                     ),
//                                   ],
//                                 ),
 
//                                 const SizedBox(height: 15),
 
//                                 // Password Field
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text(
//                                       "Password",
//                                       style: TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                     const SizedBox(height: 5),
//                                     TextFormField(
//                                       controller: _passwordController,
//                                       obscureText: _obscureText,
//                                       enabled: !_isLoading,
//                                       style: const TextStyle(
//                                           color:
//                                               Color.fromARGB(255, 17, 17, 17)),
//                                       decoration: InputDecoration(
//                                         hintText: "Password",
//                                         hintStyle:
//                                             const TextStyle(color: Colors.grey),
//                                         filled: true,
//                                         fillColor: const Color.fromARGB(
//                                             255, 255, 255, 255),
//                                         border: OutlineInputBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(12),
//                                         ),
//                                         suffixIcon: IconButton(
//                                           icon: Icon(
//                                             _obscureText
//                                                 ? Icons.visibility_off
//                                                 : Icons.visibility,
//                                             color: Colors.grey,
//                                           ),
//                                           onPressed: () {
//                                             setState(() {
//                                               _obscureText = !_obscureText;
//                                             });
//                                           },
//                                         ),
//                                       ),
//                                       validator: (value) {
//                                         if (value == null || value.isEmpty) {
//                                           return 'Password is required';
//                                         }
//                                         return null;
//                                       },
//                                     ),
//                                   ],
//                                 ),
 
//                                 const SizedBox(height: 10),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: _isLoading
//                                         ? null
//                                         : () {
//                                             // Add Forgot Password logic
//                                           },
//                                     child: const Text(
//                                       "Forgot Password?",
//                                       style: TextStyle(color: Colors.white70),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
 
//                                 // Login Button
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     height: 50,
//                                     child: ElevatedButton(
//                                       onPressed: _isLoading
//                                           ? null
//                                           : _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor:
//                                             const Color(0xFF2979FF),
//                                         disabledBackgroundColor:
//                                             const Color(0xFF2979FF)
//                                                 .withOpacity(0.6),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(10),
//                                         ),
//                                       ),
//                                       child: _isLoading
//                                           ? const SizedBox(
//                                               width: 24,
//                                               height: 24,
//                                               child: CircularProgressIndicator(
//                                                 color: Colors.white,
//                                                 strokeWidth: 2.5,
//                                               ),
//                                             )
//                                           : const Text(
//                                               "Log In",
//                                               style: TextStyle(
//                                                   fontSize: 16,
//                                                   color: Colors.white,
//                                                   fontWeight: FontWeight.bold),
//                                             ),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// }
 
 





















// import 'dart:ui';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:local_auth/local_auth.dart'; // BIOMETRIC VERSION: Import for Face ID/Touch ID
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/screens/forgot_password.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();
  
//   // BIOMETRIC VERSION: Initialize Local Authentication for Face ID/Touch ID
//   final LocalAuthentication _localAuth = LocalAuthentication();

//   // Controllers
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   // State
//   bool _obscureText = true;
//   bool _isLoading = false; // BASE VERSION: Added loading state variable to track login process
//   final _formKey = GlobalKey<FormState>();
  
//   // BIOMETRIC VERSION: State variables for biometric authentication
//   bool _canUseBiometric = false; // Can device support biometric?
//   bool _isBiometricEnabled = false; // Has user logged in before?
//   bool _showBiometricButton = false; // Show Face ID button on UI?

//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
    
//     // BIOMETRIC VERSION: Check if biometric login is available when screen loads
//     _checkBiometricAvailability();
//   }

//   // BIOMETRIC VERSION: Check if device supports biometric and if user has previously logged in
//   Future<void> _checkBiometricAvailability() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Check if device can use biometric authentication (Face ID/Touch ID/Fingerprint)
//       final canCheckBiometrics = await _localAuth.canCheckBiometrics;
//       final isDeviceSupported = await _localAuth.isDeviceSupported();
      
//       // Check if user has previously logged in successfully
//       final hasLoggedInBefore = prefs.getString('lastBiometricEmail') != null;
      
//       // BIOMETRIC VERSION: Check if the last biometric login is still valid (within 1 hour)
//       final lastLoginTime = prefs.getInt('lastBiometricLoginTime');
//       final isSessionValid = lastLoginTime != null && 
//           DateTime.now().millisecondsSinceEpoch - lastLoginTime < 3600000; // 1 hour = 3600000 ms
      
//       setState(() {
//         _canUseBiometric = canCheckBiometrics && isDeviceSupported;
//         _isBiometricEnabled = hasLoggedInBefore;
//         // Show biometric button only if device supports it, user logged in before, and session is valid
//         _showBiometricButton = _canUseBiometric && _isBiometricEnabled && isSessionValid;
//       });
      
//       // BIOMETRIC VERSION: Auto-fill email if biometric is available
//       if (_showBiometricButton) {
//         final savedEmail = prefs.getString('lastBiometricEmail');
//         if (savedEmail != null) {
//           _emailController.text = savedEmail;
//         }
//       }
      
//     } catch (e) {
//       print("BIOMETRIC VERSION: Error checking availability: $e");
//     }
//   }

//   // BIOMETRIC VERSION: Handle Face ID/Touch ID authentication
//   Future<void> _handleBiometricLogin() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // BIOMETRIC VERSION: Check if session is still valid (within 1 hour)
//       final lastLoginTime = prefs.getInt('lastBiometricLoginTime');
//       if (lastLoginTime == null || 
//           DateTime.now().millisecondsSinceEpoch - lastLoginTime >= 3600000) {
//         // Session expired, require password login
//         setState(() {
//           _isLoading = false;
//           _showBiometricButton = false;
//         });
//         _showSnackBar("Biometric session expired. Please login with password.");
//         return;
//       }
      
//       // BIOMETRIC VERSION: Trigger Face ID/Touch ID/Fingerprint prompt
//       final authenticated = await _localAuth.authenticate(
//         localizedReason: 'Authenticate to login to ShiftSmart',
//         options: const AuthenticationOptions(
//           stickyAuth: true, // Keep auth dialog until success or cancel
//           biometricOnly: true, // Only use biometric, no PIN fallback
//         ),
//       );

//       if (!authenticated) {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Biometric authentication failed");
//         return;
//       }

//       // BIOMETRIC VERSION: Retrieve saved credentials after successful biometric authentication
//       final savedEmail = prefs.getString('lastBiometricEmail');
//       final savedToken = prefs.getString('appToken');
//       final savedUserId = prefs.getInt('userId');
//       final savedRole = prefs.getString('userRole');

//       if (savedEmail == null || savedToken == null || savedUserId == null) {
//         setState(() {
//           _isLoading = false;
//           _showBiometricButton = false;
//         });
//         _showSnackBar("Session expired. Please login with password.");
//         return;
//       }

//       // BIOMETRIC VERSION: Fetch fresh profile data
//       final fullProfile = await _authService.fetchFullEmployeeProfile(savedEmail);

//       if (fullProfile != null) {
//         // Update user provider with latest data
//         final userProfile = {
//           "userId": savedUserId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": savedRole ?? "Employee",
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(context, listen: false)
//               .setUserProfile(userProfile);
//         }

//         // Navigate to appropriate screen based on role
//         if (mounted) {
//           if (savedRole == "Manager") {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                   builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//             );
//           } else {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//             );
//           }
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Could not load profile. Please login again.");
//       }

//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showSnackBar("Biometric login error: $e");
//       print("BIOMETRIC VERSION: Login Exception: $e");
//     }
//   }

//   // BOTH VERSIONS: Main Login Logic
//   void _handleEmailPasswordLogin() async {
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     // BASE VERSION: Removed snackbar notification for validation errors
//     // Now only shows red text below fields when empty or invalid
//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       return; // Just return - let field errors display below the fields
//     }

//     // BASE VERSION: Set loading state to true when login starts
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // 1. Call Login Endpoint
//       final loginResponse = await _authService.login(email, password);

//       // BASE VERSION: Set loading to false before showing error
//       if (loginResponse == null) {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Unable to connect to server.");
//         return;
//       }

//       // 2. Error Handling
//       bool isSuccess = loginResponse['message'] == "Login successful" ||
//           loginResponse['message'] ==
//               "Login with temporary password successful";
//       bool isOnboarding = loginResponse["onboardingRequired"] == true;

//       // BASE VERSION: Handle incorrect password/credentials from server
//       // Shows SnackBar notification with server error message
//       if (!isSuccess && !isOnboarding) {
//         String backendMsg =
//             loginResponse['message'] ?? "An unexpected error occurred.";
        
//         setState(() {
//           _isLoading = false;
//         });
        
//         // BASE VERSION: Check for specific error messages and show user-friendly text
//         if (backendMsg.toLowerCase().contains('password') || 
//             backendMsg.toLowerCase().contains('credentials') ||
//             backendMsg.toLowerCase().contains('invalid')) {
//           _showSnackBar("Incorrect password. Please try again.");
//         } else {
//           _showSnackBar(backendMsg);
//         }
//         return;
//       }

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);

//       // 3. Handle Onboarding / Resubmission
//       if (isOnboarding) {
//         final int? idToPass =
//             loginResponse["employeeId"] ?? loginResponse["userId"];
//         final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
//         Map<String, dynamic>? existingProfile;

//         if (onboardingMode == "resubmission" && idToPass != null) {
//           existingProfile =
//               await _authService.fetchRejectedProfileData(idToPass);
//         }

//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Emponboard(
//                 email: email,
//                 existingProfile: existingProfile,
//                 employeeId: idToPass,
//               ),
//             ),
//           );
//         }
//         return;
//       }

//       // 4. Exchange Password for Token
//       final exchangeResponse =
//           await _authService.exchangePasswordForToken(email, password);

//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Authentication failed.");
//         return;
//       }

//       // CRITICAL: Save Token BEFORE initializing FCM registration
//       await prefs.setString('appToken', exchangeResponse['appToken']);
//       print("Token saved successfully.");

//       // 5. Fetch Full Profile
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Employee";
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);

//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString(
//           'userName',
//           "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//         );

//         // BIOMETRIC VERSION: Save credentials for future biometric login after successful password login
//         await prefs.setString('lastBiometricEmail', email);
//         // BIOMETRIC VERSION: Save current timestamp for 1-hour session validation
//         await prefs.setInt('lastBiometricLoginTime', DateTime.now().millisecondsSinceEpoch);
//         print("BIOMETRIC VERSION: Credentials saved for future biometric login");

//         // Update Provider
//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(context, listen: false)
//               .setUserProfile(userProfile);
//         }

//         // Enable Push Notifications
//         try {
//           print("Initializing FCM for User: ${fullProfile["EmployeeId"]}");
//           final notificationService = NotificationService();
//           await notificationService.initializeFCM(
//             employeeId: fullProfile["EmployeeId"],
//             userTag: "user_${fullProfile["EmployeeId"]}",
//           );
//           final fcmToken = await FirebaseMessaging.instance.getToken();
//           print("MY FCM TOKEN: $fcmToken");
//         } catch (fcmError) {
//           print("FCM Init Warning: $fcmError");
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Could not load profile.");
//         return;
//       }

//       // 6. Navigation
//       if (mounted) {
//         if (role == "Manager") {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//           );
//         } else {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showSnackBar("Login Error: $e");
//       print("Login Exception: $e");
//     }
//   }

//   // BASE VERSION: Enhanced SnackBar styling for better visibility
//   // Shows red notification at bottom of screen for server errors
//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             message,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.all(16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           duration: const Duration(seconds: 4),
//           action: SnackBarAction(
//             label: 'OK',
//             textColor: Colors.white,
//             onPressed: () {
//               ScaffoldMessenger.of(context).hideCurrentSnackBar();
//             },
//           ),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;

//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   // BASE VERSION: Disabled auto-validation
//                   // Errors only show when user clicks "Log In" button
//                   autovalidateMode: AutovalidateMode.disabled,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: const AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(136, 42, 41, 41)
//                                   .withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white),
//                                 ),
//                                 const SizedBox(height: 20),
                                
//                                 // BIOMETRIC VERSION: Show Face ID/Touch ID button if available and session is valid
//                                 if (_showBiometricButton) ...[
//                                   Center(
//                                     child: Column(
//                                       children: [
//                                         // BIOMETRIC VERSION: Face ID icon button
//                                         IconButton(
//                                           onPressed: _isLoading ? null : _handleBiometricLogin,
//                                           icon: const Icon(
//                                             Icons.fingerprint,
//                                             size: 64,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 8),
//                                         const Text(
//                                           "Login with Face ID / Touch ID",
//                                           style: TextStyle(
//                                             color: Colors.white70,
//                                             fontSize: 14,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 20),
//                                         const Row(
//                                           children: [
//                                             Expanded(
//                                                 child: Divider(
//                                                     color: Colors.white38,
//                                                     thickness: 1)),
//                                             Padding(
//                                               padding: EdgeInsets.symmetric(horizontal: 8.0),
//                                               child: Text("Or use password",
//                                                   style: TextStyle(color: Colors.white)),
//                                             ),
//                                             Expanded(
//                                                 child: Divider(
//                                                     color: Colors.white38,
//                                                     thickness: 1)),
//                                           ],
//                                         ),
//                                         const SizedBox(height: 20),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
                                
//                                 // Email Field
//                                 const Text("Email",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _emailController,
//                                   keyboardType: TextInputType.emailAddress,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 32, 32, 32)),
//                                   decoration: InputDecoration(
//                                     hintText: "username@gmail.com",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     // BASE VERSION: White borders for all states
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     enabledBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     errorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedErrorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     // BASE VERSION: Bold red error text with white stroke/shadow effect
//                                     errorStyle: const TextStyle(
//                                       color: Colors.red,
//                                       fontWeight: FontWeight.w900,
//                                       fontSize: 13,
//                                     ),
//                                   ),
//                                   // BASE VERSION: Email validation
//                                   // Shows error below field only when form is submitted
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty) {
//                                       return 'Please enter an email';
//                                     }
//                                     const emailRegex =
//                                         r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                                     if (!RegExp(emailRegex).hasMatch(value)) {
//                                       return 'Please enter a valid email address';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 15),
//                                 // Password Field
//                                 const Text("Password",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _passwordController,
//                                   obscureText: _obscureText,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 17, 17, 17)),
//                                   decoration: InputDecoration(
//                                     hintText: "Password",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     // BASE VERSION: White borders for all states
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     enabledBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     errorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedErrorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     // BASE VERSION: Bold red error text with white stroke/shadow effect
//                                     errorStyle: const TextStyle(
//                                       color: Colors.red,
//                                       fontWeight: FontWeight.w900,
//                                       fontSize: 13,
//                                     ),
//                                     suffixIcon: IconButton(
//                                       icon: Icon(
//                                         _obscureText
//                                             ? Icons.visibility_off
//                                             : Icons.visibility,
//                                         color: Colors.grey,
//                                       ),
//                                       onPressed: () => setState(
//                                           () => _obscureText = !_obscureText),
//                                     ),
//                                   ),
//                                   // BASE VERSION: Password validation
//                                   // Shows error below field only when form is submitted
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty) {
//                                       return 'Please enter your password';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 const ForgotPasswordScreen()),
//                                       );
//                                     },
//                                     child: const Text("Forgot Password?",
//                                         style:
//                                             TextStyle(color: Colors.white70)),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     child: ElevatedButton(
//                                       // BASE VERSION: Disable button when loading
//                                       onPressed: _isLoading ? null : _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         // BASE VERSION: Change button color to grey when loading
//                                         backgroundColor:
//                                             _isLoading ? Colors.grey : const Color(0xFF2979FF),
//                                         padding: const EdgeInsets.symmetric(
//                                             vertical: 16, horizontal: 0),
//                                         shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(10)),
//                                       ),
//                                       // BASE VERSION: Show loading spinner when logging in
//                                       child: _isLoading
//                                           ? const SizedBox(
//                                               height: 20,
//                                               width: 20,
//                                               child: CircularProgressIndicator(
//                                                 color: Colors.white,
//                                                 strokeWidth: 2,
//                                               ),
//                                             )
//                                           : const Text("Log In",
//                                               style: TextStyle(
//                                                   fontSize: 16,
//                                                   color: Colors.white)),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),

//                                 // const Row(
//                                 //   children: [
//                                 //     Expanded(
//                                 //         child: Divider(
//                                 //             color: Colors.white38,
//                                 //             thickness: 1)),
//                                 //     Padding(
//                                 //       padding:
//                                 //           EdgeInsets.symmetric(horizontal: 8.0),
//                                 //       child: Text("Or Sign In With",
//                                 //           style:
//                                 //               TextStyle(color: Colors.white)),
//                                 //     ),
//                                 //     Expanded(
//                                 //         child: Divider(
//                                 //             color: Colors.white38,
//                                 //             thickness: 1)),
//                                 //   ],
//                                 // ),
//                                 const SizedBox(height: 20),

//                                 // // Social Buttons (Placeholders)
//                                 // Center(
//                                 //   child: SizedBox(
//                                 //     width: size.width * 0.8,
//                                 //     child: Row(
//                                 //       mainAxisAlignment:
//                                 //           MainAxisAlignment.spaceEvenly,
//                                 //       children: [
//                                 //         Expanded(
//                                 //           child: ElevatedButton.icon(
//                                 //             onPressed: () {},
//                                 //             icon: Image.network(
//                                 //               'https://img.icons8.com/?size=100&id=17949&format=png&color=000000',
//                                 //               height: 24,
//                                 //               width: 24,
//                                 //             ),
//                                 //             label: const Text("Google"),
//                                 //             style: ElevatedButton.styleFrom(
//                                 //               backgroundColor: Colors.white,
//                                 //               foregroundColor: Colors.black,
//                                 //               padding:
//                                 //                   const EdgeInsets.symmetric(
//                                 //                       horizontal: 16,
//                                 //                       vertical: 12),
//                                 //               shape: RoundedRectangleBorder(
//                                 //                   borderRadius:
//                                 //                       BorderRadius.circular(
//                                 //                           20)),
//                                 //             ),
//                                 //           ),
//                                 //         ),
//                                 //         const SizedBox(width: 16),
//                                 //         Expanded(
//                                 //           child: ElevatedButton.icon(
//                                 //             onPressed: () {},
//                                 //             icon: Image.network(
//                                 //               'https://img.icons8.com/?size=100&id=22989&format=png&color=000000',
//                                 //               height: 24,
//                                 //               width: 24,
//                                 //             ),
//                                 //             label: const Text("Microsoft"),
//                                 //             style: ElevatedButton.styleFrom(
//                                 //               backgroundColor: Colors.white,
//                                 //               foregroundColor: Colors.black,
//                                 //               padding:
//                                 //                   const EdgeInsets.symmetric(
//                                 //                       horizontal: 16,
//                                 //                       vertical: 12),
//                                 //               shape: RoundedRectangleBorder(
//                                 //                   borderRadius:
//                                 //                       BorderRadius.circular(
//                                 //                           20)),
//                                 //             ),
//                                 //           ),
//                                 //         ),
//                                 //       ],
//                                 //     ),
//                                 //   ),
//                                 // ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// }






















// import 'dart:ui';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/screens/forgot_password.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();

//   // Controllers
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   // State
//   bool _obscureText = true;
//   bool _isLoading = false; // CHANGE 1: Added loading state variable to track login process
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//   }

//   // Main Login Logic
//   void _handleEmailPasswordLogin() async {
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     // CHANGE 2: Removed snackbar notification for validation errors
//     // Now only shows red text below fields when empty or invalid
//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       return; // Just return - let field errors display below the fields
//     }

//     // CHANGE 3: Set loading state to true when login starts
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // 1. Call Login Endpoint
//       final loginResponse = await _authService.login(email, password);

//       // CHANGE 4: Set loading to false before showing error
//       if (loginResponse == null) {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Unable to connect to server.");
//         return;
//       }

//       // 2. Error Handling
//       bool isSuccess = loginResponse['message'] == "Login successful" ||
//           loginResponse['message'] ==
//               "Login with temporary password successful";
//       bool isOnboarding = loginResponse["onboardingRequired"] == true;

//       // CHANGE 5: Handle incorrect password/credentials from server
//       // Shows SnackBar notification with server error message
//       if (!isSuccess && !isOnboarding) {
//         String backendMsg =
//             loginResponse['message'] ?? "An unexpected error occurred.";
        
//         setState(() {
//           _isLoading = false;
//         });
        
//         // CHANGE 6: Check for specific error messages and show user-friendly text
//         if (backendMsg.toLowerCase().contains('password') || 
//             backendMsg.toLowerCase().contains('credentials') ||
//             backendMsg.toLowerCase().contains('invalid')) {
//           _showSnackBar("Incorrect password. Please try again.");
//         } else {
//           _showSnackBar(backendMsg);
//         }
//         return;
//       }

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);

//       // 3. Handle Onboarding / Resubmission
//       if (isOnboarding) {
//         final int? idToPass =
//             loginResponse["employeeId"] ?? loginResponse["userId"];
//         final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
//         Map<String, dynamic>? existingProfile;

//         if (onboardingMode == "resubmission" && idToPass != null) {
//           existingProfile =
//               await _authService.fetchRejectedProfileData(idToPass);
//         }

//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Emponboard(
//                 email: email,
//                 existingProfile: existingProfile,
//                 employeeId: idToPass,
//               ),
//             ),
//           );
//         }
//         return;
//       }

//       // 4. Exchange Password for Token
//       final exchangeResponse =
//           await _authService.exchangePasswordForToken(email, password);

//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Authentication failed.");
//         return;
//       }

//       // CRITICAL: Save Token BEFORE initializing FCM registration
//       await prefs.setString('appToken', exchangeResponse['appToken']);
//       print("Token saved successfully.");

//       // 5. Fetch Full Profile
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Employee";
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);

//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString(
//           'userName',
//           "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//         );

//         // Update Provider
//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(context, listen: false)
//               .setUserProfile(userProfile);
//         }

//         // Enable Push Notifications
//         try {
//           print("Initializing FCM for User: ${fullProfile["EmployeeId"]}");
//           final notificationService = NotificationService();
//           // Since we are logged in, we pass the real EmployeeId.
//           // Because ID != 0, it will proceed to register with the backend using the saved AppToken.
//           await notificationService.initializeFCM(
//             employeeId: fullProfile["EmployeeId"],
//             userTag: "user_${fullProfile["EmployeeId"]}",
//           );
//           final fcmToken = await FirebaseMessaging.instance.getToken();
//           print("MY FCM TOKEN: $fcmToken");
//         } catch (fcmError) {
//           print("FCM Init Warning: $fcmError");
//         }
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         _showSnackBar("Could not load profile.");
//         return;
//       }

//       // 6. Navigation
//       if (mounted) {
//         if (role == "Manager") {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//           );
//         } else {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//           );
//         }
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       _showSnackBar("Login Error: $e");
//       print("Login Exception: $e");
//     }
//   }

//   // CHANGE 7: Enhanced SnackBar styling for better visibility
//   // Shows red notification at bottom of screen for server errors
//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             message,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.all(16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           duration: const Duration(seconds: 4),
//           action: SnackBarAction(
//             label: 'OK',
//             textColor: Colors.white,
//             onPressed: () {
//               ScaffoldMessenger.of(context).hideCurrentSnackBar();
//             },
//           ),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;

//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   // CHANGE 8: Disabled auto-validation
//                   // Errors only show when user clicks "Log In" button
//                   autovalidateMode: AutovalidateMode.disabled,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: const AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(136, 42, 41, 41)
//                                   .withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white),
//                                 ),
//                                 const SizedBox(height: 20),
//                                 // Email Field
//                                 const Text("Email",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _emailController,
//                                   keyboardType: TextInputType.emailAddress,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 32, 32, 32)),
//                                   decoration: InputDecoration(
//                                     hintText: "username@gmail.com",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     // CHANGE 9: White borders for all states
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     enabledBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     errorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedErrorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     // CHANGE 10: Bold red error text with white stroke/shadow effect
//                                     errorStyle: const TextStyle(
//                                       color: Colors.red,
//                                       fontWeight: FontWeight.w900,
//                                       fontSize: 13,
                                      
//                                     ),
//                                   ),
//                                   // CHANGE 11: Email validation
//                                   // Shows error below field only when form is submitted
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty) {
//                                       return 'Please enter an email';
//                                     }
//                                     const emailRegex =
//                                         r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                                     if (!RegExp(emailRegex).hasMatch(value)) {
//                                       return 'Please enter a valid email address';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 15),
//                                 // Password Field
//                                 const Text("Password",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _passwordController,
//                                   obscureText: _obscureText,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 17, 17, 17)),
//                                   decoration: InputDecoration(
//                                     hintText: "Password",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     // CHANGE 12: White borders for all states
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     enabledBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     errorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white)),
//                                     focusedErrorBorder: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12),
//                                         borderSide: const BorderSide(color: Colors.white, width: 2)),
//                                     // CHANGE 13: Bold red error text with white stroke/shadow effect
//                                     errorStyle: const TextStyle(
//                                       color: Colors.red,
//                                       fontWeight: FontWeight.w900,
//                                       fontSize: 13,
                                      
//                                     ),
//                                     suffixIcon: IconButton(
//                                       icon: Icon(
//                                         _obscureText
//                                             ? Icons.visibility_off
//                                             : Icons.visibility,
//                                         color: Colors.grey,
//                                       ),
//                                       onPressed: () => setState(
//                                           () => _obscureText = !_obscureText),
//                                     ),
//                                   ),
//                                   // CHANGE 14: Password validation
//                                   // Shows error below field only when form is submitted
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty) {
//                                       return 'Please enter your password';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 const ForgotPasswordScreen()),
//                                       );
//                                     },
//                                     child: const Text("Forgot Password?",
//                                         style:
//                                             TextStyle(color: Colors.white70)),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     child: ElevatedButton(
//                                       // CHANGE 15: Disable button when loading
//                                       onPressed: _isLoading ? null : _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         // CHANGE 16: Change button color to grey when loading
//                                         backgroundColor:
//                                             _isLoading ? Colors.grey : const Color(0xFF2979FF),
//                                         padding: const EdgeInsets.symmetric(
//                                             vertical: 16, horizontal: 0),
//                                         shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(10)),
//                                       ),
//                                       // CHANGE 17: Show loading spinner when logging in
//                                       child: _isLoading
//                                           ? const SizedBox(
//                                               height: 20,
//                                               width: 20,
//                                               child: CircularProgressIndicator(
//                                                 color: Colors.white,
//                                                 strokeWidth: 2,
//                                               ),
//                                             )
//                                           : const Text("Log In",
//                                               style: TextStyle(
//                                                   fontSize: 16,
//                                                   color: Colors.white)),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),

//                                 const Row(
//                                   children: [
//                                     Expanded(
//                                         child: Divider(
//                                             color: Colors.white38,
//                                             thickness: 1)),
//                                     Padding(
//                                       padding:
//                                           EdgeInsets.symmetric(horizontal: 8.0),
//                                       child: Text("Or Sign In With",
//                                           style:
//                                               TextStyle(color: Colors.white)),
//                                     ),
//                                     Expanded(
//                                         child: Divider(
//                                             color: Colors.white38,
//                                             thickness: 1)),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 20),

//                                 // Social Buttons (Placeholders)
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.8,
//                                     child: Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.spaceEvenly,
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {},
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=17949&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Google"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 16),
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {},
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=22989&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Microsoft"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// }



































// // lib/screens/login.dart
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart'; // Import Response
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// // import 'package:shiftsmart/services/flutterauth.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:provider/provider.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';
// import 'package:shiftsmart/screens/forgot_password.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();
//   // final Flutterauth _flutterauth = Flutterauth();

//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   bool isLoggedIn = false;
//   String? accessToken;
//   bool _obscureText = true;
//   String? userName;
//   String? userEmail;
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//   }

//   // --- REVERTED LOGIN LOGIC ---
//   // void _handleEmailPasswordLogin() async {
//   //   String email = _emailController.text.trim();
//   //   String password = _passwordController.text.trim();

//   //   if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//   //     _showSnackBar("Please fix the errors in the form.");
//   //     return;
//   //   }

//   //   try {
//   //     // -----------------------------------------------------------------
//   //     // STEP 1: Call the LOGIN endpoint
//   //     // -----------------------------------------------------------------
//   //     final loginResponse = await _authService.login(email, password);
//   //     print("Login Response in UI: $loginResponse");

//   //     // Check for null response or if the 'Message' key exists (indicating an error)
//   //     if (loginResponse == null || loginResponse.containsKey('Message')) {
//   //       String errorMessage = loginResponse?['Message'] ??
//   //           "Login failed. Please check your credentials.";
//   //       _showSnackBar(errorMessage);
//   //       return;
//   //     }
//   //     // Although AuthService handles non-200, double-check successful message just in case
//   //     if (loginResponse['message'] != "Login successful" &&
//   //         loginResponse['message'] !=
//   //             "Login with temporary password successful") {
//   //       _showSnackBar(loginResponse['message'] ??
//   //           "An unexpected error occurred during login.");
//   //       return;
//   //     }

//   //     final prefs = await SharedPreferences.getInstance();
//   //     await prefs.setString('userEmail', email);
//   //     print("User Email stored: $email");

//   //     // -----------------------------------------------------------------
//   //     // STEP 2: Check ONBOARDING flags (ORIGINAL LOGIC)
//   //     // -----------------------------------------------------------------
//   //     // Default to false (complete) if null, as per original plan
//   //     final bool onboardingRequired =
//   //         loginResponse["onboardingRequired"] ?? false;
//   //     final String onboardingMode = loginResponse["onboardingMode"] ?? "none";

//   //     // *** ORIGINAL LOGIC: If onboardingRequired is TRUE, go to onboarding ***
//   //     if (onboardingRequired) {
//   //       print("Onboarding required. Mode: $onboardingMode");

//   //       Map<String, dynamic>? existingProfile;

//   //       if (onboardingMode == "resubmission") {
//   //         print("Resubmission mode: Fetching rejected items.");
//   //         final int? employeeId = loginResponse["employeeId"];

//   //         if (employeeId != null) {
//   //           existingProfile =
//   //               await _authService.fetchRejectedProfileData(employeeId);
//   //           if (existingProfile == null) {
//   //             _showSnackBar(
//   //                 "Could not load resubmission data. Please contact support.");
//   //             return;
//   //           }
//   //         } else {
//   //           _showSnackBar("Could not get Employee ID for resubmission.");
//   //           return;
//   //         }
//   //       }

//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(
//   //           builder: (context) => Emponboard(
//   //             email: email,
//   //             rejectionReason: loginResponse['rejectionReason'],
//   //             existingProfile: existingProfile,
//   //           ),
//   //         ),
//   //       );
//   //       return; // Stop execution
//   //     }

//   //     // *** ORIGINAL LOGIC: If onboardingRequired is FALSE, user is active ***
//   //     // -----------------------------------------------------------------
//   //     // STEP 3: User is active. Exchange password for a token.
//   //     // -----------------------------------------------------------------
//   //     print("User is active. Exchanging password for token.");
//   //     final exchangeResponse =
//   //         await _authService.exchangePasswordForToken(email, password);

//   //     if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//   //       _showSnackBar(exchangeResponse?['Message'] ?? "Authentication failed");
//   //       return;
//   //     }

//   //     print("Token received. Proceeding to fetch profile.");
//   //     // -----------------------------------------------------------------
//   //     if (exchangeResponse['appToken'] != null) {
//   //       // We reuse the 'prefs' instance you created earlier at the top of the function
//   //       await prefs.setString('appToken', exchangeResponse['appToken']);
//   //       print("✅ Token saved to SharedPreferences: appToken");
//   //     } else {
//   //       print("⚠️ Warning: AppToken was null in exchange response");
//   //     }
//   //     // -----------------------------------------------------------------
//   //     // STEP 4: Token is saved. Now fetch profile and navigate.
//   //     // -----------------------------------------------------------------
//   //     int? userId = exchangeResponse["userId"];
//   //     String role = exchangeResponse["userRole"] ??
//   //         "Unknown"; // Use role from exchange response
//   //     await prefs.setInt('userId', userId!);
//   //     await prefs.setString('userRole', role);

//   //     final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//   //     if (fullProfile != null) {
//   //       // (Your existing code for setting SharedPreferences and Provider...)
//   //       await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//   //       await prefs.setString(
//   //         'userName',
//   //         "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//   //       );

//   //       final userProfile = {
//   //         "userId": userId,
//   //         "employeeId": fullProfile["EmployeeId"],
//   //         "firstName": fullProfile["FirstName"] ?? "",
//   //         "middleName": fullProfile["MiddleName"] ?? "",
//   //         "lastName": fullProfile["LastName"] ?? "",
//   //         "gender": fullProfile["Gender"] ?? "",
//   //         "email": fullProfile["Email"] ?? "",
//   //         "mobileNumber": fullProfile["MobileNumber"] ?? "",
//   //         "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//   //         "street": fullProfile["Street"] ?? "",
//   //         "city": fullProfile["City"] ?? "",
//   //         "state": fullProfile["State"] ?? "",
//   //         "postalCode": fullProfile["PostalCode"] ?? "",
//   //         "country": fullProfile["Country"] ?? "",
//   //         "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//   //         "jobRole": fullProfile["JobRole"] ?? "",
//   //         "userRole": role, // Use role from exchange response
//   //         "profilePicture": fullProfile["ProfilePicture"] ?? "",
//   //         "bankAccountName": fullProfile["BankAccountName"] ?? "",
//   //         "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//   //         "bankBSB": fullProfile["BankBSB"] ?? "",
//   //         "bankName": fullProfile["BankName"] ?? "",
//   //         "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//   //       };

//   //       Provider.of<UserProvider>(context, listen: false)
//   //           .setUserProfile(userProfile);

//   //       // Initialize FCM and register device token
//   //       final notificationService = NotificationService();
//   //       await notificationService.initializeFCM(
//   //         employeeId: fullProfile["EmployeeId"],
//   //         userTag: "user_${fullProfile["EmployeeId"]}",
//   //       );
//   //     } else {
//   //       _showSnackBar("Could not load full profile data.");
//   //       return;
//   //     }

//   //     // Navigate to the appropriate page based on user role
//   //     print("Navigating based on role: $role"); // Add log for role check
//   //     if (role == "Manager") {
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(
//   //             builder: (context) => const Bottomnavbar(
//   //                   selectedIndex: 0,
//   //                 )),
//   //       );
//   //     } else {
//   //       // Default to employee dashboard if role is not Manager or empty
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (context) => EmpBottomnavbar()),
//   //       );
//   //     }
//   //   } catch (e) {
//   //     _showSnackBar("Login failed: ${e.toString()}");
//   //     print("Login Error: $e");
//   //   }
//   // }
//   // --- END OF REVERTED FUNCTION ---

//   void _handleEmailPasswordLogin() async {
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       _showSnackBar("Please fix the errors in the form.");
//       return;
//     }

//     try {
//       // -----------------------------------------------------------------
//       // STEP 1: Call the LOGIN endpoint
//       // -----------------------------------------------------------------
//       final loginResponse = await _authService.login(email, password);
//       print("Login Response in UI: $loginResponse");

//       // Check for null response
//       if (loginResponse == null) {
//         _showSnackBar(
//             "Unable to connect to the server. Please check your internet.");
//         return;
//       }

//       // --- 🛠️ IMPROVED ERROR HANDLING 🛠️ ---

//       // 1. Check Flags
//       bool isSuccess = loginResponse['message'] == "Login successful" ||
//           loginResponse['message'] ==
//               "Login with temporary password successful";
//       bool isOnboarding = loginResponse["onboardingRequired"] == true;

//       // 2. Handle Errors (If NOT Success AND NOT Onboarding)
//       if (!isSuccess && !isOnboarding) {
//         String backendMsg =
//             loginResponse['message'] ?? loginResponse['Message'] ?? "";

//         // 🎨 User-Friendly Message Translation
//         String userFriendlyMsg = "An unexpected error occurred.";

//         if (backendMsg.contains("Pending")) {
//           userFriendlyMsg =
//               "Your account is currently under review. Please wait for admin approval.";
//         } else if (backendMsg.contains("Invalid credentials") ||
//             backendMsg.contains("401")) {
//           userFriendlyMsg = "Invalid email or password. Please try again.";
//         } else if (backendMsg.contains("User not found")) {
//           userFriendlyMsg = "No account found with this email.";
//         } else if (backendMsg.isNotEmpty) {
//           // Fallback: Clean up "Server Error (403): ..." to just the message part if possible
//           userFriendlyMsg =
//               backendMsg.replaceAll(RegExp(r'Server Error \(\d+\): '), '');
//         }

//         _showSnackBar(userFriendlyMsg);
//         return;
//       }
//       // --- 🛠️ END ERROR HANDLING 🛠️ ---

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);
//       print("User Email stored: $email");

//       // -----------------------------------------------------------------
//       // STEP 2: Check ONBOARDING flags
//       // -----------------------------------------------------------------
//       final bool onboardingRequired =
//           loginResponse["onboardingRequired"] ?? false;
//       final String onboardingMode = loginResponse["onboardingMode"] ?? "none";

//       if (onboardingRequired) {
//         print("Onboarding required. Mode: $onboardingMode");

//         Map<String, dynamic>? existingProfile;

//         // 1. EXTRACT ID HERE (So it's available for both fetching and navigation)
//         final int? idToPass =
//             loginResponse["employeeId"] ?? loginResponse["userId"];
//         print("🔹 ID extracted for Onboarding: $idToPass");

//         // Check specifically for resubmission
//         if (onboardingMode == "resubmission") {
//           print("Resubmission mode: Fetching rejected items.");

//           if (idToPass != null && idToPass != 0) {
//             // Use the extracted ID
//             existingProfile =
//                 await _authService.fetchRejectedProfileData(idToPass);

//             if (existingProfile == null) {
//               _showSnackBar(
//                   "Could not load your profile data. Please contact support.");
//               return;
//             }
//           } else {
//             print("Warning: Employee ID is null or 0 during resubmission.");
//           }
//         }

//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => Emponboard(
//               email: email,
//               existingProfile: existingProfile,
//               // 2. PASS THE ID HERE (This was missing in your code!)
//               employeeId: idToPass,
//             ),
//           ),
//         );
//         return; // Stop execution
//       }

//       // -----------------------------------------------------------------
//       // STEP 3: User is active. Exchange password for a token.
//       // -----------------------------------------------------------------
//       print("User is active. Exchanging password for token.");
//       final exchangeResponse =
//           await _authService.exchangePasswordForToken(email, password);

//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         _showSnackBar("Authentication failed. Please try again.");
//         return;
//       }

//       print("Token received. Proceeding to fetch profile.");
//       if (exchangeResponse['appToken'] != null) {
//         await prefs.setString('appToken', exchangeResponse['appToken']);
//         print("✅ Token saved to SharedPreferences: appToken");
//       }

//       // -----------------------------------------------------------------
//       // STEP 4: Token is saved. Now fetch profile and navigate.
//       // -----------------------------------------------------------------
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Unknown";
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);

//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString(
//           'userName',
//           "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//         );

//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         Provider.of<UserProvider>(context, listen: false)
//             .setUserProfile(userProfile);

//         final notificationService = NotificationService();
//         await notificationService.initializeFCM(
//           employeeId: fullProfile["EmployeeId"],
//           userTag: "user_${fullProfile["EmployeeId"]}",
//         );
//       } else {
//         _showSnackBar("Could not load your profile. Please restart the app.");
//         return;
//       }

//       print("Navigating based on role: $role");
//       if (role == "Manager") {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => EmpBottomnavbar()),
//         );
//       }
//     } catch (e) {
//       _showSnackBar("Login failed. Please check your connection.");
//       print("Login Error: $e");
//     }
//   }

//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   // Future<void> _mslogIn() async {
//   //   final success = await _flutterauth.signIn();
//   //   if (success) {
//   //     setState(() {
//   //       userName = _flutterauth.profile?['name'];
//   //       userEmail = _flutterauth.profile?['preferred_username'];
//   //     });
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;

//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   autovalidateMode: AutovalidateMode.onUserInteraction,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(136, 42, 41, 41)
//                                   .withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white),
//                                 ),
//                                 const SizedBox(height: 20),

//                                 // Email Field
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text(
//                                       "Email",
//                                       style: TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                     const SizedBox(height: 5),
//                                     TextFormField(
//                                       controller: _emailController,
//                                       keyboardType: TextInputType.emailAddress,
//                                       style: const TextStyle(
//                                           color:
//                                               Color.fromARGB(255, 32, 32, 32)),
//                                       decoration: InputDecoration(
//                                         hintText: "username@gmail.com",
//                                         hintStyle:
//                                             const TextStyle(color: Colors.grey),
//                                         filled: true,
//                                         fillColor: const Color.fromARGB(
//                                             255, 255, 255, 255),
//                                         border: OutlineInputBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(12),
//                                         ),
//                                       ),
//                                       validator: (value) {
//                                         if (value == null || value.isEmpty) {
//                                           return 'Please enter an email';
//                                         }
//                                         const emailRegex =
//                                             r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                                         if (!RegExp(emailRegex)
//                                             .hasMatch(value)) {
//                                           return 'Please enter a valid email address';
//                                         }
//                                         return null;
//                                       },
//                                     ),
//                                   ],
//                                 ),

//                                 const SizedBox(height: 15),

//                                 // Password Field
//                                 Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text(
//                                       "Password",
//                                       style: TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                     const SizedBox(height: 5),
//                                     TextFormField(
//                                       controller: _passwordController,
//                                       obscureText: _obscureText,
//                                       style: const TextStyle(
//                                           color:
//                                               Color.fromARGB(255, 17, 17, 17)),
//                                       decoration: InputDecoration(
//                                         hintText: "Password",
//                                         hintStyle:
//                                             const TextStyle(color: Colors.grey),
//                                         filled: true,
//                                         fillColor: const Color.fromARGB(
//                                             255, 255, 255, 255),
//                                         border: OutlineInputBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(12),
//                                         ),
//                                         suffixIcon: IconButton(
//                                           icon: Icon(
//                                             _obscureText
//                                                 ? Icons.visibility_off
//                                                 : Icons.visibility,
//                                             color: Colors.grey,
//                                           ),
//                                           onPressed: () {
//                                             setState(() {
//                                               _obscureText = !_obscureText;
//                                             });
//                                           },
//                                         ),
//                                       ),
//                                       validator: (value) {
//                                         if (value == null || value.isEmpty) {
//                                           return 'Please enter your password';
//                                         }
//                                         return null;
//                                       },
//                                     ),
//                                   ],
//                                 ),

//                                 const SizedBox(height: 10),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 const ForgotPasswordScreen()),
//                                       );
//                                     },
//                                     child: const Text(
//                                       "Forgot Password?",
//                                       style: TextStyle(color: Colors.white70),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     child: ElevatedButton(
//                                       onPressed: _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor:
//                                             const Color(0xFF2979FF),
//                                         padding: const EdgeInsets.symmetric(
//                                             vertical: 16, horizontal: 0),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(10),
//                                         ),
//                                       ),
//                                       child: const Text(
//                                         "Log In",
//                                         style: TextStyle(
//                                             fontSize: 16, color: Colors.white),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(
//                                   height: 15,
//                                 ),

//                                 const Row(
//                                   children: [
//                                     Expanded(
//                                       child: Divider(
//                                         color: Colors.white38,
//                                         thickness: 1,
//                                       ),
//                                     ),
//                                     Padding(
//                                       padding:
//                                           EdgeInsets.symmetric(horizontal: 8.0),
//                                       child: Text(
//                                         "Or Sign In With",
//                                         style: TextStyle(color: Colors.white),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Divider(
//                                         color: Colors.white38,
//                                         thickness: 1,
//                                       ),
//                                     ),
//                                   ],
//                                 ),

//                                 const SizedBox(height: 20),

//                                 // Social Buttons
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.8,
//                                     child: Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.spaceEvenly,
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {
//                                               // Navigator.pushReplacement(
//                                               //   context,
//                                               //   MaterialPageRoute(
//                                               //       builder: (context) =>
//                                               //           const Emponboard()),
//                                               // );
//                                             },
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=17949&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Google"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 16),
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {
//                                               // _mslogIn();
//                                             },
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=22989&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Microsoft"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// } // End of _LoginState class






// lib/screens/login.dart


// import 'dart:ui';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/screens/employee/empOnboard.dart';
// import 'package:shiftsmart/screens/forgot_password.dart';
// import 'package:shiftsmart/services/auth_service.dart';
// import 'package:shiftsmart/services/notification_service.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:shiftsmart/widgets/loginBackground.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final AuthService _authService = AuthService();

//   // Controllers
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   // State
//   bool _obscureText = true;
//   bool _isLoading = false;                                // ← ADDED THIS LINE
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     disableFullScreen();
//   }

//   // Main Login Logic
//   void _handleEmailPasswordLogin() async {
//     String email = _emailController.text.trim();
//     String password = _passwordController.text.trim();

//     if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
//       _showSnackBar("Please fix the errors in the form.");
//       return;
//     }

//     // Set loading state to true                            // ← ADDED THIS LINE
//     setState(() {
//       _isLoading = true;
//     });

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );

//     try {
//       // 1. Call Login Endpoint
//       final loginResponse = await _authService.login(email, password);

//       // Remove loading indicator
//       Navigator.of(context).pop();

//       if (loginResponse == null) {
//         _showSnackBar("Unable to connect to server.");
//         return;
//       }

//       // 2. Error Handling
//       bool isSuccess = loginResponse['message'] == "Login successful" ||
//           loginResponse['message'] ==
//               "Login with temporary password successful";
//       bool isOnboarding = loginResponse["onboardingRequired"] == true;

//       if (!isSuccess && !isOnboarding) {
//         String backendMsg =
//             loginResponse['message'] ?? "An unexpected error occurred.";
//         _showSnackBar(backendMsg);
//         return;
//       }

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userEmail', email);

//       // 3. Handle Onboarding / Resubmission
//       if (isOnboarding) {
//         final int? idToPass =
//             loginResponse["employeeId"] ?? loginResponse["userId"];
//         final String onboardingMode = loginResponse["onboardingMode"] ?? "none";
//         Map<String, dynamic>? existingProfile;

//         if (onboardingMode == "resubmission" && idToPass != null) {
//           existingProfile =
//               await _authService.fetchRejectedProfileData(idToPass);
//         }

//         if (mounted) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Emponboard(
//                 email: email,
//                 existingProfile: existingProfile,
//                 employeeId: idToPass,
//               ),
//             ),
//           );
//         }
//         return;
//       }

//       // 4. Exchange Password for Token
//       final exchangeResponse =
//           await _authService.exchangePasswordForToken(email, password);

//       if (exchangeResponse == null || exchangeResponse['appToken'] == null) {
//         _showSnackBar("Authentication failed.");
//         return;
//       }

//       // CRITICAL: Save Token BEFORE initializing FCM registration
//       await prefs.setString('appToken', exchangeResponse['appToken']);
//       print("Token saved successfully.");

//       // 5. Fetch Full Profile
//       int? userId = exchangeResponse["userId"];
//       String role = exchangeResponse["userRole"] ?? "Employee";
//       await prefs.setInt('userId', userId!);
//       await prefs.setString('userRole', role);

//       final fullProfile = await _authService.fetchFullEmployeeProfile(email);

//       if (fullProfile != null) {
//         await prefs.setInt('employeeId', fullProfile['EmployeeId']);
//         await prefs.setString(
//           'userName',
//           "${fullProfile["FirstName"]} ${fullProfile["LastName"]}",
//         );

//         // Update Provider
//         final userProfile = {
//           "userId": userId,
//           "employeeId": fullProfile["EmployeeId"],
//           "firstName": fullProfile["FirstName"] ?? "",
//           "middleName": fullProfile["MiddleName"] ?? "",
//           "lastName": fullProfile["LastName"] ?? "",
//           "gender": fullProfile["Gender"] ?? "",
//           "email": fullProfile["Email"] ?? "",
//           "mobileNumber": fullProfile["MobileNumber"] ?? "",
//           "dateOfBirth": fullProfile["DateOfBirth"] ?? "",
//           "street": fullProfile["Street"] ?? "",
//           "city": fullProfile["City"] ?? "",
//           "state": fullProfile["State"] ?? "",
//           "postalCode": fullProfile["PostalCode"] ?? "",
//           "country": fullProfile["Country"] ?? "",
//           "employmentStatus": fullProfile["EmploymentStatus"] ?? "",
//           "jobRole": fullProfile["JobRole"] ?? "",
//           "userRole": role,
//           "profilePicture": fullProfile["ProfilePicture"] ?? "",
//           "bankAccountName": fullProfile["BankAccountName"] ?? "",
//           "bankAccountNumber": fullProfile["BankAccountNumber"] ?? "",
//           "bankBSB": fullProfile["BankBSB"] ?? "",
//           "bankName": fullProfile["BankName"] ?? "",
//           "nextOfKins": (fullProfile["NextOfKins"] as List<dynamic>? ?? []),
//         };

//         if (mounted) {
//           Provider.of<UserProvider>(context, listen: false)
//               .setUserProfile(userProfile);
//         }

//         // Enable Push Notifications
//         try {
//           print("Initializing FCM for User: ${fullProfile["EmployeeId"]}");
//           final notificationService = NotificationService();
//           // Since we are logged in, we pass the real EmployeeId.
//           // Because ID != 0, it will proceed to register with the backend using the saved AppToken.
//           await notificationService.initializeFCM(
//             employeeId: fullProfile["EmployeeId"],
//             userTag: "user_${fullProfile["EmployeeId"]}",
//           );
//           final fcmToken = await FirebaseMessaging.instance.getToken();
//           print("MY FCM TOKEN: $fcmToken");
//         } catch (fcmError) {
//           print("FCM Init Warning: $fcmError");
//         }
//       } else {
//         _showSnackBar("Could not load profile.");
//         return;
//       }

//       // 6. Navigation
//       if (mounted) {
//         if (role == "Manager") {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => const Bottomnavbar(selectedIndex: 0)),
//           );
//         } else {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => const EmpBottomnavbar()),
//           );
//         }
//       }
//     } catch (e) {
//       _showSnackBar("Login Error: $e");
//       print("Login Exception: $e");
//     }
//   }

//   void _showSnackBar(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text(message)));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final logoSize = size.width * 0.5;
//     final paddingUnit = size.width * 0.03;

//     return Scaffold(
//         backgroundColor: const Color(0xFF2F3846),
//         body: Stack(children: [
//           const Positioned.fill(child: LoginBackground()),
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(paddingUnit * 2),
//                 child: Form(
//                   key: _formKey,
//                   autovalidateMode: AutovalidateMode.onUserInteraction,
//                   child: Column(
//                     children: [
//                       Image(
//                         image: const AssetImage('assets/logo.png'),
//                         width: logoSize,
//                         height: logoSize,
//                       ),
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//                           child: Container(
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: const Color.fromARGB(136, 42, 41, 41)
//                                   .withOpacity(0.6),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(color: Colors.white),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black.withOpacity(0.2),
//                                   spreadRadius: 2,
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "Login",
//                                   style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.white),
//                                 ),
//                                 const SizedBox(height: 20),
//                                 // Email Field
//                                 const Text("Email",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _emailController,
//                                   keyboardType: TextInputType.emailAddress,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 32, 32, 32)),
//                                   decoration: InputDecoration(
//                                     hintText: "username@gmail.com",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12)),
//                                   ),
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty)
//                                       return 'Please enter an email';
//                                     const emailRegex =
//                                         r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
//                                     if (!RegExp(emailRegex).hasMatch(value))
//                                       return 'Please enter a valid email address';
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 15),
//                                 // Password Field
//                                 const Text("Password",
//                                     style: TextStyle(
//                                         color: Colors.white, fontSize: 16)),
//                                 const SizedBox(height: 5),
//                                 TextFormField(
//                                   controller: _passwordController,
//                                   obscureText: _obscureText,
//                                   style: const TextStyle(
//                                       color: Color.fromARGB(255, 17, 17, 17)),
//                                   decoration: InputDecoration(
//                                     hintText: "Password",
//                                     hintStyle:
//                                         const TextStyle(color: Colors.grey),
//                                     filled: true,
//                                     fillColor: const Color.fromARGB(
//                                         255, 255, 255, 255),
//                                     border: OutlineInputBorder(
//                                         borderRadius:
//                                             BorderRadius.circular(12)),
//                                     suffixIcon: IconButton(
//                                       icon: Icon(
//                                         _obscureText
//                                             ? Icons.visibility_off
//                                             : Icons.visibility,
//                                         color: Colors.grey,
//                                       ),
//                                       onPressed: () => setState(
//                                           () => _obscureText = !_obscureText),
//                                     ),
//                                   ),
//                                   validator: (value) {
//                                     if (value == null || value.isEmpty)
//                                       return 'Please enter your password';
//                                     return null;
//                                   },
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: TextButton(
//                                     onPressed: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 const ForgotPasswordScreen()),
//                                       );
//                                     },
//                                     child: const Text("Forgot Password?",
//                                         style:
//                                             TextStyle(color: Colors.white70)),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.7,
//                                     child: ElevatedButton(
//                                       //onPressed: _handleEmailPasswordLogin,
//                                       onPressed: _isLoading ? null : _handleEmailPasswordLogin,
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor:
//                                             _isLoading ? Colors.grey : const Color(0xFF2979FF),
//                                             //const Color(0xFF2979FF),
//                                         padding: const EdgeInsets.symmetric(
//                                             vertical: 16, horizontal: 0),
//                                         shape: RoundedRectangleBorder(
//                                             borderRadius:
//                                                 BorderRadius.circular(10)),
//                                       ),
//                                       child: const Text("Log In",
//                                           style: TextStyle(
//                                               fontSize: 16,
//                                               color: Colors.white)),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 15),

//                                 const Row(
//                                   children: [
//                                     Expanded(
//                                         child: Divider(
//                                             color: Colors.white38,
//                                             thickness: 1)),
//                                     Padding(
//                                       padding:
//                                           EdgeInsets.symmetric(horizontal: 8.0),
//                                       child: Text("Or Sign In With",
//                                           style:
//                                               TextStyle(color: Colors.white)),
//                                     ),
//                                     Expanded(
//                                         child: Divider(
//                                             color: Colors.white38,
//                                             thickness: 1)),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 20),

//                                 // Social Buttons (Placeholders)
//                                 Center(
//                                   child: SizedBox(
//                                     width: size.width * 0.8,
//                                     child: Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.spaceEvenly,
//                                       children: [
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {},
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=17949&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Google"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                         const SizedBox(width: 16),
//                                         Expanded(
//                                           child: ElevatedButton.icon(
//                                             onPressed: () {},
//                                             icon: Image.network(
//                                               'https://img.icons8.com/?size=100&id=22989&format=png&color=000000',
//                                               height: 24,
//                                               width: 24,
//                                             ),
//                                             label: const Text("Microsoft"),
//                                             style: ElevatedButton.styleFrom(
//                                               backgroundColor: Colors.white,
//                                               foregroundColor: Colors.black,
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                       horizontal: 16,
//                                                       vertical: 12),
//                                               shape: RoundedRectangleBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                           20)),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ]));
//   }
// }
