import 'package:flutter/foundation.dart';

/// Coordinates catalog reloads between screens in the same app instance.
class CatalogRefreshController extends ChangeNotifier {
  CatalogRefreshController._();

  static final CatalogRefreshController instance = CatalogRefreshController._();

  int _revision = 0;

  int get revision => _revision;

  void catalogChanged() {
    _revision++;
    notifyListeners();
  }
}
