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
    'DRIVING LICENSE',
    'PHILSYS',
    'PHILIPPINE IDENTIFICATION',
    'NATIONAL ID',
    'PASSPORT',
    'UNIFIED MULTI PURPOSE ID',
    'UMID',
    'POSTAL ID',
    'PROFESSIONAL REGULATION COMMISSION',
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
      markerDescription: 'a supported government ID label',
    );
    if (idReadable) score += 10;

    final orReadable = _addDocumentTypeCheck(
      checks: checks,
      label: 'Official Receipt (OR)',
      text: orText,
      error: errors['OR'],
      markers: const ['OFFICIAL RECEIPT'],
      markerDescription: 'the Official Receipt label',
    );
    if (orReadable) score += 10;

    final crReadable = _addDocumentTypeCheck(
      checks: checks,
      label: 'Certificate of Registration (CR)',
      text: crText,
      error: errors['CR'],
      markers: const ['CERTIFICATE OF REGISTRATION'],
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

    final allReadable =
        idText.trim().isNotEmpty &&
        orText.trim().isNotEmpty &&
        crText.trim().isNotEmpty &&
        errors.isEmpty;
    if (allReadable) score += 5;

    final criticalMatches = nameMatch && orPlateMatch && crPlateMatch;
    if (score >= 85 && criticalMatches && errors.isEmpty) {
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

    final markerFound = markers.any(normalizedText.contains);
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

    final textTokens = _normalizeWords(text).split(' ').toSet();
    final firstAndLastMatch =
        textTokens.contains(nameTokens.first) &&
        textTokens.contains(nameTokens.last);
    if (!firstAndLastMatch) return false;

    final matchedTokens = nameTokens.where(textTokens.contains).length;
    return matchedTokens >= 2;
  }

  static bool _plateAppearsInText(String plate, String text) {
    final normalizedPlate = _normalizeCompact(plate);
    if (normalizedPlate.length < 5) return false;
    return _normalizeCompact(text).contains(normalizedPlate);
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
