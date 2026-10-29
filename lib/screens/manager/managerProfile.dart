import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/ProfileService.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/utils/profile_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/widgets/success_dialog.dart'; // 👈 Import Success Dialog

class ManagerProfile extends StatefulWidget {
  const ManagerProfile({super.key});

  @override
  State<ManagerProfile> createState() => _ManagerProfileState();
}

class _ManagerProfileState extends State<ManagerProfile> {
  // Navigation State
  int _currentStep = 1;
  bool _isInitialized = false;
  bool _isLoading = false;
  File? _selectedProfilePicture;
  final List<Map<String, dynamic>> _nokList = [];

  // --- Controllers: Step 1 (Personal Info) ---
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _midNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _suburbController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  // --- Controllers: Step 2 (Bank & Job) ---
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bsbController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _jobroleController = TextEditingController();

  // --- Controllers: Step 3 (Next of Kin) ---
  final TextEditingController noknameController = TextEditingController();
  final TextEditingController nokrelationController = TextEditingController();
  final TextEditingController nokmobileController = TextEditingController();
  final TextEditingController nokaddressController = TextEditingController();
  final TextEditingController nokemailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    enableFullScreen();
  }

  // Load initial data
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _populateFieldsFromUserProvider();
        _isInitialized = true;
      }
    });
  }

  void _populateFieldsFromUserProvider() {
    final userProfile =
        Provider.of<UserProvider>(context, listen: false).userProfile;
    setState(() {
      _firstNameController.text = userProfile['firstName'] ?? '';
      _midNameController.text = userProfile['middleName'] ?? '';
      _lastNameController.text = userProfile['lastName'] ?? '';
      _genderController.text = userProfile['gender'] ?? '';
      _phoneController.text = userProfile['mobileNumber'] ?? '';
      _emailController.text = userProfile['email'] ?? '';
      _dateController.text = userProfile['dateOfBirth'] ?? '';
      _streetController.text = userProfile['street'] ?? '';
      _suburbController.text = userProfile['city'] ?? '';
      _stateController.text = userProfile['state'] ?? '';
      _postalController.text = userProfile['postalCode'] ?? '';
      _countryController.text = userProfile['country'] ?? '';
      _accountNameController.text = userProfile['bankAccountName'] ?? '';
      _bsbController.text = userProfile['bankBSB'] ?? '';
      _accountNumberController.text = userProfile['bankAccountNumber'] ?? '';
      _bankNameController.text = userProfile['bankName'] ?? '';
      _jobroleController.text = userProfile['jobRole'] ?? '';

      // Populate NoK list if available
      if (userProfile['nextOfKins'] != null &&
          userProfile['nextOfKins'] is List &&
          (userProfile['nextOfKins'] as List).isNotEmpty) {
        final nok = userProfile['nextOfKins'][0];
        noknameController.text = nok['fullName'] ?? '';
        nokrelationController.text = nok['relationship'] ?? '';
        nokmobileController.text = nok['mobileNumber'] ?? '';
        nokaddressController.text = nok['address'] ?? '';
        nokemailController.text = nok['email'] ?? '';
      }
    });
  }

  // Submit Update
  Future<void> _updateProfile(File? profilePictureFile) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final employeeId = userProvider.userProfile['employeeId'];

    final profile = {
      "firstName": _firstNameController.text,
      "middleName": _midNameController.text,
      "lastName": _lastNameController.text,
      "gender": _genderController.text,
      "email": _emailController.text,
      "mobileNumber": _phoneController.text,
      "dateOfBirth": _dateController.text,
      "street": _streetController.text,
      "city": _suburbController.text,
      "state": _stateController.text,
      "postalCode": _postalController.text,
      "country": _countryController.text,
      "bankAccountName": _accountNameController.text,
      "bankBSB": _bsbController.text,
      "bankAccountNumber": _accountNumberController.text,
      "bankName": _bankNameController.text,
      "employmentStatus": "Active",
      "jobRole": _jobroleController.text
    };

    final error = await ProfileService().updateProfile(
      employeeId: employeeId,
      profile: profile,
      nextOfKins: _nokList,
      profilePicture: profilePictureFile,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        // Refresh provider data
        await refreshUserProfileFromBackend(context);
        _populateFieldsFromUserProvider();

        // Show Success Dialog
        SuccessDialog.show(
          context,
          title: "Profile Updated",
          message: "Your profile details have been updated successfully.",
          buttonText: "OK",
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentStep = 1); // Reset to first step
          },
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update Failed: $error'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(showBackButton: true),
      drawer: const Sidenav(),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Form(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentStep == 1) _buildProfileForm(),
                                  if (_currentStep == 2) _buildBankAndJobForm(),
                                  if (_currentStep == 3) _buildNextofkinForm(),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Navigation Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentStep == 1)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => Navigator.pop(context),
                              ),
                            if (_currentStep > 1)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => setState(() => _currentStep--),
                              ),
                            GradientButton(
                              text: _currentStep == 3
                                  ? (_isLoading ? "Updating..." : "Update")
                                  : "Next",
                              onPressed: () async {
                                if (_currentStep < 3) {
                                  setState(() => _currentStep++);
                                } else {
                                  // Update Action
                                  setState(() => _isLoading = true);
                                  await _updateProfile(_selectedProfilePicture);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: Profile Form ---
  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(
            child: ProfileAvatar(
          editable: true,
          initialImage: _selectedProfilePicture,
          onImageSelected: (File image) {
            setState(() {
              _selectedProfilePicture = image;
            });
          },
        )),
        const SizedBox(height: 20),
        _buildTextField("First Name", _firstNameController),
        _buildTextField("Middle Name", _midNameController),
        _buildTextField("Last Name", _lastNameController),
        _buildTextField("Gender", _genderController),
        _buildTextField("Phone Number", _phoneController),
        _buildTextField("Email", _emailController),
        _buildTextField("Date of birth", _dateController),
        const Text("Address",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        _buildSubTextField("Street Address", _streetController),
        _buildSubTextField("Suburb", _suburbController),
        _buildSubTextField("State/Territory", _stateController),
        _buildSubTextField("Postal Code", _postalController,
            keyboardType: TextInputType.number),
        _buildSubTextField("Country", _countryController),
      ],
    );
  }

  // --- Step 2: Bank Details ---
  Widget _buildBankAndJobForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text("Bank Details",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        _buildSubTextField("Account Name", _accountNameController),
        _buildSubTextField("BSB Number", _bsbController,
            keyboardType: TextInputType.number),
        _buildSubTextField("Account Number", _accountNumberController,
            keyboardType: TextInputType.number),
        _buildSubTextField("Bank Name", _bankNameController),
        _buildTextField("Job Role", _jobroleController),
      ],
    );
  }

  // --- Step 3: Next of Kin ---
  Widget _buildNextofkinForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Next of Kin",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (noknameController.text.isEmpty ||
                      nokrelationController.text.isEmpty ||
                      nokmobileController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Please fill basic NoK fields")),
                    );
                    return;
                  }

                  setState(() {
                    _nokList.add({
                      "fullName": noknameController.text.trim(),
                      "relationship": nokrelationController.text.trim(),
                      "mobileNumber": nokmobileController.text.trim(),
                      "email": nokemailController.text.trim(),
                      "address": nokaddressController.text.trim(),
                    });

                    // Clear fields
                    noknameController.clear();
                    nokrelationController.clear();
                    nokmobileController.clear();
                    nokemailController.clear();
                    nokaddressController.clear();
                  });
                },
                child:
                    const Icon(Icons.add_circle_outline, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 12),
          _buildSubTextField("Full Name", noknameController),
          _buildSubTextField("Relationship", nokrelationController),
          _buildSubTextField("Mobile Number", nokmobileController,
              keyboardType: TextInputType.phone),
          _buildSubTextField("Email", nokemailController,
              keyboardType: TextInputType.emailAddress),
          _buildSubTextField("Address", nokaddressController),
          const SizedBox(height: 16),

          // NoK Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nokList.map((nok) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nok['relationship'] ?? 'NoK',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _nokList.remove(nok));
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    )
                  ],
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white)),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white70),
              decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                  hintText: ' $label',
                  hintStyle: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  // Fixed the issue where all fields were numeric only
  Widget _buildSubTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text, // Default to text
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white)),
            child: TextFormField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              validator: validator,
              keyboardType: keyboardType, // Dynamic Keyboard Type
              decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  hintText: ' $label',
                  hintStyle: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }
}
