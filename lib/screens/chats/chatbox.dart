import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiftsmart/models/Message.dart';
import 'package:shiftsmart/screens/chats/chat_service.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Chatbox extends StatefulWidget {
  final int chatParticipantId;
  final int receiverId;
  final String receiverName;

  const Chatbox({
    super.key,
    required this.chatParticipantId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<Chatbox> createState() => _ChatboxState();
}

class _ChatboxState extends State<Chatbox> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _userId = 0;
  List<Message> _messages = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _getUserId();
    // Auto-refresh messages every 5 seconds
    _timer =
        Timer.periodic(const Duration(seconds: 5), (timer) => _fetchMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Prioritize employeeId, fallback to userId
      _userId = prefs.getInt('employeeId') ?? prefs.getInt('userId') ?? 0;
    });
    // Fetch messages only after we know who "We" are
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    final msgs = await _chatService.fetchMessages(widget.chatParticipantId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      // Optional: Auto-scroll to bottom on first load could go here
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text;
    _messageController.clear();

    final success = await _chatService.sendMessage(
      chatParticipantId: widget.chatParticipantId,
      senderId: _userId,
      receiverId: widget.receiverId,
      text: text,
    );

    if (success) {
      _fetchMessages(); // Refresh immediately
      // Auto-scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send message")),
      );
    }
  }

  // --- Helper to Format Time (e.g., 10:30 AM) ---
  String _formatTime(DateTime dt) {
    final localTime = dt.toLocal();
    final hour = localTime.hour > 12
        ? localTime.hour - 12
        : (localTime.hour == 0 ? 12 : localTime.hour);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      // Updated Uppernavbar usage (requires the update we did previously)
      appBar: Uppernavbar(
        showBackButton: true,
        title: widget.receiverName,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          "No messages yet",
                          style: TextStyle(
                            color: Colors.white54,
                            // ========== NEW CODE START ==========
                            // UPDATED: Increased font size for better visibility
                            fontSize: 18, // Larger font size
                            // UPDATED: Added font weight for emphasis
                            fontWeight: FontWeight.w600, // Medium bold
                            // ========== NEW CODE END ==========
                          ),
                        )
                    )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];

                          // --- UI LOGIC START ---
                          // Check if message is mine
                          final isMe = msg.senderId == _userId;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              // Limit width so it looks like a bubble
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.blueAccent
                                    : const Color(
                                        0xFF2A2F45), // Dark grey for receiver
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  // Tail logic: Square off the bottom corner nearest the sender
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.text,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  // Time Stamp
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          // --- UI LOGIC END ---
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF2A2F45),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}





















// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
// import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/models/Employee.dart';
// import 'package:shiftsmart/screens/chats/chat_service.dart';
// import 'package:shiftsmart/services/EmployeeService.dart';
// import 'package:shiftsmart/utils/fullscreen_helper.dart';
// import 'package:shiftsmart/widgets/background.dart';
// import 'package:shiftsmart/widgets/gradienthorizontal.dart';
// import 'package:shiftsmart/widgets/sidenav.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';
// import 'package:uuid/uuid.dart';

// class Chatbox extends StatefulWidget {
//   final int chatParticipantId;

//   const Chatbox({super.key, required this.chatParticipantId});

//   @override
//   State<Chatbox> createState() => _ChatboxState();
// }

// class _ChatboxState extends State<Chatbox> {
//   final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
//   List<types.Message> _messages = [];
//   types.User? _user;
//   final _uuid = const Uuid();
//   bool _isLoading = true;
//   int? _currentUserId;
//   int? _receiverId;
//   String _receiverName = '';
//   final ChatService _chatService = ChatService();
// final EmployeeService _employeeService = EmployeeService(); // already exists

//   @override
//   void initState() {
//     super.initState();
//     enableFullScreen();
//     _initializeUser();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _refreshKey.currentState?.show();
//       _refreshData();
//     });
//   }

//   Future<void> _refreshData() async {
//     setState(() => _isLoading = true);
//     await _loadMessages();
//     setState(() => _isLoading = false);
//   }

//   Future<void> _initializeUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     final int? userId = prefs.getInt('employeeId') ?? prefs.getInt('managerId');
//     final String fullName = prefs.getString('userName') ?? 'Unknown User';

//     if (userId != null) {
//       setState(() {
//         _currentUserId = userId;
//         _user = types.User(id: userId.toString(), firstName: fullName);
//       });

//       await _fetchChatParticipantsAndSetReceiver();
//     }
//   }

//   /// Fetch the chat participants and determine the receiver ID
//  Future<void> _fetchChatParticipantsAndSetReceiver() async {
//   if (_currentUserId == null) return;

//   final participantList = await _chatService.fetchChatParticipants(_currentUserId!);
//   final employeeList = await _employeeService.fetchAllEmployees();

//   final participant = participantList.firstWhere(
//     (p) => p['ChatParticipantId'] == widget.chatParticipantId,
//     orElse: () => null,
//   );

//   if (participant != null) {
//     final int emp1 = participant['Employee1Id'];
//     final int emp2 = participant['Employee2Id'];
//     final int receiverId = _currentUserId == emp1 ? emp2 : emp1;

//     final receiver = employeeList.firstWhere(
//       (e) => e.employeeId == receiverId,
//       orElse: () => Employee(employeeId: receiverId, firstName: 'Unknown', email: 'Unknown'),
//     );

//     final String name = receiver.firstName;

//     setState(() {
//       _receiverId = receiverId;
//       _receiverName = name;
//     });

//     debugPrint('✅ Receiver: $_receiverId ($_receiverName)');
//   } else {
//     debugPrint('❌ No participant found for ChatParticipantId ${widget.chatParticipantId}');
//   }
// }

//   Future<void> _loadMessages() async {
//   final chatList = await _chatService.fetchMessages(widget.chatParticipantId);

//   chatList.sort((a, b) => DateTime.parse(b['SentAt']).compareTo(DateTime.parse(a['SentAt'])));

//   setState(() {
//     _messages = chatList.map((msg) {
//       return types.TextMessage(
//         id: msg['MessageId'].toString(),
//         author: types.User(id: msg['SenderId'].toString()),
//         text: msg['Message'],
//       );
//     }).toList();
//   });
// }

//   void _handleSendPressed(types.PartialText message) async {
//     if (message.text.trim().isEmpty || _user == null || _receiverId == null) return;

//     final textMessage = types.TextMessage(
//       author: _user!,
//       createdAt: DateTime.now().toLocal().millisecondsSinceEpoch,
//       id: _uuid.v4(),
//       text: message.text.trim(),
//     );

//     _addMessage(textMessage);
//     await _sendMessage(textMessage);
//   }

//   void _addMessage(types.Message message) {
//     setState(() {
//       _messages.insert(0, message);
//     });
//   }

//   Future<void> _sendMessage(types.TextMessage message) async {
//   if (_currentUserId == null || _receiverId == null) return;

//   await _chatService.sendMessage(
//     chatParticipantId: widget.chatParticipantId,
//     senderId: _currentUserId!,
//     receiverId: _receiverId!,
//     text: message.text,
//   );
// }

//   // Handle message tap (for files or links)
//   void _handleMessageTap(BuildContext _, types.Message message) async {
//     if (message is types.FileMessage) {
//       var localPath = message.uri;

//       if (message.uri.startsWith('http')) {
//         try {
//           final index =
//               _messages.indexWhere((element) => element.id == message.id);
//           final updatedMessage =
//               (_messages[index] as types.FileMessage).copyWith(isLoading: true);

//           setState(() {
//             _messages[index] = updatedMessage;
//           });

//           final client = http.Client();
//           final request = await client.get(Uri.parse(message.uri));
//           final bytes = request.bodyBytes;
//           final documentsDir = (await getApplicationDocumentsDirectory()).path;
//           localPath = '$documentsDir/${message.name}';

//           if (!File(localPath).existsSync()) {
//             final file = File(localPath);
//             await file.writeAsBytes(bytes);
//           }
//         } finally {
//           final index =
//               _messages.indexWhere((element) => element.id == message.id);
//           final updatedMessage =
//               (_messages[index] as types.FileMessage).copyWith(isLoading: null);

//           setState(() {
//             _messages[index] = updatedMessage;
//           });
//         }
//       }
//     }
//   }

//   // Handle preview data (for links shared in chat)
//   void _handlePreviewDataFetched(
//       types.TextMessage message, types.PreviewData previewData) {
//     final index = _messages.indexWhere((element) => element.id == message.id);
//     final updatedMessage = (_messages[index] as types.TextMessage)
//         .copyWith(previewData: previewData);

//     setState(() {
//       _messages[index] = updatedMessage;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       appBar: const Uppernavbar(),
//       drawer: const Sidenav(),
//       body: Stack(
//         children: [
//           const Positioned.fill(child: Background()),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
//               child: _isLoading
//                   ? const Center(child: CircularProgressIndicator(color: Color(0xFF724584)))
//                   : RefreshIndicator(
//                       key: _refreshKey,
//                       onRefresh: _refreshData,
//                       color: Colors.white,
//                       child: Column(
//                         children: [
//                           const SizedBox(height: 8),
//                           Gradienthorizontal(
//                             width: double.infinity,
//                             height: 60,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 20),
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       GestureDetector(
//                                         onTap: () {
//                                           Navigator.pop(context);
//                                         },
//                                         child: const Icon(Icons.arrow_back, color: Color(0xFF00BFFF), size: 36),
//                                       ),
//                                       const SizedBox(width: 12),
//                                       Text(
//                                         _receiverName,
//                                         style: const TextStyle(
//                                           fontFamily: 'Poppins',
//                                           fontWeight: FontWeight.w700,
//                                           fontSize: 18,
//                                           letterSpacing: -0.3,
//                                           color: Colors.white,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           Expanded(
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.05),
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                               child: chat_ui.Chat(
//                                 messages: _messages,
//                                 onMessageTap: _handleMessageTap,
//                                 onPreviewDataFetched: _handlePreviewDataFetched,
//                                 onSendPressed: _handleSendPressed,
//                                 showUserAvatars: false,
//                                 showUserNames: true,
//                                 user: _user!,

//                                 theme: const chat_ui.DefaultChatTheme(
//                                   backgroundColor: Colors.transparent,
//                                   inputBackgroundColor: Color.fromARGB(170, 255, 255, 255),
//                                   inputTextColor: Colors.black,
//                                   primaryColor: Color(0xFFE1F5FE),
//                                   secondaryColor: Color(0xFFF0F0F0),
//                                   sentMessageBodyTextStyle: TextStyle(color: Colors.black87, fontSize: 15),
//                                   receivedMessageBodyTextStyle: TextStyle(color: Colors.black87, fontSize: 15),
//                                   inputBorderRadius: BorderRadius.all(Radius.circular(12)),
//                                   inputTextCursorColor: Colors.black,
//                                   inputTextStyle: TextStyle(fontSize: 16),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//             ),
//           ),
//         ],
//       ),

//     );
//   }
// }

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shiftsmart/models/Message.dart';
// import 'package:shiftsmart/screens/chats/chat_service.dart';
// import 'package:shiftsmart/widgets/uppernavbar.dart';

// class Chatbox extends StatefulWidget {
//   final int chatParticipantId;
//   final int receiverId;
//   final String receiverName;

//   const Chatbox({
//     super.key,
//     required this.chatParticipantId,
//     required this.receiverId,
//     required this.receiverName,
//   });

//   @override
//   State<Chatbox> createState() => _ChatboxState();
// }

// class _ChatboxState extends State<Chatbox> {
//   final ChatService _chatService = ChatService();
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();

//   int _userId = 0;
//   List<Message> _messages = [];
//   bool _isLoading = true;
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     _getUserId();
//     // Auto-refresh messages every 5 seconds
//     _timer =
//         Timer.periodic(const Duration(seconds: 5), (timer) => _fetchMessages());
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   Future<void> _getUserId() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       // Prioritize employeeId, fallback to userId
//       _userId = prefs.getInt('employeeId') ?? prefs.getInt('userId') ?? 0;
//     });
//     // Fetch messages only after we know who "We" are
//     _fetchMessages();
//   }

//   Future<void> _fetchMessages() async {
//     final msgs = await _chatService.fetchMessages(widget.chatParticipantId);
//     if (mounted) {
//       setState(() {
//         _messages = msgs;
//         _isLoading = false;
//       });
//       // Optional: Auto-scroll to bottom on first load could go here
//     }
//   }

//   Future<void> _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;

//     final text = _messageController.text;
//     _messageController.clear();

//     final success = await _chatService.sendMessage(
//       chatParticipantId: widget.chatParticipantId,
//       senderId: _userId,
//       receiverId: widget.receiverId,
//       text: text,
//     );

//     if (success) {
//       _fetchMessages(); // Refresh immediately
//       // Auto-scroll to bottom after sending
//       Future.delayed(const Duration(milliseconds: 300), () {
//         if (_scrollController.hasClients) {
//           _scrollController.animateTo(
//             _scrollController.position.maxScrollExtent,
//             duration: const Duration(milliseconds: 300),
//             curve: Curves.easeOut,
//           );
//         }
//       });
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to send message")),
//       );
//     }
//   }

//   // --- Helper to Format Time (e.g., 10:30 AM) ---
//   String _formatTime(DateTime dt) {
//     final localTime = dt.toLocal();
//     final hour = localTime.hour > 12
//         ? localTime.hour - 12
//         : (localTime.hour == 0 ? 12 : localTime.hour);
//     final minute = localTime.minute.toString().padLeft(2, '0');
//     final period = localTime.hour >= 12 ? 'PM' : 'AM';
//     return "$hour:$minute $period";
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C2230),
//       // Updated Uppernavbar usage (requires the update we did previously)
//       appBar: Uppernavbar(
//         showBackButton: true,
//         title: widget.receiverName,
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: _isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : _messages.isEmpty
//                     ? const Center(
//                         child: Text(
//                           "No messages yet",
//                           style: TextStyle(
//                             color: Colors.white54
//                           ),
//                         )
//                     : ListView.builder(
//                         controller: _scrollController,
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 16, vertical: 10),
//                         itemCount: _messages.length,
//                         itemBuilder: (context, index) {
//                           final msg = _messages[index];

//                           // --- UI LOGIC START ---
//                           // Check if message is mine
//                           final isMe = msg.senderId == _userId;

//                           return Align(
//                             alignment: isMe
//                                 ? Alignment.centerRight
//                                 : Alignment.centerLeft,
//                             child: Container(
//                               margin: const EdgeInsets.symmetric(vertical: 4),
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 16, vertical: 12),
//                               // Limit width so it looks like a bubble
//                               constraints: BoxConstraints(
//                                 maxWidth:
//                                     MediaQuery.of(context).size.width * 0.75,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: isMe
//                                     ? Colors.blueAccent
//                                     : const Color(
//                                         0xFF2A2F45), // Dark grey for receiver
//                                 borderRadius: BorderRadius.only(
//                                   topLeft: const Radius.circular(16),
//                                   topRight: const Radius.circular(16),
//                                   // Tail logic: Square off the bottom corner nearest the sender
//                                   bottomLeft: isMe
//                                       ? const Radius.circular(16)
//                                       : Radius.zero,
//                                   bottomRight: isMe
//                                       ? Radius.zero
//                                       : const Radius.circular(16),
//                                 ),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     msg.text,
//                                     style: const TextStyle(
//                                         color: Colors.white, fontSize: 15),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   // Time Stamp
//                                   Text(
//                                     _formatTime(msg.createdAt),
//                                     style: TextStyle(
//                                       color: isMe
//                                           ? Colors.white70
//                                           : Colors.white38,
//                                       fontSize: 10,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                           // --- UI LOGIC END ---
//                         },
//                       ),
//           ),
//           _buildInputArea(),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputArea() {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       color: const Color(0xFF2A2F45),
//       child: Row(
//         children: [
//           Expanded(
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.black26,
//                 borderRadius: BorderRadius.circular(24),
//               ),
//               child: TextField(
//                 controller: _messageController,
//                 style: const TextStyle(color: Colors.white),
//                 decoration: const InputDecoration(
//                   hintText: "Type a message...",
//                   hintStyle: TextStyle(color: Colors.white54),
//                   border: InputBorder.none,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           CircleAvatar(
//             backgroundColor: Colors.blueAccent,
//             child: IconButton(
//               icon: const Icon(Icons.send, color: Colors.white, size: 20),
//               onPressed: _sendMessage,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
