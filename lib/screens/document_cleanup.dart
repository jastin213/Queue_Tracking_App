import 'package:flutter/material.dart';

import '../services/document_retention_cleanup.dart';
import '../theme/app_theme.dart';

class DocumentCleanupPage extends StatefulWidget {
  const DocumentCleanupPage({super.key});

  @override
  State<DocumentCleanupPage> createState() => _DocumentCleanupPageState();
}

class _DocumentCleanupPageState extends State<DocumentCleanupPage> {
  final DocumentRetentionCleanupService _cleanupService =
      DocumentRetentionCleanupService();
  final ScrollController _scrollController = ScrollController();

  List<ExpiredDocumentCandidate> _candidates = const [];
  final Set<String> _selectedIds = <String>{};
  bool _isLoading = true;
  bool _isCleaning = false;
  String? _loadError;

  Color get _backgroundColor => AppColors.activeBackground;
  Color get _primaryColor => AppColors.activePrimary;
  Color get _cardColor => AppColors.activeSurface;
  Color get _borderColor => AppColors.activeBorder;
  Color get _mutedTextColor => AppColors.activeMutedText;
  Color get _softPrimaryColor => AppColors.activeSoftPrimary;

  @override
  void initState() {
    super.initState();
    _loadExpiredDocuments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExpiredDocuments() async {
    if (_isCleaning) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final candidates = await _cleanupService.loadExpiredDocuments();
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _selectedIds.removeWhere(
          (id) => !candidates.any((candidate) => candidate.id == id),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    if (message.contains('permission-denied')) {
      return 'Permission denied. Sign in with an administrator account and '
          'make sure the latest Firestore rules are deployed.';
    }
    if (message.contains('unavailable') || message.contains('offline')) {
      return 'The server could not be reached. Check the internet connection '
          'and refresh before attempting cleanup.';
    }
    return message;
  }

  int get _selectedBytes => _candidates
      .where((candidate) => _selectedIds.contains(candidate.id))
      .fold(0, (total, candidate) => total + candidate.estimatedBytes);

  void _toggleAll(bool selected) {
    setState(() {
      _selectedIds.clear();
      if (selected) {
        _selectedIds.addAll(_candidates.map((candidate) => candidate.id));
      }
    });
  }

  Future<void> _reviewCandidate(ExpiredDocumentCandidate candidate) async {
    final data = candidate.data;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.fact_check_outlined, color: _primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Review Expired Uploads',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogDetail('Customer', candidate.customerName),
                _dialogDetail('Plate number', candidate.plate),
                _dialogDetail('Appointment date', candidate.appointmentDate),
                _dialogDetail('Queue code', candidate.queue),
                _dialogDetail(
                  'Expiration date',
                  _formatDate(candidate.expiresAt),
                ),
                _dialogDetail(
                  'Stored size',
                  _formatBytes(candidate.estimatedBytes),
                ),
                _dialogDetail(
                  'Storage backend',
                  _backendLabel(candidate.backend),
                ),
                const SizedBox(height: 8),
                Divider(color: _borderColor),
                const SizedBox(height: 8),
                Text(
                  'Files scheduled for removal',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _documentLine('Valid ID', data['idFile']),
                _documentLine('Official Receipt (OR)', data['orFile']),
                _documentLine(
                  'Certificate of Registration (CR)',
                  data['crFile'],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softPrimaryColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: _primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'The appointment, customer, plate, result, and report '
                          'information will be preserved. Only uploaded document '
                          'files are removed.',
                          style: TextStyle(
                            color: _mutedTextColor,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _dialogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: _mutedTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentLine(String label, Object? fileName) {
    final value = fileName?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(Icons.description_outlined, color: _mutedTextColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${value?.isNotEmpty == true ? value : 'Stored document'}',
              style: TextStyle(
                color: _mutedTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClean() async {
    final selected = _candidates
        .where((candidate) => _selectedIds.contains(candidate.id))
        .toList();
    if (selected.isEmpty || _isCleaning) return;

    bool acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Archive and Delete Documents?',
            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} expired appointment${selected.length == 1 ? '' : 's'} '
                  'will be processed. Approximately ${_formatBytes(_selectedBytes)} '
                  'of uploaded documents will be removed.',
                  style: TextStyle(color: _mutedTextColor, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'A lightweight historical archive is saved first. Appointment '
                  'and report records are not deleted.',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.red,
                  value: acknowledged,
                  onChanged: (value) =>
                      setDialogState(() => acknowledged = value == true),
                  title: Text(
                    'I understand that uploaded documents cannot be recovered '
                    'through the application after cleanup.',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('ARCHIVE & DELETE'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await _cleanSelected(selected);
  }

  Future<void> _cleanSelected(List<ExpiredDocumentCandidate> selected) async {
    setState(() => _isCleaning = true);
    int purged = 0;
    int failed = 0;
    int estimatedBytesFreed = 0;
    final failedNames = <String>[];

    for (final candidate in selected) {
      try {
        final result = await _cleanupService.archiveAndDelete(candidate);
        purged += 1;
        estimatedBytesFreed += result.estimatedBytesFreed;
      } catch (_) {
        failed += 1;
        failedNames.add(candidate.customerName);
      }
    }

    await _cleanupService.recordManualCleanup(
      selected: selected.length,
      purged: purged,
      failed: failed,
      estimatedBytesFreed: estimatedBytesFreed,
    );

    if (!mounted) return;
    setState(() {
      _isCleaning = false;
      _selectedIds.clear();
    });
    await _loadExpiredDocuments();
    if (!mounted) return;

    final message = failed == 0
        ? '$purged appointment${purged == 1 ? '' : 's'} cleaned. Estimated '
              '${_formatBytes(estimatedBytesFreed)} freed.'
        : '$purged cleaned and $failed failed. No active appointment records '
              'were deleted.${failedNames.isEmpty ? '' : ' Check: ${failedNames.join(', ')}'}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed == 0
            ? Colors.green.shade700
            : Colors.orange.shade800,
      ),
    );
  }

  String _backendLabel(String backend) {
    if (backend == 'firestore') return 'Firestore document storage';
    if (backend == 'firebase_storage') return 'Firebase Storage';
    if (backend == 'purged') return 'Already removed';
    return 'Legacy or unknown storage';
  }

  String _formatDate(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Size unavailable';
    const kib = 1024;
    const mib = 1024 * 1024;
    if (bytes >= mib) return '${(bytes / mib).toStringAsFixed(2)} MiB';
    if (bytes >= kib) return '${(bytes / kib).toStringAsFixed(1)} KiB';
    return '$bytes bytes';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _candidates.isNotEmpty && _selectedIds.length == _candidates.length;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Document Retention',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh expired documents',
            onPressed: _isLoading || _isCleaning ? null : _loadExpiredDocuments,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _buildBody(allSelected)),
    );
  }

  Widget _buildBody(bool allSelected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final horizontalPadding = wide ? 24.0 : 12.0;
        return RefreshIndicator(
          onRefresh: _loadExpiredDocuments,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: wide,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      children: [
                        _buildPageSummary(wide),
                        const SizedBox(height: 14),
                        _buildSafetyCard(),
                        const SizedBox(height: 14),
                        if (_isLoading)
                          _buildLoadingCard()
                        else if (_loadError != null)
                          _buildErrorCard()
                        else if (_candidates.isEmpty)
                          _buildEmptyCard()
                        else ...[
                          _buildSelectionHeader(allSelected),
                          if (_selectedIds.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildCleanupAction(wide),
                          ],
                          const SizedBox(height: 10),
                          for (final candidate in _candidates) ...[
                            _buildCandidateCard(candidate),
                            const SizedBox(height: 10),
                          ],
                          if (_candidates.length ==
                              DocumentRetentionCleanupService
                                  .maximumCandidatesPerLoad)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Showing the oldest 100 expired appointments. '
                                'Refresh after cleanup to load the next group.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _mutedTextColor),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageSummary(bool wide) {
    final totalBytes = _candidates.fold<int>(
      0,
      (total, candidate) => total + candidate.estimatedBytes,
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expired Document Cleanup',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 24 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Review eligible uploads before permanently removing the files.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final metrics = <Widget>[
      _summaryMetric(
        Icons.event_busy_outlined,
        _isLoading ? '—' : '${_candidates.length}',
        'Expired records',
      ),
      _summaryMetric(
        Icons.cloud_outlined,
        _isLoading ? '—' : _formatBytes(totalBytes),
        'Recorded size',
      ),
      _summaryMetric(
        Icons.check_circle_outline_rounded,
        '${_selectedIds.length}',
        'Selected',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 22 : 18),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 4, child: heading),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        Expanded(child: metrics[index]),
                        if (index != metrics.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      Expanded(child: metrics[index]),
                      if (index != metrics.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _summaryMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupAction(bool wide) {
    final information = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedIds.length} record${_selectedIds.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatBytes(_selectedBytes)} of recorded uploads',
                style: TextStyle(
                  color: _mutedTextColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _isCleaning ? null : _confirmAndClean,
      icon: _isCleaning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.delete_forever_outlined),
      label: Text(_isCleaning ? 'CLEANING...' : 'CLEAN SELECTED'),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.28)),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: information),
                const SizedBox(width: 16),
                action,
              ],
            )
          : Column(
              children: [
                information,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: action),
              ],
            ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.inventory_2_outlined, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual 365-Day Retention Cleanup',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Only appointments whose uploaded documents have reached '
                  'their recorded expiration date appear here. Review and '
                  'select records before cleanup. Essential appointment and '
                  'report information is archived and preserved.',
                  style: TextStyle(
                    color: _mutedTextColor,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() => _messageCard(
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: CircularProgressIndicator(),
    ),
  );

  Widget _buildErrorCard() => _messageCard(
    child: Column(
      children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 42),
        const SizedBox(height: 10),
        Text(
          _loadError!,
          textAlign: TextAlign.center,
          style: TextStyle(color: _primaryColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadExpiredDocuments,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('TRY AGAIN'),
        ),
      ],
    ),
  );

  Widget _buildEmptyCard() => _messageCard(
    child: Column(
      children: [
        Icon(Icons.verified_outlined, color: Colors.green.shade600, size: 48),
        const SizedBox(height: 10),
        Text(
          'No expired uploads found',
          style: TextStyle(
            color: _primaryColor,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'No document is currently eligible for manual cleanup.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedTextColor),
        ),
      ],
    ),
  );

  Widget _messageCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildSelectionHeader(bool allSelected) {
    final totalBytes = _candidates.fold<int>(
      0,
      (total, candidate) => total + candidate.estimatedBytes,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: _isCleaning
                ? null
                : (value) => _toggleAll(value == true),
          ),
          Expanded(
            child: Text(
              '${_candidates.length} expired appointment${_candidates.length == 1 ? '' : 's'} '
              '• ${_formatBytes(totalBytes)}',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: _isCleaning ? null : () => _toggleAll(!allSelected),
            child: Text(allSelected ? 'CLEAR ALL' : 'SELECT ALL'),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(ExpiredDocumentCandidate candidate) {
    final selected = _selectedIds.contains(candidate.id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
      decoration: BoxDecoration(
        color: selected ? _softPrimaryColor : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _primaryColor : _borderColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: _isCleaning
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selectedIds.add(candidate.id);
                    } else {
                      _selectedIds.remove(candidate.id);
                    }
                  }),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      candidate.customerName,
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _tag('EXPIRED', Colors.red),
                    _tag(
                      _backendLabel(candidate.backend).toUpperCase(),
                      _primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${candidate.plate} • ${candidate.queue} • ${candidate.appointmentDate}',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expired ${_formatDate(candidate.expiresAt)} • '
                  '${_formatBytes(candidate.estimatedBytes)}',
                  style: TextStyle(color: _mutedTextColor, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isCleaning
                        ? null
                        : () => _reviewCandidate(candidate),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('REVIEW DETAILS'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
