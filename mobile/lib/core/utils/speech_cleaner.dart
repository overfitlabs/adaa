/// Utility for cleaning and formatting AI assistant responses
/// into natural, human-like speech suitable for Text-to-Speech engines.
class SpeechCleaner {
  /// Transforms markdown-rich text into clean, spoken prose:
  /// - Strips parenthesized or raw UUIDs
  /// - Removes markdown styling (bold, italics, headers, code)
  /// - Converts lists and bullets into natural speech pauses
  /// - Removes decorative emojis that read awkwardly aloud
  /// - Normalizes spaces and punctuation for natural TTS prosody
  static String cleanForSpeech(String rawText) {
    if (rawText.isEmpty) {
      return '';
    }

    var text = rawText;

    // 1. Remove parenthesized or bracketed UUIDs (e.g. (401c6f94-e359-4b02-...))
    text = text.replaceAll(
      RegExp(r'\s*[\(\[]\s*[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\s*[\)\]]'),
      '',
    );

    // 2. Remove any remaining raw UUID patterns
    text = text.replaceAll(
      RegExp(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'),
      'garment',
    );

    // 3. Remove code blocks ```...``` and inline code `...`
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // 4. Convert markdown links [title](url) -> title
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // 5. Clean markdown headers (e.g. "### Header" -> "Header")
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '');

    // 6. Strip bold and italic delimiters (**bold** -> bold, *italic* -> italic)
    text = text.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'__([^_]+)__'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'_([^_]+)_'),
      (match) => match.group(1) ?? '',
    );

    // 7. Format numbered lists: "1. ", "2. " -> "1, ", "2, " with brief audio pauses
    text = text.replaceAllMapped(
      RegExp(r'^\s*(\d+)\.\s+', multiLine: true),
      (match) => '${match.group(1)}, ',
    );

    // 8. Bullet points: "- ", "* ", "• " -> comma pause
    text = text.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), ', ');

    // 9. Remove decorative emojis that sound awkward when vocalized (e.g. 💅, 😭, ✨, etc.)
    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );

    // 10. Normalize whitespace, multiple commas, and clean punctuation
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    text = text.replaceAll(RegExp(r'\.\s*,'), '.');
    text = text.replaceAll(RegExp(r',\s*,'), ',');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }
}
