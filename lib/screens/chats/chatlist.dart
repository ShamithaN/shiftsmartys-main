import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Keep for type safety if needed elsewhere
import 'package:shiftsmart/models/ChatListItem.dart';
import 'package:shiftsmart/models/SearchEmployee.dart'; // <--- Import New Model
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/screens/chats/chatbox.dart';
import 'package:shiftsmart/screens/chats/chat_service.dart';

class Chatlist extends StatefulWidget {
  final bool isInsideBottomNav;
  const Chatlist({super.key, this.isInsideBottomNav = false});

  @override
  State<Chatlist> createState() => _ChatlistState();
}

class _ChatlistState extends State<Chatlist> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = true;
  int _userId = 0;

  List<ChatListItem> filteredChats = [];

  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('employeeId') ?? prefs.getInt('userId');
    if (id != null) {
      setState(() {
        _userId = id;
      });
      await _fetchChats();
    }
  }

  Future<void> _fetchChats() async {
    try {
      final chatList = await _chatService.fetchChatList();
      if (mounted) {
        setState(() {
          filteredChats = chatList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Helper to Format Time ---
  String _formatTime(DateTime? dt) {
    if (dt == null) return "";
    final local = dt.toLocal();
    final now = DateTime.now();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour > 12
          ? local.hour - 12
          : (local.hour == 0 ? 12 : local.hour);
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$minute $period";
    }
    return "${local.day}/${local.month}";
  }

  void showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SearchUserDialog(
        onUserSelected: (searchEmp) {
          Navigator.pop(context);
          _createAndOpenChatFromSearch(searchEmp);
        },
      ),
    );
  }

  // --- Modified Create Chat Function for Search Results ---
  Future<void> _createAndOpenChatFromSearch(SearchEmployee receiver) async {
    if (receiver.employeeId == _userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot chat with yourself.")),
      );
      return;
    }

    final success = await _chatService.createChat(
      senderId: _userId,
      receiverId: receiver.employeeId,
      message: "👋 Started a new chat",
    );

    if (success) {
      await _fetchChats();
      if (mounted) {
        try {
          // Find the new chat in the updated list
          final chat = filteredChats
              .firstWhere((c) => c.partnerId == receiver.employeeId);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Chatbox(
                chatParticipantId: chat.chatId,
                receiverId: receiver.employeeId,
                receiverName: receiver.firstName,
              ),
            ),
          );
          _fetchChats();
        } catch (e) {
          _fetchChats();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Stack(
      children: [
        const Background(),
        Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromARGB(180, 42, 50, 67),
                      Color.fromARGB(180, 34, 40, 52)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Chats",
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    GestureDetector(
                      onTap: () => showSearchDialog(context),
                      child: const Icon(Icons.add_comment_rounded,
                          color: Colors.blue, size: 28),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredChats.isEmpty
                      ? const Center(
                          child: Text(
                            "No chats yet.",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ))
                      : RefreshIndicator(
                          key: _refreshKey,
                          onRefresh: _fetchChats,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = filteredChats[index];

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Chatbox(
                                          chatParticipantId: chat.chatId,
                                          receiverId: chat.partnerId,
                                          receiverName: chat.partnerName,
                                        ),
                                      ),
                                    );
                                    _fetchChats();
                                  },
                                  child: Gradienthorizontal(
                                    width: double.infinity,
                                    height: 80,
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 16.0, right: 12.0),
                                          child: CircleAvatar(
                                            backgroundColor: Colors.white24,
                                            backgroundImage:
                                                (chat.partnerPhoto != null &&
                                                        chat.partnerPhoto!
                                                            .isNotEmpty)
                                                    ? NetworkImage(
                                                        chat.partnerPhoto!)
                                                    : null,
                                            child: (chat.partnerPhoto == null)
                                                ? const Icon(Icons.person,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    chat.partnerName,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 16.0),
                                                    child: Text(
                                                      _formatTime(
                                                          chat.lastMessageTime),
                                                      style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  chat.lastMessage.isNotEmpty
                                                      ? chat.lastMessage
                                                      : "No messages yet",
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ],
    );

    if (widget.isInsideBottomNav) {
      return content;
    } else {
      return Scaffold(
        drawer: const Sidenav(currentScreen: 'Chat'),
        appBar: const Uppernavbar(),
        backgroundColor: const Color(0xFF1C2230),
        body: content,
      );
    }
  }
}

// --- UPDATED SEARCH DIALOG (Uses SearchEmployee) ---
class _SearchUserDialog extends StatefulWidget {
  final Function(SearchEmployee) onUserSelected; // Type Updated
  const _SearchUserDialog({required this.onUserSelected});

  @override
  State<_SearchUserDialog> createState() => _SearchUserDialogState();
}

class _SearchUserDialogState extends State<_SearchUserDialog> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<SearchEmployee> _searchResults = []; // Type Updated
  bool _isSearching = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 2) {
        setState(() => _searchResults = []);
        return;
      }

      setState(() => _isSearching = true);

      // Calls the new updated service method
      final results = await _chatService.searchEmployees(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2F45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          children: [
            const Text(
              "Find Employee",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type name...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? const Center(
                          child: Text("No users found",
                              style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final emp = _searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                backgroundImage: (emp.profilePicture != null &&
                                        emp.profilePicture!.isNotEmpty)
                                    ? NetworkImage(emp.profilePicture!)
                                    : null,
                                child: (emp.profilePicture == null ||
                                        emp.profilePicture!.isEmpty)
                                    ? const Icon(Icons.person,
                                        color: Colors.white)
                                    : null,
                              ),
                              title: Text(emp.firstName,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(emp.email ?? "No Email",
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                              onTap: () => widget.onUserSelected(emp),
                            );
                          },
                        ),
            ),
            // ========== CHANGED CODE START ==========
            // UPDATED: Styled Cancel button with gradient and proper sizing
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6), // Blue gradient start
                      Color(0xFF2563EB), // Blue gradient end
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // ========== CHANGED CODE END ==========
          ],
        ),
      ),
    );
  }
}













// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/models/Employee.dart';
// import 'package:shiftsmart/screens/chats/ChatParticipantM.dart';
// import 'package:shiftsmart/services/EmployeeService.dart'; // 1. Import EmployeeService
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:shiftsmart/screens/chats/chatbox.dart';
// import 'package:shiftsmart/screens/chats/chat_service.dart';

// class Chatlist extends StatefulWidget {
//   final bool isInsideBottomNav;
//   const Chatlist({super.key, this.isInsideBottomNav = false});

//   @override
//   State<Chatlist> createState() => _ChatlistState();
// }

// class _ChatlistState extends State<Chatlist> {
//   final GlobalKey<RefreshIndicatorState> _refreshKey =
//       GlobalKey<RefreshIndicatorState>();
//   bool _isLoading = true;
//   late int _userId;
//   List<ChatParticipant> filteredChats = [];
//   Map<int, String> _employeeNames = {}; // 2. Store Names Here

//   final ChatService _chatService = ChatService();
//   final EmployeeService _employeeService =
//       EmployeeService(); // Service to fetch names

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     await _getUserId();
//     await _fetchEmployeeNames(); // 3. Fetch names on startup
//   }

//   Future<void> _getUserId() async {
//     final prefs = await SharedPreferences.getInstance();
//     final id = prefs.getInt('employeeId') ?? prefs.getInt('userId');
//     if (id != null) {
//       setState(() {
//         _userId = id;
//       });
//       await _fetchChats();
//     }
//   }

//   // --- NEW: Fetch Names ---
//   Future<void> _fetchEmployeeNames() async {
//     try {
//       final nameMap = await _employeeService.fetchEmployeeNameMap();
//       if (mounted) {
//         setState(() {
//           _employeeNames = nameMap;
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching names: $e");
//     }
//   }

//   Future<void> _fetchChats() async {
//     try {
//       final chatList = await _chatService.fetchChatParticipants(_userId);
//       if (mounted) {
//         setState(() {
//           filteredChats =
//               chatList.map((chat) => ChatParticipant.fromJson(chat)).toList();
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       debugPrint("Error loading chats: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // --- SEARCH DIALOG ---
//   void showSearchDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => _SearchUserDialog(
//         onUserSelected: (employee) {
//           Navigator.pop(context);
//           _createAndOpenChat(employee);
//         },
//       ),
//     );
//   }

//   Future<void> _createAndOpenChat(Employee receiver) async {
//     if (receiver.employeeId == _userId) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("You cannot chat with yourself.")),
//       );
//       return;
//     }

//     // Create chat
//     final success = await _chatService.createChat(
//       senderId: _userId,
//       receiverId: receiver.employeeId,
//       message: "👋 Started a new chat",
//     );

//     if (success) {
//       // Refresh list to ensure we have the new chat ID
//       await _fetchChats();

//       if (mounted) {
//         try {
//           // Find the chat object for this user
//           final chat = filteredChats.firstWhere((c) =>
//               (c.employee1Id == _userId &&
//                   c.employee2Id == receiver.employeeId) ||
//               (c.employee1Id == receiver.employeeId &&
//                   c.employee2Id == _userId));

//           // 4. Navigate & Refresh on Return
//           await Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Chatbox(
//                 chatParticipantId: chat.chatParticipantId,
//                 receiverId: receiver.employeeId,
//                 receiverName: receiver.firstName ?? "Unknown",
//               ),
//             ),
//           );

//           // Refresh list when they come back
//           _fetchChats();
//         } catch (e) {
//           debugPrint("Chat created but couldn't find ID immediately.");
//           _fetchChats(); // Retry refresh
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget content = Stack(
//       children: [
//         const Background(),
//         Column(
//           children: [
//             Padding(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [
//                       Color.fromARGB(180, 42, 50, 67),
//                       Color.fromARGB(180, 34, 40, 52)
//                     ],
//                   ),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Padding(
//                       padding: EdgeInsets.all(16.0),
//                       child: Text("Chats",
//                           style: TextStyle(
//                               fontSize: 20,
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold)),
//                     ),
//                     GestureDetector(
//                       onTap: () => showSearchDialog(context),
//                       child: const Icon(Icons.add_comment_rounded,
//                           color: Colors.blue, size: 28),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : filteredChats.isEmpty
//                       ? const Center(
//                           child: Text("No chats yet.",
//                               style: TextStyle(color: Colors.white54)))
//                       : RefreshIndicator(
//                           key: _refreshKey,
//                           onRefresh: _fetchChats,
//                           child: ListView.builder(
//                             padding: const EdgeInsets.symmetric(horizontal: 20),
//                             itemCount: filteredChats.length,
//                             itemBuilder: (context, index) {
//                               final chat = filteredChats[index];
//                               final otherId = (_userId == chat.employee1Id)
//                                   ? chat.employee2Id
//                                   : chat.employee1Id;

//                               // 5. Look up the Real Name
//                               final realName =
//                                   _employeeNames[otherId] ?? "User $otherId";

//                               return Padding(
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 6.0),
//                                 child: GestureDetector(
//                                   onTap: () async {
//                                     // 6. Navigate & Wait for Return
//                                     await Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => Chatbox(
//                                           chatParticipantId:
//                                               chat.chatParticipantId,
//                                           receiverId: otherId,
//                                           receiverName: realName,
//                                         ),
//                                       ),
//                                     );
//                                     // Refresh list when user returns (updates last message preview)
//                                     _fetchChats();
//                                   },
//                                   child: Gradienthorizontal(
//                                     width: double.infinity,
//                                     height: 80,
//                                     child: Row(
//                                       children: [
//                                         const Padding(
//                                           padding: EdgeInsets.only(
//                                               left: 16.0, right: 12.0),
//                                           child: CircleAvatar(
//                                             backgroundColor: Colors.white24,
//                                             child: Icon(Icons.person,
//                                                 color: Colors.white),
//                                           ),
//                                         ),
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.start,
//                                             mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                             children: [
//                                               // Display Real Name
//                                               Text(
//                                                 realName,
//                                                 style: const TextStyle(
//                                                     color: Colors.white,
//                                                     fontWeight: FontWeight.bold,
//                                                     fontSize: 16),
//                                               ),
//                                               const SizedBox(height: 4),
//                                               const Text(
//                                                   "Tap to view conversation",
//                                                   style: TextStyle(
//                                                       color: Colors.white54,
//                                                       fontSize: 13)),
//                                             ],
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//             ),
//             const SizedBox(height: 80),
//           ],
//         ),
//       ],
//     );

//     if (widget.isInsideBottomNav) {
//       return content;
//     } else {
//       return Scaffold(
//         drawer: const Sidenav(currentScreen: 'Chat'),
//         appBar: const Uppernavbar(),
//         backgroundColor: const Color(0xFF1C2230),
//         body: content,
//       );
//     }
//   }
// }

// // --- Search Dialog (Unchanged, kept for completeness) ---
// class _SearchUserDialog extends StatefulWidget {
//   final Function(Employee) onUserSelected;
//   const _SearchUserDialog({required this.onUserSelected});

//   @override
//   State<_SearchUserDialog> createState() => _SearchUserDialogState();
// }

// class _SearchUserDialogState extends State<_SearchUserDialog> {
//   final ChatService _chatService = ChatService();
//   final TextEditingController _searchController = TextEditingController();
//   List<Employee> _searchResults = [];
//   bool _isSearching = false;
//   Timer? _debounce;

//   void _onSearchChanged(String query) {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();

//     _debounce = Timer(const Duration(milliseconds: 500), () async {
//       if (query.length < 2) {
//         setState(() => _searchResults = []);
//         return;
//       }

//       setState(() => _isSearching = true);
//       final results = await _chatService.searchEmployees(query);

//       if (mounted) {
//         setState(() {
//           _searchResults = results;
//           _isSearching = false;
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: const Color(0xFF2A2F45),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         height: 500,
//         child: Column(
//           children: [
//             const Text(
//               "Find Employee",
//               style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: _searchController,
//               onChanged: _onSearchChanged,
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 hintText: "Type name...",
//                 hintStyle: const TextStyle(color: Colors.white38),
//                 filled: true,
//                 fillColor: Colors.black26,
//                 prefixIcon: const Icon(Icons.search, color: Colors.white54),
//                 border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     borderSide: BorderSide.none),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Expanded(
//               child: _isSearching
//                   ? const Center(child: CircularProgressIndicator())
//                   : _searchResults.isEmpty
//                       ? const Center(
//                           child: Text("No users found",
//                               style: TextStyle(color: Colors.white38)))
//                       : ListView.builder(
//                           itemCount: _searchResults.length,
//                           itemBuilder: (context, index) {
//                             final emp = _searchResults[index];
//                             return ListTile(
//                               leading: const CircleAvatar(
//                                   backgroundColor: Colors.blueAccent,
//                                   child:
//                                       Icon(Icons.person, color: Colors.white)),
//                               title: Text(emp.firstName,
//                                   style: const TextStyle(color: Colors.white)),
//                               subtitle: Text(emp.email ?? "No Email",
//                                   style: const TextStyle(
//                                       color: Colors.white54, fontSize: 12)),
//                               onTap: () => widget.onUserSelected(emp),
//                             );
//                           },
//                         ),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Cancel"),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/models/Employee.dart'; // Keep for type safety if needed elsewhere
// import 'package:shiftsmart/models/ChatListItem.dart';
// import 'package:shiftsmart/models/SearchEmployee.dart'; // <--- Import New Model
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:shiftsmart/screens/chats/chatbox.dart';
// import 'package:shiftsmart/screens/chats/chat_service.dart';

// class Chatlist extends StatefulWidget {
//   final bool isInsideBottomNav;
//   const Chatlist({super.key, this.isInsideBottomNav = false});

//   @override
//   State<Chatlist> createState() => _ChatlistState();
// }

// class _ChatlistState extends State<Chatlist> {
//   final GlobalKey<RefreshIndicatorState> _refreshKey =
//       GlobalKey<RefreshIndicatorState>();
//   bool _isLoading = true;
//   int _userId = 0;

//   List<ChatListItem> filteredChats = [];

//   final ChatService _chatService = ChatService();

//   @override
//   void initState() {
//     super.initState();
//     _getUserId();
//   }

//   Future<void> _getUserId() async {
//     final prefs = await SharedPreferences.getInstance();
//     final id = prefs.getInt('employeeId') ?? prefs.getInt('userId');
//     if (id != null) {
//       setState(() {
//         _userId = id;
//       });
//       await _fetchChats();
//     }
//   }

//   Future<void> _fetchChats() async {
//     try {
//       final chatList = await _chatService.fetchChatList();
//       if (mounted) {
//         setState(() {
//           filteredChats = chatList;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       debugPrint("Error loading chats: $e");
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // --- Helper to Format Time ---
//   String _formatTime(DateTime? dt) {
//     if (dt == null) return "";
//     final local = dt.toLocal();
//     final now = DateTime.now();

//     if (local.year == now.year &&
//         local.month == now.month &&
//         local.day == now.day) {
//       final hour = local.hour > 12
//           ? local.hour - 12
//           : (local.hour == 0 ? 12 : local.hour);
//       final minute = local.minute.toString().padLeft(2, '0');
//       final period = local.hour >= 12 ? 'PM' : 'AM';
//       return "$hour:$minute $period";
//     }
//     return "${local.day}/${local.month}";
//   }

//   void showSearchDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => _SearchUserDialog(
//         onUserSelected: (searchEmp) {
//           Navigator.pop(context);
//           _createAndOpenChatFromSearch(searchEmp);
//         },
//       ),
//     );
//   }

//   // --- Modified Create Chat Function for Search Results ---
//   Future<void> _createAndOpenChatFromSearch(SearchEmployee receiver) async {
//     if (receiver.employeeId == _userId) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("You cannot chat with yourself.")),
//       );
//       return;
//     }

//     final success = await _chatService.createChat(
//       senderId: _userId,
//       receiverId: receiver.employeeId,
//       message: "👋 Started a new chat",
//     );

//     if (success) {
//       await _fetchChats();
//       if (mounted) {
//         try {
//           // Find the new chat in the updated list
//           final chat = filteredChats
//               .firstWhere((c) => c.partnerId == receiver.employeeId);

//           await Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => Chatbox(
//                 chatParticipantId: chat.chatId,
//                 receiverId: receiver.employeeId,
//                 receiverName: receiver.firstName,
//               ),
//             ),
//           );
//           _fetchChats();
//         } catch (e) {
//           _fetchChats();
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     Widget content = Stack(
//       children: [
//         const Background(),
//         Column(
//           children: [
//             Padding(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [
//                       Color.fromARGB(180, 42, 50, 67),
//                       Color.fromARGB(180, 34, 40, 52)
//                     ],
//                   ),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Padding(
//                       padding: EdgeInsets.all(16.0),
//                       child: Text("Chats",
//                           style: TextStyle(
//                               fontSize: 20,
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold)),
//                     ),
//                     GestureDetector(
//                       onTap: () => showSearchDialog(context),
//                       child: const Icon(Icons.add_comment_rounded,
//                           color: Colors.blue, size: 28),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: _isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : filteredChats.isEmpty
//                       ? const Center(
//                           child: Text("No chats yet.",
//                               style: TextStyle(color: Colors.white54)))
//                       : RefreshIndicator(
//                           key: _refreshKey,
//                           onRefresh: _fetchChats,
//                           child: ListView.builder(
//                             padding: const EdgeInsets.symmetric(horizontal: 20),
//                             itemCount: filteredChats.length,
//                             itemBuilder: (context, index) {
//                               final chat = filteredChats[index];

//                               return Padding(
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 6.0),
//                                 child: GestureDetector(
//                                   onTap: () async {
//                                     await Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => Chatbox(
//                                           chatParticipantId: chat.chatId,
//                                           receiverId: chat.partnerId,
//                                           receiverName: chat.partnerName,
//                                         ),
//                                       ),
//                                     );
//                                     _fetchChats();
//                                   },
//                                   child: Gradienthorizontal(
//                                     width: double.infinity,
//                                     height: 80,
//                                     child: Row(
//                                       children: [
//                                         Padding(
//                                           padding: const EdgeInsets.only(
//                                               left: 16.0, right: 12.0),
//                                           child: CircleAvatar(
//                                             backgroundColor: Colors.white24,
//                                             backgroundImage:
//                                                 (chat.partnerPhoto != null &&
//                                                         chat.partnerPhoto!
//                                                             .isNotEmpty)
//                                                     ? NetworkImage(
//                                                         chat.partnerPhoto!)
//                                                     : null,
//                                             child: (chat.partnerPhoto == null)
//                                                 ? const Icon(Icons.person,
//                                                     color: Colors.white)
//                                                 : null,
//                                           ),
//                                         ),
//                                         Expanded(
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.start,
//                                             mainAxisAlignment:
//                                                 MainAxisAlignment.center,
//                                             children: [
//                                               Row(
//                                                 mainAxisAlignment:
//                                                     MainAxisAlignment
//                                                         .spaceBetween,
//                                                 children: [
//                                                   Text(
//                                                     chat.partnerName,
//                                                     style: const TextStyle(
//                                                         color: Colors.white,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                         fontSize: 16),
//                                                   ),
//                                                   Padding(
//                                                     padding:
//                                                         const EdgeInsets.only(
//                                                             right: 16.0),
//                                                     child: Text(
//                                                       _formatTime(
//                                                           chat.lastMessageTime),
//                                                       style: const TextStyle(
//                                                           color: Colors.white54,
//                                                           fontSize: 12),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                               const SizedBox(height: 4),
//                                               Text(
//                                                   chat.lastMessage.isNotEmpty
//                                                       ? chat.lastMessage
//                                                       : "No messages yet",
//                                                   maxLines: 1,
//                                                   overflow:
//                                                       TextOverflow.ellipsis,
//                                                   style: const TextStyle(
//                                                       color: Colors.white70,
//                                                       fontSize: 13)),
//                                             ],
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//             ),
//             const SizedBox(height: 80),
//           ],
//         ),
//       ],
//     );

//     if (widget.isInsideBottomNav) {
//       return content;
//     } else {
//       return Scaffold(
//         drawer: const Sidenav(currentScreen: 'Chat'),
//         appBar: const Uppernavbar(),
//         backgroundColor: const Color(0xFF1C2230),
//         body: content,
//       );
//     }
//   }
// }

// // --- UPDATED SEARCH DIALOG (Uses SearchEmployee) ---
// class _SearchUserDialog extends StatefulWidget {
//   final Function(SearchEmployee) onUserSelected; // Type Updated
//   const _SearchUserDialog({required this.onUserSelected});

//   @override
//   State<_SearchUserDialog> createState() => _SearchUserDialogState();
// }

// class _SearchUserDialogState extends State<_SearchUserDialog> {
//   final ChatService _chatService = ChatService();
//   final TextEditingController _searchController = TextEditingController();

//   List<SearchEmployee> _searchResults = []; // Type Updated
//   bool _isSearching = false;
//   Timer? _debounce;

//   void _onSearchChanged(String query) {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();

//     _debounce = Timer(const Duration(milliseconds: 500), () async {
//       if (query.length < 2) {
//         setState(() => _searchResults = []);
//         return;
//       }

//       setState(() => _isSearching = true);

//       // Calls the new updated service method
//       final results = await _chatService.searchEmployees(query);

//       if (mounted) {
//         setState(() {
//           _searchResults = results;
//           _isSearching = false;
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       backgroundColor: const Color(0xFF2A2F45),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         height: 500,
//         child: Column(
//           children: [
//             const Text(
//               "Find Employee",
//               style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: _searchController,
//               onChanged: _onSearchChanged,
//               style: const TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 hintText: "Type name...",
//                 hintStyle: const TextStyle(color: Colors.white38),
//                 filled: true,
//                 fillColor: Colors.black26,
//                 prefixIcon: const Icon(Icons.search, color: Colors.white54),
//                 border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                     borderSide: BorderSide.none),
//               ),
//             ),
//             const SizedBox(height: 10),
//             Expanded(
//               child: _isSearching
//                   ? const Center(child: CircularProgressIndicator())
//                   : _searchResults.isEmpty
//                       ? const Center(
//                           child: Text("No users found",
//                               style: TextStyle(color: Colors.white38)))
//                       : ListView.builder(
//                           itemCount: _searchResults.length,
//                           itemBuilder: (context, index) {
//                             final emp = _searchResults[index];
//                             return ListTile(
//                               leading: CircleAvatar(
//                                 backgroundColor: Colors.blueAccent,
//                                 backgroundImage: (emp.profilePicture != null &&
//                                         emp.profilePicture!.isNotEmpty)
//                                     ? NetworkImage(emp.profilePicture!)
//                                     : null,
//                                 child: (emp.profilePicture == null ||
//                                         emp.profilePicture!.isEmpty)
//                                     ? const Icon(Icons.person,
//                                         color: Colors.white)
//                                     : null,
//                               ),
//                               title: Text(emp.firstName,
//                                   style: const TextStyle(color: Colors.white)),
//                               subtitle: Text(emp.email ?? "No Email",
//                                   style: const TextStyle(
//                                       color: Colors.white54, fontSize: 12)),
//                               onTap: () => widget.onUserSelected(emp),
//                             );
//                           },
//                         ),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Cancel"),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
