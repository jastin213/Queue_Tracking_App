import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/conditional_auto_approval.dart';
import 'package:queue_tracking_app/services/document_review_analyzer.dart';

void main() {
  DocumentReviewResult review({
    required int score,
    required List<DocumentReviewCheckState> states,
  }) {
    const titles = [
      'Valid ID document type',
      'Official Receipt (OR) document type',
      'Certificate of Registration (CR) document type',
      'Customer name on ID',
      'Plate number on OR',
      'Plate number on CR',
    ];
    return DocumentReviewResult(
      score: score,
      title: 'Review',
      summary: 'Summary',
      checks: [
        for (var index = 0; index < states.length; index++)
          DocumentReviewCheck(
            title: titles[index],
            detail: 'Detail',
            state: states[index],
          ),
      ],
    );
  }

  test('approves only a high-score review with every check passed', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 100,
        states: List.filled(6, DocumentReviewCheckState.passed),
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
    );

    expect(decision.action, ConditionalAutoApprovalAction.approve);
  });

  test('approves at 80 percent when one plate document is unclear', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 80,
        states: const [
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.warning,
          DocumentReviewCheckState.passed,
        ],
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
    );

    expect(decision.action, ConditionalAutoApprovalAction.approve);
  });

  test('keeps an 80 score pending when a required document type fails', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 80,
        states: const [
          DocumentReviewCheckState.warning,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.passed,
        ],
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
    );

    expect(decision.action, ConditionalAutoApprovalAction.manualReview);
  });

  test('requests another upload when OCR cannot read a document', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 70,
        states: const [
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.unavailable,
        ],
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
    );

    expect(decision.action, ConditionalAutoApprovalAction.requestResubmission);
  });

  test('never auto-approves suspicious duplicate documents', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 100,
        states: List.filled(6, DocumentReviewCheckState.passed),
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: true,
    );

    expect(decision.action, ConditionalAutoApprovalAction.manualReview);
  });

  test('rejects a confirmed zero score when auto-rejection is enabled', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 0,
        states: List.filled(6, DocumentReviewCheckState.warning),
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
      autoRejectionEnabled: true,
    );

    expect(decision.action, ConditionalAutoApprovalAction.reject);
  });

  test('does not reject zero when OCR information is unavailable', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 0,
        states: const [
          DocumentReviewCheckState.warning,
          DocumentReviewCheckState.unavailable,
        ],
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
      autoRejectionEnabled: true,
    );

    expect(decision.action, ConditionalAutoApprovalAction.requestResubmission);
  });

  test('keeps a confirmed zero out of rejection when setting is disabled', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 0,
        states: List.filled(6, DocumentReviewCheckState.warning),
      ),
      allRequiredDocumentsPresent: true,
      queueSlotAvailable: true,
      suspiciousDuplicateDetected: false,
    );

    expect(decision.action, ConditionalAutoApprovalAction.requestResubmission);
  });
}
