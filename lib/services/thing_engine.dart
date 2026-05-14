import 'dart:math';
import '../models/thing_entry.dart';
import '../models/any_result.dart';
import 'game_engine.dart' show AnswerType, AnswerTypeExt, AskedQuestion;

class ThingEngine {
  final List<ThingEntry> _all;
  List<ThingEntry> _candidates;
  final Map<ThingEntry, double> _scores  = {};
  final Map<ThingEntry, double> _popBias = {};
  final List<String>            _asked   = [];
  final List<AskedQuestion>     _history = [];
  int _questionCount = 0;
  late String _currentAttribute;

  static const double eliminationThreshold = -1.2;
  static const int    autoGuessAt          = 1;
  static const int    differentiatorAt     = 10;
  static const int    maxQuestions         = 18;

  // ── Attribute list ────────────────────────────────────────────────────────
  static const List<String> kAttributes = [
    // Core — highest early-phase boost, always asked first
    'can_be_touched', 'is_living', 'is_object', 'is_handheld',
    // Broad type discriminators
    'is_physical', 'is_manmade', 'is_natural',
    'is_animal', 'is_plant', 'is_food', 'is_drink', 'is_food_or_drink',
    'is_vehicle', 'is_place', 'is_abstract', 'is_event',
    'is_brand', 'is_digital', 'is_digital_or_brand',
    'is_person', 'is_character', 'is_fictional',
    // Object domain
    'is_tool', 'is_household', 'is_kitchen',
    'is_wearable', 'is_accessory', 'is_clothing', 'is_furniture',
    // Physical properties — asked early-to-mid
    'is_found_at_home', 'is_electric', 'is_small', 'is_large',
    'is_used_daily', 'is_found_in_nature',
    'can_move_by_itself', 'is_motorized', 'is_dangerous',
    // Watch / accessory domain
    'is_watch_related', 'is_clock_or_watch', 'is_smartwatch',
    'is_digital_watch', 'is_analog_watch', 'is_luxury_brand',
    'is_affordable_brand', 'is_japanese_brand', 'is_swiss_brand',
    'is_american_brand', 'is_korean_brand',
    // Tech domain
    'is_phone_related', 'is_computer_related',
    'is_game_related', 'is_app_related', 'is_social_media',
    'is_software', 'is_mobile_app', 'is_video_game', 'is_board_game',
    'is_car_brand', 'is_car_model',
    // Tool domain
    'is_tool_for_repair', 'is_cutting_tool', 'is_writing_tool',
    'is_cooking_tool', 'is_eating_tool',
    // More physical
    'is_edible',
    'is_bathroom_item', 'is_bedroom_item', 'is_outdoor_item',
    // Animal domain
    'is_pet', 'is_wild_animal', 'is_farm_animal',
    'can_fly', 'lives_in_water', 'is_insect', 'is_mammal',
    'is_bird', 'is_reptile', 'is_fish',
    // Plant / food domain
    'is_fruit', 'is_vegetable', 'is_tree', 'is_flower', 'is_spice',
    'is_sweet', 'is_sour', 'is_liquid',
    // Material
    'is_metal', 'is_wood', 'is_plastic', 'is_glass',
    'is_fabric', 'is_leather', 'is_paper',
    // Nature / weather / space
    'is_weather_related', 'is_sky_related', 'is_space_related',
    'is_water_related', 'is_fire_related', 'is_air_related', 'is_earth_related', 'is_hot', 'is_cold',
    // Place domain
    'is_city', 'is_country', 'is_building', 'is_natural_place',
    'is_historical_place',
    // Abstract / emotion domain
    'is_emotion', 'is_positive', 'is_negative', 'is_time_related',
    'is_mind_related', 'is_sleep_related',
    'is_religious_or_spiritual', 'is_money_related', 'is_symbol',
    // Health
    'is_health_related', 'is_health_condition',
    // Context
    'is_sport_related', 'is_music_related', 'is_school_related',
    'is_child_friendly', 'is_turkish', 'is_global',
    'is_used_for_fun', 'is_used_for_work',
    // Popularity
    'popularity_high',
  ];

  // ── Turkish questions ─────────────────────────────────────────────────────
  static const Map<String, String> kQuestions = {
    'is_physical':              'Bu şey fiziksel olarak var mı?',
    'is_living':                'Bu şey canlı mı?',
    'is_manmade':               'Bu şey insan yapımı mı?',
    'is_natural':               'Bu şey doğada kendiliğinden var mı?',
    'is_animal':                'Bu şey bir hayvan mı?',
    'is_plant':                 'Bu şey bir bitki mi?',
    'is_food':                  'Bu şey yiyecek mi?',
    'is_drink':                 'Bu şey bir içecek mi?',
    'is_food_or_drink':         'Bu şey yiyecek veya içecek mi?',
    'is_vehicle':               'Bu şey bir taşıt mı?',
    'is_place':                 'Bu şey bir yer mi?',
    'is_abstract':              'Bu şey soyut bir kavram veya duygu mu?',
    'is_event':                 'Bu şey bir olay veya durum mu?',
    'is_brand':                 'Bu şey bir marka mı?',
    'is_digital':               'Bu şey bir elektronik cihaz veya yazılım mı? (telefon, uygulama, oyun...)',
    'is_digital_or_brand':      'Bu şey bir marka veya dijital ürün mü?',
    'is_person':                'Bu şey bir kişi mi?',
    'is_character':             'Bu şey bir karakter veya figür mü?',
    'is_fictional':             'Bu şey kurgusal mı?',
    'is_tool':                  'Bu şey bir el aleti mi?',
    'is_household':             'Bu şey bir ev eşyası mı?',
    'is_kitchen':               'Bu şey mutfakta kullanılır mı?',
    'is_object':                'Bu şey elle tutulabilen bir nesne mi?',
    'is_wearable':              'Bu şey giyilebilir veya takılabilir mi?',
    'is_accessory':             'Bu şey bir aksesuar mı?',
    'is_clothing':              'Bu şey bir giysi mi?',
    'is_furniture':             'Bu şey bir mobilya mı?',
    'is_watch_related':         'Bu şey bir saatle ilgili mi?',
    'is_clock_or_watch':        'Bu şey bir saat mi?',
    'is_smartwatch':            'Bu şey akıllı saat mi?',
    'is_digital_watch':         'Bu şey dijital saatleriyle bilinen bir şey mi?',
    'is_analog_watch':          'Bu şey akrep-yelkovanlı klasik saat mi?',
    'is_luxury_brand':          'Bu şey lüks bir marka mı?',
    'is_affordable_brand':      'Bu şey uygun fiyatlı bir marka olarak bilinir mi?',
    'is_japanese_brand':        'Bu şey Japon markası mı?',
    'is_swiss_brand':           'Bu şey İsviçre markası mı?',
    'is_american_brand':        'Bu şey Amerikan markası mı?',
    'is_korean_brand':          'Bu şey Kore markası mı?',
    'is_electric':              'Bu şey elektrikli mi?',
    'is_motorized':             'Bu şey motorlu mu?',
    'is_handheld':              'Bu şey tek elle taşınabilir mi?',
    'is_phone_related':         'Bu şey telefonla ilgili mi?',
    'is_computer_related':      'Bu şey bilgisayarla ilgili mi?',
    'is_game_related':          'Bu şey oyunla ilgili mi?',
    'is_app_related':           'Bu şey bir uygulama mı?',
    'is_social_media':          'Bu şey sosyal medya platformu mu?',
    'is_software':              'Bu şey bir yazılım mı?',
    'is_mobile_app':            'Bu şey bir mobil uygulama mı?',
    'is_video_game':            'Bu şey bir video oyunu mu?',
    'is_board_game':            'Bu şey bir masa oyunu mu?',
    'is_car_brand':             'Bu şey bir araba markası mı?',
    'is_car_model':             'Bu şey belirli bir araba modeli mi?',
    'is_tool_for_repair':       'Bu şey tamir veya inşaat işlerinde kullanılır mı?',
    'is_cutting_tool':          'Bu şey kesmek için kullanılır mı?',
    'is_writing_tool':          'Bu şey yazmak için kullanılır mı?',
    'is_cooking_tool':          'Bu şey yemek pişirmek için mi kullanılır?',
    'is_eating_tool':           'Bu şey yemek yemek için mi kullanılır?',
    'is_edible':                'Bu şey yenilebilir mi?',
    'is_used_daily':            'Bu şey günlük hayatta sık kullanılır mı?',
    'is_found_at_home':         'Bu şey evde bulunur mu?',
    'is_found_in_nature':       'Bu şey doğada bulunur mu?',
    'is_large':                 'Bu şey büyük mü?',
    'is_small':                 'Bu şey küçük mü?',
    'can_move_by_itself':       'Bu şey kendi kendine hareket edebilir mi?',
    'can_be_touched':           'Bu şey elle dokunulabilir mi?',
    'is_dangerous':             'Bu şey tehlikeli olabilir mi?',
    'is_bathroom_item':         'Bu şey banyoda bulunur mu?',
    'is_bedroom_item':          'Bu şey yatak odasında bulunur mu?',
    'is_outdoor_item':          'Bu şey genellikle dışarıda kullanılır mı?',
    'is_pet':                   'Bu şey evcil hayvan mı?',
    'is_wild_animal':           'Bu şey vahşi/yabani bir hayvan mı?',
    'is_farm_animal':           'Bu şey çiftlik hayvanı mı?',
    'can_fly':                  'Bu şey uçabilir mi?',
    'lives_in_water':           'Bu şey suda yaşar mı?',
    'is_insect':                'Bu şey bir böcek mi?',
    'is_mammal':                'Bu şey memeli bir hayvan mı?',
    'is_bird':                  'Bu şey bir kuş mu?',
    'is_reptile':               'Bu şey bir sürüngen mi?',
    'is_fish':                  'Bu şey bir balık mı?',
    'is_fruit':                 'Bu şey bir meyve mi?',
    'is_vegetable':             'Bu şey bir sebze mi?',
    'is_tree':                  'Bu şey bir ağaç mı?',
    'is_flower':                'Bu şey bir çiçek mi?',
    'is_spice':                 'Bu şey bir baharat mı?',
    'is_sweet':                 'Bu şey tatlı mı?',
    'is_sour':                  'Bu şey ekşi mi?',
    'is_liquid':                'Bu şey sıvı mı?',
    'is_metal':                 'Bu şey metalden yapılmış mı?',
    'is_wood':                  'Bu şey ahşaptan yapılmış mı?',
    'is_plastic':               'Bu şey plastikten yapılmış mı?',
    'is_glass':                 'Bu şey camdan yapılmış mı?',
    'is_fabric':                'Bu şey kumaştan yapılmış mı?',
    'is_leather':               'Bu şey deriden yapılmış mı?',
    'is_paper':                 'Bu şey kağıttan yapılmış mı?',
    'is_weather_related':       'Bu şey bir hava olayıyla ilgili mi?',
    'is_sky_related':           'Bu şey gökyüzüyle ilgili mi?',
    'is_space_related':         'Bu şey uzayla ilgili mi?',
    'is_water_related':         'Bu şey suyla ilgili mi?',
    'is_fire_related':          'Bu şey ateşle ilgili mi?',
    'is_air_related':           'Bu şey havayla veya uçuşla ilgili mi?',
    'is_earth_related':         'Bu şey toprak veya zemin işlemeyle ilgili mi?',
    'is_hot':                   'Bu şey sıcak mı?',
    'is_cold':                  'Bu şey soğuk mu?',
    'is_city':                  'Bu şey bir şehir mi?',
    'is_country':               'Bu şey bir ülke mi?',
    'is_building':              'Bu şey bir bina veya yapı mı?',
    'is_natural_place':         'Bu şey doğal bir yer mi? (dağ, deniz, orman...)',
    'is_historical_place':      'Bu şey tarihi bir yer mi?',
    'is_emotion':               'Bu şey bir duygu mu?',
    'is_positive':              'Bu şey genel olarak olumlu bir şey mi?',
    'is_negative':              'Bu şey genel olarak olumsuz bir şey mi?',
    'is_time_related':          'Bu şey zamanla ilgili mi?',
    'is_mind_related':          'Bu şey zihin veya düşünceyle ilgili mi?',
    'is_sleep_related':         'Bu şey uykuyla ilgili mi?',
    'is_religious_or_spiritual':'Bu şey dini veya manevi bir şey mi?',
    'is_money_related':         'Bu şey parayla ilgili mi?',
    'is_symbol':                'Bu şey bir sembol mü?',
    'is_health_related':        'Bu şey sağlıkla ilgili mi?',
    'is_health_condition':      'Bu şey bir hastalık veya sağlık durumu mu?',
    'is_sport_related':         'Bu şey sporla ilgili mi?',
    'is_music_related':         'Bu şey müzikle ilgili mi?',
    'is_school_related':        'Bu şey okul veya eğitimle ilgili mi?',
    'is_child_friendly':        'Bu şey çocuklar için uygun mu?',
    'is_turkish':               "Bu şey Türkiye'ye özgü mü?",
    'is_global':                'Bu şey dünya genelinde çok bilinen bir şey mi?',
    'is_used_for_fun':          'Bu şey eğlence amaçlı mı?',
    'is_used_for_work':         'Bu şey iş veya çalışma amacıyla kullanılır mı?',
    'popularity_high':          'Bu şey çok popüler ve bilinen bir şey mi?',
  };

  // ── Logical implication table ─────────────────────────────────────────────
  // When attr is definitively answered (key = 'attr:1' or 'attr:0'),
  // auto-answer the mapped attributes without spending a question on them.
  static const Map<String, Map<String, int>> _implications = {
    // Touchable → physical, not abstract/place (NOT 'not digital': tablets are touchable AND digital)
    'can_be_touched:1': {'is_physical': 1, 'is_abstract': 0, 'is_place': 0},
    // Not touchable → not handheld/object/wearable
    'can_be_touched:0': {'is_handheld': 0, 'is_object': 0, 'is_wearable': 0},
    // Living → not manmade/abstract/digital/vehicle/tool/furniture/electric/motorized
    'is_living:1':      {'is_manmade': 0, 'is_abstract': 0, 'is_digital': 0,
                         'is_vehicle': 0, 'is_tool': 0, 'is_furniture': 0,
                         'is_electric': 0, 'is_motorized': 0},
    // Not living → not animal/plant (humans can't make living things either way)
    'is_living:0':      {'is_animal': 0, 'is_plant': 0},
    // Abstract → not physical/touchable/handheld/object/living/animal/plant/vehicle/food
    'is_abstract:1':    {'is_physical': 0, 'can_be_touched': 0, 'is_handheld': 0,
                         'is_object': 0, 'is_living': 0, 'is_animal': 0,
                         'is_plant': 0, 'is_vehicle': 0, 'is_food': 0,
                         'is_drink': 0, 'is_food_or_drink': 0},
    // Not physical → not touchable/handheld/object/living/animal/plant/vehicle
    'is_physical:0':    {'can_be_touched': 0, 'is_handheld': 0, 'is_object': 0,
                         'is_living': 0, 'is_animal': 0, 'is_plant': 0,
                         'is_vehicle': 0},
    // Manmade → not living/natural/animal/plant
    'is_manmade:1':     {'is_living': 0, 'is_natural': 0,
                         'is_animal': 0, 'is_plant': 0},
    // Digital → not living (physical digital devices like tablets CAN be touched/held/objects)
    'is_digital:1':     {'is_living': 0},
    // Place → not handheld/object/living/food/vehicle
    'is_place:1':       {'is_handheld': 0, 'is_object': 0, 'is_living': 0,
                         'is_food': 0, 'is_vehicle': 0},
    // Animal → living/physical; not manmade/abstract/plant/vehicle
    'is_animal:1':      {'is_living': 1, 'is_physical': 1,
                         'is_manmade': 0, 'is_abstract': 0,
                         'is_plant': 0, 'is_vehicle': 0},
    // Plant → living/physical; not manmade/abstract/animal/vehicle
    'is_plant:1':       {'is_living': 1, 'is_physical': 1,
                         'is_manmade': 0, 'is_abstract': 0,
                         'is_animal': 0, 'is_vehicle': 0},
    // Vehicle → manmade/physical/touchable; not living/abstract/animal/plant
    'is_vehicle:1':     {'is_manmade': 1, 'is_physical': 1, 'can_be_touched': 1,
                         'is_living': 0, 'is_abstract': 0,
                         'is_animal': 0, 'is_plant': 0},
    // Food → edible/physical/touchable; not living/abstract/vehicle/place
    'is_food:1':        {'is_edible': 1, 'is_physical': 1, 'can_be_touched': 1,
                         'is_living': 0, 'is_abstract': 0,
                         'is_vehicle': 0, 'is_place': 0},
    'is_food_or_drink:1': {'is_edible': 1, 'is_physical': 1, 'can_be_touched': 1,
                           'is_living': 0, 'is_abstract': 0,
                           'is_vehicle': 0, 'is_place': 0},
    // Object (holdable) → physical/touchable; not abstract/place (NOT 'not digital': tablets are objects AND digital)
    'is_object:1':      {'is_physical': 1, 'can_be_touched': 1,
                         'is_abstract': 0, 'is_place': 0},
    // Brand → not living/animal/plant
    'is_brand:1':       {'is_living': 0, 'is_animal': 0, 'is_plant': 0},
    // Furniture → physical/manmade/touchable; not electric/motorized/handheld/phone/computer/living/food
    'is_furniture:1':   {'can_be_touched': 1, 'is_physical': 1, 'is_manmade': 1,
                         'is_living': 0, 'is_electric': 0, 'is_motorized': 0,
                         'is_handheld': 0, 'is_phone_related': 0, 'is_computer_related': 0,
                         'is_food': 0, 'is_drink': 0},
    // Material mutual exclusions — if made of X, not made of other materials
    'is_wood:1':     {'is_plastic': 0, 'is_metal': 0, 'is_glass': 0,
                      'is_fabric': 0, 'is_leather': 0, 'is_paper': 0},
    'is_plastic:1':  {'is_wood': 0, 'is_metal': 0, 'is_glass': 0,
                      'is_fabric': 0, 'is_leather': 0, 'is_paper': 0},
    'is_metal:1':    {'is_wood': 0, 'is_plastic': 0, 'is_glass': 0,
                      'is_fabric': 0, 'is_leather': 0, 'is_paper': 0},
    'is_glass:1':    {'is_wood': 0, 'is_plastic': 0, 'is_metal': 0,
                      'is_fabric': 0, 'is_leather': 0, 'is_paper': 0},
    'is_fabric:1':   {'is_wood': 0, 'is_plastic': 0, 'is_metal': 0,
                      'is_glass': 0, 'is_leather': 0, 'is_paper': 0},
    'is_leather:1':  {'is_wood': 0, 'is_plastic': 0, 'is_metal': 0,
                      'is_glass': 0, 'is_fabric': 0, 'is_paper': 0},
    'is_paper:1':    {'is_wood': 0, 'is_plastic': 0, 'is_metal': 0,
                      'is_glass': 0, 'is_fabric': 0, 'is_leather': 0},
  };

  // ── Bayesian constants ────────────────────────────────────────────────────
  static const List<double> _weights   = [1.00, 0.67, 0.00, -0.67, -1.00];
  static const List<double> _pGivHas  = [0.60, 0.28, 0.08,  0.03,  0.01];
  static const List<double> _pGivNot  = [0.01, 0.03, 0.08,  0.28,  0.60];
  static const double ln2 = 0.6931471805599453;

  ThingEngine(List<ThingEntry> entries, {String? forceBranch, Map<String, AnswerType>? preAnswers})
      : _all        = entries,
        _candidates = _filterByBranch(entries, forceBranch) {
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
        if (w == 0.0) continue;
        if (w > 0.99) {
          // Hard filter: remove candidates that contradict this YES answer
          _candidates = _candidates.where((c) => c.getAttribute(entry.key) == 1).toList();
        } else if (w < -0.99) {
          // Hard filter: remove candidates that contradict this NO answer
          _candidates = _candidates.where((c) => c.getAttribute(entry.key) == 0).toList();
        } else {
          // Soft scoring for non-definitive answers
          for (final c in _candidates) {
            final has  = c.getAttribute(entry.key) == 1;
            final sign = has ? 1.0 : -1.0;
            final mag  = (w * sign > 0) ? 0.5 : 1.6;
            _scores[c] = (_scores[c] ?? 0.0) + w * sign * mag;
          }
          _candidates = _candidates
              .where((c) => (_scores[c] ?? 0.0) > eliminationThreshold)
              .toList();
        }
      }
      if (_candidates.isEmpty) {
        _candidates = List<ThingEntry>.from(_filterByBranch(entries, forceBranch));
      }
      // Propagate implication chains from definite pre-answers
      for (final entry in preAnswers.entries) {
        final w = entry.value.weight;
        if (w > 0.99 || w < -0.99) {
          final impliedValue = w > 0 ? 1 : 0;
          final subs = _implications['${entry.key}:$impliedValue'];
          if (subs != null) {
            for (final e in subs.entries) {
              _applyImplication(e.key, e.value);
            }
          }
        }
      }
    }

    // Mark attributes that are uniform across ALL branch candidates as already known.
    // This prevents asking trivially-answered questions (e.g. "is it an animal?"
    // when we're already in the animal branch and every candidate is one).
    if (forceBranch != null && _candidates.isNotEmpty) {
      _computeAndMarkCommonAttrs();
    }

    _currentAttribute = _selectBestQuestion();
  }

  // Detect attributes where every remaining candidate has the same value.
  // Asking such a question provides zero information — skip it.
  void _computeAndMarkCommonAttrs() {
    for (final attr in kAttributes) {
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
        // Propagate implications of this known-uniform attribute
        final subs = _implications['$attr:$commonVal'];
        if (subs != null) {
          for (final e in subs.entries) {
            if (!_asked.contains(e.key)) _asked.add(e.key);
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

  // ── Probability / IG computation ──────────────────────────────────────────
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

  String _selectBestQuestion() {
    final fallback = kAttributes.firstWhere(
      (a) => !_asked.contains(a),
      orElse: () => kAttributes.first,
    );
    if (_candidates.length <= 1) return fallback;
    if (_candidates.length <= differentiatorAt) return _selectDifferentiator();
    final probs = _computeProbs();
    final hNow  = _entropy(probs.values);
    double best  = double.negativeInfinity;
    String bestA = fallback;
    for (final attr in kAttributes) {
      if (_asked.contains(attr)) continue;
      final ig = _ig(attr, probs, hNow);
      if (ig < 0.01) continue;
      if (ig > best) { best = ig; bestA = attr; }
    }
    if (best == double.negativeInfinity) return _selectDifferentiator();
    return bestA;
  }

  String _selectDifferentiator() {
    final fallback = kAttributes.firstWhere(
      (a) => !_asked.contains(a),
      orElse: () => kAttributes.first,
    );
    final top5 = rankedCandidates.take(5).map((e) => e.key).toList();
    if (top5.length <= 1) return fallback;
    final u = 1.0 / top5.length;
    double best = double.negativeInfinity;
    String bestA = fallback;
    for (final attr in kAttributes) {
      if (_asked.contains(attr)) continue;
      double pHas = 0.0;
      for (final c in top5) { if (c.getAttribute(attr) == 1) pHas += u; }
      final pNot = 1.0 - pHas;
      if (pHas < 1e-9 || pNot < 1e-9) continue;
      double ig = 0.0;
      if (pHas > 1e-15) ig -= pHas * log(pHas) / ln2;
      if (pNot > 1e-15) ig -= pNot * log(pNot) / ln2;
      if (ig > best) { best = ig; bestA = attr; }
    }
    return bestA;
  }

  // Apply a logically implied answer without asking the user.
  // Hard-filters candidates that contradict the logical consequence,
  // then recursively follows the implication chain.
  void _applyImplication(String attr, int impliedValue) {
    if (_asked.contains(attr)) return;
    _asked.add(attr);
    if (impliedValue == 1) {
      _candidates = _candidates.where((c) => c.getAttribute(attr) == 1).toList();
    } else {
      _candidates = _candidates.where((c) => c.getAttribute(attr) == 0).toList();
    }
    final subs = _implications['$attr:$impliedValue'];
    if (subs != null) {
      for (final e in subs.entries) {
        _applyImplication(e.key, e.value);
      }
    }
  }

  void answer(AnswerType ans) {
    final attr = _currentAttribute;
    _asked.add(attr);
    _history.add(AskedQuestion(attr, kQuestions[attr] ?? attr, ans));
    _questionCount++;
    final w = ans.weight;
    if (w != 0.0) {
      for (final c in _candidates) {
        final has  = c.getAttribute(attr) == 1;
        final sign = has ? 1.0 : -1.0;
        final mag  = (w * sign > 0) ? 0.5 : 1.6;
        _scores[c] = (_scores[c] ?? 0.0) + w * sign * mag;
      }
      _candidates = _candidates
          .where((c) => (_scores[c] ?? 0.0) > eliminationThreshold)
          .toList();
      // For definite YES/NO answers propagate logical consequences
      if (w > 0.99 || w < -0.99) {
        final impliedValue = w > 0 ? 1 : 0;
        final subs = _implications['$attr:$impliedValue'];
        if (subs != null) {
          for (final e in subs.entries) {
            _applyImplication(e.key, e.value);
          }
        }
      }
    }
    if (_questionCount < maxQuestions && _candidates.length > 1) {
      _currentAttribute = _selectBestQuestion();
    }
  }

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

  bool get shouldGuess {
    if (_candidates.length <= autoGuessAt) return true;
    if (!kAttributes.any((a) => !_asked.contains(a))) return true;
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
