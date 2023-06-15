import 'package:csv/csv.dart';
import 'package:repository/repository.dart';
import 'package:thingzee/data/inventory_csv_row.dart';

class InventoryCSVImporter {
  Future<bool> importInventoryData(String csvString, Repository r) async {
    List<List<dynamic>> csvData =
        const CsvToListConverter().convert(csvString, shouldParseNumbers: true);

    if (csvData.isEmpty) {
      return false;
    }

    Map<String, int> headerIndices = csvData[0].asMap().map((k, v) => MapEntry(v.toString(), k));
    csvData.removeAt(0);

    for (final row in csvData) {
      InventoryCSVRow inventoryRow = InventoryCSVRow();
      inventoryRow.fromRow(row, headerIndices);
      r.items.put(inventoryRow.toItem());
      r.inv.put(inventoryRow.toInventory());
    }

    return true;
  }
}