import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _maxDistance;
  late RangeValues _ageRange;
  late Set<String> _selectedGenders;
  bool _isSaving = false;

  static const List<Map<String, String>> _genderOptions = [
    {'value': 'male', 'label': 'Men'},
    {'value': 'female', 'label': 'Women'},
    {'value': 'other', 'label': 'Non-binary / Other'},
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final prefs = user?.preferences ?? UserPreferences();
    _maxDistance = prefs.maxDistance.clamp(1, 100).toDouble();
    _ageRange = RangeValues(
      prefs.minAge.clamp(18, 80).toDouble(),
      prefs.maxAge.clamp(18, 80).toDouble(),
    );
    _selectedGenders = Set<String>.from(prefs.genderPreference);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final api = context.read<ApiService>();
      final updatedUser = await api.updatePreferences({
        'genderPreference': _selectedGenders.toList(),
        'minAge': _ageRange.start.round(),
        'maxAge': _ageRange.end.round(),
        'maxDistance': _maxDistance.round(),
      });
      if (mounted) {
        context.read<AuthProvider>().updateUser(updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preferences saved!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionCard(
            title: 'Discovery Preferences',
            children: [
              // MAX DISTANCE
              _SettingRow(
                label: 'Maximum Distance',
                value: '${_maxDistance.round()} km',
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accent,
                  inactiveTrackColor: AppTheme.surface2,
                  thumbColor: AppTheme.accent,
                  overlayColor: AppTheme.accent.withOpacity(0.2),
                  valueIndicatorColor: AppTheme.accent,
                  valueIndicatorTextStyle: const TextStyle(color: AppTheme.background),
                ),
                child: Slider(
                  value: _maxDistance,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${_maxDistance.round()} km',
                  onChanged: (v) => setState(() => _maxDistance = v),
                ),
              ),
              const SizedBox(height: 20),

              // AGE RANGE
              _SettingRow(
                label: 'Age Range',
                value: '${_ageRange.start.round()} – ${_ageRange.end.round()}',
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: AppTheme.surface2,
                  thumbColor: AppTheme.primary,
                  overlayColor: AppTheme.primary.withOpacity(0.2),
                  valueIndicatorColor: AppTheme.primary,
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: RangeSlider(
                  values: _ageRange,
                  min: 18,
                  max: 80,
                  divisions: 62,
                  labels: RangeLabels(
                    _ageRange.start.round().toString(),
                    _ageRange.end.round().toString(),
                  ),
                  onChanged: (v) => setState(() => _ageRange = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SectionCard(
            title: 'Show Me',
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _genderOptions.map((option) {
                  final val = option['value']!;
                  final label = option['label']!;
                  final selected = _selectedGenders.contains(val);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          if (_selectedGenders.length > 1) {
                            _selectedGenders.remove(val);
                          }
                        } else {
                          _selectedGenders.add(val);
                        }
                      });
                    },
                    child: selected
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface2,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.surface2),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: AppTheme.textMedium,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
            ],
          ),

          const SizedBox(height: 32),

          // SAVE BUTTON
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save Preferences',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surface2.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;

  const _SettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMedium, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
