import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

import '../providers/kitchen_provider.dart';

const _docLabels = <String, String>{
  'fssai': 'FSSAI License',
  'id_proof': 'ID Proof',
};

/// Upload/view verification documents (multipart → R2).
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _picker = ImagePicker();
  List<dynamic> _docs = const [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await ref.read(apiClientProvider).getList('/kitchens/me/documents');
      if (mounted) setState(() => _docs = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload(String docType) async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).postMultipart(
        '/kitchens/me/documents/upload',
        fields: {'docType': docType},
        files: {
          'file': [picked.path]
        },
      );
      await _load();
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'Upload your FSSAI license and ID proof for verification.'),
                const SizedBox(height: 16),
                for (final e in _docLabels.entries) _docCard(e.key, e.value),
                if (_uploading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
    );
  }

  Widget _docCard(String type, String label) {
    final count = _docs.where((d) => (d as Map)['docType'] == type).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleMedium)),
                if (count > 0)
                  const Icon(Icons.check_circle,
                      color: HomelyColors.sageDeep),
              ],
            ),
            const SizedBox(height: 4),
            Text('$count uploaded',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : () => _upload(type),
              icon: const Icon(Icons.upload_file),
              label: Text(count == 0 ? 'Upload' : 'Upload another'),
            ),
          ],
        ),
      ),
    );
  }
}
