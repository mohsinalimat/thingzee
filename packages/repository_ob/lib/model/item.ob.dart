import 'dart:core';

import 'package:objectbox/objectbox.dart';
import 'package:repository/model/item.dart';
@Entity()
class ObjectBoxItem {
  @Unique()
  late String upc;
  late String iuid;
  late String name;
  late String variety;
  late String category;
  late String type;
  late int unitCount;
  late String unitName;
  late String unitPlural;
  late String imageUrl;
  late bool consumable;
  late String languageCode;
  List<ItemTranslation> translations = [];
  @Id()
  int id = 0;
  ObjectBoxItem();
  ObjectBoxItem.from(Item original) {
    upc = original.upc;
    iuid = original.iuid;
    name = original.name;
    variety = original.variety;
    category = original.category;
    type = original.type;
    unitCount = original.unitCount;
    unitName = original.unitName;
    unitPlural = original.unitPlural;
    imageUrl = original.imageUrl;
    consumable = original.consumable;
    languageCode = original.languageCode;
    translations = original.translations;
  }
  Item toItem() {
    return Item()
      ..upc = upc
      ..iuid = iuid
      ..name = name
      ..variety = variety
      ..category = category
      ..type = type
      ..unitCount = unitCount
      ..unitName = unitName
      ..unitPlural = unitPlural
      ..imageUrl = imageUrl
      ..consumable = consumable
      ..languageCode = languageCode
      ..translations = translations
    ;
  }
}
@Entity()
class ObjectBoxItemTranslation {
  late String languageCode;
  late String name;
  late String variety;
  late String unitName;
  late String unitPlural;
  @Id()
  int id = 0;
  ObjectBoxItemTranslation();
  ObjectBoxItemTranslation.from(ItemTranslation original) {
    languageCode = original.languageCode;
    name = original.name;
    variety = original.variety;
    unitName = original.unitName;
    unitPlural = original.unitPlural;
  }
  ItemTranslation toItemTranslation() {
    return ItemTranslation()
      ..languageCode = languageCode
      ..name = name
      ..variety = variety
      ..unitName = unitName
      ..unitPlural = unitPlural
    ;
  }
}
