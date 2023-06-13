import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_linalg/matrix.dart';
import 'package:ml_linalg/vector.dart';
import 'package:repository/ml/normalizer.dart';
import 'package:repository/ml/observation.dart';
import 'package:repository/ml/ols_regressor.dart';

class EmptyRegressor implements Regressor {
  @override
  bool get hasXIntercept => false;

  @override
  bool get hasSlope => false;

  @override
  double get slope => 0;

  @override
  int get xIntercept => 0;

  @override
  double predict(int x) {
    return 0;
  }
}

class HoltLinearRegressor extends Regressor {
  final List<MapEntry<int, double>> data;
  final double alpha;
  final double beta;
  final int unitDuration;

  HoltLinearRegressor(this.data, this.alpha, this.beta,
      {this.unitDuration = Duration.millisecondsPerDay});

  HoltLinearRegressor.fromMap(Map<int, double> mapData, this.alpha, this.beta,
      {this.unitDuration = Duration.millisecondsPerDay})
      : data = mapData.entries.toList();

  @override
  bool get hasXIntercept => true;

  @override
  bool get hasSlope => true;

  @override
  double get slope {
    _HoltLinearResult result = _calculateHoltLinear();
    // Return the final calculated trend as the slope.
    return result.trend;
  }

  @override
  int get xIntercept {
    _HoltLinearResult result = _calculateHoltLinear();

    // The time when the trend hits zero is when level + dt * trend = 0, solving for dt gives.
    int dtZero = (-result.level / result.trend).round();

    // Return the timestamp when the trend is expected to hit zero.
    return data.last.key + dtZero * unitDuration;
  }

  @override
  double predict(int x) {
    _HoltLinearResult result = _calculateHoltLinear();

    // Estimate the time difference from the last known point to the prediction point.
    int dtPred = (x - data.last.key) ~/ unitDuration;

    // Return the forecasted value.
    return result.level + dtPred * result.trend;
  }

  // A private method to calculate the current level and trend using Holt's Linear Exponential Smoothing.
  _HoltLinearResult _calculateHoltLinear() {
    // Define the initial level and trend.
    double level = data[0].value;
    double trend = data[1].value - data[0].value;

    // Iteratively apply Holt's Linear Exponential Smoothing.
    for (var i = 1; i < data.length; i++) {
      // Calculate the time difference between current and previous timestamp.
      int dt = (data[i].key - data[i - 1].key) ~/ unitDuration;

      // Adjust level and trend for the elapsed time.
      double oldLevel = level;
      level = alpha * data[i].value + (1 - alpha) * (level + dt * trend);
      trend = beta * (level - oldLevel) / dt + (1 - beta) * trend;
    }

    return _HoltLinearResult(level, trend);
  }
}

class MLLinearRegressor implements Regressor {
  final LinearRegressor regressor;
  final Normalizer normalizer;

  MLLinearRegressor(this.regressor, this.normalizer);

  @override
  bool get hasXIntercept => true;

  @override
  bool get hasSlope => false;

  @override
  double get slope => 0;

  @override
  int get xIntercept {
    // Define the search window for timestamps.
    double lowerBound = DateTime.now().millisecondsSinceEpoch.toDouble();
    double upperBound = lowerBound + 30 * 24 * 60 * 60 * 1000; // 30 days

    double predictedAmount;
    double mid;

    // Check if the upper bound is high enough
    var observation = Observation(
      timestamp: upperBound,
      amount: 0,
      householdCount: 2,
    );

    var matrix = Matrix.fromRows([Vector.fromList(observation.normalize(normalizer))]);
    var dataframe = DataFrame.fromMatrix(matrix);
    predictedAmount = regressor.predict(dataframe)[0].data.first;

    // If the predicted amount at the upper bound is above zero,
    // continuously double the upper bound until the predicted amount is below zero.
    while (predictedAmount > 0) {
      upperBound *= 2;

      observation = Observation(
        timestamp: upperBound,
        amount: 0,
        householdCount: 2,
      );

      matrix = Matrix.fromRows([Vector.fromList(observation.normalize(normalizer))]);
      dataframe = DataFrame.fromMatrix(matrix);
      predictedAmount = regressor.predict(dataframe)[0].data.first;
    }

    // Perform binary search
    int counter = 0;
    while ((upperBound - lowerBound).abs() > 1 && counter < 50) {
      mid = (lowerBound + upperBound) / 2;

      observation = Observation(
        timestamp: mid,
        amount: 0,
        householdCount: 2,
      );

      matrix = Matrix.fromRows([Vector.fromList(observation.normalize(normalizer))]);
      dataframe = DataFrame.fromMatrix(matrix);
      predictedAmount = regressor.predict(dataframe)[0].data.first;

      if (predictedAmount > 0) {
        lowerBound = mid;
      } else {
        upperBound = mid;
      }

      counter++;
    }

    // Return the timestamp when amount runs out
    return upperBound.round();
  }

  @override
  double predict(int x) {
    var observation = Observation(
      timestamp: x.toDouble(),
      amount: 0,
      householdCount: 2,
    );

    final vector = Vector.fromList(observation.normalize(normalizer));
    final matrix = Matrix.fromRows([vector]);
    var dataframe = DataFrame.fromMatrix(matrix, header: Observation.header);

    final df = dataframe.dropSeries(names: [regressor.targetName]);

    var predicted = regressor.predict(df);
    return predicted[0].data.first;
  }
}

class NaiveRegressor implements Regressor {
  final List<MapEntry<int, double>> data;
  final int unitDuration;

  NaiveRegressor(this.data, {this.unitDuration = Duration.millisecondsPerDay});

  NaiveRegressor.fromMap(Map<int, double> map, {int unitDuration = Duration.millisecondsPerDay})
      : this(map.entries.toList(), unitDuration: unitDuration);

  @override
  bool get hasXIntercept => true;

  @override
  bool get hasSlope => true;

  @override
  double get slope {
    // Calculate the time difference between the last two timestamps
    int dt = (data.last.key - data[data.length - 2].key) ~/ unitDuration;

    // Calculate the value difference between the last two points
    double dv = data.last.value - data[data.length - 2].value;

    // Calculate the trend
    return dv / dt;
  }

  @override
  int get xIntercept {
    // Calculate the time difference between the last two timestamps
    int dt = (data.last.key - data[data.length - 2].key) ~/ unitDuration;

    // Calculate the value difference between the last two points
    double dv = data.last.value - data[data.length - 2].value;

    // Calculate the trend
    double trend = dv / dt;

    // Calculate the time at which the trend line crosses the x-axis
    return (data.last.key - (data.last.value / trend) * unitDuration).toInt();
  }

  @override
  double predict(int timestamp) {
    // Calculate the time difference between the last two timestamps
    int dt = (data.last.key - data[data.length - 2].key) ~/ unitDuration;

    // Calculate the value difference between the last two points
    double dv = data.last.value - data[data.length - 2].value;

    // Calculate the trend
    double trend = dv / dt;

    // Estimate the time difference from the last known point to the prediction point
    int dtPred = (timestamp - data.last.key) ~/ unitDuration;

    // Return the forecasted value
    return data.last.value + dtPred * trend;
  }
}

abstract class Regressor {
  bool get hasXIntercept;
  bool get hasSlope;
  double get slope;
  int get xIntercept;
  double predict(int x);
}

class SimpleLinearRegressor implements Regressor {
  late double _intercept;
  late double _slope;

  SimpleLinearRegressor(Map<int, double> dataPoints) {
    final xValues = dataPoints.keys.toList();
    final yValues = dataPoints.values.toList();

    // Calculate the means of x and y
    final xMean = xValues.reduce((a, b) => a + b) / xValues.length;
    final yMean = yValues.reduce((a, b) => a + b) / yValues.length;

    // Calculate slope (m) and intercept (c) for y = mx + c
    var numerator = 0.0;
    var denominator = 0.0;

    for (var i = 0; i < xValues.length; i++) {
      numerator += (xValues[i] - xMean) * (yValues[i] - yMean);
      denominator += (xValues[i] - xMean) * (xValues[i] - xMean);
    }

    _slope = numerator / denominator;
    _intercept = yMean - _slope * xMean;
  }

  @override
  bool get hasXIntercept => true;

  @override
  bool get hasSlope => true;

  @override
  double get slope => _slope;

  @override
  int get xIntercept {
    return (-_intercept / _slope).round();
  }

  @override
  double predict(int x) {
    return _slope * x + _intercept;
  }
}

class SimpleOLSRegressor implements Regressor {
  final OLSRegressor regressor;
  final Normalizer normalizer;

  SimpleOLSRegressor(this.regressor, this.normalizer);

  @override
  bool get hasXIntercept => false;

  @override
  bool get hasSlope => false;

  @override
  double get slope => 0;

  @override
  int get xIntercept => 0;

  @override
  double predict(int x) {
    var observation = Observation(
      timestamp: x.toDouble(),
      amount: 0,
      householdCount: 2,
    );

    final vector = Vector.fromList(observation.normalize(normalizer));
    final matrix = Matrix.fromRows([vector]);

    var dataframe = DataFrame.fromMatrix(matrix, header: Observation.header);
    dataframe = dataframe.dropSeries(names: [regressor.target]);

    var predicted = regressor.predict(dataframe);
    return predicted;
  }
}

class SingleDataPointLinearRegressor implements Regressor {
  final double intercept;

  SingleDataPointLinearRegressor(this.intercept);

  @override
  bool get hasXIntercept => false;

  @override
  bool get hasSlope => false;

  @override
  double get slope => 0;

  @override
  int get xIntercept => 0;

  @override
  double predict(int x) {
    return intercept;
  }
}

class TwoPointLinearRegressor implements Regressor {
  final double _slope;
  final double _intercept;

  TwoPointLinearRegressor(this._slope, this._intercept);
  TwoPointLinearRegressor.fromPoints(int x1, double y1, int x2, double y2)
      : _slope = (y2 - y1) / (x2 - x1),
        _intercept = y1 - (y2 - y1) / (x2 - x1) * x1;

  @override
  bool get hasXIntercept => true;

  @override
  bool get hasSlope => true;

  @override
  double get slope => _slope;

  @override
  int get xIntercept {
    return (-_intercept / _slope).round();
  }

  double get yIntercept => _intercept;

  @override
  double predict(int x) {
    return _slope * x + _intercept;
  }
}

class _HoltLinearResult {
  final double level;
  final double trend;

  _HoltLinearResult(this.level, this.trend);
}
