import 'package:csv/csv.dart';
import 'package:repository/ml/history_series.dart';
import 'package:repository/ml/ml_history.dart';
import 'package:repository/repository.dart';
import 'package:thingzee/data/history_csv_row.dart';

class HistoryCSVImporter {
  Future<bool> importHistory(String csvString, Repository r) async {
    List<List<dynamic>> csvData =
        const CsvToListConverter().convert(csvString, shouldParseNumbers: true);
    Map<String, MLHistory> upcHistoryMap = {};
    Map<String, Map<int, HistorySeries>> upcSeriesIdMap = {};

    if (csvData.isEmpty) {
      return false;
    }

    Map<String, int> headerIndices = csvData[0].asMap().map((k, v) => MapEntry(v.toString(), k));
    csvData.removeAt(0);

    // Create all the history rows, removing those that are null (invalid)
    List<HistoryCSVRow> allHistoryRows = csvData
        .map((row) => HistoryCSVRow.fromRow(row, headerIndices))
        .whereType<HistoryCSVRow>()
        .toList();

    for (final historyRow in allHistoryRows) {
      // Ensure that the MLHistory exists, creating if necessary
      if (!upcHistoryMap.containsKey(historyRow.upc)) {
        upcHistoryMap[historyRow.upc] = MLHistory()..upc = historyRow.upc;
      }

      // Create or get the HistorySeries
      if (!upcSeriesIdMap.containsKey(historyRow.upc) ||
          !upcSeriesIdMap[historyRow.upc]!.containsKey(historyRow.seriesId)) {
        upcSeriesIdMap[historyRow.upc] = {historyRow.seriesId: HistorySeries()};
      }

      // Add the observation to the correct series
      upcSeriesIdMap[historyRow.upc]![historyRow.seriesId]!
          .observations
          .add(historyRow.toObservation());
    }

    // Add HistorySeries objects to the corresponding MLHistory object.
    for (final upc in upcHistoryMap.keys) {
      // Get the list of series for this upc
      var seriesIds = upcSeriesIdMap[upc]?.keys;

      // There are some series for this upc
      if (seriesIds != null) {
        // Make sure they're in order
        seriesIds = seriesIds.toList()..sort();

        // Add the series to the history object
        for (final id in seriesIds) {
          upcHistoryMap[upc]?.series.add(upcSeriesIdMap[upc]![id]!);
        }
      }

      // Put the history object in the repository
      r.hist.put(upcHistoryMap[upc]!);
    }

    return true;
  }
}