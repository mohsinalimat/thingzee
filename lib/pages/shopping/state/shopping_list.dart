import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:repository/model/item.dart';
import 'package:repository/repository.dart';
import 'package:thingzee/app.dart';

final shoppingListProvider = StateNotifierProvider<ShoppingList, ShoppingListState>((ref) {
  return ShoppingList(App.repo);
});

class ShoppingList extends StateNotifier<ShoppingListState> {
  final Repository repo;

  ShoppingList(this.repo) : super(ShoppingListState([], {}));

  // void refresh() {
  //   state = state.copyWith(
  //     items: ,
  //     checked: state.items.fold<Map<String, bool>>(
  //       {},
  //       (checked, product) => checked..putIfAbsent(product.upc, () => false),
  //     ),
  //   );
  // }
  void check(int index, bool value) {
    final items = state.items;
    assert(index < items.length);

    var checked = state.checked;
    final item = items[index];

    if (value) {
      checked.add(item.upc);
    } else {
      checked.remove(item.upc);
    }

    state = state.copyWith(
      checked: checked,
    );
  }

  bool isChecked(int index) {
    final items = state.items;
    assert(index < items.length);

    final item = items[index];
    return state.checked.contains(item.upc);
  }

  void removeAt(int index) {
    var items = state.items;
    assert(index < items.length);
    final item = items[index];

    // TODO: Turn off restock for this item here if removed from list

    // Remove the item from the list
    items.removeAt(index);

    // Remove the check if present
    var checked = state.checked;
    checked.remove(item.upc);

    state = state.copyWith(
      items: items,
      checked: checked,
    );
  }
}

class ShoppingListState {
  final List<Item> items;
  final Set<String> checked;

  ShoppingListState(this.items, this.checked);

  ShoppingListState copyWith({
    List<Item>? items,
    Set<String>? checked,
  }) {
    return ShoppingListState(
      items ?? this.items,
      checked ?? this.checked,
    );
  }
}
