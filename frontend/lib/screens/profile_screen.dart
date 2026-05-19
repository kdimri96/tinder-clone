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
          const SnackBar(
            content: Text('Profile saved!'),
            backgroundColor: AppTheme.success,
          ),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
          ).createShader(bounds),
          child: const Text('Profile',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textMedium),
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
            _buildPhotoGrid(user),
            const SizedBox(height: 28),
            _SectionTitle('About ${user.name}'),
            const SizedBox(height: 14),
            _darkField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                final age = int.tryParse(v ?? '');
                if (age == null || age < 18 || age > 100) return 'Enter valid age (18-100)';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              dropdownColor: AppTheme.surface,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 15),
              decoration: _inputDecoration('Gender', Icons.person_outline),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 12),
            _darkField(
              controller: _bioController,
              label: 'Bio',
              icon: Icons.edit_outlined,
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 12),
            _darkField(
              controller: _jobController,
              label: 'Job',
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 12),
            _darkField(
              controller: _schoolController,
              label: 'School',
              icon: Icons.school_outlined,
            ),
            const SizedBox(height: 28),
            _SectionTitle('Interests'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interestOptions.map((interest) {
                final selected = _interests.contains(interest);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _interests.remove(interest);
                    } else {
                      _interests.add(interest);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.surface2,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: selected ? AppTheme.primary : AppTheme.textMedium,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppTheme.textDark, fontSize: 15),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textMedium),
      prefixIcon: Icon(icon, color: AppTheme.textMedium, size: 20),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.surface2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.surface2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error),
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
          return Stack(
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
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }
        return GestureDetector(
          onTap: _pickAndUploadPhoto,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surface2),
            ),
            child: const Icon(Icons.add, color: AppTheme.primary, size: 32),
          ),
        );
      },
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
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    );
  }
}
