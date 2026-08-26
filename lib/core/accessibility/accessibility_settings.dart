import 'package:flutter/material.dart';

/// Immutable accessibility preferences applied throughout the app.
@immutable
class AccessibilitySettings {
  /// Creates a complete accessibility preference set.
  const AccessibilitySettings({
    this.largeFonts = false,
    this.dyslexiaFont = false,
    this.highContrast = false,
    this.darkMode = false,
    this.reducedMotion = false,
    this.voiceNavigation = false,
    this.textToSpeech = false,
    this.largeButtons = false,
    this.closedCaptions = true,
  });

  final bool largeFonts;
  final bool dyslexiaFont;
  final bool highContrast;
  final bool darkMode;
  final bool reducedMotion;
  final bool voiceNavigation;
  final bool textToSpeech;
  final bool largeButtons;
  final bool closedCaptions;

  /// Returns a copy with selected values replaced.
  AccessibilitySettings copyWith({
    bool? largeFonts,
    bool? dyslexiaFont,
    bool? highContrast,
    bool? darkMode,
    bool? reducedMotion,
    bool? voiceNavigation,
    bool? textToSpeech,
    bool? largeButtons,
    bool? closedCaptions,
  }) => AccessibilitySettings(
    largeFonts: largeFonts ?? this.largeFonts,
    dyslexiaFont: dyslexiaFont ?? this.dyslexiaFont,
    highContrast: highContrast ?? this.highContrast,
    darkMode: darkMode ?? this.darkMode,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    voiceNavigation: voiceNavigation ?? this.voiceNavigation,
    textToSpeech: textToSpeech ?? this.textToSpeech,
    largeButtons: largeButtons ?? this.largeButtons,
    closedCaptions: closedCaptions ?? this.closedCaptions,
  );

  /// Serializes settings for offline persistence.
  Map<String, dynamic> toJson() => {
    'largeFonts': largeFonts,
    'dyslexiaFont': dyslexiaFont,
    'highContrast': highContrast,
    'darkMode': darkMode,
    'reducedMotion': reducedMotion,
    'voiceNavigation': voiceNavigation,
    'textToSpeech': textToSpeech,
    'largeButtons': largeButtons,
    'closedCaptions': closedCaptions,
  };

  /// Deserializes stored settings.
  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      AccessibilitySettings(
        largeFonts: json['largeFonts'] as bool? ?? false,
        dyslexiaFont: json['dyslexiaFont'] as bool? ?? false,
        highContrast: json['highContrast'] as bool? ?? false,
        darkMode: json['darkMode'] as bool? ?? false,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        voiceNavigation: json['voiceNavigation'] as bool? ?? false,
        textToSpeech: json['textToSpeech'] as bool? ?? false,
        largeButtons: json['largeButtons'] as bool? ?? false,
        closedCaptions: json['closedCaptions'] as bool? ?? false,
      );
}
