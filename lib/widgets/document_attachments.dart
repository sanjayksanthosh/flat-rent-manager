import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../theme.dart';

/// Helpers shared by the move-in form and the tenant details page for the
/// documents stored on a tenant. Each document is one picked file with:
///   name     – display name of the attachment (user supplied)
///   fileName – original file name
///   type     – 'pdf' or 'image'
///   mime     – detected mime type
///   data     – base64 encoded bytes
String documentMime(Map<String, String> doc) {
  final mime = doc['mime'];
  if (mime != null && mime.isNotEmpty) return mime;
  final type = doc['type'] ?? '';
  if (type.contains('/')) return type;
  return _mimeForName(doc['fileName'] ?? doc['name'] ?? '');
}

String _mimeForName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.bmp')) return 'image/bmp';
  if (n.endsWith('.heic') || n.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

bool isPdfDocument(Map<String, String> doc) => documentMime(doc) == 'application/pdf';

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _documentSize(Map<String, String> doc) {
  final raw = doc['data'];
  if (raw == null || raw.isEmpty) return '';
  return formatFileSize(base64Decode(raw).length);
}

/// Opens the system file picker, then a small dialog asking for the document
/// name. Returns the picked documents (already base64 encoded).
Future<List<Map<String, String>>> pickDocuments(
  BuildContext context, {
  String? suggestedName,
}) async {
  final nameCtrl = TextEditingController(text: suggestedName ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Document'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'e.g. Aadhaar, Rent Agreement',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You can pick one or more images/PDF files next.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
          child: const Text('Choose Files'),
        ),
      ],
    ),
  );
  nameCtrl.dispose();
  if (name == null) return const [];

  FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'],
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open the file picker'),
        backgroundColor: AppTheme.danger,
      ));
    }
    return const [];
  }
  if (result == null || result.files.isEmpty) return const [];

  final docs = <Map<String, String>>[];
  for (final file in result.files) {
    final bytes = file.bytes;
    if (bytes == null) continue;
    if (bytes.length > 10 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${file.name} is larger than 10 MB'),
          backgroundColor: AppTheme.warning,
        ));
      }
      continue;
    }
    final mime = _mimeForName(file.name);
    final displayName = name.isNotEmpty
        ? name
        : file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    docs.add({
      'name': displayName,
      'fileName': file.name,
      'type': mime == 'application/pdf' ? 'pdf' : 'image',
      'mime': mime,
      'data': base64Encode(bytes),
    });
  }
  return docs;
}

/// Card-less editor used inside forms (move-in) and inside a card
/// (tenant details).
class DocumentsEditor extends StatelessWidget {
  final List<Map<String, String>> documents;
  final ValueChanged<List<Map<String, String>>> onChanged;
  final String emptyText;
  final bool showHeader;

  const DocumentsEditor({
    super.key,
    required this.documents,
    required this.onChanged,
    this.emptyText = 'No documents attached',
    this.showHeader = true,
  });

  Future<void> _add(BuildContext context) async {
    final picked = await pickDocuments(context);
    if (picked.isEmpty) return;
    onChanged([...documents, ...picked]);
  }

  void _remove(int index) {
    final updated = [...documents]..removeAt(index);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showHeader)
        Row(children: [
          const Expanded(
            child: Text('Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
          TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Add'),
          ),
        ])
      else
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Add Document'),
          ),
        ),
      if (documents.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(emptyText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        )
      else
        ...documents.asMap().entries.map((entry) {
          final index = entry.key;
          final doc = entry.value;
          final pdf = isPdfDocument(doc);
          final fileName = doc['fileName'] ?? doc['name'] ?? 'Document';
          final size = _documentSize(doc);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (pdf ? AppTheme.danger : AppTheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(pdf ? Icons.picture_as_pdf : Icons.image,
                  size: 20, color: pdf ? AppTheme.danger : AppTheme.primary),
            ),
            title: Text(doc['name'] ?? fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              [fileName, if (size.isNotEmpty) size].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'View',
                onPressed: () => DocumentViewer.open(context, doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                tooltip: 'Remove',
                onPressed: () => _remove(index),
              ),
            ]),
          );
        }),
      if (documents.isEmpty && showHeader)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Add Document'),
          ),
        ),
    ]);
  }
}

class DocumentViewer extends StatelessWidget {
  final Map<String, String> doc;

  const DocumentViewer({super.key, required this.doc});

  static void open(BuildContext context, Map<String, String> doc) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewer(doc: doc)));
  }

  Uint8List get _bytes {
    try {
      return base64Decode(doc['data'] ?? '');
    } catch (_) {
      return Uint8List(0);
    }
  }

  String get _name => doc['fileName'] ?? doc['name'] ?? 'Document';

  Future<void> _share() async {
    final bytes = _bytes;
    await Share.shareXFiles([
      XFile.fromData(bytes, mimeType: documentMime(doc), name: _name),
    ], text: doc['name'] ?? _name);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final pdf = isPdfDocument(doc);
    return Scaffold(
      appBar: AppBar(
        title: Text(doc['name'] ?? _name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.share, size: 20), tooltip: 'Share', onPressed: _share),
        ],
      ),
      body: bytes.isEmpty
          ? const Center(child: Text('This document has no data'))
          : pdf
              ? PdfPreview(
                  build: (format) async => bytes,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                  pdfFileName: _name,
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(child: Text('Cannot display document')),
                    ),
                  ),
                ),
    );
  }
}
