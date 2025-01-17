import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:quiver/core.dart';
import 'package:repository/database/joined_item_database.dart';
import 'package:repository/repository.dart';
import 'package:thingzee/app.dart';

final shoppingCartProvider = StateNotifierProvider<ShoppingCart, ShoppingCartState>((ref) {
  return ShoppingCart(App.repo);
});

class ShoppingCart extends StateNotifier<ShoppingCartState> {
  final Repository repo;

  ShoppingCart(this.repo) : super(ShoppingCartState(items: []));

  void add(JoinedItem item) {
    state = state.copyWith(
      items: [...state.items, item],
    );
  }

  void remove(JoinedItem item) {
    state = state.copyWith(
      items: state.items..remove(item),
    );
  }

  void removeAt(int index) {
    state = state.copyWith(
      items: state.items..removeAt(index),
    );
  }

  void completeTrip() {
    for (final item in state.items) {
      // Pull the latest version from the database
      var latestInventory = repo.inv.get(item.inventory.upc);
      var inventory = latestInventory.orNull ?? item.inventory;

      // User might not have updated the amount in a while.
      // Update the amount to the predicted amount before we increment
      // it. Still not totally accurate, but should be better
      // than using a old likely inaccurate amount.
      if (inventory.canPredict) {
        inventory.amount = inventory.predictedAmount.roundToDouble();
      }

      final now = DateTime.now();
      inventory.amount += 1;
      inventory.history.add(now.millisecondsSinceEpoch, inventory.amount, 2);
      inventory.lastUpdate = Optional.of(now);

      repo.inv.put(inventory);
    }

    state = state.copyWith(
      items: [],
    );
  }
}

class ShoppingCartState {
  final List<JoinedItem> items;
  final Map<String, double> prices = {};

  ShoppingCartState({required this.items});

  ShoppingCartState copyWith({
    List<JoinedItem>? items,
  }) {
    return ShoppingCartState(
      items: items ?? this.items,
    );
  }
}
