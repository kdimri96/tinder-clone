import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_colors.dart';

class LikeCommentSheet extends StatefulWidget {
  final String userName;
  final String sectionLabel;

  const LikeCommentSheet({
    Key? key,
    required this.userName,
    required this.sectionLabel,
  }) : super(key: key);

  /// Returns the comment text (possibly empty) when sent, or null if dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String userName,
    required String sectionLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LikeCommentSheet(
        userName: userName,
        sectionLabel: sectionLabel,
      ),
    );
  }

  @override
  State<LikeCommentSheet> createState() => _LikeCommentSheetState();
}

class _LikeCommentSheetState extends State<LikeCommentSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() => Navigator.of(context).pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Heart + label
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                  child: Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.of(context).textDark,
                      ),
                      children: [
                        TextSpan(text: 'Like ${widget.userName}'),
                        TextSpan(
                          text: "'s ",
                          style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.of(context).textMedium),
                        ),
                        TextSpan(text: widget.sectionLabel),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'Say something to stand out — or just send the like.',
              style: TextStyle(color: AppColors.of(context).textMedium, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Comment field
            Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.of(context).surface2),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                maxLines: 3,
                minLines: 2,
                maxLength: 200,
                style: TextStyle(color: AppColors.of(context).textDark, fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Add a comment (optional)…',
                  hintStyle: TextStyle(color: AppColors.of(context).textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  counterStyle: TextStyle(color: AppColors.of(context).textLight, fontSize: 11),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Send button
            GestureDetector(
              onTap: _send,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Send Like',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
