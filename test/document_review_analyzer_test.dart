import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/document_review_analyzer.dart';

void main() {
  group('DocumentReviewAnalyzer', () {
    test('marks consistent documents as likely consistent', () {
      final result = DocumentReviewAnalyzer.analyze(
        customerName: 'Juan Dela Cruz',
        enteredPlate: 'ABC 1234',
        idText: 'REPUBLIC OF THE PHILIPPINES NATIONAL ID JUAN DELA CRUZ',
        orText: 'LAND TRANSPORTATION OFFICE OFFICIAL RECEIPT ABC-1234',
        crText: 'CERTIFICATE OF REGISTRATION PLATE NUMBER ABC 1234',
      );

      expect(result.title, 'Likely consistent');
      expect(result.score, 100);
      expect(
        result.checks.where(
          (check) => check.state == DocumentReviewCheckState.warning,
        ),
        isEmpty,
      );
    });

    test('flags plate mismatches for manual review', () {
      final result = DocumentReviewAnalyzer.analyze(
        customerName: 'Juan Dela Cruz',
        enteredPlate: 'ABC1234',
        idText: 'PHILSYS NATIONAL ID JUAN DELA CRUZ',
        orText: 'OFFICIAL RECEIPT XYZ5678',
        crText: 'CERTIFICATE OF REGISTRATION XYZ5678',
      );

      expect(result.title, isNot('Likely consistent'));
      expect(
        result.checks.where((check) => check.title.contains('Plate number')),
        everyElement(
          predicate<DocumentReviewCheck>(
            (check) => check.state == DocumentReviewCheckState.warning,
          ),
        ),
      );
    });

    test('does not fail when OCR is unavailable for one document', () {
      final result = DocumentReviewAnalyzer.analyze(
        customerName: 'Maria Santos',
        enteredPlate: 'DEF5678',
        idText: '',
        orText: 'OFFICIAL RECEIPT DEF5678',
        crText: 'CERTIFICATE OF REGISTRATION DEF5678',
        errors: const {'ID': 'PDF OCR is not supported.'},
      );

      expect(result.title, 'Manual review required');
      expect(
        result.checks.any(
          (check) => check.state == DocumentReviewCheckState.unavailable,
        ),
        isTrue,
      );
    });

    test('tolerates common OCR mistakes in otherwise matching documents', () {
      final result = DocumentReviewAnalyzer.analyze(
        customerName: 'Julie Rebadavia',
        enteredPlate: '624EJH',
        idText:
            'REPUBLIC OF THE PHILIPPINES DRIVER L1CENSE '
            'Ju1ie Rebadavia DATE OF BIRTH 01 01 2000',
        orText:
            'LAND TRANSPORTATION OFFICE OFFlCIAL RECEIPT '
            'PLATE NO 624EJH AMOUNT PAID 500',
        crText:
            'CERTIF1CATE OF REGISTRATlON ENGINE NO 12345 '
            'CHASSIS NO 67890 PLATE 624EJH',
      );

      expect(result.title, 'Likely consistent');
      expect(result.score, 100);
      expect(
        result.checks.where(
          (check) => check.state == DocumentReviewCheckState.warning,
        ),
        isEmpty,
      );
    });

    test('gives unrelated readable images a zero consistency score', () {
      final result = DocumentReviewAnalyzer.analyze(
        customerName: 'Kehn Rebadavia',
        enteredPlate: 'WQER123',
        idText: 'A beautiful mountain landscape during sunset',
        orText: 'Birthday celebration with family and friends',
        crText: 'Fresh fruit vegetables and flowers at the market',
      );

      expect(result.title, 'Issues detected');
      expect(result.score, 0);
      expect(
        result.checks.where(
          (check) => check.state == DocumentReviewCheckState.passed,
        ),
        isEmpty,
      );
    });
  });
}
