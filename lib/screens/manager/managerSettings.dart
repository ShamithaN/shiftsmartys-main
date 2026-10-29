import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/ProfileService.dart';
import 'package:shiftsmart/theme.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/bottomnavbar.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/success_dialog.dart'; // 👈 Import Success Dialog

class ManagerSettings extends StatefulWidget {
  const ManagerSettings({super.key});

  @override
  State<ManagerSettings> createState() => _ManagerSettingsState();
}

class _ManagerSettingsState extends State<ManagerSettings> {
  // Controllers
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
  }

  // --- Update Password Logic ---
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
      // 2. Get User Data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userProfile = userProvider.userProfile;

      // DEBUG LOG: Check if email exists
      debugPrint("Manager Profile Data: $userProfile");

      // Fallback: Check 'email' key, if not found check 'Email' (case sensitive)
      final userEmail = userProfile["email"] ?? userProfile["Email"];

      if (userEmail == null || userEmail.toString().isEmpty) {
        setState(() => _isLoading = false);
        _showSnackBar("Error: Manager email not found in profile.",
            isError: true);
        return;
      }

      debugPrint("Attempting to update password for: $userEmail");

      // 3. API Call
      final success = await _profileService.updatePassword(
          userEmail, currentPassword, newPassword);

      setState(() => _isLoading = false);

      if (success != null && success) {
        if (mounted) {
          // --- Show Success Dialog ---
          SuccessDialog.show(
            context,
            title: "Password Updated",
            message: "Your password has been changed successfully.",
            buttonText: "OK",
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const Bottomnavbar(selectedIndex: 0),
                ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: false,
      ),
      drawer: const Sidenav(
        currentScreen: 'ManagerSettings',
      ),
      body: Stack(
        children: [
          const Background(),
          Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Gradienthorizontal(
                width: double.infinity,
                height: 600,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    // Added ScrollView to prevent overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        const Text(
                          'Settings',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: ProfileAvatar(
                            editable: false,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordFields(),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF724584))),
        ],
      ),
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        _buildPasswordInputField(
          controller: _currentPasswordController,
          hintText: "Current Password",
          isVisible: _currentPasswordVisible,
          toggleVisibility: () => setState(
              () => _currentPasswordVisible = !_currentPasswordVisible),
        ),
        const SizedBox(height: 16),
        _buildPasswordInputField(
          controller: _newPasswordController,
          hintText: "New Password",
          isVisible: _newPasswordVisible,
          toggleVisibility: () =>
              setState(() => _newPasswordVisible = !_newPasswordVisible),
        ),
        const SizedBox(height: 16),
        _buildPasswordInputField(
          controller: _confirmPasswordController,
          hintText: "Confirm Password",
          isVisible: _confirmPasswordVisible,
          toggleVisibility: () => setState(
              () => _confirmPasswordVisible = !_confirmPasswordVisible),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.gradientBlueButton,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed:
                  _isLoading ? null : _updatePassword, // Disable when loading
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _isLoading ? 'Updating...' : 'Update',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
