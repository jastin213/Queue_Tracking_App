import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/conditional_auto_approval.dart';
import 'package:queue_tracking_app/services/document_review_analyzer.dart';

void main() {
  DocumentReviewResult review({
    required int score,
    required List<DocumentReviewCheckState> states,
  }) {
    return DocumentReviewResult(
      score: score,
      title: 'Review',
      summary: 'Summary',
      checks: [
        for (var index = 0; index < states.length; index++)
          DocumentReviewCheck(
            title: 'Check $index',
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

  test('keeps readable but uncertain documents for manual review', () {
    final decision = ConditionalAutoApproval.evaluate(
      review: review(
        score: 80,
        states: const [
          DocumentReviewCheckState.passed,
          DocumentReviewCheckState.warning,
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
}
