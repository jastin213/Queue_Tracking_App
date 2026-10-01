import 'document_review_analyzer.dart';

enum ConditionalAutoApprovalAction {
  approve,
  reject,
  manualReview,
  requestResubmission,
}

class ConditionalAutoApprovalDecision {
  const ConditionalAutoApprovalDecision({
    required this.action,
    required this.reason,
  });

  final ConditionalAutoApprovalAction action;
  final String reason;

  bool get canApprove => action == ConditionalAutoApprovalAction.approve;
  bool get canReject => action == ConditionalAutoApprovalAction.reject;
}

class ConditionalAutoApproval {
  static const int defaultMinimumScore = 80;

  static ConditionalAutoApprovalDecision evaluate({
    required DocumentReviewResult review,
    required bool allRequiredDocumentsPresent,
    required bool queueSlotAvailable,
    required bool suspiciousDuplicateDetected,
    bool autoRejectionEnabled = false,
    int minimumScore = defaultMinimumScore,
  }) {
    if (!allRequiredDocumentsPresent) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.requestResubmission,
        reason: 'One or more required documents are missing.',
      );
    }

    if (review.checks.any(
      (check) => check.state == DocumentReviewCheckState.unavailable,
    )) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.requestResubmission,
        reason:
            'At least one document could not be read automatically. A clearer image is required.',
      );
    }

    final everySupportedCheckFailed =
        review.checks.isNotEmpty &&
        review.checks.every(
          (check) => check.state == DocumentReviewCheckState.warning,
        );
    if (autoRejectionEnabled &&
        review.score == 0 &&
        everySupportedCheckFailed) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.reject,
        reason:
            'No required ID, OR, CR, customer-name, or plate information matched after the original and enhanced OCR checks.',
      );
    }

    if (review.score < 50) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.requestResubmission,
        reason:
            'The uploaded files did not contain enough matching document information.',
      );
    }

    if (suspiciousDuplicateDetected) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.manualReview,
        reason:
            'A document appears on another appointment with different customer or vehicle information.',
      );
    }

    if (!queueSlotAvailable) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.manualReview,
        reason: 'The selected queue slot is no longer available.',
      );
    }

    bool checkPassed(String title) => review.checks.any(
      (check) =>
          check.title == title &&
          check.state == DocumentReviewCheckState.passed,
    );
    final requiredDocumentTypesPassed =
        checkPassed('Valid ID document type') &&
        checkPassed('Official Receipt (OR) document type') &&
        checkPassed('Certificate of Registration (CR) document type');
    final customerNamePassed = checkPassed('Customer name on ID');
    final atLeastOnePlatePassed =
        checkPassed('Plate number on OR') || checkPassed('Plate number on CR');
    final requiredEvidencePassed =
        requiredDocumentTypesPassed &&
        customerNamePassed &&
        atLeastOnePlatePassed;
    if (review.score >= minimumScore && requiredEvidencePassed) {
      return const ConditionalAutoApprovalDecision(
        action: ConditionalAutoApprovalAction.approve,
        reason:
            'All document types and the customer name matched, and the plate was confirmed on at least one vehicle document.',
      );
    }

    return const ConditionalAutoApprovalDecision(
      action: ConditionalAutoApprovalAction.manualReview,
      reason:
          'The documents were readable, but one or more checks need administrator review.',
    );
  }
}
