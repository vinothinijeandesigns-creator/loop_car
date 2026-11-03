import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';

class SettingsHeader extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? vehicle;
  final double? averageRating;
  final int? ratingCount;
  final VoidCallback onProfileUpdated;

  const SettingsHeader({
    super.key,
    this.profile,
    this.vehicle,
    this.averageRating,
    this.ratingCount,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsHeader> createState() => _SettingsHeaderState();
}

class _SettingsHeaderState extends State<SettingsHeader> {
  bool _isUploading = false;

  int _calculateCompleteness() {
    int score = 0;
    
    // 1. Profile Picture
    if (widget.profile?['avatar_url'] != null) score++;
    
    // 2. Personal Details (checking basic fields)
    if (widget.profile?['first_name'] != null && 
        widget.profile?['last_name'] != null && 
        widget.profile?['mobile'] != null) {
      score++;
    }
    
    // 3. Vehicle Details
    if (widget.vehicle != null) score++;
    
    // 4. Communication Preferences (if they set any of them to non-null, meaning they saved it)
    if (widget.profile?['comm_emails'] != null || 
        widget.profile?['comm_push_notifications'] != null || 
        widget.profile?['comm_text_messages'] != null || 
        widget.profile?['comm_phone_calls'] != null) {
      score++;
    }
    
    // 5. Postal Address (if they set at least one address field)
    if (widget.profile?['postal_pincode'] != null || 
        widget.profile?['postal_address_line1'] != null ||
        widget.profile?['postal_full_name'] != null) {
      score++;
    }
    
    return score;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final userId = SupabaseConfig.userId;
      if (userId == null) throw Exception("Not logged in");

      final file = File(image.path);
      final fileExt = image.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload to Supabase Storage
      await SupabaseConfig.client.storage
          .from('avatars')
          .upload(fileName, file, fileOptions: FileOptions(upsert: true));

      // Get public URL
      final imageUrl = SupabaseConfig.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Save to profile
      await SupabaseConfig.client
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);

      // Trigger refresh in parent
      widget.onProfileUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.profile?['first_name'] as String? ?? "User";
    final avatarUrl = widget.profile?['avatar_url'] as String?;
    
    final completedCount = _calculateCompleteness();
    final double progressValue = completedCount / 5;

    return Column(
      children: [
        /// TAG LINE
        const SizedBox(height: 8),
        const Text(
          "Ride, Laugh, Repeat. For Less!",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),

        const SizedBox(height: 16),

        /// MAIN PROFILE CARD
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// PROFILE ROW
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null 
                        ? const Icon(Icons.person, color: Colors.white, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.averageRating != null && widget.averageRating! > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${widget.averageRating!.toStringAsFixed(1)} / 5",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.ratingCount != null)
                                Text(
                                  " • ${widget.ratingCount} ratings",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          )
                        else
                          const Text(
                            "Newcomer",
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right),
                ],
              ),

              const SizedBox(height: 16),

              /// COMPLETE PROFILE SECTION
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F7FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Complete your profile",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      "This helps builds trust, encouraging members to travel with you.",
                      style: TextStyle(fontSize: 13),
                    ),

                    const SizedBox(height: 10),

                    Text("$completedCount out of 5 complete"),

                    const SizedBox(height: 8),

                    LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF00C6D2),
                    ),

                    const SizedBox(height: 6),

                    TextButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadImage,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00C6D2),
                              ),
                            )
                          : const Icon(Icons.add_a_photo, size: 16, color: Color(0xFF00C6D2)),
                      label: Text(
                        _isUploading ? "Uploading..." : "Add profile picture",
                        style: const TextStyle(color: Color(0xFF00C6D2)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}
