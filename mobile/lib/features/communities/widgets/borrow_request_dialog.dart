import 'package:flutter/material.dart';
import '../../../core/models/wardrobe_item.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/private_image_view.dart';

class BorrowRequestDialog extends StatefulWidget {
  final String communityId;
  final String listingId;
  final String communityName;
  final WardrobeItem garment;
  final String ownerName;

  const BorrowRequestDialog({
    super.key,
    required this.communityId,
    required this.listingId,
    required this.communityName,
    required this.garment,
    required this.ownerName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String communityId,
    required String listingId,
    required String communityName,
    required WardrobeItem garment,
    required String ownerName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BorrowRequestDialog(
        communityId: communityId,
        listingId: listingId,
        communityName: communityName,
        garment: garment,
        ownerName: ownerName,
      ),
    );
  }

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  final TextEditingController _messageController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _dateError;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _validateDates();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? now),
      firstDate: _startDate ?? now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _validateDates();
      });
    }
  }

  void _validateDates() {
    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
      _dateError = 'Start date cannot be after end date.';
    } else {
      _dateError = null;
    }
  }

  Future<void> _submitRequest() async {
    _validateDates();
    if (_dateError != null) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiClient.createBorrowRequest(
        widget.communityId,
        widget.listingId,
        message: _messageController.text,
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Borrow request sent to ${widget.ownerName}! Track it under Activity.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.missing,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Request to Borrow',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PrivateImageView(
                      imageUrl: widget.garment.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.garment.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Owner: ${widget.ownerName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        Text(
                          widget.communityName,
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date Range Section
            const Text(
              'REQUESTED BORROW WINDOW (OPTIONAL)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _isSubmitting ? null : _selectStartDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    label: Text(
                      _startDate != null ? _formatDate(_startDate!) : 'Start Date',
                      style: TextStyle(fontSize: 11, color: _startDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _isSubmitting ? null : _selectEndDate,
                    icon: const Icon(Icons.event_available_outlined, size: 14),
                    label: Text(
                      _endDate != null ? _formatDate(_endDate!) : 'End Date',
                      style: TextStyle(fontSize: 11, color: _endDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (_dateError != null) ...[
              const SizedBox(height: 6),
              Text(_dateError!, style: const TextStyle(color: AppColors.missing, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),

            // Message Section
            const Text(
              'MESSAGE TO OWNER',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              enabled: !_isSubmitting,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Introduce yourself and describe your event or occasion...',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRequest,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
