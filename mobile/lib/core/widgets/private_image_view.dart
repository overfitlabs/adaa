import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../theme/app_colors.dart';

class PrivateImageView extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onRefreshUrl;

  const PrivateImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onRefreshUrl,
  });

  @override
  State<PrivateImageView> createState() => _PrivateImageViewState();
}

class _PrivateImageViewState extends State<PrivateImageView> {
  int _retryCount = 0;

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.imageUrl;
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return _buildFallback(isError: false);
    }

    final resolvedUrl = ApiEndpoints.resolveImageUrl(rawUrl);

    // Determine whether auth headers are needed:
    // Cloudinary signed URLs already carry cryptographic HMAC signatures in their URL/query.
    // Local /storage endpoints require the Supabase Bearer token for authorization.
    final bool isCloudinary = resolvedUrl.contains('cloudinary.com');
    final Map<String, String>? headers = (!isCloudinary &&
            ApiClient.authToken != null &&
            ApiClient.authToken!.trim().isNotEmpty)
        ? {'Authorization': 'Bearer ${ApiClient.authToken!.trim()}'}
        : null;

    Widget imageWidget = Image.network(
      resolvedUrl,
      key: ValueKey('$resolvedUrl-$_retryCount'),
      headers: headers,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: AppColors.accentSoft,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFallback(isError: true);
      },
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallback({required bool isError}) {
    if (widget.errorWidget != null && isError) {
      return widget.errorWidget!;
    }
    if (widget.placeholder != null && !isError) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.accentSoft,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.broken_image_outlined : Icons.checkroom,
              size: (widget.width != null && widget.width! < 60) ? 20 : 36,
              color: isError ? AppColors.missing : AppColors.textMuted,
            ),
            if (isError && widget.onRefreshUrl != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _retryCount++);
                  widget.onRefreshUrl!();
                },
                child: const Text(
                  'Tap to retry',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
