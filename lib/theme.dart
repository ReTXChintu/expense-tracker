import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _accent = Color(0xFF4361EE);
const _accentDark = Color(0xFF6380FF);

/// Design tokens for spacing and radii.
class AppSpacing {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const card = 16.0;
  static const sheet = 20.0;
  static const chip = 99.0;
}

class AppShadows {
  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> elevated(bool isDark) => [
        BoxShadow(
          color: _accent.withValues(alpha: isDark ? 0.2 : 0.15),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Subtle scaffold gradient for depth.
class AppScaffoldBackground extends StatelessWidget {
  final Widget child;
  const AppScaffoldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF14142A), base]
              : [const Color(0xFFEEF1FF), base],
          stops: const [0.0, 0.45],
        ),
      ),
      child: child,
    );
  }
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: brightness == Brightness.light
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF0F0F8),
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.light
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF0F0F8),
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: brightness == Brightness.light
            ? const Color(0xFF1A1A2E)
            : const Color(0xFFF0F0F8),
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: brightness == Brightness.light
            ? const Color(0xFF555566)
            : const Color(0xFFAAAAAC),
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: brightness == Brightness.light
            ? const Color(0xFF888899)
            : const Color(0xFF666677),
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: brightness == Brightness.light
            ? const Color(0xFF888899)
            : const Color(0xFF666677),
      ),
    );
  }

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        textTheme: _textTheme(Brightness.light),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF5F6FA),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: _accent.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _accent : const Color(0xFF999999),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _accent : const Color(0xFF999999),
            );
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEF4),
          thickness: 1,
          space: 0,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accentDark,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F18),
        textTheme: _textTheme(Brightness.dark),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A28),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F0F18),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF0F0F8),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Color(0xFFF0F0F8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _accentDark,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A28),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A3A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A2A3A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accentDark, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFF555566)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A28),
          indicatorColor: _accentDark.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _accentDark : const Color(0xFF555566),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _accentDark : const Color(0xFF555566),
            );
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1E1E2E),
          thickness: 1,
          space: 0,
        ),
      );
}

// Colors accessible across screens
class AC {
  static const accent = _accent;
  static const accentDark = _accentDark;
  static const debit = Color(0xFFE53935);
  static const credit = Color(0xFF43A047);
  static const smsColor = Color(0xFF8B5CF6);
  static const gmailColor = Color(0xFFEA4335);
  static const manualColor = Color(0xFF0EA5E9);
  static const uncategorized = Color(0xFFF59E0B);
}
