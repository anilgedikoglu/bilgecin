import 'any_result.dart';

class ThingEntry {
  final String name;
  final String mainType;
  final String subType;
  final List<int> attrs; // 160 boolean cols (CSV 3-162)
  final int popularityScore; // CSV col 163
  final String colorCommon;   // col 164
  final String materialCommon;// col 165
  final String placeCommon;   // col 166
  final String category;      // col 167
  final String knownFor;      // col 168

  ThingEntry({
    required this.name,
    required this.mainType,
    required this.subType,
    required this.attrs,
    required this.popularityScore,
    required this.colorCommon,
    required this.materialCommon,
    required this.placeCommon,
    required this.category,
    required this.knownFor,
  });

  // CSV column index = attrIndex[attr] + 3
  static const Map<String, int> attrIndex = {
    'is_person':                     0,
    'is_character':                  1,
    'is_real':                       2,
    'is_fictional':                  3,
    'is_physical':                   4,
    'is_tangible':                   5,
    'is_living':                     6,
    'is_human':                      7,
    'is_animal':                     8,
    'is_plant':                      9,
    'is_food':                       10,
    'is_drink':                      11,
    'is_manmade':                    12,
    'is_natural':                    13,
    'is_object':                     14,
    'is_tool':                       15,
    'is_household':                  16,
    'is_kitchen':                    17,
    'is_vehicle':                    18,
    'is_place':                      19,
    'is_event':                      20,
    'is_abstract':                   21,
    'is_brand':                      22,
    'is_digital':                    23,
    'is_proper_name':                24,
    'is_turkish':                    25,
    'is_global':                     26,
    'is_edible':                     27,
    'is_electric':                   28,
    'is_motorized':                  29,
    'is_handheld':                   30,
    'is_wearable':                   31,
    'is_dangerous':                  32,
    'is_used_daily':                 33,
    'is_found_at_home':              34,
    'is_found_in_nature':            35,
    'is_used_for_work':              36,
    'is_used_for_fun':               37,
    'is_sleep_related':              38,
    'is_mind_related':               39,
    'is_health_related':             40,
    'is_water_related':              41,
    'is_fire_related':               42,
    'is_air_related':                43,
    'is_space_related':              44,
    'is_money_related':              45,
    'is_religious_or_spiritual':     46,
    'is_sport_related':              47,
    'is_music_related':              48,
    'is_school_related':             49,
    'is_child_friendly':             50,
    'is_large':                      51,
    'is_small':                      52,
    'can_move_by_itself':            53,
    'can_be_seen':                   54,
    'can_be_heard':                  55,
    'can_be_smelt':                  56,
    'can_be_touched':                57,
    'is_brand_or_model':             58,
    'is_generic_type':               59,
    'is_specific_product':           60,
    'is_accessory':                  61,
    'is_clothing':                   62,
    'is_watch_related':              63,
    'is_clock_or_watch':             64,
    'is_wrist_worn':                 65,
    'is_digital_watch':              66,
    'is_analog_watch':               67,
    'is_smartwatch':                 68,
    'is_luxury_brand':               69,
    'is_affordable_brand':           70,
    'is_japanese_brand':             71,
    'is_swiss_brand':                72,
    'is_american_brand':             73,
    'is_korean_brand':               74,
    'is_chinese_brand':              75,
    'has_smartwatch':                76,
    'known_for_durable_watches':     77,
    'known_for_military_style':      78,
    'known_for_classic_design':      79,
    'known_for_sports_use':          80,
    'known_for_fashion':             81,
    'known_for_premium_quality':     82,
    'known_for_affordable_products': 83,
    'is_phone_related':              84,
    'is_computer_related':           85,
    'is_game_related':               86,
    'is_app_related':                87,
    'is_car_brand':                  88,
    'is_car_model':                  89,
    'is_social_media':               90,
    'is_tool_for_repair':            91,
    'is_cutting_tool':               92,
    'is_holding_tool':               93,
    'is_measuring_tool':             94,
    'is_writing_tool':               95,
    'is_cleaning_tool':              96,
    'is_cooking_tool':               97,
    'is_eating_tool':                98,
    'is_furniture':                  99,
    'is_bathroom_item':              100,
    'is_bedroom_item':               101,
    'is_living_room_item':           102,
    'is_office_item':                103,
    'is_outdoor_item':               104,
    'is_pet':                        105,
    'is_wild_animal':                106,
    'is_farm_animal':                107,
    'can_fly':                       108,
    'lives_in_water':                109,
    'lives_on_land':                 110,
    'is_insect':                     111,
    'is_mammal':                     112,
    'is_bird':                       113,
    'is_reptile':                    114,
    'is_fish':                       115,
    'is_fruit':                      116,
    'is_vegetable':                  117,
    'is_tree':                       118,
    'is_flower':                     119,
    'is_spice':                      120,
    'is_sweet':                      121,
    'is_sour':                       122,
    'is_hot':                        123,
    'is_cold':                       124,
    'is_liquid':                     125,
    'is_solid':                      126,
    'is_gas':                        127,
    'is_weather_related':            128,
    'is_sky_related':                129,
    'is_earth_related':              130,
    'is_metal':                      131,
    'is_wood':                       132,
    'is_plastic':                    133,
    'is_glass':                      134,
    'is_fabric':                     135,
    'is_leather':                    136,
    'is_ceramic':                    137,
    'is_paper':                      138,
    'is_software':                   139,
    'is_internet_related':           140,
    'is_online_service':             141,
    'is_mobile_app':                 142,
    'is_video_game':                 143,
    'is_board_game':                 144,
    'is_city':                       145,
    'is_country':                    146,
    'is_building':                   147,
    'is_room':                       148,
    'is_natural_place':              149,
    'is_historical_place':           150,
    'is_emotion':                    151,
    'is_positive':                   152,
    'is_negative':                   153,
    'is_time_related':               154,
    'is_law_related':                155,
    'is_health_condition':           156,
    'is_symptom':                    157,
    'is_profession':                 158,
    'is_symbol':                     159,
  };

  int _a(int i) => i < attrs.length ? attrs[i] : 0;

  int getAttribute(String attr) {
    switch (attr) {
      case 'is_food_or_drink':    return (_a(10) == 1 || _a(11) == 1) ? 1 : 0;
      case 'is_digital_or_brand': return (_a(22) == 1 || _a(23) == 1) ? 1 : 0;
      case 'popularity_high':     return popularityScore >= 90 ? 1 : 0;
    }
    final idx = attrIndex[attr];
    if (idx == null) return 0;
    return _a(idx);
  }

  AnyResult toResult() => AnyResult(
    name:        name,
    category:    category,
    description: knownFor,
    isPerson:    false,
  );

  factory ThingEntry.fromCsvRow(List<String> row) {
    int p(int i) => i < row.length ? (int.tryParse(row[i].trim()) ?? 0) : 0;
    return ThingEntry(
      name:           row[0].trim(),
      mainType:       row.length > 1   ? row[1].trim()   : '',
      subType:        row.length > 2   ? row[2].trim()   : '',
      attrs:          List<int>.generate(160, (i) => p(i + 3)),
      popularityScore: p(163),
      colorCommon:    row.length > 164 ? row[164].trim() : '',
      materialCommon: row.length > 165 ? row[165].trim() : '',
      placeCommon:    row.length > 166 ? row[166].trim() : '',
      category:       row.length > 167 ? row[167].trim() : '',
      knownFor:       row.length > 168 ? row[168].trim() : '',
    );
  }

  @override
  String toString() => name;
}
