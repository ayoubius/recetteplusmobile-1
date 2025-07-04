import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Afficher le sélecteur de source d'image
  static Future<ImageSource?> showImageSourceSelector(
      BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choisir une photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    context,
                    'Caméra',
                    Icons.camera_alt,
                    ImageSource.camera,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(
                    context,
                    'Galerie',
                    Icons.photo_library,
                    ImageSource.gallery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildSourceOption(
    BuildContext context,
    String title,
    IconData icon,
    ImageSource source,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionner et traiter une image
  static Future<Uint8List?> pickImage({
    required ImageSource source,
    int maxWidth = 800,
    int maxHeight = 800,
    int imageQuality = 85,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        // Vérifier la taille du fichier (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          throw Exception('Image trop volumineuse (max 5MB)');
        }

        return bytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la sélection d\'image: $e');
      }
      rethrow;
    }
  }

  /// Uploader un avatar vers Supabase Storage
  static Future<String?> uploadAvatar({
    required Uint8List imageBytes,
    required String userId,
    String? oldAvatarUrl,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Supprimer l'ancien avatar si il existe
      if (oldAvatarUrl != null) {
        try {
          final oldPath = _extractPathFromUrl(oldAvatarUrl);
          if (oldPath != null) {
            await supabase.storage.from('avatars').remove([oldPath]);
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Erreur lors de la suppression de l\'ancien avatar: $e');
          }
        }
      }

      // Générer un nom de fichier unique
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Uploader la nouvelle image
      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Obtenir l'URL publique
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      if (kDebugMode) {
        print('✅ Avatar uploadé avec succès: $publicUrl');
      }

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'upload de l\'avatar: $e');
      }
      rethrow;
    }
  }

  /// Extraire le chemin du fichier depuis une URL Supabase
  static String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Format attendu: /storage/v1/object/public/avatars/filename
      if (pathSegments.length >= 5 && pathSegments[3] == 'avatars') {
        return pathSegments.last;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de l\'extraction du chemin: $e');
      }
      return null;
    }
  }

  /// Supprimer un avatar
  static Future<bool> deleteAvatar(String avatarUrl) async {
    try {
      final supabase = Supabase.instance.client;
      final path = _extractPathFromUrl(avatarUrl);

      if (path != null) {
        await supabase.storage.from('avatars').remove([path]);

        if (kDebugMode) {
          print('✅ Avatar supprimé avec succès: $path');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur lors de la suppression de l\'avatar: $e');
      }
      return false;
    }
  }
}
