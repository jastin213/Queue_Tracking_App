enum DocumentReviewCheckState { passed, warning, unavailable }

class DocumentReviewCheck {
  const DocumentReviewCheck({
    required this.title,
    required this.detail,
    required this.state,
  });

  final String title;
  final String detail;
  final DocumentReviewCheckState state;
}

class DocumentReviewResult {
  const DocumentReviewResult({
    required this.score,
    required this.title,
    required this.summary,
    required this.checks,
  });

  final int score;
  final String title;
  final String summary;
  final List<DocumentReviewCheck> checks;
}

class DocumentReviewAnalyzer {
  static const _idMarkers = <String>[
    'DRIVER LICENSE',
    'DRIVERS LICENSE',
    'DRIVER S LICENSE',
    'DRIVING LICENSE',
    'PHILSYS',
    'PHILIPPINE IDENTIFICATION',
    'PHILIPPINE IDENTIFICATION CARD',
    'NATIONAL ID',
    'PASSPORT',
    'PHILIPPINE PASSPORT',
    'UNIFIED MULTI PURPOSE ID',
    'UMID',
    'POSTAL ID',
    'PROFESSIONAL REGULATION COMMISSION',
    'PHILHEALTH',
    'SOCIAL SECURITY SYSTEM',
    'SSS ID',
    'GOVERNMENT SERVICE INSURANCE SYSTEM',
    'GSIS',
    'VOTER S ID',
    'SENIOR CITIZEN ID',
    'PWD ID',
    'TIN ID',
  ];

  static DocumentReviewResult analyze({
    required String customerName,
    required String enteredPlate,
    required String idText,
    required String orText,
    required String crText,
    Map<String, String> errors = const {},
  }) {
    final checks = <DocumentReviewCheck>[];
    var score = 0;

    final idReadable = _addDocumentTypeCheck(
      checks: checks,
      label: 'Valid ID',
      text: idText,
      error: errors['ID'],
      markers: _idMarkers,
      supportingMarkers: const [
        'SURNAME',
        'GIVEN NAME',
        'DATE OF BIRTH',
        'BIRTH DATE',
        'LICENSE NO',
        'IDENTIFICATION NO',
        'ADDRESS',
      ],
      markerDescription: 'a supported government ID label',
    );
    if (idReadable) score += 10;

    final orReadable = _addDocumentTypeCheck(
      checks: checks,
      label: 'Official Receipt (OR)',
      text: orText,
      error: errors['OR'],
      markers: const ['OFFICIAL RECEIPT'],
      supportingMarkers: const [
        'OR NO',
        'AMOUNT PAID',
        'TOTAL AMOUNT',
        'TRANSACTION DATE',
        'DATE OF PAYMENT',
        'PAYMENT',
        'FEE',
      ],
      markerDescription: 'the Official Receipt label',
    );
    if (orReadable) score += 10;

    final crReadable = _addDocumentTypeCheck(
      checks: checks,
      label: 'Certificate of Registration (CR)',
      text: crText,
      error: errors['CR'],
      markers: const [
        'CERTIFICATE OF REGISTRATION',
        'CERTIFICATE REGISTRATION',
      ],
      supportingMarkers: const [
        'CHASSIS NO',
        'ENGINE NO',
        'MV FILE NO',
        'YEAR MODEL',
        'BODY TYPE',
        'MAKE',
        'COLOR',
      ],
      markerDescription: 'the Certificate of Registration label',
    );
    if (crReadable) score += 10;

    final nameMatch = _nameAppearsInText(customerName, idText);
    if (errors['ID'] != null || idText.trim().isEmpty) {
      checks.add(
        const DocumentReviewCheck(
          title: 'Customer name on ID',
          detail: 'Not checked because readable ID text was unavailable.',
          state: DocumentReviewCheckState.unavailable,
        ),
      );
    } else if (nameMatch) {
      score += 25;
      checks.add(
        DocumentReviewCheck(
          title: 'Customer name on ID',
          detail: 'The OCR text contains the registered name: $customerName.',
          state: DocumentReviewCheckState.passed,
        ),
      );
    } else {
      checks.add(
        DocumentReviewCheck(
          title: 'Customer name on ID',
          detail:
              'The registered name "$customerName" was not confidently found. '
              'Check spelling and inspect the ID manually.',
          state: DocumentReviewCheckState.warning,
        ),
      );
    }

    final orPlateMatch = _plateAppearsInText(enteredPlate, orText);
    _addPlateCheck(
      checks: checks,
      label: 'Plate number on OR',
      plate: enteredPlate,
      matched: orPlateMatch,
      text: orText,
      error: errors['OR'],
    );
    if (orPlateMatch) score += 20;

    final crPlateMatch = _plateAppearsInText(enteredPlate, crText);
    _addPlateCheck(
      checks: checks,
      label: 'Plate number on CR',
      plate: enteredPlate,
      matched: crPlateMatch,
      text: crText,
      error: errors['CR'],
    );
    if (crPlateMatch) score += 20;

    final criticalMatches = nameMatch && orPlateMatch && crPlateMatch;
    final allDocumentTypesConfirmed = idReadable && orReadable && crReadable;
    final coherentEvidence =
        nameMatch &&
        (orPlateMatch || crPlateMatch) &&
        allDocumentTypesConfirmed;
    if (coherentEvidence && errors.isEmpty) {
      score += 5;
    }

    if (score >= 85 &&
        criticalMatches &&
        allDocumentTypesConfirmed &&
        errors.isEmpty) {
      return DocumentReviewResult(
        score: score,
        title: 'Likely consistent',
        summary:
            'The key name and plate details were found. Visually inspect the '
            'documents before making the final decision.',
        checks: checks,
      );
    }

    if (score >= 50) {
      return DocumentReviewResult(
        score: score,
        title: 'Manual review required',
        summary:
            'Some information matched, but one or more items need the '
            'administrator\'s attention.',
        checks: checks,
      );
    }

    return DocumentReviewResult(
      score: score,
      title: 'Issues detected',
      summary:
          'OCR could not confirm enough information. Inspect the files and '
          'request clearer or corrected documents when necessary.',
      checks: checks,
    );
  }

  static bool _addDocumentTypeCheck({
    required List<DocumentReviewCheck> checks,
    required String label,
    required String text,
    required String? error,
    required List<String> markers,
    List<String> supportingMarkers = const [],
    required String markerDescription,
  }) {
    if (error != null) {
      checks.add(
        DocumentReviewCheck(
          title: '$label readability',
          detail: error,
          state: DocumentReviewCheckState.unavailable,
        ),
      );
      return false;
    }

    final normalizedText = _normalizeWords(text);
    if (normalizedText.length < 15) {
      checks.add(
        DocumentReviewCheck(
          title: '$label readability',
          detail:
              'Very little text was detected. Review or request a clearer image.',
          state: DocumentReviewCheckState.warning,
        ),
      );
      return false;
    }

    final primaryMarkerFound = markers.any(
      (marker) => _containsApproximatePhrase(normalizedText, marker),
    );
    final supportingMarkerCount = supportingMarkers
        .where((marker) => _containsApproximatePhrase(normalizedText, marker))
        .length;
    final markerFound = primaryMarkerFound || supportingMarkerCount >= 2;
    checks.add(
      DocumentReviewCheck(
        title: '$label document type',
        detail: markerFound
            ? 'OCR found text expected on this document.'
            : 'OCR did not confidently find $markerDescription. Verify manually.',
        state: markerFound
            ? DocumentReviewCheckState.passed
            : DocumentReviewCheckState.warning,
      ),
    );
    return markerFound;
  }

  static void _addPlateCheck({
    required List<DocumentReviewCheck> checks,
    required String label,
    required String plate,
    required bool matched,
    required String text,
    required String? error,
  }) {
    if (error != null || text.trim().isEmpty) {
      checks.add(
        DocumentReviewCheck(
          title: label,
          detail: 'Not checked because readable document text was unavailable.',
          state: DocumentReviewCheckState.unavailable,
        ),
      );
      return;
    }

    checks.add(
      DocumentReviewCheck(
        title: label,
        detail: matched
            ? 'The entered plate $plate was found in the document.'
            : 'The entered plate $plate was not confidently found. Verify manually.',
        state: matched
            ? DocumentReviewCheckState.passed
            : DocumentReviewCheckState.warning,
      ),
    );
  }

  static bool _nameAppearsInText(String name, String text) {
    final nameTokens = _normalizeWords(
      name,
    ).split(' ').where((token) => token.length >= 2).toList();
    if (nameTokens.length < 2) return false;

    final textTokens = _normalizeWords(text).split(' ');
    bool containsNameToken(String nameToken) => textTokens.any(
      (textToken) => _tokensApproximatelyEqual(nameToken, textToken),
    );
    final firstAndLastMatch =
        containsNameToken(nameTokens.first) &&
        containsNameToken(nameTokens.last);
    if (!firstAndLastMatch) return false;

    final matchedTokens = nameTokens.where(containsNameToken).length;
    return matchedTokens >= 2;
  }

  static bool _plateAppearsInText(String plate, String text) {
    final normalizedPlate = _normalizeCompact(plate);
    if (normalizedPlate.length < 5) return false;
    if (_normalizeCompact(text).contains(normalizedPlate)) return true;

    final textTokens = _normalizeWords(
      text,
    ).split(' ').where((token) => token.isNotEmpty).toList();
    for (var start = 0; start < textTokens.length; start++) {
      var candidate = '';
      for (
        var tokenCount = 1;
        tokenCount <= 3 && start + tokenCount <= textTokens.length;
        tokenCount++
      ) {
        candidate += textTokens[start + tokenCount - 1];
        if ((candidate.length - normalizedPlate.length).abs() > 1) continue;
        if (_levenshteinDistance(candidate, normalizedPlate) <= 1) return true;
      }
    }
    return false;
  }

  static bool _containsApproximatePhrase(String text, String phrase) {
    final textTokens = _normalizeWords(
      text,
    ).split(' ').where((token) => token.isNotEmpty).toList();
    final phraseTokens = _normalizeWords(
      phrase,
    ).split(' ').where((token) => token.isNotEmpty).toList();
    if (phraseTokens.isEmpty || textTokens.length < phraseTokens.length) {
      return false;
    }

    for (
      var start = 0;
      start <= textTokens.length - phraseTokens.length;
      start++
    ) {
      var totalDistance = 0;
      var matches = true;
      for (var index = 0; index < phraseTokens.length; index++) {
        final expected = _normalizeOcrWord(phraseTokens[index]);
        final actual = _normalizeOcrWord(textTokens[start + index]);
        final allowedDistance = expected.length >= 5 ? 1 : 0;
        final distance = _levenshteinDistance(expected, actual);
        if (distance > allowedDistance) {
          matches = false;
          break;
        }
        totalDistance += distance;
      }
      if (matches && totalDistance <= 2) return true;
    }
    return false;
  }

  static bool _tokensApproximatelyEqual(String expected, String actual) {
    if (expected == actual) return true;
    if (expected.length < 4 || actual.length < 4) return false;
    if ((expected.length - actual.length).abs() > 1) return false;
    return _levenshteinDistance(expected, actual) <= 1;
  }

  static String _normalizeOcrWord(String value) {
    return value
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B');
  }

  static int _levenshteinDistance(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;

    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var firstIndex = 1; firstIndex <= first.length; firstIndex++) {
      final current = List<int>.filled(second.length + 1, 0);
      current[0] = firstIndex;
      for (var secondIndex = 1; secondIndex <= second.length; secondIndex++) {
        final substitutionCost =
            first.codeUnitAt(firstIndex - 1) ==
                second.codeUnitAt(secondIndex - 1)
            ? 0
            : 1;
        final deletion = previous[secondIndex] + 1;
        final insertion = current[secondIndex - 1] + 1;
        final substitution = previous[secondIndex - 1] + substitutionCost;
        current[secondIndex] = [
          deletion,
          insertion,
          substitution,
        ].reduce((minimum, value) => value < minimum ? value : minimum);
      }
      previous = current;
    }
    return previous.last;
  }

  static String _normalizeWords(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeCompact(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
