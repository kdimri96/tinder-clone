import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../providers/discovery_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_notification.dart';
import '../utils/app_colors.dart';

void showReportBottomSheet(BuildContext context, UserModel user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportBottomSheet(user: user),
  );
}

class _ReportBottomSheet extends StatefulWidget {
  final UserModel user;
  const _ReportBottomSheet({required this.user});

  @override
  State<_ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<_ReportBottomSheet> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  static const List<Map<String, String>> _reasons = [
    {'value': 'inappropriate', 'label': 'Inappropriate Content'},
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'fake', 'label': 'Fake Profile'},
    {'value': 'harassment', 'label': 'Harassment'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      AppNotification.error(context, 'Please select a reason');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final api = context.read<ApiService>();
      await api.reportUser(
        widget.user.id,
        _selectedReason!,
        details: _detailsController.text.trim(),
      );
      if (mounted) {
        context.read<DiscoveryProvider>().removeUserById(widget.user.id);
        Navigator.pop(context);
        AppNotification.success(context, '${widget.user.name} has been reported and blocked.');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _blockOnly() async {
    setState(() => _isSubmitting = true);
    try {
      final api = context.read<ApiService>();
      await api.blockUser(widget.user.id);
      if (mounted) {
        context.read<DiscoveryProvider>().removeUserById(widget.user.id);
        Navigator.pop(context);
        AppNotification.success(context, '${widget.user.name} has been blocked.');
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.of(context).surface2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Report ${widget.user.name}',
            style: TextStyle(
              color: AppColors.of(context).textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Help us understand what\'s happening.',
            style: TextStyle(color: AppColors.of(context).textMedium, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Reason chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) {
              final val = r['value']!;
              final label = r['label']!;
              final selected = _selectedReason == val;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = val),
                child: selected
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.of(context).surface2,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.of(context).textMedium,
                            fontSize: 13,
                          ),
                        ),
                      ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Optional details
          TextField(
            controller: _detailsController,
            maxLines: 3,
            style: TextStyle(color: AppColors.of(context).textDark, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(color: AppColors.of(context).textLight),
              filled: true,
              fillColor: AppColors.of(context).surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 20),

          // Report & Block button
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Report & Block',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // Just Block button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _blockOnly,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.of(context).textMedium,
                side: BorderSide(color: AppColors.of(context).surface2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text(
                'Just Block',
                style: TextStyle(
                  color: AppColors.of(context).textMedium,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
