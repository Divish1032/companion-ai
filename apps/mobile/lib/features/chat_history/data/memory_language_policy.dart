/// Versioned, language-scoped rules for exact phone-owned memory.
///
/// The registry is intentionally local and source controlled. Unsupported
/// languages fail closed: they may answer normally but cannot create durable
/// profile or relationship claims until a reviewed policy is added.
class MemoryLanguagePolicy {
  const MemoryLanguagePolicy({
    required this.languageTag,
    required this.version,
    required this.supportsDurableExactClaims,
    required this.questionMarkers,
    required this.confirmationMarkers,
    required this.rejectionMarkers,
    required this.greetings,
    required this.correctionMarkers,
    required this.sensitiveMarkers,
    required this.invalidPersonValues,
    required this.languageValues,
    required this.namePatterns,
    required this.relationshipPatterns,
    required this.goalPatterns,
    required this.workMarkers,
    required this.relationshipMarkers,
    required this.preferenceMarkers,
    required this.shortResponseMarkers,
    required this.comfortStyleMarkers,
    required this.morningWalkMarkers,
    required this.politicsBoundaryMarkers,
  });

  final String languageTag;
  final int version;
  final bool supportsDurableExactClaims;
  final List<String> questionMarkers;
  final List<String> confirmationMarkers;
  final List<String> rejectionMarkers;
  final Set<String> greetings;
  final List<String> correctionMarkers;
  final List<String> sensitiveMarkers;
  final Set<String> invalidPersonValues;
  final Map<String, String> languageValues;
  final List<RegExp> namePatterns;
  final List<RegExp> relationshipPatterns;
  final List<RegExp> goalPatterns;
  final List<String> workMarkers;
  final List<String> relationshipMarkers;
  final List<String> preferenceMarkers;
  final List<String> shortResponseMarkers;
  final List<String> comfortStyleMarkers;
  final List<String> morningWalkMarkers;
  final List<String> politicsBoundaryMarkers;

  bool containsAny(String text, Iterable<String> values) =>
      values.any(text.contains);

  bool isQuestion(String text) => containsAny(text, questionMarkers);

  bool isValidPersonValue(String value) {
    final normalized = normalize(value);
    return normalized.length >= 2 &&
        !invalidPersonValues.contains(normalized) &&
        !isQuestion(normalized);
  }

  String normalize(String value) => value
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase()
      .replaceAll('हिन्दी', 'हिंदी');
}

class MemoryLanguagePolicyRegistry {
  static const fallback = MemoryLanguagePolicy(
    languageTag: 'und',
    version: 1,
    supportsDurableExactClaims: false,
    questionMarkers: ['?'],
    confirmationMarkers: [],
    rejectionMarkers: [],
    greetings: {},
    correctionMarkers: [],
    sensitiveMarkers: [],
    invalidPersonValues: {},
    languageValues: {},
    namePatterns: [],
    relationshipPatterns: [],
    goalPatterns: [],
    workMarkers: [],
    relationshipMarkers: [],
    preferenceMarkers: [],
    shortResponseMarkers: [],
    comfortStyleMarkers: [],
    morningWalkMarkers: [],
    politicsBoundaryMarkers: [],
  );

  static final hiIN = MemoryLanguagePolicy(
    languageTag: 'hi-IN',
    version: 1,
    supportsDurableExactClaims: true,
    // `के है` is an observed Vosk rendering of Hindi `क्या है` in name
    // questions. It must be interpreted as a question, never a person name.
    questionMarkers: const [
      '?',
      'क्या',
      'कौन',
      'कैसे',
      'किस',
      'के है',
      'kya',
      'kaun',
      'kaise',
      'kis',
      'yaad hai',
      'remember',
    ],
    confirmationMarkers: const [
      'हाँ',
      'हां',
      'haan',
      'ha',
      'yes',
      'याद रखना',
      'yaad rakh',
      'confirm',
    ],
    rejectionMarkers: const [
      'नहीं याद',
      'मत याद',
      'nahin',
      'nahi',
      'no',
      'reject',
    ],
    greetings: const {'नमस्ते', 'hi', 'hello', 'hey', 'haan', 'हाँ'},
    correctionMarkers: const [
      'असल में',
      'नहीं',
      'गलत',
      'actually',
      'nahi',
      'nahin',
      'correction',
      'instead',
    ],
    sensitiveMarkers: const [
      'आत्महत्या',
      'मर जाना',
      'खुद को मार',
      'suicide',
      'medical',
      'medical advice',
      'medicine',
      'दवा',
      'डॉक्टर',
      'doctor',
      'कानूनी',
      'legal',
      'वकील',
      'lawyer',
      'loan',
      'investment',
      'financial',
      'sexual',
      'नशा',
      'addiction',
      'drugs',
      'सिर्फ तुम',
      'तुम्हारे बिना',
    ],
    invalidPersonValues: const {
      'के',
      'क्या',
      'गिनाए',
      'है',
      'नाम',
      'का',
      'की',
      'को',
      'से',
      'और',
    },
    languageValues: const {
      'हिंदी': 'Hindi',
      'hindi': 'Hindi',
      'इंग्लिश': 'English',
      'english': 'English',
      'hinglish': 'Hinglish',
    },
    namePatterns: [
      RegExp(
        r'(?:मेरा|meri|mera|my) नाम\s+([a-z\u0900-\u097f]{2,32})(?:\s+(?:है|hai))?',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:my name is)\s+([a-z\u0900-\u097f]{2,32})',
        caseSensitive: false,
      ),
    ],
    relationshipPatterns: [
      RegExp(
        r'(?:मेरा|मेरी|मेरे)\s+(भाई|बहन)\s+का\s+नाम\s+([a-z\u0900-\u097f]{2,32})(?:\s+है)?',
        caseSensitive: false,
      ),
      RegExp(
        r'my\s+(brother|sister)\s+(?:name is|is)\s+([a-z\u0900-\u097f]{2,32})',
        caseSensitive: false,
      ),
      // Observed Vosk rendering of "मेरे भाई का नाम रोहन है". The final
      // copula keeps this assertion-only; question variants are routed before
      // claim extraction by [questionMarkers].
      RegExp(
        r'मैंने\s+(भाई|बहन)\s+का\s+नाम\s+([a-z\u0900-\u097f]{2,32})\s+है',
        caseSensitive: false,
      ),
    ],
    goalPatterns: [RegExp(r'(?:मेरा|मेरी) लक्ष्य\s+(.{2,80}?)\s+(?:है|हैं)')],
    workMarkers: const ['office', 'काम', 'ऑफिस', 'work', 'manager'],
    relationshipMarkers: const ['भाई', 'बहन', 'brother', 'sister'],
    preferenceMarkers: const [
      'पसंद',
      'prefer',
      'केवल',
      'सिर्फ',
      'only',
      'जवाब',
      'उत्तर',
      'reply',
      'answer',
    ],
    shortResponseMarkers: const [
      'छोटे जवाब',
      'छोटा जवाब',
      'बहुत लंबे नहीं',
      'short replies',
      'short reply',
    ],
    comfortStyleMarkers: const [
      'सलाह देने से पहले',
      'advice se pehle',
      'listen first',
    ],
    morningWalkMarkers: const [
      'रोज सुबह टहल',
      'हर सुबह टहल',
      'daily morning walk',
    ],
    politicsBoundaryMarkers: const [
      'राजनीति पर बात नहीं',
      'politics par baat nahi',
    ],
  );

  static MemoryLanguagePolicy forLanguage(String languageTag) {
    final normalized = languageTag.trim().toLowerCase();
    return normalized == 'hi-in' || normalized == 'hi' ? hiIN : fallback;
  }
}
