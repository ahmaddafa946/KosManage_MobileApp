/// Shared text normalization for the maintenance classifiers.
List<String> tokenizeMaintenanceText(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll('ac/elektronik', 'ac elektronik')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');

  return normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 1)
      .toList(growable: false);
}
