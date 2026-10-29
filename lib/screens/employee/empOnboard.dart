// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/OnboardingService.dart';
// import 'package:shiftsmart/utils/validators.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
// import 'package:shiftsmart/widgets/gradientButton.dart';
// import 'package:shiftsmart/screens/login.dart';

// class Emponboard extends StatefulWidget {
//   final String email;
//   final Map<String, dynamic>? existingProfile;
//   final int? employeeId;

//   const Emponboard({
//     super.key,
//     required this.email,
//     this.existingProfile,
//     this.employeeId,
//   });

//   @override
//   State<Emponboard> createState() => _EmponboardState();
// }

// class _EmponboardState extends State<Emponboard> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final OnboardingService _service = OnboardingService();

//   int _currentStep = 1;
//   bool _isLoading = true;
//   bool _isSubmitting = false;
//   bool _isResubmission = false;

//   bool _isLoadingBank = false;
//   bool _isBankNameReadOnly = true;
//   final FocusNode _bsbFocusNode = FocusNode();

//   // Controllers
//   final _firstNameCtrl = TextEditingController();
//   final _midNameCtrl = TextEditingController();
//   final _lastNameCtrl = TextEditingController();
//   final _phoneCtrl = TextEditingController();
//   final _dobCtrl = TextEditingController();

//   final _streetCtrl = TextEditingController();
//   final _cityCtrl = TextEditingController();
//   final _stateCtrl = TextEditingController();
//   final _zipCtrl = TextEditingController();
//   final _countryCtrl = TextEditingController();

//   final _tfnCtrl = TextEditingController();
//   final _abnCtrl = TextEditingController();

//   final _accNameCtrl = TextEditingController();
//   final _bsbCtrl = TextEditingController();
//   final _accNumCtrl = TextEditingController();
//   final _bankNameCtrl = TextEditingController();

//   final _passCtrl = TextEditingController();
//   final _confirmPassCtrl = TextEditingController();

//   final _nokNameCtrl = TextEditingController();
//   final _nokRelCtrl = TextEditingController();
//   final _nokPhoneCtrl = TextEditingController();
//   final _nokEmailCtrl = TextEditingController();
//   final _nokAddressCtrl = TextEditingController();

//   String _jobRole = "";
//   String _empType = "";
//   List<String> _requiredDocs = [];
//   List<String> _rejectedKeys = [];

//   File? _profilePic;
//   final Map<String, File> _uploadedDocs = {};

//   String? _gender;

//   final List<String> _genderOptions = [
//     "Man",
//     "Woman",
//     "Non-binary",
//     "I use a different term",
//     "Prefer not to say",
//   ];

//   final List<Map<String, dynamic>> _nokList = [];

//   @override
//   void initState() {
//     super.initState();
//     _initData();
//     _bsbFocusNode.addListener(() {
//       if (!_bsbFocusNode.hasFocus) {
//         String clean = _bsbCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
//         if (clean.length == 6) _handleBsbLookup();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _bsbFocusNode.dispose();
//     super.dispose();
//   }

//   // --- SMART NAVIGATION ---
//   bool _stepHasContent(int step) {
//     if (!_isResubmission) return true;
//     if (step == 1) {
//       return _shouldShow("FullName") ||
//           _shouldShow("Gender") ||
//           _shouldShow("MobileNumber") ||
//           _shouldShow("DateOfBirth") ||
//           _shouldShow("Address") ||
//           _shouldShow("TaxInfo");
//     }
//     if (step == 2) return _shouldShow("Bank");
//     if (step == 3) {
//       return _shouldShow("NextOfKin") || _requiredDocs.isNotEmpty;
//     }
//     return false;
//   }

//   int? _getNextStep(int current) {
//     for (int i = current + 1; i <= 3; i++) {
//       if (_stepHasContent(i)) return i;
//     }
//     return null;
//   }

//   int? _getPrevStep(int current) {
//     for (int i = current - 1; i >= 1; i--) {
//       if (_stepHasContent(i)) return i;
//     }
//     return null;
//   }

//   bool _shouldShow(String key) {
//     if (!_isResubmission) return true;
//     return _rejectedKeys.contains(key);
//   }

//   Future<void> _initData() async {
//     if (widget.existingProfile != null) {
//       _mapResubmissionData(widget.existingProfile!);
//     } else {
//       final data = await _service.fetchInvitation(widget.email);
//       if (data != null) {
//         _mapInvitationData(data);
//       } else {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _handleBsbLookup() async {
//     String bsb = _bsbCtrl.text.trim();
//     String cleanBsb = bsb.replaceAll(RegExp(r'[^0-9]'), '');
//     if (cleanBsb.length != 6) return;

//     setState(() => _isLoadingBank = true);
//     try {
//       final result = await EmployeeService().lookupBank(cleanBsb);
//       if (result['status'] == 'Found') {
//         setState(() {
//           _bankNameCtrl.text = result['bankName'].toString();
//           _isBankNameReadOnly = true;
//         });
//       } else {
//         setState(() {
//           _bankNameCtrl.clear();
//           _isBankNameReadOnly = false;
//         });
//       }
//     } catch (e) {
//       setState(() => _isBankNameReadOnly = false);
//     } finally {
//       if (mounted) setState(() => _isLoadingBank = false);
//     }
//   }

//   void _mapResubmissionData(Map<String, dynamic> data) {
//     setState(() {
//       _isResubmission = true;
//       if (data['RejectedFields'] != null) {
//         _rejectedKeys = List<String>.from(data['RejectedFields']);
//       }
//       final rejectedDocsList =
//           data['RejectedDocuments'] as List<dynamic>? ?? [];
//       _requiredDocs = [];
//       if (rejectedDocsList.isNotEmpty) {
//         _requiredDocs = rejectedDocsList
//             .map((doc) => doc['DocumentType'].toString())
//             .toList();
//       }

//       final profile = data['Profile'] ?? {};
//       String fullName = (profile['FullName'] ?? '').trim();
//       List<String> nameParts = fullName.split(RegExp(r'\s+'));

//       if (nameParts.isNotEmpty) {
//         _firstNameCtrl.text = nameParts.first;
//         if (nameParts.length == 2) {
//           _lastNameCtrl.text = nameParts.last;
//         } else if (nameParts.length > 2) {
//           _midNameCtrl.text =
//               nameParts.sublist(1, nameParts.length - 1).join(' ');
//           _lastNameCtrl.text = nameParts.last;
//         }
//       }

//       _dobCtrl.text = (profile['DateOfBirth'] ?? '').split('T').first;
//       _phoneCtrl.text = profile['MobileNumber'] ?? '';

//       // Gender Mapping
//       String? incomingGender = profile['Gender'];
//       if (incomingGender != null) {
//         if (_genderOptions.contains(incomingGender)) {
//           _gender = incomingGender;
//         } else if (incomingGender.toLowerCase() == "male") {
//           _gender = "Man";
//         } else if (incomingGender.toLowerCase() == "female") {
//           _gender = "Woman";
//         } else {
//           _gender = null;
//         }
//       }

//       String rawAddress = profile['Address'] ?? '';
//       List<String> addrParts =
//           rawAddress.split(',').map((s) => s.trim()).toList();

//       if (addrParts.isNotEmpty) {
//         if (addrParts.isNotEmpty) _streetCtrl.text = addrParts[0];
//         if (addrParts.length > 1) _cityCtrl.text = addrParts[1];
//         if (addrParts.length > 2) _stateCtrl.text = addrParts[2];
//         if (addrParts.length > 3) _zipCtrl.text = addrParts[3];
//         if (addrParts.length > 4) _countryCtrl.text = addrParts[4];
//       }

//       final bank = profile['Bank'] ?? {};
//       _bankNameCtrl.text = bank['Name'] ?? '';
//       _bsbCtrl.text = bank['BSB'] ?? '';
//       _accNumCtrl.text = bank['AccountNumber'] ?? '';
//       _accNameCtrl.text = bank['AccountName'] ?? '';

//       final tax = profile['TaxInfo'] ?? {};
//       _empType = tax['EmploymentType'] ?? 'PAYG Employee';
//       _tfnCtrl.text = tax['Tfn'] ?? '';
//       _abnCtrl.text = tax['Abn'] ?? '';

//       _jobRole = profile['JobRole'] ?? 'Standard Role';

//       final noks = profile['NextOfKins'] as List<dynamic>? ?? [];
//       _nokList.clear();
//       for (var nok in noks) {
//         _nokList.add({
//           "fullName": nok['FullName'] ?? '',
//           "relationship": nok['Relationship'] ?? '',
//           "mobileNumber": nok['MobileNumber'] ?? '',
//           "email": nok['Email'] ?? '',
//           "address": nok['Address'] ?? '',
//         });
//       }
//       _isLoading = false;
//     });
//   }

//   void _mapInvitationData(Map<String, dynamic> data) {
//     setState(() {
//       _isResubmission = false;
//       String fullName = (data['Name'] ?? '').trim();
//       List<String> nameParts = fullName.split(RegExp(r'\s+'));

//       if (nameParts.isNotEmpty) {
//         _firstNameCtrl.text = nameParts.first;
//         if (nameParts.length == 2) {
//           _lastNameCtrl.text = nameParts.last;
//         } else if (nameParts.length > 2) {
//           _midNameCtrl.text =
//               nameParts.sublist(1, nameParts.length - 1).join(' ');
//           _lastNameCtrl.text = nameParts.last;
//         }
//       }

//       _phoneCtrl.text = data['Phone'] ?? '';
//       _jobRole = data['JobRole'] ?? '';
//       _empType = data['EmploymentType'] ?? '';

//       String docsStr = data['RequiredCertificates'] ?? '';
//       if (docsStr.isNotEmpty) {
//         _requiredDocs = docsStr
//             .split(',')
//             .map((e) => e.trim())
//             .where((e) => e.isNotEmpty)
//             .toList();
//       }
//       _isLoading = false;
//     });
//   }

//   String? _validateAge(String? dateStr) {
//     if (dateStr == null || dateStr.isEmpty) return "Date of Birth is required";
//     return null;
//   }

//   void _pickProfileImage() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       builder: (ctx) => Wrap(children: [
//         ListTile(
//           leading: const Icon(Icons.camera_alt, color: Colors.white),
//           title:
//               const Text('Take Photo', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.camera, imageQuality: 80);
//             if (img != null) setState(() => _profilePic = File(img.path));
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.photo_library, color: Colors.white),
//           title:
//               const Text('From Gallery', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.gallery, imageQuality: 80);
//             if (img != null) setState(() => _profilePic = File(img.path));
//           },
//         ),
//       ]),
//     );
//   }

//   void _pickDocument(String docName) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       builder: (ctx) => Wrap(children: [
//         ListTile(
//           leading: const Icon(Icons.camera_alt, color: Colors.white),
//           title:
//               const Text('Take Photo', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.camera, imageQuality: 80);
//             if (img != null)
//               setState(() => _uploadedDocs[docName] = File(img.path));
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.photo_library, color: Colors.white),
//           title:
//               const Text('From Gallery', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.gallery, imageQuality: 80);
//             if (img != null)
//               setState(() => _uploadedDocs[docName] = File(img.path));
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.attach_file, color: Colors.white),
//           title: const Text('Pick File (PDF)',
//               style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             FilePickerResult? result = await FilePicker.platform.pickFiles(
//               type: FileType.custom,
//               allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
//             );
//             if (result != null && result.files.single.path != null) {
//               setState(() =>
//                   _uploadedDocs[docName] = File(result.files.single.path!));
//             }
//           },
//         ),
//       ]),
//     );
//   }

//   Future<void> _selectDob(BuildContext context) async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime(2000),
//       firstDate: DateTime(1950),
//       lastDate: DateTime.now(),
//       builder: (context, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(
//               primary: Colors.blueAccent, onPrimary: Colors.white),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       String formatted =
//           "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
//       setState(() => _dobCtrl.text = formatted);
//     }
//   }

//   Future<void> _submitForm() async {
//     setState(() => _isSubmitting = true);
//     Map<String, dynamic> payload = {};

//     String finalGender = _gender ?? "";
//     if (finalGender == "Man") finalGender = "Male";
//     if (finalGender == "Woman") finalGender = "Female";

//     if (_isResubmission) {
//       payload["EmployeeId"] = widget.employeeId ?? 0;

//       if (_rejectedKeys.contains("FullName")) {
//         payload["FullName"] =
//             "${_firstNameCtrl.text} ${_midNameCtrl.text} ${_lastNameCtrl.text}"
//                 .trim();
//       }
//       if (_rejectedKeys.contains("Gender")) {
//         payload["Gender"] = finalGender;
//       }
//       if (_rejectedKeys.contains("DateOfBirth")) {
//         payload["DateOfBirth"] = _dobCtrl.text.contains("T")
//             ? _dobCtrl.text
//             : "${_dobCtrl.text}T00:00:00";
//       }
//       if (_rejectedKeys.contains("MobileNumber")) {
//         payload["MobileNumber"] = _phoneCtrl.text;
//       }
//       if (_rejectedKeys.contains("Address")) {
//         payload["Street"] = _streetCtrl.text;
//         payload["City"] = _cityCtrl.text;
//         payload["State"] = _stateCtrl.text;
//         payload["PostalCode"] = _zipCtrl.text;
//         payload["Country"] =
//             _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia";
//       }
//       if (_rejectedKeys.contains("Bank")) {
//         payload["BankBSB"] = _bsbCtrl.text;
//         payload["BankAccountNumber"] = _accNumCtrl.text;
//         payload["BankAccountName"] = _accNameCtrl.text;
//         payload["BankName"] = _bankNameCtrl.text;
//       }
//       if (_rejectedKeys.contains("TaxInfo")) {
//         payload["EmploymentType"] = _empType;
//         if (_empType.contains("Contractor")) payload["Abn"] = _abnCtrl.text;
//         if (_empType.contains("Employee")) payload["Tfn"] = _tfnCtrl.text;
//       }
//       if (_rejectedKeys.contains("NextOfKin") && _nokList.isNotEmpty) {
//         var firstNok = _nokList.first;
//         payload["NextOfKin"] = {
//           "FullName": firstNok['fullName'],
//           "MobileNumber": firstNok['mobileNumber'],
//           "Email": firstNok['email'],
//           "Relationship": firstNok['relationship'],
//           "Address": firstNok['address'],
//           "IsPrimary": true
//         };
//       }

//       // Metadata for Documents (File is in Multipart)
//       if (_uploadedDocs.isNotEmpty) {
//         List<Map<String, dynamic>> documentsList = [];
//         _uploadedDocs.forEach((key, file) {
//           documentsList.add({
//             "DocumentId": 0,
//             "DocumentType": key,
//             "DocumentUrl": "" // Empty because file is attached
//           });
//         });
//         payload["Documents"] = documentsList;
//       }
//     } else {
//       // New Onboarding Logic (Full Payload)
//       payload = {
//         "FirstName": _firstNameCtrl.text,
//         "MiddleName": _midNameCtrl.text,
//         "LastName": _lastNameCtrl.text,
//         "Email": widget.email,
//         "MobileNumber": _phoneCtrl.text,
//         "Gender": finalGender,
//         "DateOfBirth": _dobCtrl.text.isNotEmpty ? _dobCtrl.text : "1990-01-01",
//         "Street": _streetCtrl.text,
//         "City": _cityCtrl.text,
//         "State": _stateCtrl.text,
//         "PostalCode": _zipCtrl.text,
//         "Country":
//             _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia",
//         "BankBSB": _bsbCtrl.text,
//         "BankAccountNumber": _accNumCtrl.text,
//         "BankAccountName": _accNameCtrl.text,
//         "BankName": _bankNameCtrl.text,
//         "EmploymentType": _empType,
//         "JobRole": _jobRole,
//       };
//       if (_empType.contains("Contractor")) payload["Abn"] = _abnCtrl.text;
//       if (_empType.contains("Employee")) payload["Tfn"] = _tfnCtrl.text;
//     }

//     try {
//       final response = await _service.submitOnboardingForm(
//         profilePicture: _profilePic ?? File(''),
//         uploadedCertificates: _uploadedDocs,
//         profile: payload,
//         nextOfKins: _nokList,
//         password: _passCtrl.text.trim(),
//         isResubmission: _isResubmission,
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         if (mounted) {
//           Navigator.pushAndRemoveUntil(
//               context,
//               MaterialPageRoute(builder: (_) => const Login()),
//               (route) => false);
//           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text("Submitted Successfully! Please Login.")));
//         }
//       } else {
//         if (mounted)
//           ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Failed: ${response.body}")));
//       }
//     } catch (e) {
//       if (mounted)
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text("Error: $e")));
//     } finally {
//       if (mounted) setState(() => _isSubmitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading)
//       return const Scaffold(
//           backgroundColor: Color(0xFF2F3846),
//           body: Center(child: CircularProgressIndicator()));

//     // Get Steps with Content
//     int? nextStep = _getNextStep(_currentStep);
//     int? prevStep = _getPrevStep(_currentStep);

//     return Scaffold(
//       body: Stack(
//         children: [
//           const Positioned.fill(child: Background()),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   return Container(
//                     height: constraints.maxHeight,
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.white),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       children: [
//                         Expanded(
//                           child: SingleChildScrollView(
//                             child: Form(
//                               key: _formKey,
//                               autovalidateMode:
//                                   AutovalidateMode.onUserInteraction,
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   if (_currentStep == 1) _buildStep1Profile(),
//                                   if (_currentStep == 2)
//                                     _buildStep2BankAndAuth(),
//                                   if (_currentStep == 3)
//                                     _buildStep3DocsAndNok(),
//                                   const SizedBox(height: 30),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             if (prevStep == null)
//                               GradientButton(
//                                 text: "Back",
//                                 isCancel: true,
//                                 onPressed: () => Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                         builder: (_) => const Login())),
//                               )
//                             else
//                               GradientButton(
//                                 text: "Back",
//                                 isCancel: true,
//                                 onPressed: () =>
//                                     setState(() => _currentStep = prevStep!),
//                               ),
//                             GradientButton(
//                               text: nextStep == null
//                                   ? (_isSubmitting ? "Submitting..." : "Submit")
//                                   : "Next",
//                               onPressed: () {
//                                 if (nextStep != null) {
//                                   if (_formKey.currentState!.validate()) {
//                                     if (_currentStep == 1 &&
//                                         _profilePic == null &&
//                                         !_isResubmission) {
//                                       ScaffoldMessenger.of(context)
//                                           .showSnackBar(const SnackBar(
//                                               content: Text(
//                                                   "Profile picture is required")));
//                                       return;
//                                     }
//                                     setState(() => _currentStep = nextStep!);
//                                   }
//                                 } else {
//                                   // Submit Logic
//                                   bool isStep3Valid = _nokList.isNotEmpty &&
//                                       (_requiredDocs.isEmpty ||
//                                           _requiredDocs.every((doc) =>
//                                               _uploadedDocs.containsKey(doc)));

//                                   if (_isResubmission && !_stepHasContent(3)) {
//                                     isStep3Valid = true;
//                                   }

//                                   if (isStep3Valid && !_isSubmitting) {
//                                     _submitForm();
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                         const SnackBar(
//                                             content: Text(
//                                                 "Complete all requirements.")));
//                                   }
//                                 }
//                               },
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStep1Profile() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Center(
//         child: Stack(
//           children: [
//             ProfileAvatar(
//               editable: false,
//               initialImage: _profilePic,
//               onImageSelected: (_) {},
//             ),
//             if (!_isResubmission)
//               Positioned.fill(
//                 child: Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     borderRadius: BorderRadius.circular(100),
//                     onTap: _pickProfileImage,
//                   ),
//                 ),
//               ),
//             if (!_isResubmission)
//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: CircleAvatar(
//                   backgroundColor: Colors.blueAccent,
//                   radius: 18,
//                   child: IconButton(
//                     icon: const Icon(Icons.camera_alt,
//                         size: 18, color: Colors.white),
//                     onPressed: _pickProfileImage,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//       const SizedBox(height: 20),
//       if (_shouldShow("FullName")) ...[
//         _buildTextField("First Name", _firstNameCtrl),
//         _buildTextField("Middle Name", _midNameCtrl),
//         _buildTextField("Last Name", _lastNameCtrl),
//       ],
//       if (_shouldShow("Gender"))
//         _buildDropdown("Gender", _genderOptions, _gender,
//             (v) => setState(() => _gender = v)),
//       if (_shouldShow("MobileNumber"))
//         _buildTextField("Mobile Number", _phoneCtrl,
//             keyboardType: TextInputType.phone),
//       if (_shouldShow("DateOfBirth"))
//         _buildDatePicker("Date of Birth", _dobCtrl, validator: _validateAge),
//       if (_shouldShow("Address")) ...[
//         _buildTextField("Street", _streetCtrl),
//         _buildTextField("City", _cityCtrl),
//         _buildTextField("State", _stateCtrl),
//         _buildTextField("Postcode", _zipCtrl,
//             keyboardType: TextInputType.number),
//         _buildTextField("Country", _countryCtrl),
//       ],
//       const SizedBox(height: 20),
//       const Text("Employment Details",
//           style: TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
//       const SizedBox(height: 10),
//       _buildReadOnlyField("Job Role", _jobRole),
//       _buildReadOnlyField("Employment Type", _empType),
//       if (_shouldShow("TaxInfo")) ...[
//         if (_empType.contains("Contractor"))
//           _buildTextField("ABN", _abnCtrl, validator: Validators.validateABN),
//         if (_empType.contains("Employee"))
//           _buildTextField("TFN", _tfnCtrl, validator: Validators.validateTFN),
//       ]
//     ]);
//   }

//   Widget _buildStep2BankAndAuth() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       if (_shouldShow("Bank")) ...[
//         const Text("Bank Details",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),
//         _buildTextField("Account Name", _accNameCtrl),
//         _buildTextField("BSB", _bsbCtrl,
//             validator: Validators.validateBSB,
//             focusNode: _bsbFocusNode,
//             onChanged: (val) {
//               String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
//               if (clean.length == 6) {
//                 _handleBsbLookup();
//               } else {
//                 if (!_isBankNameReadOnly || _bankNameCtrl.text.isNotEmpty) {
//                   setState(() {
//                     _bankNameCtrl.clear();
//                     _isBankNameReadOnly = true;
//                   });
//                 }
//               }
//             },
//             onFieldSubmitted: (_) => _handleBsbLookup(),
//             suffixIcon: _isLoadingBank
//                 ? const Padding(
//                     padding: EdgeInsets.all(12),
//                     child: CircularProgressIndicator(
//                         strokeWidth: 2, color: Colors.white),
//                   )
//                 : null),
//         _buildTextField("Account Number", _accNumCtrl,
//             validator: Validators.validateAccountNum),
//         _buildTextField("Bank Name", _bankNameCtrl,
//             readOnly: _isBankNameReadOnly),
//       ],
//       if (!_isResubmission) ...[
//         const SizedBox(height: 20),
//         const Text("Set Password",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),
//         _buildTextField("New Password", _passCtrl,
//             obscure: true,
//             validator: (v) => v!.length < 6 ? "Min 6 chars" : null),
//         _buildTextField("Confirm Password", _confirmPassCtrl,
//             obscure: true,
//             validator: (v) =>
//                 v != _passCtrl.text ? "Passwords do not match" : null),
//       ]
//     ]);
//   }

//   Widget _buildStep3DocsAndNok() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       if (_shouldShow("NextOfKin")) ...[
//         const Text("Next of Kin",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),
//         _buildTextField("Full Name", _nokNameCtrl),
//         _buildTextField("Relationship", _nokRelCtrl),
//         _buildTextField("Mobile", _nokPhoneCtrl,
//             keyboardType: TextInputType.phone),
//         _buildTextField("Email", _nokEmailCtrl,
//             keyboardType: TextInputType.emailAddress),
//         _buildTextField("Address", _nokAddressCtrl),
//         Align(
//           alignment: Alignment.centerRight,
//           child: GradientButton(
//               text: "Add NoK",
//               onPressed: () {
//                 final name = _nokNameCtrl.text.trim();
//                 final rel = _nokRelCtrl.text.trim();
//                 final mobile = _nokPhoneCtrl.text.trim();
//                 final email = _nokEmailCtrl.text.trim();
//                 final address = _nokAddressCtrl.text.trim();
//                 if (name.isEmpty ||
//                     rel.isEmpty ||
//                     mobile.isEmpty ||
//                     email.isEmpty ||
//                     address.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text("Please fill in ALL Next of Kin fields."),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 final aussiePhoneRegex = RegExp(r'^(\+61|0)4\d{8}$');
//                 if (!aussiePhoneRegex.hasMatch(mobile)) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text(
//                           "Invalid Mobile. Use format: 04xxxxxxxx or +614xxxxxxxx"),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//                 if (!emailRegex.hasMatch(email)) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text("Please enter a valid email address."),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 setState(() {
//                   _nokList.add({
//                     "fullName": name,
//                     "relationship": rel,
//                     "mobileNumber": mobile,
//                     "email": email,
//                     "address": address,
//                   });
//                   _nokNameCtrl.clear();
//                   _nokRelCtrl.clear();
//                   _nokPhoneCtrl.clear();
//                   _nokEmailCtrl.clear();
//                   _nokAddressCtrl.clear();
//                 });
//               }),
//         ),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: _nokList.map((nok) {
//             return Chip(
//               label: Text(nok['fullName']),
//               backgroundColor: Colors.blueAccent,
//               deleteIcon: Icon(Icons.close, size: 18, color: Colors.white),
//               onDeleted: () => setState(() => _nokList.remove(nok)),
//             );
//           }).toList(),
//         ),
//       ],
//       const SizedBox(height: 20),
//       const Text("Required Documents",
//           style: TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
//       const SizedBox(height: 10),
//       if (_requiredDocs.isEmpty)
//         const Text("No documents required.",
//             style: TextStyle(color: Colors.white70)),
//       ..._requiredDocs.map((docName) {
//         bool isUploaded = _uploadedDocs.containsKey(docName);
//         return Card(
//           color: Colors.white.withOpacity(0.1),
//           child: ListTile(
//             title: Text(docName, style: const TextStyle(color: Colors.white)),
//             subtitle: Text(isUploaded ? "Uploaded" : "Required",
//                 style: TextStyle(
//                     color: isUploaded ? Colors.greenAccent : Colors.redAccent)),
//             trailing: Icon(isUploaded ? Icons.check_circle : Icons.upload_file,
//                 color: isUploaded ? Colors.green : Colors.white),
//             onTap: () => _pickDocument(docName),
//           ),
//         );
//       }).toList(),
//     ]);
//   }

//   // --- UI Helpers ---
//   Widget _buildTextField(
//     String label,
//     TextEditingController ctrl, {
//     bool obscure = false,
//     TextInputType? keyboardType,
//     String? Function(String?)? validator,
//     bool readOnly = false,
//     Widget? suffixIcon,
//     FocusNode? focusNode,
//     Function(String)? onFieldSubmitted,
//     Function(String)? onChanged,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         controller: ctrl,
//         obscureText: obscure,
//         keyboardType: keyboardType,
//         readOnly: readOnly,
//         focusNode: focusNode,
//         onFieldSubmitted: onFieldSubmitted,
//         onChanged: onChanged,
//         style: const TextStyle(color: Colors.white),
//         validator: validator ??
//             (v) => (v == null || v.isEmpty) ? "$label is required" : null,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white70),
//           filled: true,
//           fillColor: readOnly ? Colors.white10 : Colors.white.withOpacity(0.1),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//           suffixIcon: suffixIcon,
//           helperText:
//               (readOnly && ctrl.text.isNotEmpty) ? "Verified Bank" : null,
//           helperStyle: const TextStyle(color: Colors.greenAccent),
//         ),
//       ),
//     );
//   }

//   Widget _buildReadOnlyField(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         initialValue: value,
//         readOnly: true,
//         style: const TextStyle(color: Colors.white60),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white38),
//           filled: true,
//           fillColor: Colors.black26,
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       ),
//     );
//   }

//   Widget _buildDropdown(String label, List<String> items, String? value,
//       Function(String?) onChanged) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 15),
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.white38)),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: value,
//           hint: Text("Select $label",
//               style: const TextStyle(color: Colors.white70)),
//           dropdownColor: Colors.grey[900],
//           isExpanded: true,
//           icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
//           onChanged: onChanged,
//           items: items
//               .map((e) => DropdownMenuItem(
//                   value: e,
//                   child: Text(e, style: const TextStyle(color: Colors.white))))
//               .toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildDatePicker(String label, TextEditingController controller,
//       {String? Function(String?)? validator}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         controller: controller,
//         readOnly: true,
//         style: const TextStyle(color: Colors.white),
//         validator: validator ??
//             (v) => (v == null || v.isEmpty) ? "$label is required" : null,
//         onTap: () => _selectDob(context),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white70),
//           filled: true,
//           fillColor: Colors.white.withOpacity(0.1),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//           suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
//           errorStyle: const TextStyle(color: Colors.redAccent),
//         ),
//       ),
//     );
//   }
// }





// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/services/OnboardingService.dart';
// import 'package:shiftsmart/utils/validators.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
// import 'package:shiftsmart/widgets/gradientButton.dart';
// import 'package:shiftsmart/screens/login.dart';

// class Emponboard extends StatefulWidget {
//   final String email;
//   final Map<String, dynamic>? existingProfile;
//   final int? employeeId;
//   final String? rejectionReason;

//   const Emponboard({
//     super.key,
//     required this.email,
//     this.existingProfile,
//     this.employeeId,
//     this.rejectionReason,
//   });

//   @override
//   State<Emponboard> createState() => _EmponboardState();
// }

// class _EmponboardState extends State<Emponboard> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final OnboardingService _service = OnboardingService();

//   int _currentStep = 1;
//   bool _isLoading = true;
//   bool _isSubmitting = false;
//   bool _isResubmission = false;

//   bool _isLoadingBank = false;
//   bool _isBankNameReadOnly = true;
//   final FocusNode _bsbFocusNode = FocusNode();

//   // --- 1. KEY FIX: Forces ProfileAvatar to redraw immediately ---
//   Key _avatarKey = UniqueKey();

//   // Controllers
//   final _firstNameCtrl = TextEditingController();
//   final _midNameCtrl = TextEditingController();
//   final _lastNameCtrl = TextEditingController();
//   final _phoneCtrl = TextEditingController();
//   final _dobCtrl = TextEditingController();

//   final _streetCtrl = TextEditingController();
//   final _cityCtrl = TextEditingController();
//   final _stateCtrl = TextEditingController();
//   final _zipCtrl = TextEditingController();
//   final _countryCtrl = TextEditingController();

//   final _tfnCtrl = TextEditingController();
//   final _abnCtrl = TextEditingController();

//   final _accNameCtrl = TextEditingController();
//   final _bsbCtrl = TextEditingController();
//   final _accNumCtrl = TextEditingController();
//   final _bankNameCtrl = TextEditingController();

//   final _passCtrl = TextEditingController();
//   final _confirmPassCtrl = TextEditingController();

//   final _nokNameCtrl = TextEditingController();
//   final _nokRelCtrl = TextEditingController();
//   final _nokPhoneCtrl = TextEditingController();
//   final _nokEmailCtrl = TextEditingController();
//   final _nokAddressCtrl = TextEditingController();

//   String _jobRole = "";
//   String _empType = "";
//   List<String> _requiredDocs = [];
//   List<String> _rejectedKeys = [];

//   File? _profilePic;
//   final Map<String, File> _uploadedDocs = {};

//   String? _gender;

//   final List<String> _genderOptions = [
//     "Man",
//     "Woman",
//     "Non-binary",
//     "I use a different term",
//     "Prefer not to say",
//   ];

//   final List<Map<String, dynamic>> _nokList = [];

//   @override
//   void initState() {
//     super.initState();
//     _profilePic = null;
    
//     // Show rejection reason if available
//     if (widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _showRejectionReasonDialog(widget.rejectionReason!);
//       });
//     }
    
//     _initData();
//     _bsbFocusNode.addListener(() {
//       if (!_bsbFocusNode.hasFocus) {
//         String clean = _bsbCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
//         if (clean.length == 6) _handleBsbLookup();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _bsbFocusNode.dispose();
//     super.dispose();
//   }

//   // --- SMART NAVIGATION ---
//   bool _stepHasContent(int step) {
//     if (!_isResubmission) return true;
//     if (step == 1) {
//       return _shouldShow("FullName") ||
//           _shouldShow("Gender") ||
//           _shouldShow("MobileNumber") ||
//           _shouldShow("DateOfBirth") ||
//           _shouldShow("Address") ||
//           _shouldShow("TaxInfo");
//     }
//     if (step == 2) return _shouldShow("Bank");
//     if (step == 3) {
//       return _shouldShow("NextOfKin") || _requiredDocs.isNotEmpty;
//     }
//     return false;
//   }

//   int? _getNextStep(int current) {
//     for (int i = current + 1; i <= 3; i++) {
//       if (_stepHasContent(i)) return i;
//     }
//     return null;
//   }

//   int? _getPrevStep(int current) {
//     for (int i = current - 1; i >= 1; i--) {
//       if (_stepHasContent(i)) return i;
//     }
//     return null;
//   }

//   bool _shouldShow(String key) {
//     if (!_isResubmission) return true;
//     return _rejectedKeys.contains(key);
//   }

//   Future<void> _initData() async {
//     if (widget.existingProfile != null) {
//       _mapResubmissionData(widget.existingProfile!);
//     } else {
//       final data = await _service.fetchInvitation(widget.email);
//       if (data != null) {
//         _mapInvitationData(data);
//       } else {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _handleBsbLookup() async {
//     String bsb = _bsbCtrl.text.trim();
//     String cleanBsb = bsb.replaceAll(RegExp(r'[^0-9]'), '');
//     if (cleanBsb.length != 6) return;

//     setState(() => _isLoadingBank = true);
//     try {
//       final result = await EmployeeService().lookupBank(cleanBsb);
//       if (result['status'] == 'Found') {
//         setState(() {
//           _bankNameCtrl.text = result['bankName'].toString();
//           _isBankNameReadOnly = true;
//         });
//       } else {
//         setState(() {
//           _bankNameCtrl.clear();
//           _isBankNameReadOnly = false;
//         });
//       }
//     } catch (e) {
//       setState(() => _isBankNameReadOnly = false);
//     } finally {
//       if (mounted) setState(() => _isLoadingBank = false);
//     }
//   }

//   void _mapResubmissionData(Map<String, dynamic> data) {
//     setState(() {
//       _isResubmission = true;
//       if (data['RejectedFields'] != null) {
//         _rejectedKeys = List<String>.from(data['RejectedFields']);
//       }
//       final rejectedDocsList =
//           data['RejectedDocuments'] as List<dynamic>? ?? [];
//       _requiredDocs = [];
//       if (rejectedDocsList.isNotEmpty) {
//         _requiredDocs = rejectedDocsList
//             .map((doc) => doc['DocumentType'].toString())
//             .toList();
//       }

//       final profile = data['Profile'] ?? {};
//       String fullName = (profile['FullName'] ?? '').trim();
//       List<String> nameParts = fullName.split(RegExp(r'\s+'));

//       if (nameParts.isNotEmpty) {
//         _firstNameCtrl.text = nameParts.first;
//         if (nameParts.length == 2) {
//           _lastNameCtrl.text = nameParts.last;
//         } else if (nameParts.length > 2) {
//           _midNameCtrl.text =
//               nameParts.sublist(1, nameParts.length - 1).join(' ');
//           _lastNameCtrl.text = nameParts.last;
//         }
//       }

//       _dobCtrl.text = (profile['DateOfBirth'] ?? '').split('T').first;
//       _phoneCtrl.text = profile['MobileNumber'] ?? '';

//       // Gender Mapping
//       String? incomingGender = profile['Gender'];
//       if (incomingGender != null) {
//         if (_genderOptions.contains(incomingGender)) {
//           _gender = incomingGender;
//         } else if (incomingGender.toLowerCase() == "male") {
//           _gender = "Man";
//         } else if (incomingGender.toLowerCase() == "female") {
//           _gender = "Woman";
//         } else {
//           _gender = null;
//         }
//       }

//       String rawAddress = profile['Address'] ?? '';
//       List<String> addrParts =
//           rawAddress.split(',').map((s) => s.trim()).toList();

//       if (addrParts.isNotEmpty) {
//         if (addrParts.isNotEmpty) _streetCtrl.text = addrParts[0];
//         if (addrParts.length > 1) _cityCtrl.text = addrParts[1];
//         if (addrParts.length > 2) _stateCtrl.text = addrParts[2];
//         if (addrParts.length > 3) _zipCtrl.text = addrParts[3];
//         if (addrParts.length > 4) _countryCtrl.text = addrParts[4];
//       }

//       final bank = profile['Bank'] ?? {};
//       _bankNameCtrl.text = bank['Name'] ?? '';
//       _bsbCtrl.text = bank['BSB'] ?? '';
//       _accNumCtrl.text = bank['AccountNumber'] ?? '';
//       _accNameCtrl.text = bank['AccountName'] ?? '';

//       final tax = profile['TaxInfo'] ?? {};
//       _empType = tax['EmploymentType'] ?? 'PAYG Employee';
//       _tfnCtrl.text = tax['Tfn'] ?? '';
//       _abnCtrl.text = tax['Abn'] ?? '';

//       _jobRole = profile['JobRole'] ?? 'Standard Role';

//       final noks = profile['NextOfKins'] as List<dynamic>? ?? [];
//       _nokList.clear();
//       for (var nok in noks) {
//         _nokList.add({
//           "fullName": nok['FullName'] ?? '',
//           "relationship": nok['Relationship'] ?? '',
//           "mobileNumber": nok['MobileNumber'] ?? '',
//           "email": nok['Email'] ?? '',
//           "address": nok['Address'] ?? '',
//         });
//       }
//       _isLoading = false;
//     });
//   }

//   void _mapInvitationData(Map<String, dynamic> data) {
//     setState(() {
//       _isResubmission = false;
//       String fullName = (data['Name'] ?? '').trim();
//       List<String> nameParts = fullName.split(RegExp(r'\s+'));

//       if (nameParts.isNotEmpty) {
//         _firstNameCtrl.text = nameParts.first;
//         if (nameParts.length == 2) {
//           _lastNameCtrl.text = nameParts.last;
//         } else if (nameParts.length > 2) {
//           _midNameCtrl.text =
//               nameParts.sublist(1, nameParts.length - 1).join(' ');
//           _lastNameCtrl.text = nameParts.last;
//         }
//       }

//       _phoneCtrl.text = data['Phone'] ?? '';
//       _jobRole = data['JobRole'] ?? '';
//       _empType = data['EmploymentType'] ?? '';

//       String docsStr = data['RequiredCertificates'] ?? '';
//       if (docsStr.isNotEmpty) {
//         _requiredDocs = docsStr
//             .split(',')
//             .map((e) => e.trim())
//             .where((e) => e.isNotEmpty)
//             .toList();
//       }
//       _isLoading = false;
//     });
//   }

//   String? _validateAge(String? dateStr) {
//     if (dateStr == null || dateStr.isEmpty) return "Date of Birth is required";
//     return null;
//   }

//   void _pickProfileImage() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       builder: (ctx) => Wrap(children: [
//         ListTile(
//           leading: const Icon(Icons.camera_alt, color: Colors.white),
//           title:
//               const Text('Take Photo', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.camera, imageQuality: 80);
//             if (img != null) {
//               setState(() {
//                 _profilePic = File(img.path);
//                 // --- UPDATE KEY: This forces the image widget to refresh ---
//                 _avatarKey = UniqueKey();
//               });
//             }
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.photo_library, color: Colors.white),
//           title:
//               const Text('From Gallery', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.gallery, imageQuality: 80);
//             if (img != null) {
//               setState(() {
//                 _profilePic = File(img.path);
//                 // --- UPDATE KEY: This forces the image widget to refresh ---
//                 _avatarKey = UniqueKey();
//               });
//             }
//           },
//         ),
//       ]),
//     );
//   }

//   void _pickDocument(String docName) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.grey[900],
//       builder: (ctx) => Wrap(children: [
//         ListTile(
//           leading: const Icon(Icons.camera_alt, color: Colors.white),
//           title:
//               const Text('Take Photo', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.camera, imageQuality: 80);
//             if (img != null)
//               setState(() => _uploadedDocs[docName] = File(img.path));
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.photo_library, color: Colors.white),
//           title:
//               const Text('From Gallery', style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             final XFile? img = await ImagePicker()
//                 .pickImage(source: ImageSource.gallery, imageQuality: 80);
//             if (img != null)
//               setState(() => _uploadedDocs[docName] = File(img.path));
//           },
//         ),
//         ListTile(
//           leading: const Icon(Icons.attach_file, color: Colors.white),
//           title: const Text('Pick File (PDF)',
//               style: TextStyle(color: Colors.white)),
//           onTap: () async {
//             Navigator.pop(ctx);
//             FilePickerResult? result = await FilePicker.platform.pickFiles(
//               type: FileType.custom,
//               allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
//             );
//             if (result != null && result.files.single.path != null) {
//               setState(() =>
//                   _uploadedDocs[docName] = File(result.files.single.path!));
//             }
//           },
//         ),
//       ]),
//     );
//   }

//   Future<void> _selectDob(BuildContext context) async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime(2000),
//       firstDate: DateTime(1950),
//       lastDate: DateTime.now(),
//       builder: (context, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(
//               primary: Colors.blueAccent, onPrimary: Colors.white),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       String formatted =
//           "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
//       setState(() => _dobCtrl.text = formatted);
//     }
//   }

//   // --- Rejection Reason Dialog ---
//   void _showRejectionReasonDialog(String reason) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: const Color(0xFF2A2F45),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(0.2),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.error_outline, color: Colors.red, size: 60),
//               ),
//               const SizedBox(height: 20),
//               const Text(
//                 "Profile Error",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 reason,
//                 style: const TextStyle(
//                   color: Colors.white70,
//                   fontSize: 14,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 25),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () => Navigator.pop(context),
//                   child: const Text(
//                     "Okay",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   // --- 2. FIX: Better Success Popup ---
//   void _showSuccessDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: const Color(0xFF2A2F45),
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                   color: Colors.green.withOpacity(0.2),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.check_circle,
//                     color: Colors.green, size: 60),
//               ),
//               const SizedBox(height: 20),
//               const Text(
//                 "Submission Successful!",
//                 style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 10),
//               const Text(
//                 "Your details have been submitted for review. You can now login.",
//                 style: TextStyle(color: Colors.white70),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               SizedBox(
//                 width: double.infinity,
//                 child: GradientButton(
//                   text: "Go to Login",
//                   onPressed: () {
//                     Navigator.pop(context); // Close dialog
//                     Navigator.pushAndRemoveUntil(
//                         context,
//                         MaterialPageRoute(builder: (_) => const Login()),
//                         (route) => false);
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Future<void> _submitForm() async {
//     setState(() => _isSubmitting = true);
//     Map<String, dynamic> payload = {};

//     String finalGender = _gender ?? "";
//     if (finalGender == "Man") finalGender = "Male";
//     if (finalGender == "Woman") finalGender = "Female";

//     if (_isResubmission) {
//       payload["EmployeeId"] = widget.employeeId ?? 0;

//       if (_rejectedKeys.contains("FullName")) {
//         payload["FullName"] =
//             "${_firstNameCtrl.text} ${_midNameCtrl.text} ${_lastNameCtrl.text}"
//                 .trim();
//       }
//       if (_rejectedKeys.contains("Gender")) {
//         payload["Gender"] = finalGender;
//       }
//       if (_rejectedKeys.contains("DateOfBirth")) {
//         payload["DateOfBirth"] = _dobCtrl.text.contains("T")
//             ? _dobCtrl.text
//             : "${_dobCtrl.text}T00:00:00";
//       }
//       if (_rejectedKeys.contains("MobileNumber")) {
//         payload["MobileNumber"] = _phoneCtrl.text;
//       }
//       if (_rejectedKeys.contains("Address")) {
//         payload["Street"] = _streetCtrl.text;
//         payload["City"] = _cityCtrl.text;
//         payload["State"] = _stateCtrl.text;
//         payload["PostalCode"] = _zipCtrl.text;
//         payload["Country"] =
//             _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia";
//       }
//       if (_rejectedKeys.contains("Bank")) {
//         payload["BankBSB"] = _bsbCtrl.text;
//         payload["BankAccountNumber"] = _accNumCtrl.text;
//         payload["BankAccountName"] = _accNameCtrl.text;
//         payload["BankName"] = _bankNameCtrl.text;
//       }
//       if (_rejectedKeys.contains("TaxInfo")) {
//         payload["EmploymentType"] = _empType;
//         if (_empType.contains("Contractor")) payload["Abn"] = _abnCtrl.text;
//         if (_empType.contains("Employee")) payload["Tfn"] = _tfnCtrl.text;
//       }
//       if (_rejectedKeys.contains("NextOfKin") && _nokList.isNotEmpty) {
//         var firstNok = _nokList.first;
//         payload["NextOfKin"] = {
//           "FullName": firstNok['fullName'],
//           "MobileNumber": firstNok['mobileNumber'],
//           "Email": firstNok['email'],
//           "Relationship": firstNok['relationship'],
//           "Address": firstNok['address'],
//           "IsPrimary": true
//         };
//       }

//       if (_uploadedDocs.isNotEmpty) {
//         List<Map<String, dynamic>> documentsList = [];
//         _uploadedDocs.forEach((key, file) {
//           documentsList
//               .add({"DocumentId": 0, "DocumentType": key, "DocumentUrl": ""});
//         });
//         payload["Documents"] = documentsList;
//       }
//     } else {
//       payload = {
//         "FirstName": _firstNameCtrl.text,
//         "MiddleName": _midNameCtrl.text,
//         "LastName": _lastNameCtrl.text,
//         "Email": widget.email,
//         "MobileNumber": _phoneCtrl.text,
//         "Gender": finalGender,
//         "DateOfBirth": _dobCtrl.text.isNotEmpty ? _dobCtrl.text : "1990-01-01",
//         "Street": _streetCtrl.text,
//         "City": _cityCtrl.text,
//         "State": _stateCtrl.text,
//         "PostalCode": _zipCtrl.text,
//         "Country":
//             _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia",
//         "BankBSB": _bsbCtrl.text,
//         "BankAccountNumber": _accNumCtrl.text,
//         "BankAccountName": _accNameCtrl.text,
//         "BankName": _bankNameCtrl.text,
//         "EmploymentType": _empType,
//         "JobRole": _jobRole,
//       };
//       if (_empType.contains("Contractor")) payload["Abn"] = _abnCtrl.text;
//       if (_empType.contains("Employee")) payload["Tfn"] = _tfnCtrl.text;
//     }

//     try {
//       final response = await _service.submitOnboardingForm(
//         profilePicture: _profilePic ?? File(''),
//         uploadedCertificates: _uploadedDocs,
//         profile: payload,
//         nextOfKins: _nokList,
//         password: _passCtrl.text.trim(),
//         isResubmission: _isResubmission,
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         if (mounted) {
//           _showSuccessDialog(); // Show new dialog
//         }
//       } else {
//         if (mounted)
//           ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text("Failed: ${response.body}")));
//       }
//     } catch (e) {
//       if (mounted)
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text("Error: $e")));
//     } finally {
//       if (mounted) setState(() => _isSubmitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading)
//       return const Scaffold(
//           backgroundColor: Color(0xFF2F3846),
//           body: Center(child: CircularProgressIndicator()));

//     int? nextStep = _getNextStep(_currentStep);
//     int? prevStep = _getPrevStep(_currentStep);

//     return Scaffold(
//       body: Stack(
//         children: [
//           const Positioned.fill(child: Background()),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   return Container(
//                     height: constraints.maxHeight,
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.white),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       children: [
//                         Expanded(
//                           child: SingleChildScrollView(
//                             child: Form(
//                               key: _formKey,
//                               autovalidateMode:
//                                   AutovalidateMode.onUserInteraction,
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   if (_currentStep == 1) _buildStep1Profile(),
//                                   if (_currentStep == 2)
//                                     _buildStep2BankAndAuth(),
//                                   if (_currentStep == 3)
//                                     _buildStep3DocsAndNok(),
//                                   const SizedBox(height: 30),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             if (prevStep == null)
//                               GradientButton(
//                                 text: "Back",
//                                 isCancel: true,
//                                 onPressed: () => Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                         builder: (_) => const Login())),
//                               )
//                             else
//                               GradientButton(
//                                 text: "Back",
//                                 isCancel: true,
//                                 onPressed: () =>
//                                     setState(() => _currentStep = prevStep!),
//                               ),
//                             GradientButton(
//                               text: nextStep == null
//                                   ? (_isSubmitting ? "Submitting..." : "Submit")
//                                   : "Next",
//                               onPressed: () {
//                                 if (nextStep != null) {
//                                   if (_formKey.currentState!.validate()) {
//                                     if (_currentStep == 1 &&
//                                         _profilePic == null &&
//                                         !_isResubmission) {
//                                       ScaffoldMessenger.of(context)
//                                           .showSnackBar(const SnackBar(
//                                               content: Text(
//                                                   "Profile picture is required")));
//                                       return;
//                                     }
//                                     setState(() => _currentStep = nextStep!);
//                                   }
//                                 } else {
//                                   bool isStep3Valid = _nokList.isNotEmpty &&
//                                       (_requiredDocs.isEmpty ||
//                                           _requiredDocs.every((doc) =>
//                                               _uploadedDocs.containsKey(doc)));

//                                   if (_isResubmission && !_stepHasContent(3)) {
//                                     isStep3Valid = true;
//                                   }

//                                   if (isStep3Valid && !_isSubmitting) {
//                                     _submitForm();
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                         const SnackBar(
//                                             content: Text(
//                                                 "Complete all requirements.")));
//                                   }
//                                 }
//                               },
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStep1Profile() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Center(
//         child: Stack(
//           children: [
//             // FIXED: Using UniqueKey to force redraw every time image changes
//             ProfileAvatar(
//               key: _avatarKey,
//               editable: false,
//               initialImage: _profilePic,
//               onImageSelected: (_) {},
//             ),
//             if (!_isResubmission)
//               Positioned.fill(
//                 child: Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     borderRadius: BorderRadius.circular(100),
//                     onTap: _pickProfileImage,
//                   ),
//                 ),
//               ),
//             if (!_isResubmission)
//               Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: CircleAvatar(
//                   backgroundColor: Colors.blueAccent,
//                   radius: 18,
//                   child: IconButton(
//                     icon: const Icon(Icons.camera_alt,
//                         size: 18, color: Colors.white),
//                     onPressed: _pickProfileImage,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//       const SizedBox(height: 20),
//       if (_shouldShow("FullName")) ...[
//         _buildTextField("First Name", _firstNameCtrl),
//         _buildTextField("Middle Name", _midNameCtrl),
//         _buildTextField("Last Name", _lastNameCtrl),
//       ],
//       if (_shouldShow("Gender"))
//         _buildDropdown("Gender", _genderOptions, _gender,
//             (v) => setState(() => _gender = v)),
//       if (_shouldShow("MobileNumber"))
//         _buildTextField("Mobile Number", _phoneCtrl,
//             keyboardType: TextInputType.phone),
//       if (_shouldShow("DateOfBirth"))
//         _buildDatePicker("Date of Birth", _dobCtrl, validator: _validateAge),
//       if (_shouldShow("Address")) ...[
//         _buildTextField("Street", _streetCtrl),
//         _buildTextField("City", _cityCtrl),
//         _buildTextField("State", _stateCtrl),
//         _buildTextField("Postcode", _zipCtrl,
//             keyboardType: TextInputType.number),
//         _buildTextField("Country", _countryCtrl),
//       ],
//       const SizedBox(height: 20),
//       const Text("Employment Details",
//           style: TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
//       const SizedBox(height: 10),
//       _buildReadOnlyField("Job Role", _jobRole),
//       _buildReadOnlyField("Employment Type", _empType),
//       if (_shouldShow("TaxInfo")) ...[
//         if (_empType.contains("Contractor"))
//           _buildTextField("ABN", _abnCtrl, validator: Validators.validateABN),
//         if (_empType.contains("Employee"))
//           _buildTextField("TFN", _tfnCtrl, validator: Validators.validateTFN),
//       ]
//     ]);
//   }

//   // ... (Step 2 remains the same) ...
//   Widget _buildStep2BankAndAuth() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       if (_shouldShow("Bank")) ...[
//         const Text("Bank Details",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),
//         _buildTextField("Account Name", _accNameCtrl),
//         _buildTextField("BSB", _bsbCtrl,
//             validator: Validators.validateBSB,
//             focusNode: _bsbFocusNode,
//             onChanged: (val) {
//               String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
//               if (clean.length == 6) {
//                 _handleBsbLookup();
//               } else {
//                 if (!_isBankNameReadOnly || _bankNameCtrl.text.isNotEmpty) {
//                   setState(() {
//                     _bankNameCtrl.clear();
//                     _isBankNameReadOnly = true;
//                   });
//                 }
//               }
//             },
//             onFieldSubmitted: (_) => _handleBsbLookup(),
//             suffixIcon: _isLoadingBank
//                 ? const Padding(
//                     padding: EdgeInsets.all(12),
//                     child: CircularProgressIndicator(
//                         strokeWidth: 2, color: Colors.white),
//                   )
//                 : null),
//         _buildTextField("Account Number", _accNumCtrl,
//             validator: Validators.validateAccountNum),
//         _buildTextField("Bank Name", _bankNameCtrl,
//             readOnly: _isBankNameReadOnly),
//       ],
//       if (!_isResubmission) ...[
//         const SizedBox(height: 20),
//         const Text("Set Password",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),
//         _buildTextField("New Password", _passCtrl,
//             obscure: true,
//             validator: (v) => v!.length < 6 ? "Min 6 chars" : null),
//         _buildTextField("Confirm Password", _confirmPassCtrl,
//             obscure: true,
//             validator: (v) =>
//                 v != _passCtrl.text ? "Passwords do not match" : null),
//       ]
//     ]);
//   }

//   Widget _buildStep3DocsAndNok() {
//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       if (_shouldShow("NextOfKin")) ...[
//         const Text("Next of Kin",
//             style: TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 18)),
//         const SizedBox(height: 10),

//         // 3. FIX: Validators check if list is empty. If list has items, field can be empty.
//         _buildTextField("Full Name", _nokNameCtrl, validator: (v) {
//           if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
//           return (v == null || v.isEmpty) ? "Full Name is required" : null;
//         }),
//         _buildTextField("Relationship", _nokRelCtrl, validator: (v) {
//           if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
//           return (v == null || v.isEmpty) ? "Relationship is required" : null;
//         }),
//         _buildTextField("Mobile", _nokPhoneCtrl,
//             keyboardType: TextInputType.phone, validator: (v) {
//           if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
//           if (v == null || v.isEmpty) return "Mobile is required";
//           return null;
//         }),
//         _buildTextField("Email", _nokEmailCtrl,
//             keyboardType: TextInputType.emailAddress, validator: (v) {
//           if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
//           if (v == null || v.isEmpty) return "Email is required";
//           return null;
//         }),
//         _buildTextField("Address", _nokAddressCtrl, validator: (v) {
//           if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
//           return (v == null || v.isEmpty) ? "Address is required" : null;
//         }),
//         Align(
//           alignment: Alignment.centerRight,
//           child: GradientButton(
//               text: "Add NoK",
//               onPressed: () {
//                 // Validation only for the ADD button
//                 final name = _nokNameCtrl.text.trim();
//                 final rel = _nokRelCtrl.text.trim();
//                 final mobile = _nokPhoneCtrl.text.trim();
//                 final email = _nokEmailCtrl.text.trim();
//                 final address = _nokAddressCtrl.text.trim();
//                 if (name.isEmpty ||
//                     rel.isEmpty ||
//                     mobile.isEmpty ||
//                     email.isEmpty ||
//                     address.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text("Please fill in ALL Next of Kin fields."),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 final aussiePhoneRegex = RegExp(r'^(\+61|0)4\d{8}$');
//                 if (!aussiePhoneRegex.hasMatch(mobile)) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text(
//                           "Invalid Mobile. Use format: 04xxxxxxxx or +614xxxxxxxx"),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//                 if (!emailRegex.hasMatch(email)) {
//                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                       content: Text("Please enter a valid email address."),
//                       backgroundColor: Colors.redAccent));
//                   return;
//                 }
//                 setState(() {
//                   _nokList.add({
//                     "fullName": name,
//                     "relationship": rel,
//                     "mobileNumber": mobile,
//                     "email": email,
//                     "address": address,
//                   });
//                   _nokNameCtrl.clear();
//                   _nokRelCtrl.clear();
//                   _nokPhoneCtrl.clear();
//                   _nokEmailCtrl.clear();
//                   _nokAddressCtrl.clear();
//                 });
//               }),
//         ),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: _nokList.map((nok) {
//             return Chip(
//               label: Text(nok['fullName']),
//               backgroundColor: Colors.blueAccent,
//               deleteIcon:
//                   const Icon(Icons.close, size: 18, color: Colors.white),
//               onDeleted: () => setState(() => _nokList.remove(nok)),
//             );
//           }).toList(),
//         ),
//       ],
//       const SizedBox(height: 20),
//       const Text("Required Documents",
//           style: TextStyle(
//               color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
//       const SizedBox(height: 10),
//       if (_requiredDocs.isEmpty)
//         const Text("No documents required.",
//             style: TextStyle(color: Colors.white70)),
//       ..._requiredDocs.map((docName) {
//         bool isUploaded = _uploadedDocs.containsKey(docName);
//         return Card(
//           color: Colors.white.withOpacity(0.1),
//           child: ListTile(
//             title: Text(docName, style: const TextStyle(color: Colors.white)),
//             subtitle: Text(isUploaded ? "Uploaded" : "Required",
//                 style: TextStyle(
//                     color: isUploaded ? Colors.greenAccent : Colors.redAccent)),
//             trailing: Icon(isUploaded ? Icons.check_circle : Icons.upload_file,
//                 color: isUploaded ? Colors.green : Colors.white),
//             onTap: () => _pickDocument(docName),
//           ),
//         );
//       }).toList(),
//     ]);
//   }

//   // --- UI Helpers ---
//   Widget _buildTextField(
//     String label,
//     TextEditingController ctrl, {
//     bool obscure = false,
//     TextInputType? keyboardType,
//     String? Function(String?)? validator,
//     bool readOnly = false,
//     Widget? suffixIcon,
//     FocusNode? focusNode,
//     Function(String)? onFieldSubmitted,
//     Function(String)? onChanged,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         controller: ctrl,
//         obscureText: obscure,
//         keyboardType: keyboardType,
//         readOnly: readOnly,
//         focusNode: focusNode,
//         onFieldSubmitted: onFieldSubmitted,
//         onChanged: onChanged,
//         style: const TextStyle(color: Colors.white),
//         validator: validator ??
//             (v) => (v == null || v.isEmpty) ? "$label is required" : null,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white70),
//           filled: true,
//           fillColor: readOnly ? Colors.white10 : Colors.white.withOpacity(0.1),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//           suffixIcon: suffixIcon,
//           helperText:
//               (readOnly && ctrl.text.isNotEmpty) ? "Verified Bank" : null,
//           helperStyle: const TextStyle(color: Colors.greenAccent),
//         ),
//       ),
//     );
//   }

//   Widget _buildReadOnlyField(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         initialValue: value,
//         readOnly: true,
//         style: const TextStyle(color: Colors.white60),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white38),
//           filled: true,
//           fillColor: Colors.black26,
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       ),
//     );
//   }

//   Widget _buildDropdown(String label, List<String> items, String? value,
//       Function(String?) onChanged) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 15),
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//           color: Colors.white.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.white38)),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: value,
//           hint: Text("Select $label",
//               style: const TextStyle(color: Colors.white70)),
//           dropdownColor: Colors.grey[900],
//           isExpanded: true,
//           icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
//           onChanged: onChanged,
//           items: items
//               .map((e) => DropdownMenuItem(
//                   value: e,
//                   child: Text(e, style: const TextStyle(color: Colors.white))))
//               .toList(),
//         ),
//       ),
//     );
//   }

//   Widget _buildDatePicker(String label, TextEditingController controller,
//       {String? Function(String?)? validator}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15),
//       child: TextFormField(
//         controller: controller,
//         readOnly: true,
//         style: const TextStyle(color: Colors.white),
//         validator: validator ??
//             (v) => (v == null || v.isEmpty) ? "$label is required" : null,
//         onTap: () => _selectDob(context),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: const TextStyle(color: Colors.white70),
//           filled: true,
//           fillColor: Colors.white.withOpacity(0.1),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//           suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
//           errorStyle: const TextStyle(color: Colors.redAccent),
//         ),
//       ),
//     );
//   }
// }













import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shiftsmart/services/EmployeeService.dart';
import 'package:shiftsmart/services/OnboardingService.dart';
import 'package:shiftsmart/utils/validators.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/buildProfileAvatar.dart';
import 'package:shiftsmart/widgets/gradientButton.dart';
import 'package:shiftsmart/screens/login.dart';

class Emponboard extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? existingProfile;
  final int? employeeId;
  final String? rejectionReason;

  const Emponboard({
    super.key,
    required this.email,
    this.existingProfile,
    this.employeeId,
    this.rejectionReason,
  });

  @override
  State<Emponboard> createState() => _EmponboardState();
}

class _EmponboardState extends State<Emponboard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final OnboardingService _service = OnboardingService();

  int _currentStep = 1;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResubmission = false;

  bool _isLoadingBank = false;
  bool _isBankNameReadOnly = true;
  final FocusNode _bsbFocusNode = FocusNode();

  Key _avatarKey = UniqueKey();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _midNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  final _tfnCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();

  final _accNameCtrl = TextEditingController();
  final _bsbCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _nokNameCtrl = TextEditingController();
  final _nokRelCtrl = TextEditingController();
  final _nokPhoneCtrl = TextEditingController();
  final _nokEmailCtrl = TextEditingController();
  final _nokAddressCtrl = TextEditingController();

  String _jobRole = "";
  String _empType = "";
  List<String> _requiredDocs = [];
  List<String> _rejectedKeys = [];

  File? _profilePic;
  final Map<String, File> _uploadedDocs = {};

  String? _gender;

  final List<String> _genderOptions = [
    "Man",
    "Woman",
    "Non-binary",
    "I use a different term",
    "Prefer not to say",
  ];

  final List<Map<String, dynamic>> _nokList = [];

  @override
  void initState() {
    super.initState();
    _profilePic = null;
    
    if (widget.rejectionReason != null && widget.rejectionReason!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectionReasonDialog(widget.rejectionReason!);
      });
    }
    
    _initData();
    _bsbFocusNode.addListener(() {
      if (!_bsbFocusNode.hasFocus) {
        String clean = _bsbCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.length == 6) _handleBsbLookup();
      }
    });
  }

  @override
  void dispose() {
    _bsbFocusNode.dispose();
    super.dispose();
  }

  bool _stepHasContent(int step) {
    if (!_isResubmission) return true;
    if (step == 1) {
      return _shouldShow("FullName") ||
          _shouldShow("Gender") ||
          _shouldShow("MobileNumber") ||
          _shouldShow("DateOfBirth") ||
          _shouldShow("Address") ||
          _shouldShow("TaxInfo");
    }
    if (step == 2) return _shouldShow("Bank");
    if (step == 3) {
      return _shouldShow("NextOfKin") || _requiredDocs.isNotEmpty;
    }
    return false;
  }

  int? _getNextStep(int current) {
    for (int i = current + 1; i <= 3; i++) {
      if (_stepHasContent(i)) return i;
    }
    return null;
  }

  int? _getPrevStep(int current) {
    for (int i = current - 1; i >= 1; i--) {
      if (_stepHasContent(i)) return i;
    }
    return null;
  }

  bool _shouldShow(String key) {
    if (!_isResubmission) return true;
    return _rejectedKeys.contains(key);
  }

  Future<void> _initData() async {
    if (widget.existingProfile != null) {
      _mapResubmissionData(widget.existingProfile!);
    } else {
      final data = await _service.fetchInvitation(widget.email);
      if (data != null) {
        _mapInvitationData(data);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBsbLookup() async {
    String bsb = _bsbCtrl.text.trim();
    String cleanBsb = bsb.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanBsb.length != 6) return;

    setState(() => _isLoadingBank = true);
    try {
      final result = await EmployeeService().lookupBank(cleanBsb);
      if (result['status'] == 'Found') {
        setState(() {
          _bankNameCtrl.text = result['bankName'].toString();
          _isBankNameReadOnly = true;
        });
      } else {
        setState(() {
          _bankNameCtrl.clear();
          _isBankNameReadOnly = false;
        });
      }
    } catch (e) {
      setState(() => _isBankNameReadOnly = false);
    } finally {
      if (mounted) setState(() => _isLoadingBank = false);
    }
  }

  void _mapResubmissionData(Map<String, dynamic> data) {
    setState(() {
      _isResubmission = true;
      if (data['RejectedFields'] != null) {
        _rejectedKeys = List<String>.from(data['RejectedFields']);
      }
      final rejectedDocsList =
          data['RejectedDocuments'] as List<dynamic>? ?? [];
      _requiredDocs = [];
      if (rejectedDocsList.isNotEmpty) {
        _requiredDocs = rejectedDocsList
            .map((doc) => doc['DocumentType'].toString())
            .toList();
      }

      final profile = data['Profile'] ?? {};
      String fullName = (profile['FullName'] ?? '').trim();
      List<String> nameParts = fullName.split(RegExp(r'\s+'));

      if (nameParts.isNotEmpty) {
        _firstNameCtrl.text = nameParts.first;
        if (nameParts.length == 2) {
          _lastNameCtrl.text = nameParts.last;
        } else if (nameParts.length > 2) {
          _midNameCtrl.text =
              nameParts.sublist(1, nameParts.length - 1).join(' ');
          _lastNameCtrl.text = nameParts.last;
        }
      }

      _dobCtrl.text = (profile['DateOfBirth'] ?? '').split('T').first;
      _phoneCtrl.text = profile['MobileNumber'] ?? '';

      String? incomingGender = profile['Gender'];
      if (incomingGender != null) {
        if (_genderOptions.contains(incomingGender)) {
          _gender = incomingGender;
        } else if (incomingGender.toLowerCase() == "male") {
          _gender = "Man";
        } else if (incomingGender.toLowerCase() == "female") {
          _gender = "Woman";
        } else {
          _gender = null;
        }
      }

      String rawAddress = profile['Address'] ?? '';
      List<String> addrParts =
          rawAddress.split(',').map((s) => s.trim()).toList();

      if (addrParts.isNotEmpty) {
        if (addrParts.isNotEmpty) _streetCtrl.text = addrParts[0];
        if (addrParts.length > 1) _cityCtrl.text = addrParts[1];
        if (addrParts.length > 2) _stateCtrl.text = addrParts[2];
        if (addrParts.length > 3) _zipCtrl.text = addrParts[3];
        if (addrParts.length > 4) _countryCtrl.text = addrParts[4];
      }

      final bank = profile['Bank'] ?? {};
      _bankNameCtrl.text = bank['Name'] ?? '';
      _bsbCtrl.text = bank['BSB'] ?? '';
      _accNumCtrl.text = bank['AccountNumber'] ?? '';
      _accNameCtrl.text = bank['AccountName'] ?? '';

      final tax = profile['TaxInfo'] ?? {};
      _empType = tax['EmploymentType'] ?? 'PAYG Employee';
      _tfnCtrl.text = tax['Tfn'] ?? '';
      _abnCtrl.text = tax['Abn'] ?? '';

      _jobRole = profile['JobRole'] ?? 'Standard Role';

      final noks = profile['NextOfKins'] as List<dynamic>? ?? [];
      _nokList.clear();
      for (var nok in noks) {
        _nokList.add({
          "fullName": nok['FullName'] ?? '',
          "relationship": nok['Relationship'] ?? '',
          "mobileNumber": nok['MobileNumber'] ?? '',
          "email": nok['Email'] ?? '',
          "address": nok['Address'] ?? '',
        });
      }
      _isLoading = false;
    });
  }

  void _mapInvitationData(Map<String, dynamic> data) {
    setState(() {
      _isResubmission = false;
      String fullName = (data['Name'] ?? '').trim();
      List<String> nameParts = fullName.split(RegExp(r'\s+'));

      if (nameParts.isNotEmpty) {
        _firstNameCtrl.text = nameParts.first;
        if (nameParts.length == 2) {
          _lastNameCtrl.text = nameParts.last;
        } else if (nameParts.length > 2) {
          _midNameCtrl.text =
              nameParts.sublist(1, nameParts.length - 1).join(' ');
          _lastNameCtrl.text = nameParts.last;
        }
      }

      _phoneCtrl.text = data['Phone'] ?? '';
      _jobRole = data['JobRole'] ?? '';
      _empType = data['EmploymentType'] ?? '';

      String docsStr = data['RequiredCertificates'] ?? '';
      if (docsStr.isNotEmpty) {
        _requiredDocs = docsStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      _isLoading = false;
    });
  }

  String? _validateAge(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Date of Birth is required";
    return null;
  }

  void _pickProfileImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title:
              const Text('Take Photo', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.camera, imageQuality: 80);
            if (img != null) {
              setState(() {
                _profilePic = File(img.path);
                _avatarKey = UniqueKey();
              });
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white),
          title:
              const Text('From Gallery', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (img != null) {
              setState(() {
                _profilePic = File(img.path);
                _avatarKey = UniqueKey();
              });
            }
          },
        ),
      ]),
    );
  }

  void _pickDocument(String docName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title:
              const Text('Take Photo', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.camera, imageQuality: 80);
            if (img != null) {
              setState(() => _uploadedDocs[docName] = File(img.path));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white),
          title:
              const Text('From Gallery', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            final XFile? img = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (img != null) {
              setState(() => _uploadedDocs[docName] = File(img.path));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.attach_file, color: Colors.white),
          title: const Text('Pick File (PDF)',
              style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(ctx);
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
            );
            if (result != null && result.files.single.path != null) {
              setState(() =>
                  _uploadedDocs[docName] = File(result.files.single.path!));
            }
          },
        ),
      ]),
    );
  }

  Future<void> _selectDob(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      String formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() => _dobCtrl.text = formatted);
    }
  }

  void _showRejectionReasonDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2F45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: Colors.red, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Profile Error",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                reason,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
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
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2F45),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 60),
              ),
              const SizedBox(height: 20),
              const Text(
                "Submission Successful!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Your details have been submitted for review. You can now login.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: "Go to Login",
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const Login()),
                        (route) => false);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    Map<String, dynamic> payload = {};

    String finalGender = _gender ?? "";
    if (finalGender == "Man") finalGender = "Male";
    if (finalGender == "Woman") finalGender = "Female";

    if (_isResubmission) {
      payload["EmployeeId"] = widget.employeeId ?? 0;

      if (_rejectedKeys.contains("FullName")) {
        String middleName = _midNameCtrl.text.trim().isEmpty ? "N/A" : _midNameCtrl.text.trim();
        payload["FullName"] =
            "${_firstNameCtrl.text.trim()} $middleName ${_lastNameCtrl.text.trim()}"
                .trim();
      }
      if (_rejectedKeys.contains("Gender")) {
        payload["Gender"] = finalGender;
      }
      if (_rejectedKeys.contains("DateOfBirth")) {
        payload["DateOfBirth"] = _dobCtrl.text.contains("T")
            ? _dobCtrl.text
            : "${_dobCtrl.text}T00:00:00";
      }
      if (_rejectedKeys.contains("MobileNumber")) {
        payload["MobileNumber"] = _phoneCtrl.text;
      }
      if (_rejectedKeys.contains("Address")) {
        payload["Street"] = _streetCtrl.text.trim().isEmpty ? "N/A" : _streetCtrl.text.trim();
        payload["City"] = _cityCtrl.text;
        payload["State"] = _stateCtrl.text.trim().isEmpty ? "N/A" : _stateCtrl.text.trim();
        payload["PostalCode"] = _zipCtrl.text.trim().isEmpty ? "N/A" : _zipCtrl.text.trim();
        payload["Country"] =
            _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia";
      }
      if (_rejectedKeys.contains("Bank")) {
        payload["BankBSB"] = _bsbCtrl.text.trim().isEmpty ? "N/A" : _bsbCtrl.text.trim();
        payload["BankAccountNumber"] = _accNumCtrl.text.trim().isEmpty ? "N/A" : _accNumCtrl.text.trim();
        payload["BankAccountName"] = _accNameCtrl.text.trim().isEmpty ? "N/A" : _accNameCtrl.text.trim();
        payload["BankName"] = _bankNameCtrl.text.trim().isEmpty ? "N/A" : _bankNameCtrl.text.trim();
      }
      if (_rejectedKeys.contains("TaxInfo")) {
        payload["EmploymentType"] = _empType;
        if (_empType.contains("Contractor")) {
          payload["Abn"] = _abnCtrl.text.trim().isEmpty ? "N/A" : _abnCtrl.text.trim();
        }
        if (_empType.contains("Employee")) {
          payload["Tfn"] = _tfnCtrl.text.trim().isEmpty ? "N/A" : _tfnCtrl.text.trim();
        }
      }
      if (_rejectedKeys.contains("NextOfKin") && _nokList.isNotEmpty) {
        var firstNok = _nokList.first;
        payload["NextOfKin"] = {
          "FullName": firstNok['fullName'],
          "MobileNumber": firstNok['mobileNumber'],
          "Email": firstNok['email'].toString().trim().isEmpty ? "N/A" : firstNok['email'],
          "Relationship": firstNok['relationship'].toString().trim().isEmpty ? "N/A" : firstNok['relationship'],
          "Address": firstNok['address'].toString().trim().isEmpty ? "N/A" : firstNok['address'],
          "IsPrimary": true
        };
      }

      if (_uploadedDocs.isNotEmpty) {
        List<Map<String, dynamic>> documentsList = [];
        _uploadedDocs.forEach((key, file) {
          documentsList
              .add({"DocumentId": 0, "DocumentType": key, "DocumentUrl": ""});
        });
        payload["Documents"] = documentsList;
      }
    } else {
      String middleName = _midNameCtrl.text.trim().isEmpty ? "N/A" : _midNameCtrl.text.trim();
      String street = _streetCtrl.text.trim().isEmpty ? "N/A" : _streetCtrl.text.trim();
      String state = _stateCtrl.text.trim().isEmpty ? "N/A" : _stateCtrl.text.trim();
      String postcode = _zipCtrl.text.trim().isEmpty ? "N/A" : _zipCtrl.text.trim();
      String bsb = _bsbCtrl.text.trim().isEmpty ? "N/A" : _bsbCtrl.text.trim();
      String accountNum = _accNumCtrl.text.trim().isEmpty ? "N/A" : _accNumCtrl.text.trim();
      String accountName = _accNameCtrl.text.trim().isEmpty ? "N/A" : _accNameCtrl.text.trim();
      String bankName = _bankNameCtrl.text.trim().isEmpty ? "N/A" : _bankNameCtrl.text.trim();
      String tfn = _tfnCtrl.text.trim().isEmpty ? "N/A" : _tfnCtrl.text.trim();
      String abn = _abnCtrl.text.trim().isEmpty ? "N/A" : _abnCtrl.text.trim();
      
      payload = {
        "FirstName": _firstNameCtrl.text,
        "MiddleName": middleName,
        "LastName": _lastNameCtrl.text,
        "Email": widget.email,
        "MobileNumber": _phoneCtrl.text,
        "Gender": finalGender,
        "DateOfBirth": _dobCtrl.text.isNotEmpty ? _dobCtrl.text : "1990-01-01",
        "Street": street,
        "City": _cityCtrl.text,
        "State": state,
        "PostalCode": postcode,
        "Country":
            _countryCtrl.text.isNotEmpty ? _countryCtrl.text : "Australia",
        "BankBSB": bsb,
        "BankAccountNumber": accountNum,
        "BankAccountName": accountName,
        "BankName": bankName,
        "EmploymentType": _empType,
        "JobRole": _jobRole,
      };
      if (_empType.contains("Contractor")) payload["Abn"] = abn;
      if (_empType.contains("Employee")) payload["Tfn"] = tfn;
    }

    try {
      final response = await _service.submitOnboardingForm(
        profilePicture: _profilePic ?? File(''),
        uploadedCertificates: _uploadedDocs,
        profile: payload,
        nextOfKins: _nokList,
        password: _passCtrl.text.trim(),
        isResubmission: _isResubmission,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed: ${response.body}")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF2F3846),
          body: Center(child: CircularProgressIndicator()));
    }

    int? nextStep = _getNextStep(_currentStep);
    int? prevStep = _getPrevStep(_currentStep);

    return Scaffold(
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
                              key: _formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentStep == 1) _buildStep1Profile(),
                                  if (_currentStep == 2)
                                    _buildStep2BankAndAuth(),
                                  if (_currentStep == 3)
                                    _buildStep3DocsAndNok(),
                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (prevStep == null)
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const Login())),
                              )
                            else
                              GradientButton(
                                text: "Back",
                                isCancel: true,
                                onPressed: () =>
                                    setState(() => _currentStep = prevStep),
                              ),
                            GradientButton(
                              text: nextStep == null
                                  ? (_isSubmitting ? "Submitting..." : "Submit")
                                  : "Next",
                              onPressed: () {
                                if (nextStep != null) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep = nextStep);
                                  }
                                } else {
                                  bool isStep3Valid = _nokList.isNotEmpty &&
                                      (_requiredDocs.isEmpty ||
                                          _requiredDocs.every((doc) =>
                                              _uploadedDocs.containsKey(doc)));

                                  if (_isResubmission && !_stepHasContent(3)) {
                                    isStep3Valid = true;
                                  }

                                  if (isStep3Valid && !_isSubmitting) {
                                    _submitForm();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Complete all requirements.")));
                                  }
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

  Widget _buildStep1Profile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Stack(
          children: [
            ProfileAvatar(
              key: _avatarKey,
              editable: false,
              initialImage: _profilePic,
              onImageSelected: (_) {},
            ),
            if (!_isResubmission)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: _pickProfileImage,
                  ),
                ),
              ),
            if (!_isResubmission)
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt,
                        size: 18, color: Colors.white),
                    onPressed: _pickProfileImage,
                  ),
                ),
              ),
          ],
        ),
      ),
      const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            "Profile Picture (Optional)",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_shouldShow("FullName")) ...[
        _buildTextField("First Name", _firstNameCtrl),
        _buildTextField("Middle Name (Optional)", _midNameCtrl, 
            validator: (_) => null),
        _buildTextField("Last Name", _lastNameCtrl),
      ],
      if (_shouldShow("Gender"))
        _buildDropdown("Gender", _genderOptions, _gender,
            (v) => setState(() => _gender = v)),
      if (_shouldShow("MobileNumber"))
        _buildTextField("Mobile Number", _phoneCtrl,
            keyboardType: TextInputType.phone),
      if (_shouldShow("DateOfBirth"))
        _buildDatePicker("Date of Birth", _dobCtrl, validator: _validateAge),
      if (_shouldShow("Address")) ...[
        _buildTextField("Street (Optional)", _streetCtrl, 
            validator: (_) => null),
        _buildTextField("City", _cityCtrl),
        _buildTextField("State (Optional)", _stateCtrl, 
            validator: (_) => null),
        _buildTextField("Postcode (Optional)", _zipCtrl,
            keyboardType: TextInputType.number, 
            validator: (_) => null),
        _buildTextField("Country", _countryCtrl),
      ],
      const SizedBox(height: 20),
      const Text("Employment Details",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      _buildReadOnlyField("Job Role", _jobRole),
      _buildReadOnlyField("Employment Type", _empType),
      if (_shouldShow("TaxInfo")) ...[
        if (_empType.contains("Contractor"))
          _buildTextField("ABN (Optional)", _abnCtrl, 
              validator: (_) => null),
        if (_empType.contains("Employee"))
          _buildTextField("TFN (Optional)", _tfnCtrl, 
              validator: (_) => null),
      ]
    ]);
  }

  Widget _buildStep2BankAndAuth() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_shouldShow("Bank")) ...[
        const Text("Bank Details (Optional - All fields can be left empty)",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),
        _buildTextField("Account Name (Optional)", _accNameCtrl, 
            validator: (_) => null),
        _buildTextField("BSB (Optional)", _bsbCtrl,
            validator: (_) => null,
            focusNode: _bsbFocusNode,
            onChanged: (val) {
              String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
              if (clean.length == 6) {
                _handleBsbLookup();
              } else {
                if (!_isBankNameReadOnly || _bankNameCtrl.text.isNotEmpty) {
                  setState(() {
                    _bankNameCtrl.clear();
                    _isBankNameReadOnly = true;
                  });
                }
              }
            },
            onFieldSubmitted: (_) => _handleBsbLookup(),
            suffixIcon: _isLoadingBank
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : null),
        _buildTextField("Account Number (Optional)", _accNumCtrl,
            validator: (_) => null),
        _buildTextField("Bank Name (Optional)", _bankNameCtrl,
            readOnly: _isBankNameReadOnly, 
            validator: (_) => null),
      ],
      if (!_isResubmission) ...[
        const SizedBox(height: 20),
        const Text("Set Password",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),
        _buildTextField("New Password", _passCtrl,
            obscure: true,
            validator: (v) => v!.length < 6 ? "Min 6 chars" : null),
        _buildTextField("Confirm Password", _confirmPassCtrl,
            obscure: true,
            validator: (v) =>
                v != _passCtrl.text ? "Passwords do not match" : null),
      ]
    ]);
  }

  Widget _buildStep3DocsAndNok() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_shouldShow("NextOfKin")) ...[
        const Text("Next of Kin",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 10),

        _buildTextField("Full Name", _nokNameCtrl, validator: (v) {
          if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
          return (v == null || v.isEmpty) ? "Full Name is required" : null;
        }),
        _buildTextField("Relationship (Optional)", _nokRelCtrl, validator: (_) => null),
        _buildTextField("Mobile", _nokPhoneCtrl,
            keyboardType: TextInputType.phone, validator: (v) {
          if (_nokList.isNotEmpty && (v == null || v.isEmpty)) return null;
          if (v == null || v.isEmpty) return "Mobile is required";
          return null;
        }),
        _buildTextField("Email (Optional)", _nokEmailCtrl,
            keyboardType: TextInputType.emailAddress, validator: (_) => null),
        _buildTextField("Address (Optional)", _nokAddressCtrl, validator: (_) => null),
        Align(
          alignment: Alignment.centerRight,
          child: GradientButton(
              text: "Add NoK",
              onPressed: () {
                final name = _nokNameCtrl.text.trim();
                final rel = _nokRelCtrl.text.trim();
                final mobile = _nokPhoneCtrl.text.trim();
                final email = _nokEmailCtrl.text.trim();
                final address = _nokAddressCtrl.text.trim();
                
                if (name.isEmpty || mobile.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Please fill in Full Name and Mobile (required fields)."),
                      backgroundColor: Colors.redAccent));
                  return;
                }
                
                final aussiePhoneRegex = RegExp(r'^(\+61|0)4\d{8}$');
                if (!aussiePhoneRegex.hasMatch(mobile)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          "Invalid Mobile. Use format: 04xxxxxxxx or +614xxxxxxxx"),
                      backgroundColor: Colors.redAccent));
                  return;
                }
                
                if (email.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(email)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Please enter a valid email address."),
                        backgroundColor: Colors.redAccent));
                    return;
                  }
                }
                
                setState(() {
                  _nokList.add({
                    "fullName": name,
                    "relationship": rel.isEmpty ? "N/A" : rel,
                    "mobileNumber": mobile,
                    "email": email.isEmpty ? "N/A" : email,
                    "address": address.isEmpty ? "N/A" : address,
                  });
                  _nokNameCtrl.clear();
                  _nokRelCtrl.clear();
                  _nokPhoneCtrl.clear();
                  _nokEmailCtrl.clear();
                  _nokAddressCtrl.clear();
                });
              }),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _nokList.map((nok) {
            return Chip(
              label: Text(nok['fullName']),
              backgroundColor: Colors.blueAccent,
              deleteIcon:
                  const Icon(Icons.close, size: 18, color: Colors.white),
              onDeleted: () => setState(() => _nokList.remove(nok)),
            );
          }).toList(),
        ),
      ],
      const SizedBox(height: 20),
      const Text("Required Documents",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      if (_requiredDocs.isEmpty)
        const Text("No documents required.",
            style: TextStyle(color: Colors.white70)),
      ..._requiredDocs.map((docName) {
        bool isUploaded = _uploadedDocs.containsKey(docName);
        return Card(
          color: Colors.white.withOpacity(0.1),
          child: ListTile(
            title: Text(docName, style: const TextStyle(color: Colors.white)),
            subtitle: Text(isUploaded ? "Uploaded" : "Required",
                style: TextStyle(
                    color: isUploaded ? Colors.greenAccent : Colors.redAccent)),
            trailing: Icon(isUploaded ? Icons.check_circle : Icons.upload_file,
                color: isUploaded ? Colors.green : Colors.white),
            onTap: () => _pickDocument(docName),
          ),
        );
      }),
    ]);
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    Function(String)? onFieldSubmitted,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        readOnly: readOnly,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        validator: validator ??
            (v) => (v == null || v.isEmpty) ? "$label is required" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: readOnly ? Colors.white10 : Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: suffixIcon,
          helperText:
              (readOnly && ctrl.text.isNotEmpty) ? "Verified Bank" : null,
          helperStyle: const TextStyle(color: Colors.greenAccent),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: const TextStyle(color: Colors.white60),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text("Select $label",
              style: const TextStyle(color: Colors.white70)),
          dropdownColor: Colors.grey[900],
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(color: Colors.white))))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        validator: validator ??
            (v) => (v == null || v.isEmpty) ? "$label is required" : null,
        onTap: () => _selectDob(context),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}