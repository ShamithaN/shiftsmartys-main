import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';

class ProfileAvatar extends StatefulWidget {
  final bool editable;
  final File? initialImage;
  final Function(File)? onImageSelected;

  const ProfileAvatar({
    super.key,
    this.editable = true,
    this.initialImage,
    this.onImageSelected,
  });

  @override
  _ProfileAvatarState createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _selectedImageFile = widget.initialImage;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImageFile = File(image.path); 
      });

      if (widget.onImageSelected != null) {
        widget.onImageSelected!(_selectedImageFile!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = Provider.of<UserProvider>(context, listen: false)
        .userProfile["profilePicture"];

    final avatar = Container(
      width: 100,
      height: 100,
      alignment: Alignment.center,
      child: ClipOval(
        child: _selectedImageFile != null
            ? Image.file(
                _selectedImageFile!,
                fit: BoxFit.cover,
                width: 100,
                height: 100,
              )
            : (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                  )
                : const Icon(Icons.account_circle,
                    size: 100, color: Colors.white),
      ),
    );

    return Stack(
      children: [
        widget.editable
            ? GestureDetector(
                onTap: _pickImage,
                child: avatar,
              )
            : avatar,
        if (widget.editable)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.black54, size: 18),
            ),
          ),
      ],
    );
  }
}
