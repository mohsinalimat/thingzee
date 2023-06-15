import 'package:csv/csv.dart';
import 'package:repository/repository.dart';
import 'package:thingzee/data/item_csv_row.dart';

class ItemCSVImporter {
  Future<bool> importItemData(String csvString, Repository r) async {
    List<List<dynamic>> csvData =
        const CsvToListConverter().convert(csvString, shouldParseNumbers: true);

    if (csvData.isEmpty) {
      return false;
    }

    Map<String, int> headerIndices = csvData[0].asMap().map((k, v) => MapEntry(v.toString(), k));
    csvData.removeAt(0);

    for (final row in csvData) {
      ItemCSVRow itemRow = ItemCSVRow();
      itemRow.fromRow(row, headerIndices);
      r.items.put(itemRow.toItem());
    }

    return true;
  }
}
