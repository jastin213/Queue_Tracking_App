import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/document_ocr_retry_policy.dart';
import 'package:queue_tracking_app/services/document_review_analyzer.dart';

void main() {
  test('does not retry documents when every required check passes', () {
    final result = DocumentReviewAnalyzer.analyze(
      customerName: 'Juan Dela Cruz',
      enteredPlate: 'ABC1234',
      idText: 'PHILSYS NATIONAL ID JUAN DELA CRUZ DATE OF BIRTH',
      orText: 'OFFICIAL RECEIPT PLATE ABC1234 AMOUNT PAID',
      crText: 'CERTIFICATE OF REGISTRATION PLATE ABC1234 ENGINE NO',
    );

    expect(documentTypesNeedingOcrRetry(result), isEmpty);
  });

  test('retries only the OR when its plate is not confirmed', () {
    final result = DocumentReviewAnalyzer.analyze(
      customerName: 'Juan Dela Cruz',
      enteredPlate: 'ABC1234',
      idText: 'PHILSYS NATIONAL ID JUAN DELA CRUZ DATE OF BIRTH',
      orText: 'OFFICIAL RECEIPT AMOUNT PAID TRANSACTION DATE',
      crText: 'CERTIFICATE OF REGISTRATION PLATE ABC1234 ENGINE NO',
    );

    expect(documentTypesNeedingOcrRetry(result), {'OR'});
  });

  test('retries ID when the customer name is not confirmed', () {
    final result = DocumentReviewAnalyzer.analyze(
      customerName: 'Juan Dela Cruz',
      enteredPlate: 'ABC1234',
      idText: 'PHILSYS NATIONAL ID MARIA SANTOS DATE OF BIRTH',
      orText: 'OFFICIAL RECEIPT PLATE ABC1234 AMOUNT PAID',
      crText: 'CERTIFICATE OF REGISTRATION PLATE ABC1234 ENGINE NO',
    );

    expect(documentTypesNeedingOcrRetry(result), {'ID'});
  });
}
