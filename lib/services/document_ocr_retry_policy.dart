import 'document_review_analyzer.dart';

/// Returns only the documents whose required evidence was not confirmed by
/// the fast OCR pass. Clear documents are not processed a second time.
Set<String> documentTypesNeedingOcrRetry(DocumentReviewResult review) {
  final documentTypes = <String>{};
  for (final check in review.checks) {
    if (check.state == DocumentReviewCheckState.passed) continue;
    final title = check.title;
    if (title.startsWith('Valid ID') || title == 'Customer name on ID') {
      documentTypes.add('ID');
    }
    if (title.startsWith('Official Receipt') || title == 'Plate number on OR') {
      documentTypes.add('OR');
    }
    if (title.startsWith('Certificate of Registration') ||
        title == 'Plate number on CR') {
      documentTypes.add('CR');
    }
  }
  return documentTypes;
}
