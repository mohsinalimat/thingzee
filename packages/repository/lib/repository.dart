import 'package:repository/database/history_database.dart';
import 'package:repository/database/inventory_database.dart';
import 'package:repository/database/item_database.dart';

abstract class Repository {
  bool ready = false;
  bool get isMultiUser => false;

  late ItemDatabase items;
  late InventoryDatabase inv;
  late HistoryDatabase hist;
}

abstract class SharedRepository extends Repository {
  @override
  bool get isMultiUser => true;
  bool get loggedIn;

  Future<void> registerUser(String username, String email, String password);
  Future<void> loginUser(String username, String password);
}

class SynchronizedRepository extends SharedRepository {
  final Repository local;
  final SharedRepository remote;

  SynchronizedRepository(this.local, this.remote);

  @override
  bool get isMultiUser => true;

  @override
  bool get loggedIn => remote.loggedIn;

  @override
  Future<void> registerUser(String username, String email, String password) async {
    await remote.registerUser(username, email, password);
  }

  @override
  Future<void> loginUser(String username, String password) async {
    await remote.loginUser(username, password);
  }
}
