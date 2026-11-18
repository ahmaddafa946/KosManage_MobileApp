import 'dart:math' as math;

import 'maintenance_text_features.dart';
import 'maintenance_training_data.dart';

/// Linear one-vs-rest SVM for maintenance report text.
///
/// Uses TF-IDF features and deterministic Pegasos-style hinge-loss training.
/// The bundled examples are a development seed, not a validated dataset.
/// [decisionScore] and [marginGap] are raw margins, never percentages.
class MaintenanceSvm {
  const MaintenanceSvm();

  static const double _regularization = 0.01;
  static const int _epochs = 100;
  static const double _minimumReviewMargin = 0.05;
  static final _SvmModel _model = _trainModel();

  MaintenanceSvmPrediction predict({
    required String title,
    required String description,
  }) {
    final tokens = tokenizeMaintenanceText('$title $description');
    if (tokens.isEmpty) {
      return const MaintenanceSvmPrediction(
        category: 'other',
        decisionScore: 0,
        marginGap: 0,
        needsReview: true,
      );
    }

    final vector = _vectorize(
      tokens,
      _model.vocabulary,
      _model.inverseDocumentFrequency,
    );
    if (vector.isEmpty) {
      return const MaintenanceSvmPrediction(
        category: 'other',
        decisionScore: 0,
        marginGap: 0,
        needsReview: true,
      );
    }

    final scores = _model.weights.entries
        .map(
          (entry) => MapEntry(
            entry.key,
            _dot(entry.value, vector),
          ),
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = scores.first;
    final second = scores.length > 1 ? scores[1].value : 0.0;
    final marginGap = best.value - second;

    return MaintenanceSvmPrediction(
      category: best.key,
      decisionScore: best.value,
      marginGap: marginGap,
      needsReview: marginGap < _minimumReviewMargin,
    );
  }

  static _SvmModel _trainModel() {
    final tokenizedDocuments = maintenanceTrainingExamples
        .map((example) => tokenizeMaintenanceText(example.text))
        .toList(growable: false);

    final documentFrequency = <String, int>{};
    for (final tokens in tokenizedDocuments) {
      for (final token in tokens.toSet()) {
        documentFrequency.update(
          token,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final vocabulary = <String, int>{};
    for (final token in documentFrequency.keys.toList()..sort()) {
      vocabulary[token] = vocabulary.length;
    }

    final documentCount = tokenizedDocuments.length;
    final inverseDocumentFrequency = List<double>.filled(
      vocabulary.length,
      0,
    );
    for (final entry in vocabulary.entries) {
      final frequency = documentFrequency[entry.key] ?? 0;
      inverseDocumentFrequency[entry.value] =
          math.log((documentCount + 1) / (frequency + 1)) + 1;
    }

    final vectors = tokenizedDocuments
        .map(
          (tokens) => _vectorize(
            tokens,
            vocabulary,
            inverseDocumentFrequency,
          ),
        )
        .toList(growable: false);

    final categories = maintenanceCategoryValues;
    final models = <String, List<double>>{};

    for (var categoryIndex = 0;
        categoryIndex < categories.length;
        categoryIndex++) {
      final category = categories[categoryIndex];
      final weights = List<double>.filled(vocabulary.length, 0);
      final order = List<int>.generate(vectors.length, (index) => index);
      final random = math.Random(410 + categoryIndex);
      var step = 0;

      for (var epoch = 0; epoch < _epochs; epoch++) {
        order.shuffle(random);
        for (final documentIndex in order) {
          step++;
          final label =
              maintenanceTrainingExamples[documentIndex].category == category
                  ? 1.0
                  : -1.0;
          final learningRate = 1 / (_regularization * step);
          final shrink = 1 - learningRate * _regularization;

          for (var index = 0; index < weights.length; index++) {
            weights[index] *= shrink;
          }

          final vector = vectors[documentIndex];
          if (label * _dot(weights, vector) < 1) {
            for (final feature in vector.entries) {
              weights[feature.key] +=
                  learningRate * label * feature.value;
            }
          }

          _project(weights);
        }
      }

      models[category] = weights;
    }

    return _SvmModel(
      vocabulary: vocabulary,
      inverseDocumentFrequency: inverseDocumentFrequency,
      weights: models,
    );
  }

  static Map<int, double> _vectorize(
    List<String> tokens,
    Map<String, int> vocabulary,
    List<double> inverseDocumentFrequency,
  ) {
    final counts = <String, int>{};
    for (final token in tokens) {
      if (vocabulary.containsKey(token)) {
        counts.update(token, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final vector = <int, double>{};
    for (final entry in counts.entries) {
      final index = vocabulary[entry.key]!;
      final termFrequency = 1 + math.log(entry.value.toDouble());
      vector[index] = termFrequency * inverseDocumentFrequency[index];
    }

    final norm = math.sqrt(
      vector.values.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (norm == 0) return const <int, double>{};

    for (final index in vector.keys.toList()) {
      vector[index] = vector[index]! / norm;
    }
    return vector;
  }

  static double _dot(List<double> weights, Map<int, double> vector) {
    var score = 0.0;
    for (final feature in vector.entries) {
      score += weights[feature.key] * feature.value;
    }
    return score;
  }

  static void _project(List<double> weights) {
    final squaredNorm = weights.fold<double>(
      0,
      (sum, value) => sum + value * value,
    );
    final maximumNorm = 1 / math.sqrt(_regularization);
    final norm = math.sqrt(squaredNorm);
    if (norm <= maximumNorm || norm == 0) return;

    final scale = maximumNorm / norm;
    for (var index = 0; index < weights.length; index++) {
      weights[index] *= scale;
    }
  }
}

class MaintenanceSvmPrediction {
  const MaintenanceSvmPrediction({
    required this.category,
    required this.decisionScore,
    required this.marginGap,
    required this.needsReview,
  });

  final String category;

  /// Raw one-vs-rest decision margin; it is not a probability.
  final double decisionScore;

  /// Difference between the best and second-best category margins.
  final double marginGap;

  final bool needsReview;
}

class _SvmModel {
  const _SvmModel({
    required this.vocabulary,
    required this.inverseDocumentFrequency,
    required this.weights,
  });

  final Map<String, int> vocabulary;
  final List<double> inverseDocumentFrequency;
  final Map<String, List<double>> weights;
}
