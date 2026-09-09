import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoStorageService {
  ProfilePhotoStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<XFile?> pickAndCrop(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2400,
    );
    if (picked == null) return null;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            toolbarColor: const Color(0xFF101820),
            toolbarWidgetColor: const Color(0xFFFFFFFF),
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop profile photo',
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );
    } catch (_) {
      // Some web browsers cannot create the cropper platform view. Keep the
      // selected image usable instead of blocking the profile update.
      return picked;
    }
    if (cropped == null) return null;
    return XFile(cropped.path);
  }

  Future<String> upload({required XFile image, required String userId}) async {
    final ref = _storage.ref('profile_photos/$userId/avatar.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(await image.readAsBytes(), metadata);
    return ref.getDownloadURL();
  }
}
