import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../../widgets/site/hanap_button.dart';
import 'pending_approval_screen.dart';

/// Shown right after a worker's first successful login if they signed up
/// but haven't uploaded their NBI Clearance yet — uploading requires an
/// authenticated session, which doesn't exist yet at sign-up time while
/// email confirmation is required (see supabase/schema.sql "nbi-clearance"
/// storage policies: uploads must be auth.uid() = the folder owner).
class NbiUploadScreen extends StatefulWidget {
  final String userId;
  const NbiUploadScreen({super.key, required this.userId});

  @override
  State<NbiUploadScreen> createState() => _NbiUploadScreenState();
}

class _NbiUploadScreenState extends State<NbiUploadScreen> {
  PlatformFile? _nbiFile;
  String? _error;
  bool _loading = false;

  Future<void> _pickNbiFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true, // need raw bytes for storage.uploadBinary on every platform
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _nbiFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final file = _nbiFile;
    if (file == null) {
      setState(() => _error = "Please select your NBI Clearance file.");
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = "Could not read that file. Please try picking it again.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ext = (file.extension ?? 'dat').toLowerCase();
      final path = '${widget.userId}/nbi_clearance.$ext';

      await supabase.storage.from('nbi-clearance').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      await supabase.from('profiles').update({'nbi_clearance_path': path}).eq('id', widget.userId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } on StorageException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Upload failed. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.3,
            colors: [Color(0xFF141410), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("One more step", style: AppText.heading(size: 24)),
                    const SizedBox(height: 6),
                    Text(
                      "Upload your NBI Clearance so an admin can verify and approve your worker account.",
                      style: AppText.body(size: 14, color: AppColors.textSecondary).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Text("NBI Clearance", style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("Required", style: AppText.body(size: 11, weight: FontWeight.w600, color: AppColors.error)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickNbiFile,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _nbiFile != null ? AppColors.live.withValues(alpha: 0.08) : AppColors.surf2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _nbiFile != null ? AppColors.live : AppColors.hairline,
                            width: _nbiFile != null ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _nbiFile != null ? Icons.check_circle : Icons.cloud_upload,
                              size: 18,
                              color: _nbiFile != null ? AppColors.live : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nbiFile?.name ?? "Click to upload NBI Clearance (JPG, PNG, PDF)",
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(
                                  size: 13,
                                  weight: _nbiFile != null ? FontWeight.w600 : FontWeight.w400,
                                  color: _nbiFile != null ? AppColors.live : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Required for identity verification. Accepted: JPG, PNG, PDF.",
                      style: AppText.body(size: 11, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 18),

                    if (_error != null) HanapErrorBanner(message: _error!),

                    GoldButton(
                      label: "Submit for Review",
                      loadingLabel: "Uploading...",
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
