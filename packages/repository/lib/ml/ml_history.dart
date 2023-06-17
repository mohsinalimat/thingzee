import 'package:json_annotation/json_annotation.dart';
import 'package:repository/ml/history_series.dart';
import 'package:repository/ml/observation.dart';

part 'ml_history.g.dart';

@JsonSerializable(explicitToJson: true)
class MLHistory {
  String upc = '';
  List<HistorySeries> series = [];
  MLHistory();

  factory MLHistory.fromJson(Map<String, dynamic> json) => _$MLHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$MLHistoryToJson(this);

  HistorySeries get best {
    return canPredict ? current : previous;
  }

  bool get canPredict {
    return current.regressor.hasXIntercept || previous.regressor.hasXIntercept;
  }

  HistorySeries get current {
    if (series.isEmpty) {
      series.add(HistorySeries());
    }

    // There will always be at least one series
    // because we created it above if it doesn't exist
    return series.last;
  }

  int get predictedOutageTimestamp {
    return best.regressor.xIntercept;
  }

  HistorySeries get previous {
    return series.length > 1 ? series[series.length - 2] : current;
  }

  int get totalPoints {
    return series.fold(0, (sum, s) => sum + s.observations.length);
  }

  /// Adds a new data point to the history series.
  /// [timestamp] represents the time of the data point in milliseconds since epoch. This value cannot be zero.
  /// [amount] represents the amount of inventory.
  /// [householdCount] represents the number of people living in the household.
  /// Requirements:
  /// - Function will fail if [timestamp] is zero.
  /// - We only care about decreasing values. If the series is empty,
  ///   a single zero amount will be discarded.
  /// - Create a new series if necessary.
  /// - If this is a new series, add the new data point and return.
  /// - If the amount is within the minimum offset, we update the timestamp only.
  /// - If the amount is greater than the last amount, start a new series
  ///     and add the new data point.
  /// - If the amount was decreased add the amount.
  /// - If we predicted the amount to be 0 before the user set it to zero,
  ///     choose the predicted timestamp as the timestamp, assuming that
  ///     the user likely updated the amount after the fact.
  void add(int timestamp, double amount, int householdCount, {int minOffsetHours = 24}) {
    assert(timestamp != 0); // Timestamp cannot be a placeholder value

    // There is not any point in making a HistorySeries where the only
    // entry is 0. We can't use a single 0 value for prediction purposes.
    // Do not add the value under these circumstances.
    if (current.observations.isEmpty && amount == 0) {
      return;
    }

    // Create a new observation
    var observation = Observation(
      timestamp: timestamp.toDouble(),
      amount: amount,
      householdCount: householdCount,
    );

    // If the series is empty, start a new series
    if (series.isEmpty) {
      series.add(HistorySeries());
    }

    // Check if current.observations is empty. If so, we only need
    // to add the single non-zero value.
    if (current.observations.isEmpty) {
      current.observations.add(observation);
      return;
    }

    // Get the last observation in the current series
    var lastObservation = current.observations.last;

    // Calculate the time difference between the new observation and the last one
    var timeDifference = observation.timestamp - lastObservation.timestamp;

    // Define the minimum time offset in ms (specified by minOffsetHours)
    final minOffset = minOffsetHours * 60 * 60 * 1000;

    // If the time difference is less than the minimum offset, update the last observation
    if (timeDifference < minOffset) {
      current.observations.removeLast();
      current.observations.add(observation);
    }

    // Otherwise, add the new observation as usual
    else {
      // If the new observation's amount is greater than the last one,
      // start a new series and add the new observation
      if (observation.amount > lastObservation.amount) {
        // If the predicted outage timestamp is earlier than the new timestamp, add a zero amount observation
        if (predictedOutageTimestamp < timestamp) {
          current.observations.add(Observation(
            timestamp: predictedOutageTimestamp.toDouble(),
            amount: 0,
            householdCount: householdCount,
          ));
        }

        // Start a new series
        series.add(HistorySeries());
        current.observations.add(observation);
      }

      // If the new observation's amount is the same as the last one, do nothing

      // If the new observation's amount is less than the last one, add the new observation
      else if (observation.amount < lastObservation.amount) {
        // If the new observation's amount is zero and the predicted outage timestamp is earlier than the new timestamp,
        // add a zero amount observation
        if (observation.amount == 0 && predictedOutageTimestamp < timestamp) {
          current.observations.add(Observation(
            timestamp: predictedOutageTimestamp.toDouble(),
            amount: 0,
            householdCount: householdCount,
          ));
        } else {
          current.observations.add(observation);
        }
      }
    }
  }

  // Remove any invalid observations from the history
  // (This means any series where there is only a 0 value,
  // or the timestamp is 0)
  MLHistory clean() {
    for (final s in series) {
      // There was only one observation with amount 0, so remove it
      if (s.observations.length == 1 && s.observations.first.amount == 0) {
        s.observations.clear();
      }
      // Remove any observations with placeholder timestamps
      else {
        s.observations.removeWhere((o) => o.timestamp == 0);
      }
    }

    trim();
    return this;
  }

  double predict(int timestamp) {
    // Note that if this series is empty, it will predict based on the last series
    return best.regressor.predict(timestamp);
  }

  // Remove any empty series values in the history
  MLHistory trim() {
    series.removeWhere((s) => s.observations.isEmpty);
    return this;
  }
}
