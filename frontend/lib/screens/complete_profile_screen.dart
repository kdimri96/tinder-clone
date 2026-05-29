import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/api_error.dart';
import '../utils/app_config.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';
import '../utils/app_colors.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({Key? key}) : super(key: key);

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  final _bioController = TextEditingController();
  final _jobController = TextEditingController();
  final _schoolController = TextEditingController();
  int? _age;
  String? _gender;
  RangeValues _agePreference = const RangeValues(18, 40);
  final List<String> _selectedInterests = [];
  final List<String> _uploadedPhotos = [];

  static const List<String> _genders = ['Man', 'Woman', 'Non-binary', 'Other'];
  static const Map<String, String> _genderValues = {
    'Man': 'male',
    'Woman': 'female',
    'Non-binary': 'other',
    'Other': 'other',
  };

  String? _interestedIn; // 'Women', 'Men', 'Everyone'
  static const Map<String, List<String>> _preferenceValues = {
    'Women': ['female'],
    'Men': ['male'],
    'Everyone': ['male', 'female', 'other'],
  };
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
      final updatedUser = await api.uploadPhoto(picked);
      context.read<AuthProvider>().updateUser(updatedUser);
      setState(() => _uploadedPhotos.addAll(
        updatedUser.photos.where((p) => !_uploadedPhotos.contains(p)),
      ));
    } catch (e) {
      if (mounted) AppNotification.error(context, extractApiError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndFinish() async {
    if (_age == null) { _showError('Please enter your age'); return; }
    if (_gender == null) { _showError('Please select your gender'); return; }
    if (_interestedIn == null) { _showError('Please select who you are interested in'); return; }
    if (_uploadedPhotos.isEmpty) { _showError('Please add at least one photo'); return; }

    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.updateProfile({
        'age': _age,
        'gender': _genderValues[_gender!] ?? 'other',
        'bio': _bioController.text.trim(),
        'job': _jobController.text.trim(),
        'school': _schoolController.text.trim(),
        'interests': _selectedInterests,
        'preferences': {
          'genderPreference': _preferenceValues[_interestedIn!] ?? ['male', 'female', 'other'],
          'minAge': _agePreference.start.round(),
          'maxAge': _agePreference.end.round(),
        },
        'isProfileComplete': true,
      });
      if (mounted) {
        context.read<AuthProvider>().updateUser(updatedUser);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) _showError(extractApiError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    AppNotification.error(context, msg);
  }

  void _nextPage() {
    if (_currentPage == 0 && (_age == null || _gender == null || _interestedIn == null)) {
      _showError('Please fill in your age, gender and preference');
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
      backgroundColor: AppColors.of(context).background,
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
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
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
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Center(
                      child: Text('K',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                  ),
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
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= _currentPage ? AppTheme.primary : AppColors.of(context).surface2,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Your Age'),
          const SizedBox(height: 10),
          _AgeSelector(value: _age, onChanged: (v) => setState(() => _age = v)),
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
                    gradient: selected
                        ? LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: selected ? null : AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppColors.of(context).surface2,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.of(context).textMedium,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: 'I am interested in'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Women', 'Men', 'Everyone'].map((option) {
              final selected = _interestedIn == option;
              return GestureDetector(
                onTap: () => setState(() => _interestedIn = option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: selected ? null : AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppColors.of(context).surface2,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.of(context).textMedium,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(label: 'Age Preference'),
              Text(
                '${_agePreference.start.round()} – ${_agePreference.end.round()} yrs',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppColors.of(context).surface2,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.2),
              valueIndicatorColor: AppTheme.primary,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: RangeSlider(
              values: _agePreference,
              min: 18,
              max: 60,
              divisions: 42,
              labels: RangeLabels(
                _agePreference.start.round().toString(),
                _agePreference.end.round().toString(),
              ),
              onChanged: (v) => setState(() => _agePreference = v),
            ),
          ),
        ],
      ),
    );
  }

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
                    color: AppColors.of(context).surface,
                    border: Border.all(color: AppColors.of(context).surface2),
                    image: hasPhoto
                        ? DecorationImage(
                            image: NetworkImage(
                              _uploadedPhotos[i].startsWith('http')
                                  ? _uploadedPhotos[i]
                                  : '${AppConfig.mediaBaseUrl}${_uploadedPhotos[i]}',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto
                      ? null
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 32),
                            const SizedBox(height: 6),
                            Text('Add photo',
                                style: TextStyle(
                                    color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
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
            style: TextStyle(fontSize: 15, color: AppColors.of(context).textDark),
            decoration: InputDecoration(
              hintText: 'Tell others about yourself...',
              hintStyle: TextStyle(color: AppColors.of(context).textLight),
              filled: true,
              fillColor: AppColors.of(context).surface,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.of(context).surface2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.of(context).surface2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
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
                    color: selected ? AppTheme.primary.withOpacity(0.15) : AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppColors.of(context).surface2,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      color: selected ? AppTheme.primary : AppColors.of(context).textMedium,
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
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        border: Border(top: BorderSide(color: AppColors.of(context).surface2)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: _isSaving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    isLastPage ? 'Finish & Find Matches' : 'Continue',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).textMedium,
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
      style: TextStyle(fontSize: 15, color: AppColors.of(context).textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.of(context).textLight),
        filled: true,
        fillColor: AppColors.of(context).surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.of(context).surface2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.of(context).surface2),
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
      dropdownColor: AppColors.of(context).surface,
      hint: Text('Select your age', style: TextStyle(color: AppColors.of(context).textLight)),
      style: TextStyle(color: AppColors.of(context).textDark, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.of(context).surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.of(context).surface2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.of(context).surface2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
      items: List.generate(82, (i) => i + 18).map((age) {
        return DropdownMenuItem(value: age, child: Text('$age years old'));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
