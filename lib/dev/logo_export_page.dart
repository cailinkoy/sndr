import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // RenderRepaintBoundary
import 'package:path_provider/path_provider.dart';

import '../branding/sndr_logo_icon.dart';
import '../branding/sndr_logo.dart';

class LogoExportPage extends StatefulWidget {
  const LogoExportPage({super.key});

  @override
  State<LogoExportPage> createState() => _LogoExportPageState();
}

class _LogoExportPageState extends State<LogoExportPage> {
  // Export targets
  final List<int> _iconSizes = [48, 72, 96, 144, 192, 512, 1024];
  final List<int> _bannerHeights = [64, 128, 256];

  // Higher pixel ratio => crisper PNGs
  static const double _pixelRatio = 3.0;

  // One boundary key per preview
  final Map<int, GlobalKey> _iconKeys = {};
  final Map<int, GlobalKey> _bannerKeys = {};

  @override
  void initState() {
    super.initState();
    for (final s in _iconSizes) {
      _iconKeys[s] = GlobalKey(debugLabel: 'icon_$s');
    }
    for (final h in _bannerHeights) {
      _bannerKeys[h] = GlobalKey(debugLabel: 'banner_$h');
    }
  }

  Future<Directory> _exportDir() async {
    // Prefer Downloads on desktop; fallback to app docs.
    try {
      final d = await getDownloadsDirectory();
      if (d != null) {
        final dir = Directory('${d.path}${Platform.pathSeparator}sndr_exports');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}sndr_exports');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<ui.Image> _capture(
    GlobalKey key, {
    double pixelRatio = _pixelRatio,
  }) async {
    final ctx = key.currentContext!;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    return await boundary.toImage(pixelRatio: pixelRatio);
  }

  Future<void> _exportAll() async {
    final dir = await _exportDir();

    // 1) Icons (rounded dark square, no wordmark)
    for (final s in _iconSizes) {
      final img = await _capture(_iconKeys[s]!);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${dir.path}${Platform.pathSeparator}icon_$s.png',
      ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    }

    // 2) Banners (transparent PNGs with wordmark)
    for (final h in _bannerHeights) {
      final img = await _capture(_bannerKeys[h]!);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${dir.path}${Platform.pathSeparator}banner_h$h.png',
      ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    }

    if (!mounted) return;
    final exportedPath = (await _exportDir()).path;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported to: $exportedPath')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('SNDR Logo Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Icon previews (no wordmark):',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _iconSizes.map((s) {
              final sz = s.toDouble();
              return RepaintBoundary(
                key: _iconKeys[s],
                child: SizedBox(
                  width: sz,
                  height: sz,
                  child: SndrLogoIcon(
                    size: sz,
                    showWordmark: false, // dark icon only
                    bgColor: const Color(0xFF121212),
                    logoColor: cs.primary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Banner previews (with wordmark, transparent):',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Column(
            children: _bannerHeights.map((h) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RepaintBoundary(
                  key: _bannerKeys[h],
                  child: Container(
                    color: Colors.transparent, // keep banners transparent
                    child: SndrLogo(
                      height: h.toDouble(),
                      showWordmark: true,
                      // If your SndrLogo supports box/monogram params,
                      // they’ll inherit defaults here; we keep banner clean.
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _exportAll,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export PNGs'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Files: icon_48/72/96/144/192/512/1024.png and banner_h64/128/256.png\n'
            'Folder: Downloads/sndr_exports (desktop) or app documents (mobile).',
          ),
        ],
      ),
    );
  }
}
