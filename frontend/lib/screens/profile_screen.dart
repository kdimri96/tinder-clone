import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../widgets/network_image_widget.dart';
import '../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bioController;
  late TextEditingController _jobController;
  late TextEditingController _schoolController;
  late TextEditingController _ageController;
  String? _selectedGender;
  List<String> _interests = [];
  bool _isSaving = false;

  static const _interestOptions = [
    'Travel', 'Music', 'Sports', 'Gaming', 'Cooking', 'Reading',
    'Art', 'Movies', 'Fitness', 'Photography', 'Dancing', 'Nature',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _bioController = TextEditingController(text: user?.bio ?? '');
    _jobController = TextEditingController(text: user?.job ?? '');
    _schoolController = TextEditingController(text: user?.school ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    _selectedGender = user?.gender;
    _interests = List.from(user?.interests ?? []);
  }

  @override
  void dispose() {
    _bioController.dispose();
    _jobController.dispose();
    _schoolController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.uploadPhoto(picked);
      context.read<AuthProvider>().updateUser(updatedUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deletePhoto(String photoUrl) async {
    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.deletePhoto(photoUrl);
      context.read<AuthProvider>().updateUser(updatedUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.updateProfile({
        'bio': _bioController.text.trim(),
        'job': _jobController.text.trim(),
        'school': _schoolController.text.trim(),
        'age': int.tryParse(_ageController.text),
        'gender': _selectedGender,
        'interests': _interests,
      });
      context.read<AuthProvider>().updateUser(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo grid
            _buildPhotoGrid(user),
            const SizedBox(height: 24),

            // Name (read-only)
            _SectionTitle('About ${user.name}'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
              validator: (v) {
                final age = int.tryParse(v ?? '');
                if (age == null || age < 18 || age > 100) return 'Enter valid age (18-100)';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Gender
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline)),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.edit_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _jobController,
              decoration: const InputDecoration(labelText: 'Job', prefixIcon: Icon(Icons.work_outline)),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _schoolController,
              decoration: const InputDecoration(labelText: 'School', prefixIcon: Icon(Icons.school_outlined)),
            ),
            const SizedBox(height: 24),

            _SectionTitle('Interests'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interestOptions.map((interest) {
                final selected = _interests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: selected,
                  selectedColor: AppTheme.primary.withOpacity(0.15),
                  checkmarkColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textMedium,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _interests.add(interest);
                      } else {
                        _interests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(UserModel user) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        if (index < user.photos.length) {
          return GestureDetector(
            onLongPress: () => _showDeletePhotoDialog(user.photos[index]),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImageWidget(
                  imageUrl: user.photos[index],
                  borderRadius: BorderRadius.circular(12),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deletePhoto(user.photos[index]),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        // Empty slot
        return GestureDetector(
          onTap: _pickAndUploadPhoto,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: Icon(Icons.add, color: AppTheme.primary, size: 32),
          ),
        );
      },
    );
  }

  void _showDeletePhotoDialog(String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from your profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(photoUrl);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }
}
