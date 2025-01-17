import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:quiver/core.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:thingzee/app.dart';
import 'package:thingzee/data/csv_export_service.dart';
import 'package:thingzee/data/csv_import_service.dart';
import 'package:thingzee/pages/inventory/state/inventory_view.dart';
import 'package:thingzee/pages/inventory/state/item_thumbnail_cache.dart';

// Settings page
// Features to include:
// - Regenerate random scan audit
// - Location editor
// - View all unassigned (unlocated) items
// - Debug functionality to reset db

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  static Future<void> push(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<Optional<String>> pickFilePath() async {
    FilePickerResult? filePickerResult = await FilePicker.platform.pickFiles();
    Optional<String> chosenPath = const Optional.absent();

    if (filePickerResult != null) {
      chosenPath = Optional.fromNullable(filePickerResult.files.single.path);
    }

    return chosenPath;
  }

  Future<void> onExportButtonPressed(BuildContext context) async {
    await CsvExportService().exportAllData(App.repo);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Data exported successfully.'),
    ));
  }

  Future<void> onImportButtonPressed(BuildContext context) async {
    await CsvImportService().importAllData(App.repo);

    if (!mounted) return;
    await _refreshPostImport(context);
  }

  Future<void> _refreshPostImport(BuildContext context) async {
    final view = ref.read(inventoryProvider.notifier);
    final imageCache = ref.read(itemThumbnailCache.notifier);

    await view.refresh();
    await view.downloadImages(imageCache);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Backup imported.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SettingsList(
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          lightTheme: SettingsThemeData(settingsListBackground: Theme.of(context).canvasColor),
          sections: [
            SettingsSection(
              title: const Text('Backup'),
              tiles: [
                SettingsTile(
                    title: const Text('Export Backup (Zipped CSV Archive)'),
                    onPressed: onExportButtonPressed),
              ],
            ),
            SettingsSection(
              title: const Text('Restore'),
              tiles: [
                SettingsTile(
                    title: const Text('Import Backup (Zipped CSV Archive)'),
                    onPressed: onImportButtonPressed),
              ],
            ),
          ]),
    );
  }
}
