import 'dart:math';
import '../models/thing_entry.dart';
import '../models/any_result.dart';
import 'game_engine.dart' show AnswerType, AnswerTypeExt, AskedQuestion;

// ── Question definition with rich metadata ────────────────────────────────────
class _QDef {
  final String       attr;
  final String       text;
  final String       domain;   // 'core'|'animal'|'plant_food'|'object'|'digital'|'brand'|'place'|'abstract'|'health'|'space'|'natural'|'vehicle'|'watch'|'material'
  final int          tier;     // 1=earliest, 5=most specific
  final List<String> reqAny;   // any of these 'attr:val' must be in _known to unlock
  final double       confusion; // 0–1 penalty for ambiguous questions

  const _QDef(this.attr, this.text, this.domain, this.tier,
      {this.reqAny = const [], this.confusion = 0.0});
}

// ─────────────────────────────────────────────────────────────────────────────
class ThingEngine {
  final List<ThingEntry>        _all;
  List<ThingEntry>              _candidates;
  final Map<ThingEntry, double> _scores  = {};
  final Map<ThingEntry, double> _popBias = {};
  final List<String>            _asked   = [];
  final List<AskedQuestion>     _history = [];
  final Map<String, int>        _known   = {}; // attr → 0|1 (established facts)
  int     _questionCount = 0;
  late    String _currentAttribute;
  String? _forceBranch;

  // ── Tuning ─────────────────────────────────────────────────────────────────
  static const int    autoGuessAt      = 1;
  static const int    differentiatorAt = 10;
  static const int    maxQuestions     = 18;
  static const double matchMag         = 0.5;
  static const double mismatchMag      = 1.6;

  // Elimination threshold: -1.6 = one definitive mismatch (mag 1.6)
  // Keep static at -1.2 so any definitive mismatch eliminates candidates.
  static const double _elimThreshold = -1.2;

  // Multi-factor scoring weights — IG dominates; others are gentle tiebreakers
  static const double _wIG        = 1.0;
  static const double _wSplit     = 0.2;   // mild balance correction
  static const double _wDomain    = 0.1;   // very weak domain hint
  static const double _wTier      = 0.15;  // prefer earlier-tier questions
  static const double _wConfusion = 0.15;  // mild confusion penalty

  // ── Question definitions ───────────────────────────────────────────────────
  static const List<_QDef> _kDefs = [
    // ── Core broad (tier 1-2) ───────────────────────────────────────────────
    _QDef('can_be_touched',  'Bu şey elle dokunulabilir mi?',                    'core', 1),
    _QDef('is_living',       'Bu şey canlı mı?',                                 'core', 1),
    _QDef('is_object',       'Bu şey elle tutulabilen bir nesne mi?',             'core', 1),
    _QDef('is_handheld',     'Bu şey tek elle taşınabilir mi?',                  'core', 1),
    _QDef('is_physical',     'Bu şey fiziksel olarak var mı?',                   'core', 1),
    _QDef('is_manmade',      'Bu şey insan yapımı mı?',                          'core', 2),
    _QDef('is_natural',      'Bu şey doğada kendiliğinden var mı?',              'core', 2),
    // ── Broad types (tier 2) ───────────────────────────────────────────────
    _QDef('is_animal',       'Bu şey bir hayvan mı?',                            'animal',     2),
    _QDef('is_plant',        'Bu şey bir bitki mi?',                             'plant_food', 2),
    _QDef('is_food',         'Bu şey yiyecek mi?',                               'plant_food', 2),
    _QDef('is_drink',        'Bu şey içecek mi?',                                'plant_food', 2),
    _QDef('is_food_or_drink','Bu şey yiyecek veya içecek mi?',                   'plant_food', 2, confusion: 0.3),
    _QDef('is_vehicle',      'Bu şey bir taşıt mı?',                             'vehicle',    2),
    _QDef('is_place',        'Bu şey bir yer mi?',                               'place',      2),
    _QDef('is_abstract',     'Bu şey soyut bir kavram veya duygu mu?',           'abstract',   2),
    _QDef('is_event',        'Bu şey bir olay veya durum mu?',                   'abstract',   3),
    _QDef('is_brand',        'Bu şey bir marka mı?',                             'brand',      2),
    _QDef('is_digital',      'Bu şey elektronik cihaz veya yazılım mı?',         'digital',    2),
    _QDef('is_digital_or_brand','Bu şey marka veya dijital ürün mü?',            'digital',    3, confusion: 0.3),
    _QDef('is_person',       'Bu şey bir kişi mi?',                              'core',       2),
    _QDef('is_character',    'Bu şey bir karakter veya figür mü?',               'core',       3),
    _QDef('is_fictional',    'Bu şey kurgusal mı?',                              'core',       2),
    // ── Object domain (tier 3) ─────────────────────────────────────────────
    _QDef('is_tool',         'Bu şey bir el aleti mi?',                          'object', 3),
    _QDef('is_household',    'Bu şey bir ev eşyası mı?',                         'object', 3),
    _QDef('is_kitchen',      'Bu şey mutfakta kullanılır mı?',                   'object', 3),
    _QDef('is_wearable',     'Bu şey giyilebilir veya takılabilir mi?',          'object', 3),
    _QDef('is_accessory',    'Bu şey bir aksesuar mı?',                          'object', 3),
    _QDef('is_clothing',     'Bu şey bir giysi mi?',                             'object', 3),
    _QDef('is_furniture',    'Bu şey bir mobilya mı?',                           'object', 3),
    // ── Physical properties (tier 3) ──────────────────────────────────────
    _QDef('is_found_at_home','Bu şey evde bulunur mu?',                          'core',   3),
    _QDef('is_electric',     'Bu şey elektrikli mi?',                            'object', 3),
    _QDef('is_small',        'Bu şey küçük mü?',                                 'core',   3),
    _QDef('is_large',        'Bu şey büyük mü?',                                 'core',   3),
    _QDef('is_used_daily',   'Bu şey günlük hayatta sık kullanılır mı?',         'core',   3),
    _QDef('is_found_in_nature','Bu şey doğada bulunur mu?',                      'natural', 3),
    _QDef('can_move_by_itself','Bu şey kendi kendine hareket edebilir mi?',      'core',    3),
    _QDef('is_motorized',    'Bu şey motorlu mu?',                               'vehicle', 3),
    _QDef('is_dangerous',    'Bu şey tehlikeli olabilir mi?',                    'core',    4),
    // ── Watch / accessory (tier 3-5) ──────────────────────────────────────
    _QDef('is_watch_related','Bu şey bir saatle ilgili mi?',                     'watch', 3),
    _QDef('is_clock_or_watch','Bu şey bir saat mi?',                             'watch', 4, reqAny: ['is_watch_related:1']),
    _QDef('is_smartwatch',   'Bu şey akıllı saat mi?',                           'watch', 4, reqAny: ['is_watch_related:1']),
    _QDef('is_digital_watch','Bu şey dijital göstergeli bir saat mi?',           'watch', 5, reqAny: ['is_watch_related:1']),
    _QDef('is_analog_watch', 'Bu şey akrep-yelkovanlı klasik saat mi?',         'watch', 5, reqAny: ['is_watch_related:1']),
    // ── Brand attributes (tier 4-5, unlocked by is_brand:1) ───────────────
    _QDef('is_luxury_brand', 'Bu şey lüks bir marka mı?',                        'brand', 4, reqAny: ['is_brand:1']),
    _QDef('is_affordable_brand','Bu şey uygun fiyatlı marka olarak bilinir mi?', 'brand', 4, reqAny: ['is_brand:1']),
    _QDef('is_japanese_brand','Bu şey Japon markası mı?',                        'brand', 5, reqAny: ['is_brand:1']),
    _QDef('is_swiss_brand',  'Bu şey İsviçre markası mı?',                       'brand', 5, reqAny: ['is_brand:1']),
    _QDef('is_american_brand','Bu şey Amerikan markası mı?',                     'brand', 5, reqAny: ['is_brand:1']),
    _QDef('is_korean_brand', 'Bu şey Kore markası mı?',                          'brand', 5, reqAny: ['is_brand:1']),
    _QDef('is_car_brand',    'Bu şey bir araba markası mı?',                     'brand', 4, reqAny: ['is_brand:1']),
    _QDef('is_car_model',    'Bu şey belirli bir araba modeli mi?',              'brand', 4, reqAny: ['is_brand:1', 'is_car_brand:1']),
    // ── Tech domain (tier 4, unlocked by is_digital:1) ────────────────────
    _QDef('is_phone_related','Bu şey telefonla ilgili mi?',                      'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_computer_related','Bu şey bilgisayarla ilgili mi?',                'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_game_related', 'Bu şey oyunla ilgili mi?',                         'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_app_related',  'Bu şey bir uygulama mı?',                          'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_social_media', 'Bu şey sosyal medya platformu mu?',                'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_software',     'Bu şey bir yazılım mı?',                           'digital', 4, reqAny: ['is_digital:1']),
    _QDef('is_mobile_app',   'Bu şey bir mobil uygulama mı?',                    'digital', 5, reqAny: ['is_digital:1']),
    _QDef('is_video_game',   'Bu şey bir video oyunu mu?',                       'digital', 5, reqAny: ['is_digital:1']),
    _QDef('is_board_game',   'Bu şey bir masa oyunu mu?',                        'digital', 5, reqAny: ['is_digital:1', 'is_game_related:1']),
    _QDef('is_online_service','Bu şey web üzerinden çalışan bir servis mi?',     'digital', 5, reqAny: ['is_digital:1']),
    _QDef('is_internet_related','Bu şey internetle bağlantılı mı?',             'digital', 4, reqAny: ['is_digital:1']),
    // ── Tool domain (tier 4) ──────────────────────────────────────────────
    _QDef('is_tool_for_repair','Bu şey tamir veya inşaatta kullanılır mı?',      'object', 4, reqAny: ['is_tool:1', 'is_object:1']),
    _QDef('is_cutting_tool', 'Bu şey kesmek için mi kullanılır?',                'object', 4, reqAny: ['is_tool:1', 'is_object:1']),
    _QDef('is_holding_tool', 'Bu şey bir şeyleri tutmak için mi kullanılır?',    'object', 4, reqAny: ['is_tool:1', 'is_object:1']),
    _QDef('is_measuring_tool','Bu şey ölçmek için mi kullanılır?',               'object', 4, reqAny: ['is_tool:1', 'is_object:1']),
    _QDef('is_cleaning_tool','Bu şey temizlemek için mi kullanılır?',            'object', 4, reqAny: ['is_object:1', 'is_household:1']),
    _QDef('is_writing_tool', 'Bu şey yazmak için mi kullanılır?',                'object', 4, reqAny: ['is_tool:1', 'is_object:1']),
    _QDef('is_cooking_tool', 'Bu şey yemek pişirmek için mi kullanılır?',        'object', 4, reqAny: ['is_kitchen:1', 'is_object:1']),
    _QDef('is_eating_tool',  'Bu şey yemek yemek için mi kullanılır?',           'object', 4, reqAny: ['is_kitchen:1', 'is_object:1']),
    // ── Physical detail (tier 3-4) ────────────────────────────────────────
    _QDef('is_edible',       'Bu şey yenilebilir mi?',                           'plant_food', 3),
    _QDef('is_bathroom_item','Bu şey banyoda bulunur mu?',                       'object', 4),
    _QDef('is_bedroom_item', 'Bu şey yatak odasında bulunur mu?',                'object', 4),
    _QDef('is_living_room_item','Bu şey oturma odasında bulunur mu?',            'object', 4),
    _QDef('is_outdoor_item', 'Bu şey genellikle dışarıda kullanılır mı?',        'object', 4),
    _QDef('is_wrist_worn',   'Bu şey bilek veya kola takılır mı?',               'object', 4, reqAny: ['is_wearable:1', 'is_watch_related:1']),
    // ── Animal domain (tier 4, unlocked by is_animal:1) ───────────────────
    _QDef('is_pet',          'Bu şey evcil hayvan mı?',                          'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_wild_animal',  'Bu şey vahşi/yabani bir hayvan mı?',               'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_farm_animal',  'Bu şey çiftlik hayvanı mı?',                       'animal', 4, reqAny: ['is_animal:1']),
    _QDef('can_fly',         'Bu şey uçabilir mi?',                              'animal', 4, reqAny: ['is_animal:1', 'is_bird:1']),
    _QDef('lives_in_water',  'Bu şey suda yaşar mı?',                            'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_insect',       'Bu şey bir böcek mi?',                             'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_mammal',       'Bu şey memeli bir hayvan mı?',                     'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_bird',         'Bu şey bir kuş mu?',                               'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_reptile',      'Bu şey bir sürüngen mi?',                          'animal', 4, reqAny: ['is_animal:1']),
    _QDef('is_fish',         'Bu şey bir balık mı?',                             'animal', 4, reqAny: ['is_animal:1']),
    // ── Plant / food domain (tier 4, unlocked) ────────────────────────────
    _QDef('is_fruit',        'Bu şey bir meyve mi?',                             'plant_food', 4, reqAny: ['is_food:1', 'is_plant:1', 'is_edible:1']),
    _QDef('is_vegetable',    'Bu şey bir sebze mi?',                             'plant_food', 4, reqAny: ['is_food:1', 'is_plant:1', 'is_edible:1']),
    _QDef('is_tree',         'Bu şey bir ağaç mı?',                              'plant_food', 4, reqAny: ['is_plant:1']),
    _QDef('is_flower',       'Bu şey bir çiçek mi?',                             'plant_food', 4, reqAny: ['is_plant:1']),
    _QDef('is_spice',        'Bu şey bir baharat mı?',                           'plant_food', 4, reqAny: ['is_food:1', 'is_plant:1']),
    _QDef('is_sweet',        'Bu şey tatlı mı?',                                 'plant_food', 4, reqAny: ['is_food:1', 'is_drink:1', 'is_edible:1']),
    _QDef('is_sour',         'Bu şey ekşi mi?',                                  'plant_food', 5, reqAny: ['is_food:1', 'is_edible:1']),
    _QDef('is_liquid',       'Bu şey sıvı mı?',                                  'plant_food', 3),
    _QDef('is_alcoholic',    'Bu şey alkol içeriyor mu?',                        'plant_food', 4, reqAny: ['is_drink:1', 'is_liquid:1']),
    _QDef('is_carbonated',   'Bu şey gazlı mı?',                                 'plant_food', 4, reqAny: ['is_drink:1', 'is_liquid:1']),
    // ── Material (tier 4) ─────────────────────────────────────────────────
    _QDef('is_metal',        'Bu şey metalden yapılmış mı?',                     'material', 4),
    _QDef('is_wood',         'Bu şey ahşaptan yapılmış mı?',                     'material', 4),
    _QDef('is_plastic',      'Bu şey plastikten yapılmış mı?',                   'material', 4),
    _QDef('is_glass',        'Bu şey camdan yapılmış mı?',                       'material', 4),
    _QDef('is_fabric',       'Bu şey kumaştan yapılmış mı?',                     'material', 4, reqAny: ['is_wearable:1', 'is_clothing:1', 'is_furniture:1']),
    _QDef('is_leather',      'Bu şey deriden yapılmış mı?',                      'material', 5, reqAny: ['is_wearable:1', 'is_accessory:1']),
    _QDef('is_paper',        'Bu şey kağıttan yapılmış mı?',                     'material', 4, reqAny: ['is_object:1']),
    // ── Nature / weather / space (tier 3-4) ───────────────────────────────
    _QDef('is_weather_related','Bu şey bir hava olayıyla ilgili mi?',            'natural', 3),
    _QDef('is_sky_related',  'Bu şey gökyüzüyle ilgili mi?',                     'natural', 4),
    _QDef('is_space_related','Bu şey uzayla ilgili mi?',                         'space',   3),
    _QDef('is_water_related','Bu şey suyla ilgili mi?',                          'natural', 3),
    _QDef('is_fire_related', 'Bu şey ateşle ilgili mi?',                         'natural', 4),
    _QDef('is_air_related',  'Bu şey havayla veya uçuşla ilgili mi?',            'natural', 4),
    _QDef('is_earth_related','Bu şey toprak veya zemin işlemeyle ilgili mi?',    'natural', 4),
    _QDef('is_hot',          'Bu şey sıcak mı?',                                 'natural', 4, confusion: 0.2),
    _QDef('is_cold',         'Bu şey soğuk mu?',                                 'natural', 4, confusion: 0.2),
    // ── Place domain (tier 4, unlocked by is_place:1) ─────────────────────
    _QDef('is_city',         'Bu şey bir şehir mi?',                             'place', 4, reqAny: ['is_place:1']),
    _QDef('is_country',      'Bu şey bir ülke mi?',                              'place', 4, reqAny: ['is_place:1']),
    _QDef('is_building',     'Bu şey bir bina veya yapı mı?',                    'place', 4, reqAny: ['is_place:1']),
    _QDef('is_natural_place','Bu şey doğal bir yer mi? (dağ, deniz, orman...)',  'place', 4, reqAny: ['is_place:1']),
    _QDef('is_historical_place','Bu şey tarihi bir yer mi?',                     'place', 5, reqAny: ['is_place:1', 'is_building:1']),
    // ── Abstract / emotion (tier 4, mostly unlocked by is_abstract:1) ─────
    _QDef('is_emotion',      'Bu şey bir duygu mu?',                             'abstract', 4, reqAny: ['is_abstract:1']),
    _QDef('is_positive',     'Bu şey genel olarak olumlu bir şey mi?',           'abstract', 4, reqAny: ['is_abstract:1', 'is_emotion:1']),
    _QDef('is_negative',     'Bu şey genel olarak olumsuz bir şey mi?',          'abstract', 4, reqAny: ['is_abstract:1', 'is_emotion:1']),
    _QDef('is_time_related', 'Bu şey zamanla ilgili mi?',                        'abstract', 4, reqAny: ['is_abstract:1']),
    _QDef('is_mind_related', 'Bu şey zihin veya düşünceyle ilgili mi?',          'abstract', 4),
    _QDef('is_sleep_related','Bu şey uykuyla ilgili mi?',                        'abstract', 5, reqAny: ['is_abstract:1', 'is_health_related:1']),
    _QDef('is_religious_or_spiritual','Bu şey dini veya manevi bir şey mi?',     'abstract', 3),
    _QDef('is_money_related','Bu şey parayla ilgili mi?',                        'abstract', 4),
    _QDef('is_symbol',       'Bu şey bir sembol mü?',                            'abstract', 3),
    // ── Health (tier 3-4) ─────────────────────────────────────────────────
    _QDef('is_health_related','Bu şey sağlıkla ilgili mi?',                      'health', 3),
    _QDef('is_health_condition','Bu şey bir hastalık veya sağlık durumu mu?',    'health', 4, reqAny: ['is_health_related:1']),
    // ── Context / cross-domain (tier 3-4) ─────────────────────────────────
    _QDef('is_sport_related','Bu şey sporla ilgili mi?',                         'core', 3),
    _QDef('is_music_related','Bu şey müzikle ilgili mi?',                        'core', 3),
    _QDef('is_school_related','Bu şey okul veya eğitimle ilgili mi?',            'core', 4),
    _QDef('is_child_friendly','Bu şey çocuklar için uygun mu?',                  'core', 4),
    _QDef('is_turkish',      "Bu şey Türkiye'ye özgü mü?",                       'core', 4),
    _QDef('is_global',       'Bu şey dünya genelinde çok bilinen bir şey mi?',   'core', 4),
    _QDef('is_used_for_fun', 'Bu şey eğlence amaçlı mı?',                       'core', 3),
    _QDef('is_used_for_work','Bu şey iş veya çalışma amacıyla kullanılır mı?',  'core', 4),
  ];

  // Public backward-compat lists derived from _kDefs
  static final List<String>         kAttributes = _kDefs.map((d) => d.attr).toList();
  static final Map<String, String>  kQuestions  = {for (final d in _kDefs) d.attr: d.text};

  // ── Expanded implication table ─────────────────────────────────────────────
  static const Map<String, Map<String, int>> _implications = {
    // Touchable
    'can_be_touched:1': {'is_physical': 1, 'is_abstract': 0, 'is_place': 0},
    'can_be_touched:0': {'is_handheld': 0, 'is_object': 0, 'is_wearable': 0},
    // Living
    'is_living:1':      {'is_manmade': 0, 'is_abstract': 0, 'is_digital': 0,
                         'is_vehicle': 0, 'is_tool': 0, 'is_furniture': 0,
                         'is_electric': 0, 'is_motorized': 0},
    'is_living:0':      {'is_animal': 0, 'is_plant': 0},
    // Abstract
    'is_abstract:1':    {'is_physical': 0, 'can_be_touched': 0, 'is_handheld': 0,
                         'is_object': 0, 'is_living': 0, 'is_animal': 0,
                         'is_plant': 0, 'is_vehicle': 0, 'is_food': 0,
                         'is_drink': 0, 'is_food_or_drink': 0},
    'is_physical:0':    {'can_be_touched': 0, 'is_handheld': 0, 'is_object': 0,
                         'is_living': 0, 'is_animal': 0, 'is_plant': 0,
                         'is_vehicle': 0},
    // Manmade
    'is_manmade:1':     {'is_living': 0, 'is_natural': 0, 'is_animal': 0, 'is_plant': 0},
    // Digital
    'is_digital:1':     {'is_living': 0},
    // Place
    'is_place:1':       {'is_handheld': 0, 'is_object': 0, 'is_living': 0,
                         'is_food': 0, 'is_vehicle': 0},
    // Animal chain (subtype → parent, safe for all items)
    'is_animal:1':      {'is_living': 1, 'is_physical': 1,
                         'is_manmade': 0, 'is_abstract': 0,
                         'is_plant': 0, 'is_vehicle': 0,
                         'is_used_daily': 0, 'is_outdoor_item': 0},
    'is_bird:1':        {'is_animal': 1, 'is_living': 1},
    'is_fish:1':        {'is_animal': 1, 'is_living': 1},
    'is_insect:1':      {'is_animal': 1, 'is_living': 1},
    'is_mammal:1':      {'is_animal': 1, 'is_living': 1},
    'is_reptile:1':     {'is_animal': 1, 'is_living': 1},
    // Plant chain
    'is_plant:1':       {'is_living': 1, 'is_physical': 1,
                         'is_manmade': 0, 'is_abstract': 0,
                         'is_animal': 0, 'is_vehicle': 0,
                         'is_used_daily': 0, 'is_outdoor_item': 0},
    // Food / drink chain
    'is_food:1':        {'is_edible': 1, 'is_physical': 1, 'can_be_touched': 1,
                         'is_living': 0, 'is_abstract': 0,
                         'is_vehicle': 0, 'is_place': 0},
    'is_food_or_drink:1': {'is_edible': 1, 'is_physical': 1, 'can_be_touched': 1,
                           'is_living': 0, 'is_abstract': 0,
                           'is_vehicle': 0, 'is_place': 0},
    // Object
    'is_object:1':      {'is_physical': 1, 'can_be_touched': 1,
                         'is_abstract': 0, 'is_place': 0},
    // Vehicle
    'is_vehicle:1':     {'is_manmade': 1, 'is_physical': 1, 'can_be_touched': 1,
                         'is_living': 0, 'is_abstract': 0,
                         'is_animal': 0, 'is_plant': 0},
    // Brand
    'is_brand:1':       {'is_living': 0, 'is_animal': 0, 'is_plant': 0},
    // Furniture
    'is_furniture:1':   {'can_be_touched': 1, 'is_physical': 1, 'is_manmade': 1,
                         'is_living': 0, 'is_electric': 0, 'is_motorized': 0,
                         'is_handheld': 0, 'is_phone_related': 0, 'is_computer_related': 0,
                         'is_food': 0, 'is_drink': 0},
    // Wearable chain
    'is_clothing:1':    {'is_wearable': 1},
    // Emotion chain
    'is_emotion:1':     {'is_abstract': 1},
    // Place subtypes
    'is_city:1':        {'is_place': 1},
    'is_country:1':     {'is_place': 1},
    'is_building:1':    {'is_place': 1, 'is_manmade': 1},
  };

  // ── Bayesian constants ────────────────────────────────────────────────────
  static const List<double> _weights  = [1.00, 0.67, 0.00, -0.67, -1.00];
  static const List<double> _pGivHas  = [0.60, 0.28, 0.08,  0.03,  0.01];
  static const List<double> _pGivNot  = [0.01, 0.03, 0.08,  0.28,  0.60];
  static const double ln2 = 0.6931471805599453;

  // ── Constructor ──────────────────────────────────────────────────────────
  ThingEngine(List<ThingEntry> entries, {String? forceBranch, Map<String, AnswerType>? preAnswers})
      : _all        = entries,
        _candidates = _filterByBranch(entries, forceBranch) {
    _forceBranch = forceBranch;
    if (_candidates.isEmpty) _candidates = List<ThingEntry>.from(entries);
    for (final e in _all) {
      _scores[e]  = 0.0;
      _popBias[e] = (e.popularityScore / 100.0) * 0.35;
    }
    _candidates = List<ThingEntry>.from(_candidates);

    if (preAnswers != null && preAnswers.isNotEmpty) {
      for (final entry in preAnswers.entries) {
        _asked.add(entry.key);
        final w = entry.value.weight;
        final val = w > 0 ? 1 : 0;
        if (w > 0.99 || w < -0.99) _known[entry.key] = val;
        if (w == 0.0) continue;
        if (w > 0.99) {
          _candidates = _candidates.where((c) => c.getAttribute(entry.key) == 1).toList();
        } else if (w < -0.99) {
          _candidates = _candidates.where((c) => c.getAttribute(entry.key) == 0).toList();
        } else {
          for (final c in _candidates) {
            final has  = c.getAttribute(entry.key) == 1;
            final sign = has ? 1.0 : -1.0;
            final mag  = (w * sign > 0) ? matchMag : mismatchMag;
            _scores[c] = (_scores[c] ?? 0.0) + w * sign * mag;
          }
          _candidates = _candidates
              .where((c) => (_scores[c] ?? 0.0) > _elimThreshold)
              .toList();
        }
      }
      if (_candidates.isEmpty) {
        _candidates = List<ThingEntry>.from(_filterByBranch(entries, forceBranch));
      }
      // Propagate implications for definitive pre-answers
      for (final entry in preAnswers.entries) {
        final w = entry.value.weight;
        if (w > 0.99 || w < -0.99) {
          final impliedValue = w > 0 ? 1 : 0;
          final subs = _implications['${entry.key}:$impliedValue'];
          if (subs != null) {
            for (final e in subs.entries) { _applyImplication(e.key, e.value); }
          }
        }
      }
    }

    // Mark uniform attributes as already known
    if (forceBranch != null && _candidates.isNotEmpty) {
      _computeAndMarkCommonAttrs();
    }

    _currentAttribute = _selectBestQuestion();
  }

  // ── Uniform-attribute detection ──────────────────────────────────────────
  void _computeAndMarkCommonAttrs() {
    for (final def in _kDefs) {
      final attr = def.attr;
      if (_asked.contains(attr)) continue;
      int? commonVal;
      bool allSame = true;
      for (final c in _candidates) {
        final v = c.getAttribute(attr);
        if (commonVal == null) {
          commonVal = v;
        } else if (v != commonVal) {
          allSame = false;
          break;
        }
      }
      if (allSame && commonVal != null) {
        _asked.add(attr);
        _known[attr] = commonVal;
        final subs = _implications['$attr:$commonVal'];
        if (subs != null) {
          for (final e in subs.entries) {
            if (!_asked.contains(e.key)) {
              _asked.add(e.key);
              _known[e.key] = e.value;
            }
          }
        }
      }
    }
  }

  static List<ThingEntry> _filterByBranch(List<ThingEntry> all, String? branch) {
    if (branch == null) return all;
    final filtered = all.where((e) => e.mainType == branch).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  // ── Branch → domain mapping (for domain coherence bonus) ─────────────────
  String get _branchDomain {
    switch (_forceBranch) {
      case 'animal':                  return 'animal';
      case 'plant_food':              return 'plant_food';
      case 'vehicle':                 return 'vehicle';
      case 'place_building':          return 'place';
      case 'digital_product':         return 'digital';
      case 'brand_product':           return 'brand';
      case 'object_tool_household':   return 'object';
      case 'abstract_concept':        return 'abstract';
      case 'health_condition':        return 'health';
      case 'space_thing':             return 'space';
      case 'natural_thing':           return 'natural';
      default:                        return 'core';
    }
  }

  // Precondition check — always true: IG filter already avoids irrelevant
  // questions; hard preconditions block useful questions before their
  // prerequisite is established, wasting the question budget.
  bool _meetsPreCondition(_QDef def) => true;

  // ── Probability / IG computation ─────────────────────────────────────────
  Map<ThingEntry, double> _computeProbs() {
    if (_candidates.isEmpty) return {};
    final decay = _questionCount < 12 ? (1.0 - _questionCount / 12.0) : 0.0;
    double maxS = double.negativeInfinity;
    for (final c in _candidates) {
      final s = (_scores[c] ?? 0.0) + (_popBias[c] ?? 0.0) * decay;
      if (s > maxS) maxS = s;
    }
    double total = 0.0;
    final exps = <ThingEntry, double>{};
    for (final c in _candidates) {
      final s = (_scores[c] ?? 0.0) + (_popBias[c] ?? 0.0) * decay;
      final v = exp(s - maxS);
      exps[c] = v; total += v;
    }
    if (total == 0) {
      final u = 1.0 / _candidates.length;
      return {for (final c in _candidates) c: u};
    }
    return {for (final en in exps.entries) en.key: en.value / total};
  }

  static double _entropy(Iterable<double> probs) {
    double h = 0.0;
    for (final p in probs) { if (p > 1e-15) h -= p * log(p) / ln2; }
    return h;
  }

  double _ig(String attr, Map<ThingEntry, double> probs, double hNow) {
    double pHas = 0.0;
    for (final c in _candidates) {
      if (c.getAttribute(attr) == 1) pHas += probs[c] ?? 0.0;
    }
    final pNot = 1.0 - pHas;
    if (pHas < 1e-9 || pNot < 1e-9) return 0.0;
    if (_candidates.length > 500) {
      double ig = 0.0;
      if (pHas > 1e-15) ig -= pHas * log(pHas) / ln2;
      if (pNot > 1e-15) ig -= pNot * log(pNot) / ln2;
      return ig;
    }
    double expectedH = 0.0;
    for (int i = 0; i < _weights.length; i++) {
      final w       = _weights[i];
      final pAnswer = _pGivHas[i] * pHas + _pGivNot[i] * pNot;
      if (pAnswer < 1e-9) continue;
      if (w == 0.0) { expectedH += pAnswer * hNow; continue; }
      final ePos = exp(w); final eNeg = exp(-w);
      final tot  = pHas * ePos + pNot * eNeg;
      double h = 0.0;
      for (final c in _candidates) {
        final p = probs[c] ?? 0.0;
        if (p < 1e-15) continue;
        final scale = c.getAttribute(attr) == 1 ? ePos : eNeg;
        final np    = p * scale / tot;
        if (np > 1e-15) h -= np * log(np) / ln2;
      }
      expectedH += pAnswer * h;
    }
    return hNow - expectedH;
  }

  // ── Multi-factor question score ──────────────────────────────────────────
  double _questionScore(_QDef def, double ig, double pHas) {
    final splitBalance   = 1.0 - (pHas - 0.5).abs() * 2.0;
    final domainCoherence = def.domain == _branchDomain ? 1.0 : 0.0;
    final tierPriority   = (5 - def.tier) / 4.0;
    return ig          * _wIG
         + splitBalance * _wSplit
         + domainCoherence * _wDomain
         + tierPriority * _wTier
         - def.confusion * _wConfusion;
  }

  // ── Question selection ────────────────────────────────────────────────────
  String _selectBestQuestion() {
    final fallback = _kDefs
        .firstWhere((d) => !_asked.contains(d.attr), orElse: () => _kDefs.first)
        .attr;
    if (_candidates.length <= 1) return fallback;
    if (_candidates.length <= differentiatorAt) return _selectDifferentiator();

    final probs = _computeProbs();
    final hNow  = _entropy(probs.values);
    double best  = double.negativeInfinity;
    String bestA = fallback;

    for (final def in _kDefs) {
      if (_asked.contains(def.attr)) continue;
      if (!_meetsPreCondition(def)) continue;
      final ig = _ig(def.attr, probs, hNow);
      if (ig < 0.01) continue;
      // pHas for split balance
      double pHas = 0.0;
      for (final c in _candidates) {
        if (c.getAttribute(def.attr) == 1) pHas += probs[c] ?? 0.0;
      }
      final score = _questionScore(def, ig, pHas);
      if (score > best) { best = score; bestA = def.attr; }
    }
    if (best == double.negativeInfinity) return _selectDifferentiator();
    return bestA;
  }

  String _selectDifferentiator() {
    final fallback = _kDefs
        .firstWhere((d) => !_asked.contains(d.attr), orElse: () => _kDefs.first)
        .attr;
    final ranked = rankedCandidates;
    final top    = ranked.take(5).map((e) => e.key).toList();
    if (top.length <= 1) return fallback;

    final top1 = ranked.isNotEmpty     ? ranked[0].key : null;
    final top2 = ranked.length > 1     ? ranked[1].key : null;
    final top3 = ranked.length > 2     ? ranked[2].key : null;
    final u    = 1.0 / top.length;

    double best  = double.negativeInfinity;
    String bestA = fallback;

    for (final def in _kDefs) {
      if (_asked.contains(def.attr)) continue;
      if (!_meetsPreCondition(def)) continue;
      double pHas = 0.0;
      for (final c in top) { if (c.getAttribute(def.attr) == 1) pHas += u; }
      final pNot = 1.0 - pHas;
      if (pHas < 1e-9 || pNot < 1e-9) continue;
      double ig = 0.0;
      if (pHas > 1e-15) ig -= pHas * log(pHas) / ln2;
      if (pNot > 1e-15) ig -= pNot * log(pNot) / ln2;

      // Separation bonus: reward questions that distinguish top candidates
      double sep = 0.0;
      if (top1 != null && top2 != null &&
          top1.getAttribute(def.attr) != top2.getAttribute(def.attr)) sep += 2.0;
      if (top1 != null && top3 != null &&
          top1.getAttribute(def.attr) != top3.getAttribute(def.attr)) sep += 1.2;

      final score = ig + sep;
      if (score > best) { best = score; bestA = def.attr; }
    }
    return bestA;
  }

  // ── Implication propagation ───────────────────────────────────────────────
  void _applyImplication(String attr, int impliedValue) {
    if (_asked.contains(attr)) return;
    _asked.add(attr);
    _known[attr] = impliedValue;
    if (impliedValue == 1) {
      _candidates = _candidates.where((c) => c.getAttribute(attr) == 1).toList();
    } else {
      _candidates = _candidates.where((c) => c.getAttribute(attr) == 0).toList();
    }
    final subs = _implications['$attr:$impliedValue'];
    if (subs != null) {
      for (final e in subs.entries) { _applyImplication(e.key, e.value); }
    }
  }

  // ── Answer processing ─────────────────────────────────────────────────────
  void answer(AnswerType ans) {
    final attr = _currentAttribute;
    _asked.add(attr);
    _history.add(AskedQuestion(attr, kQuestions[attr] ?? attr, ans));
    _questionCount++;
    final w = ans.weight;
    if (w != 0.0) {
      if (w > 0.99 || w < -0.99) _known[attr] = w > 0 ? 1 : 0;
      for (final c in _candidates) {
        final has  = c.getAttribute(attr) == 1;
        final sign = has ? 1.0 : -1.0;
        final mag  = (w * sign > 0) ? matchMag : mismatchMag;
        _scores[c] = (_scores[c] ?? 0.0) + w * sign * mag;
      }
      _candidates = _candidates
          .where((c) => (_scores[c] ?? 0.0) > _elimThreshold)
          .toList();
      if (w > 0.99 || w < -0.99) {
        final impliedValue = w > 0 ? 1 : 0;
        final subs = _implications['$attr:$impliedValue'];
        if (subs != null) {
          for (final e in subs.entries) { _applyImplication(e.key, e.value); }
        }
      }
    }
    if (_questionCount < maxQuestions && _candidates.length > 1) {
      _currentAttribute = _selectBestQuestion();
    }
  }

  // ── Public getters ────────────────────────────────────────────────────────
  String get currentAttribute => _currentAttribute;
  String get currentQuestion  => kQuestions[_currentAttribute] ?? _currentAttribute;
  int    get questionCount    => _questionCount;
  bool   get isMaxReached     => _questionCount >= maxQuestions;
  int    get candidateCount   => _candidates.length;

  List<MapEntry<ThingEntry, double>> get rankedCandidates {
    final probs = _computeProbs();
    return _candidates
        .map((c) => MapEntry(c, probs[c] ?? 0.0))
        .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
  }

  ThingEntry get bestGuess {
    final r = rankedCandidates;
    return r.isNotEmpty ? r.first.key : _all.first;
  }

  AnyResult get bestResult => bestGuess.toResult();

  List<ThingEntry> get top5 =>
      rankedCandidates.take(5).map((e) => e.key).toList();

  double get confidence {
    final r = rankedCandidates;
    return r.isEmpty ? 0.0 : r.first.value;
  }

  // ── Guess trigger ────────────────────────────────────────────────────────
  bool get shouldGuess {
    if (_candidates.length <= autoGuessAt) return true;
    if (!_kDefs.any((d) => !_asked.contains(d.attr))) return true;
    if (_questionCount < 3) return false;
    final top = rankedCandidates;
    if (top.isEmpty || top.length == 1) return true;
    // In differentiator range: always ask, never guess on confidence alone
    if (_candidates.length <= differentiatorAt) return false;
    if (top.length >= 3 && top[2].value > 0 &&
        top[0].value / top[2].value >= 10.0) return true;
    if (_questionCount < 4) return false;
    if (top[0].value >= 0.50) return true;
    if (top[1].value > 0 && top[0].value / top[1].value >= 5.0) return true;
    return false;
  }

  List<AskedQuestion> get history => List.unmodifiable(_history);
}
