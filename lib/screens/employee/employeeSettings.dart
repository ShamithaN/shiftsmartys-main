import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/responsive.dart';
import 'package:shiftsmart/services/ProfileService.dart';
import 'package:shiftsmart/theme.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
import 'package:shiftsmart/widgets/emp_slidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class EmployeeSettings extends StatefulWidget {
  const EmployeeSettings({super.key});

  @override
  State<EmployeeSettings> createState() => _EmployeeSettingsState();
}

class _EmployeeSettingsState extends State<EmployeeSettings> {
  // --- State Variables ---
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  // --- Services ---
  final ProfileService _profileService = ProfileService();

  // --- Controllers ---
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    
    // ========== NEW CODE START ==========
    // CHANGE 1: Add listener to rebuild UI when password changes
    // This makes the validation indicators update in real-time as user types
    _newPasswordController.addListener(() {
      setState(() {});
    });
    // ========== NEW CODE END ==========
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ========== NEW CODE START ==========
  // CHANGE 2: Password validation helper methods
  // These getters check if the password meets each requirement
  bool get _hasMinLength => _newPasswordController.text.length >= 6;
  bool get _hasUpperCase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowerCase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => _newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _isDifferentFromCurrent => 
      _currentPasswordController.text.isNotEmpty && 
      _newPasswordController.text.isNotEmpty && 
      _currentPasswordController.text != _newPasswordController.text;
  // ========== NEW CODE END ==========

  // --- Logic: Update Password ---
  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. Validation
    if (newPassword.isEmpty ||
        currentPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar("Passwords do not match", isError: true);
      return;
    }

    if (currentPassword == newPassword) {
      _showSnackBar("New password must be different from current password",
          isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar("Password must be at least 6 characters long",
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userEmail = userProvider.userProfile["email"];

      // 2. API Call
      final success = await _profileService.updatePassword(
          userEmail, currentPassword, newPassword);

      setState(() => _isLoading = false);

      if (success != null && success) {
        if (mounted) {
          // 3. Show Success Dialog
          SuccessDialog.show(
            context,
            title: "Password Updated",
            message: "Your password has been changed successfully.",
            buttonText: "OK",
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate back to Dashboard or stay here, clearing fields
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const EmpBottomnavbar()),
              );
            },
          );
        }
      } else {
        _showSnackBar("Failed to update password. Check current password.",
            isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Exception: $e");
      _showSnackBar("Something went wrong: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      drawer: const EmpSidenav(
        currentScreen: 'EmployeeSettings',
      ),
      appBar: const Uppernavbar(
        showBackButton: false,
      ),
      body: Stack(
        children: [
          const Background(),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.isDesktop(context)
                        ? 100
                        : (Responsive.isTablet(context) ? 40 : 20),
                    10,
                    Responsive.isDesktop(context)
                        ? 100
                        : (Responsive.isTablet(context) ? 40 : 20),
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadiusL),
                          gradient: AppTheme.backgroundGradient,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildProfileHeader(),
                            const SizedBox(height: 30),
                            _buildPasswordFields(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF724584))),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return const Center(
        child: ProfileAvatar(
      editable: false,
    ));
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        // Current Password
        _buildPasswordInputField(
          controller: _currentPasswordController,
          hintText: "Current Password",
          isVisible: _currentPasswordVisible,
          toggleVisibility: () {
            setState(() {
              _currentPasswordVisible = !_currentPasswordVisible;
            });
          },
        ),
        const SizedBox(height: 16),

        // New Password
        _buildPasswordInputField(
          controller: _newPasswordController,
          hintText: "New Password",
          isVisible: _newPasswordVisible,
          toggleVisibility: () {
            setState(() {
              _newPasswordVisible = !_newPasswordVisible;
            });
          },
        ),
        
        // ========== NEW CODE START ==========
        // CHANGE 3: Password validation requirements display
        // Shows real-time validation feedback below the New Password field
        // Only displays when the user has started typing
        if (_newPasswordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildValidationItem(
                  "At least 6 characters",
                  _hasMinLength,
                ),
                _buildValidationItem(
                  "Contains uppercase letter (A-Z)",
                  _hasUpperCase,
                ),
                _buildValidationItem(
                  "Contains lowercase letter (a-z)",
                  _hasLowerCase,
                ),
                _buildValidationItem(
                  "Contains number (0-9)",
                  _hasDigit,
                ),
                _buildValidationItem(
                  "Contains special character (!@#\$%^&*)",
                  _hasSpecialChar,
                ),
                // Only show "different from current" if current password is entered
                if (_currentPasswordController.text.isNotEmpty)
                  _buildValidationItem(
                    "Different from current password",
                    _isDifferentFromCurrent,
                  ),
              ],
            ),
          ),
        // ========== NEW CODE END ==========
        
        const SizedBox(height: 16),

        // Confirm Password
        _buildPasswordInputField(
          controller: _confirmPasswordController,
          hintText: "Confirm Password",
          isVisible: _confirmPasswordVisible,
          toggleVisibility: () {
            setState(() {
              _confirmPasswordVisible = !_confirmPasswordVisible;
            });
          },
        ),
        const SizedBox(height: 24),

        // Update Button
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.gradientBlueButton,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isLoading ? 'Updating...' : 'Update',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== NEW CODE START ==========
  // CHANGE 4: Widget to display individual validation requirement
  // Shows green checkmark if requirement is met, red X if not met
  Widget _buildValidationItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(255, 255, 255, 255),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(255, 255, 255, 255),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  // ========== NEW CODE END ==========

  Widget _buildPasswordInputField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback toggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade400,
            ),
            onPressed: toggleVisibility,
          ),
        ),
      ),
    );
  }
}













// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shiftsmart/providers/user_provider.dart';
// import 'package:shiftsmart/responsive.dart';
// import 'package:shiftsmart/services/ProfileService.dart';
// import 'package:shiftsmart/theme.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
// import 'package:shiftsmart/widgets/emp_bottomnavbar.dart';
// import 'package:shiftsmart/widgets/emp_slidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:shiftsmart/widgets/success_dialog.dart';

// class EmployeeSettings extends StatefulWidget {
//   const EmployeeSettings({super.key});

//   @override
//   State<EmployeeSettings> createState() => _EmployeeSettingsState();
// }

// class _EmployeeSettingsState extends State<EmployeeSettings> {
//   // --- State Variables ---
//   bool _currentPasswordVisible = false;
//   bool _newPasswordVisible = false;
//   bool _confirmPasswordVisible = false;
//   bool _isLoading = false; // Added loading state

//   // --- Services ---
//   final ProfileService _profileService = ProfileService();

//   // --- Controllers ---
//   final TextEditingController _currentPasswordController =
//       TextEditingController();
//   final TextEditingController _newPasswordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     enableFullScreen();
//   }

//   @override
//   void dispose() {
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   // --- Logic: Update Password ---
//   Future<void> _updatePassword() async {
//     final currentPassword = _currentPasswordController.text.trim();
//     final newPassword = _newPasswordController.text.trim();
//     final confirmPassword = _confirmPasswordController.text.trim();

//     // 1. Validation
//     if (newPassword.isEmpty ||
//         currentPassword.isEmpty ||
//         confirmPassword.isEmpty) {
//       _showSnackBar("Please fill in all fields", isError: true);
//       return;
//     }

//     if (newPassword != confirmPassword) {
//       _showSnackBar("Passwords do not match", isError: true);
//       return;
//     }

//     if (currentPassword == newPassword) {
//       _showSnackBar("New password must be different from current password",
//           isError: true);
//       return;
//     }

//     if (newPassword.length < 6) {
//       _showSnackBar("Password must be at least 6 characters long",
//           isError: true);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final userProvider = Provider.of<UserProvider>(context, listen: false);
//       final userEmail = userProvider.userProfile["email"];

//       // 2. API Call
//       final success = await _profileService.updatePassword(
//           userEmail, currentPassword, newPassword);

//       setState(() => _isLoading = false);

//       if (success != null && success) {
//         if (mounted) {
//           // 3. Show Success Dialog
//           SuccessDialog.show(
//             context,
//             title: "Password Updated",
//             message: "Your password has been changed successfully.",
//             buttonText: "OK",
//             onPressed: () {
//               Navigator.pop(context); // Close dialog
//               // Navigate back to Dashboard or stay here, clearing fields
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(
//                     builder: (context) => const EmpBottomnavbar()),
//               );
//             },
//           );
//         }
//       } else {
//         _showSnackBar("Failed to update password. Check current password.",
//             isError: true);
//       }
//     } catch (e) {
//       setState(() => _isLoading = false);
//       debugPrint("Exception: $e");
//       _showSnackBar("Something went wrong: $e", isError: true);
//     }
//   }

//   void _showSnackBar(String message, {bool isError = false}) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.redAccent : Colors.green,
//       ));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       drawer: const EmpSidenav(
//         currentScreen: 'EmployeeSettings',
//       ),
//       appBar: const Uppernavbar(
//         showBackButton: false,
//       ),
//       body: Stack(
//         children: [
//           const Background(),
//           Column(
//             children: [
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: EdgeInsets.fromLTRB(
//                     Responsive.isDesktop(context)
//                         ? 100
//                         : (Responsive.isTablet(context) ? 40 : 20),
//                     10,
//                     Responsive.isDesktop(context)
//                         ? 100
//                         : (Responsive.isTablet(context) ? 40 : 20),
//                     0,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           borderRadius:
//                               BorderRadius.circular(AppTheme.borderRadiusL),
//                           gradient: AppTheme.backgroundGradient,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               'Settings',
//                               style: TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             _buildProfileHeader(),
//                             const SizedBox(height: 30),
//                             _buildPasswordFields(),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           if (_isLoading)
//             const Center(
//                 child: CircularProgressIndicator(color: Color(0xFF724584))),
//         ],
//       ),
//     );
//   }

//   Widget _buildProfileHeader() {
//     return const Center(
//         child: ProfileAvatar(
//       editable: false,
//     ));
//   }

//   Widget _buildPasswordFields() {
//     return Column(
//       children: [
//         // Current Password
//         _buildPasswordInputField(
//           controller: _currentPasswordController,
//           hintText: "Current Password",
//           isVisible: _currentPasswordVisible,
//           toggleVisibility: () {
//             setState(() {
//               _currentPasswordVisible = !_currentPasswordVisible;
//             });
//           },
//         ),
//         const SizedBox(height: 16),

//         // New Password
//         _buildPasswordInputField(
//           controller: _newPasswordController,
//           hintText: "New Password",
//           isVisible: _newPasswordVisible,
//           toggleVisibility: () {
//             setState(() {
//               _newPasswordVisible = !_newPasswordVisible;
//             });
//           },
//         ),
//         const SizedBox(height: 16),

//         // Confirm Password
//         _buildPasswordInputField(
//           controller: _confirmPasswordController,
//           hintText: "Confirm Password",
//           isVisible: _confirmPasswordVisible,
//           toggleVisibility: () {
//             setState(() {
//               _confirmPasswordVisible = !_confirmPasswordVisible;
//             });
//           },
//         ),
//         const SizedBox(height: 24),

//         // Update Button
//         SizedBox(
//           width: MediaQuery.of(context).size.width * 0.5,
//           child: Container(
//             decoration: BoxDecoration(
//               gradient: AppTheme.gradientBlueButton,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: ElevatedButton(
//               onPressed: _isLoading ? null : _updatePassword,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.transparent,
//                 shadowColor: Colors.transparent,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: Text(
//                 _isLoading ? 'Updating...' : 'Update',
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPasswordInputField({
//     required TextEditingController controller,
//     required String hintText,
//     required bool isVisible,
//     required VoidCallback toggleVisibility,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: TextField(
//         controller: controller,
//         obscureText: !isVisible,
//         style: const TextStyle(color: Colors.white),
//         decoration: InputDecoration(
//           contentPadding:
//               const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
//           border: InputBorder.none,
//           hintText: hintText,
//           hintStyle: TextStyle(color: Colors.grey.shade400),
//           suffixIcon: IconButton(
//             icon: Icon(
//               isVisible ? Icons.visibility : Icons.visibility_off,
//               color: Colors.grey.shade400,
//             ),
//             onPressed: toggleVisibility,
//           ),
//         ),
//       ),
//     );
//   }
// }
