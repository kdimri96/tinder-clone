import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Form data
  final _bioController = TextEditingController();
  final _jobController = TextEditingController();
  final _schoolController = TextEditingController();
  int? _age;
  String? _gender;
  final List<String> _selectedInterests = [];
  final List<String> _uploadedPhotos = [];

  static const List<String> _genders = ['Man', 'Woman', 'Non-binary', 'Other'];
  static const List<String> _allInterests = [
    'Travel', 'Music', 'Sports', 'Gaming', 'Cooking',
    'Reading', 'Art', 'Movies', 'Fitness', 'Photography',
    'Dancing', 'Nature', 'Fashion', 'Foodie', 'Pets',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _uploadPhoto() async {
    if (_uploadedPhotos.length >= 6) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.uploadPhoto(picked.path);
      context.read<AuthProvider>().updateUser(updatedUser);
      setState(() => _uploadedPhotos.addAll(
        updatedUser.photos.where((p) => !_uploadedPhotos.contains(p)),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndFinish() async {
    if (_age == null) {
      _showError('Please enter your age');
      return;
    }
    if (_gender == null) {
      _showError('Please select your gender');
      return;
    }
    if (_uploadedPhotos.isEmpty) {
      _showError('Please add at least one photo');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.updateProfile({
        'age': _age,
        'gender': _gender!.toLowerCase(),
        'bio': _bioController.text.trim(),
        'job': _jobController.text.trim(),
        'school': _schoolController.text.trim(),
        'interests': _selectedInterests,
        'isProfileComplete': true,
      });
      if (mounted) {
        context.read<AuthProvider>().updateUser(updatedUser);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) _showError('Failed to save profile. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage == 0 && (_age == null || _gender == null)) {
      _showError('Please fill in your age and gender');
      return;
    }
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAndFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildBasicsPage(),
                _buildPhotosPage(),
                _buildAboutPage(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final titles = ['The basics', 'Your photos', 'About you'];
    final subtitles = [
      'Help others know who you are',
      'Show your best self',
      'Share your passions',
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Step ${_currentPage + 1} of 3',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                titles[_currentPage],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitles[_currentPage],
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= _currentPage ? AppTheme.primary : const Color(0xFFE0E0E0),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── PAGE 1: BASICS ─────────────────────────────────────────────

  Widget _buildBasicsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Your Age'),
          const SizedBox(height: 10),
          _AgeSelector(
            value: _age,
            onChanged: (v) => setState(() => _age = v),
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: 'I am a'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _genders.map((g) {
              final selected = _gender == g;
              return GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? AppTheme.primary : const Color(0xFFDEDEDE),
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── PAGE 2: PHOTOS ─────────────────────────────────────────────

  Widget _buildPhotosPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Add photos (min. 1, up to 6)'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: 6,
            itemBuilder: (_, i) {
              final hasPhoto = i < _uploadedPhotos.length;
              return GestureDetector(
                onTap: hasPhoto ? null : _uploadPhoto,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                    image: hasPhoto
                        ? DecorationImage(
                            image: NetworkImage(_uploadedPhotos[i]),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppTheme.primary, size: 32),
                            const SizedBox(height: 6),
                            Text(
                              'Add photo',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ── PAGE 3: ABOUT ──────────────────────────────────────────────

  Widget _buildAboutPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Bio'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Tell others about yourself...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: 'Job (optional)'),
          const SizedBox(height: 10),
          _SimpleTextField(controller: _jobController, hint: 'What do you do?'),
          const SizedBox(height: 20),
          _SectionLabel(label: 'School (optional)'),
          const SizedBox(height: 10),
          _SimpleTextField(controller: _schoolController, hint: 'Where did you study?'),
          const SizedBox(height: 24),
          _SectionLabel(label: 'Interests'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final selected = _selectedInterests.contains(interest);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedInterests.remove(interest);
                    } else if (_selectedInterests.length < 10) {
                      _selectedInterests.add(interest);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.primary : const Color(0xFFDEDEDE),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      color: selected ? AppTheme.primary : Colors.black87,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastPage = _currentPage == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isLastPage ? 'Finish & Find Matches' : 'Continue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ── HELPER WIDGETS ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF333333),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SimpleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SimpleTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AgeSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _AgeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      hint: Text('Select your age', style: TextStyle(color: Colors.grey.shade400)),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      items: List.generate(82, (i) => i + 18).map((age) {
        return DropdownMenuItem(value: age, child: Text('$age years old'));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
