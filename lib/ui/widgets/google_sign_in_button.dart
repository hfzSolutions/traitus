import 'package:flutter/material.dart';

/// Google Sign-In button that follows Google's branding guidelines
/// 
/// According to Google's Identity Guidelines:
/// - White background (#FFFFFF)
/// - Gray border (#DADCE0)
/// - Official Google logo (18x18px minimum)
/// - Proper spacing and padding
/// - Text: "Sign in with Google" or "Continue with Google"
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Google's official colors
    final backgroundColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0);
    final textColor = isDark ? Colors.white : const Color(0xFF3C4043);
    
    return SizedBox(
      width: double.infinity,
      height: 48, // Google's recommended minimum height
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Matches app's standard button border radius
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Google logo - try to load from assets, fallback to SVG-like icon
            _buildGoogleLogo(),
            const SizedBox(width: 12), // Spacing between logo and text
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.25,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    // Try to load Google logo from assets
    return Image.asset(
      'assets/google_logo.png',
      width: 18,
      height: 18,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: Create a simple Google "G" icon
        // This is a temporary fallback - you should add the official Google logo
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4), // Google blue
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Center(
            child: Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

