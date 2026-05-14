import 'dart:math';
import '../models/character.dart';

// ─── Answer Type ──────────────────────────────────────────────────────────────

enum AnswerType { yes, probably, dontKnow, probablyNot, no }

extension AnswerTypeExt on AnswerType {
  String get label {
    switch (this) {
      case AnswerType.yes:         return 'Evet';
      case AnswerType.probably:    return 'Herhalde';
      case AnswerType.dontKnow:    return 'Bilmiyorum';
      case AnswerType.probablyNot: return 'Herhalde Değil';
      case AnswerType.no:          return 'Hayır';
    }
  }

  double get weight {
    switch (this) {
      case AnswerType.yes:         return  1.00;
      case AnswerType.probably:    return  0.67;
      case AnswerType.dontKnow:    return  0.00;
      case AnswerType.probablyNot: return -0.67;
      case AnswerType.no:          return -1.00;
    }
  }
}

// ─── History entry ────────────────────────────────────────────────────────────

class AskedQuestion {
  final String attribute;
  final String questionText;
  final AnswerType answer;
  const AskedQuestion(this.attribute, this.questionText, this.answer);
}

// ─── Attribute metadata ───────────────────────────────────────────────────────
//
// group:         question category for phase-boost and diversity penalty
// knowability:   probability [0–1] that a typical user knows the answer
// isPrivateLife: suppress early in game (before _privateLifeSuppressUntil)

class _AttrMeta {
  final int group;
  final double knowability;
  final bool isPrivateLife;
  const _AttrMeta(this.group, this.knowability, {this.isPrivateLife = false});
}

// ─── Game Engine ─────────────────────────────────────────────────────────────
//
// Hybrid Bayesian engine — v1.5:
//
//   • 5-way Information Gain with realistic conditional answer probabilities.
//   • Per-attribute metadata: knowability, isPrivateLife, group.
//   • Score formula: IG × phaseBoost × knowability × dynMult
//                       × diversityBoost × cooldownPenalty × privPenalty
//   • Separate popularity bias (_popBias) that decays linearly to 0 by q=14.
//   • Group-level cooldown (3 questions) after "Bilmiyorum".
//   • Private-life suppression (0.20×) for q < 7.
//   • Differentiator mode (pool ≤ 8): binary IG focused on top-5 candidates.
//   • Hard elimination at −3.2 (softer than v1.4's −2.6).
//   • Multi-trigger shouldGuess: pool size, dominance ratio, late-game q≥16.
//   • learnFromWrongGuess stub for future warm-start learning.
//
// NOTE: _scores is Map<Character, double> keyed by object identity (NOT name).
// Name-keyed maps cause N× score amplification for duplicate-named CSV rows.

class GameEngine {
  final List<Character> _all;
  List<Character> _candidates;
  final Map<Character, double> _scores  = {};
  final Map<Character, double> _popBias = {};
  final List<String>           _asked   = [];
  final List<AskedQuestion>    _history = [];
  late String _currentAttribute;
  int _questionCount = 0;

  final Map<String, double> _attrDynMult     = {};
  int _consecutiveDontKnow = 0;
  final Map<int, int> _groupCooldownAt = {}; // group → questionCount at dontKnow

  final List<String>        _attributes;
  final Map<String, String> _questions;

  static const int    maxQuestions              = 20;
  static const double eliminationThreshold      = -3.2;
  static const int    autoGuessAt               = 3;
  static const int    differentiatorAt          = 8;
  static const int    _groupCooldownLen         = 3;
  static const int    _privateLifeSuppressUntil = 7;
  static const double _privateLifePenaltyMult   = 0.20;

  // ── Attribute list ─────────────────────────────────────────────────────────
  // Order matters: most discriminating attributes come first so fallback
  // selection (when IG scores tie at 0) picks good defaults.

  static const List<String> kAllAttributes = [
    // Fundamental (group 0)
    'is_fictional', 'is_male', 'is_turkish',
    // Profession (group 1)
    'is_singer', 'is_actor', 'is_football_player', 'is_sportsman',
    'is_politician', 'is_rapper', 'is_youtuber',
    'is_director', 'is_model', 'is_comedian', 'is_tv_host',
    'is_musician', 'is_athlete', 'is_in_entertainment',
    // Fictional traits (group 2b → group 7)
    'is_villain', 'is_superhero',
    // Source (group 2)
    'from_movie', 'from_anime', 'from_tv_series', 'from_fiction_media',
    // Personal (group 3)
    'is_alive', 'is_historical', 'is_married', 'has_children',
    // Physical (group 4)
    'has_beard', 'wears_glasses', 'height_tall', 'height_short',
    // Age (group 5)
    'age_under_35', 'age_over_50', 'age_under_25',
    'age_over_40',  'age_over_60', 'age_over_70',
    'born_after_1990', 'born_after_1980', 'born_before_1960',
    // Fame (group 6)
    'popularity_high', 'very_popular',
  ];

  // ── Question texts ─────────────────────────────────────────────────────────

  static const Map<String, String> kAttributeQuestions = {
    'is_fictional':        'Bu karakter kurgusal mı?',
    'is_male':             'Bu karakter erkek mi?',
    'is_turkish':          'Bu karakter Türk mü?',
    'is_singer':           'Bu karakter şarkıcı mı?',
    'is_actor':            'Bu karakter oyuncu mu?',
    'is_football_player':  'Bu karakter futbolcu mu?',
    'is_sportsman':        'Bu karakter sporcu mu?',
    'is_politician':       'Bu karakter siyasetçi mi?',
    'is_rapper':           'Bu karakter rapper mı?',
    'is_youtuber':         'Bu karakter YouTuber mı?',
    'is_director':         'Bu karakter yönetmen mi?',
    'is_model':            'Bu karakter model mi?',
    'is_comedian':         'Bu karakter komedyen mi?',
    'is_tv_host':          'Bu karakter TV sunucusu mu?',
    'is_villain':          'Bu karakter kötü adam mı?',
    'is_superhero':        'Bu karakter kahraman/savaşçı mı?',
    'is_musician':         'Bu karakter müzisyen mi?',
    'is_athlete':          'Bu karakter spor dünyasından mı?',
    'is_in_entertainment': 'Bu karakter eğlence dünyasında mı?',
    'from_movie':          'Bu karakter bir filmden mi?',
    'from_anime':          'Bu karakter anime/manga karakteri mi?',
    'from_tv_series':      'Bu karakter bir diziden mi?',
    'from_fiction_media':  'Bu karakter film, dizi veya animeden mi?',
    'is_alive':            'Bu karakter hayatta mı?',
    'is_historical':       'Bu karakter tarihi bir figür mü?',
    'is_married':          'Bu karakter evli mi?',
    'has_children':        'Bu karakterin çocuğu var mı?',
    'has_beard':           'Bu karakterin sakalı var mı?',
    'wears_glasses':       'Bu karakter gözlük takıyor mu?',
    'height_tall':         'Bu karakter uzun boylu mu? (185 cm ve üzeri)',
    'height_short':        'Bu karakter kısa boylu mu? (170 cm ve altı)',
    'age_under_35':        'Bu karakter 35 yaşından genç mi?',
    'age_over_50':         'Bu karakter 50 yaşından büyük mü?',
    'age_under_25':        'Bu karakter 25 yaşından genç mi?',
    'age_over_40':         'Bu karakter 40 yaşından büyük mü?',
    'age_over_60':         'Bu karakter 60 yaşından büyük mü?',
    'age_over_70':         'Bu karakter 70 yaşından büyük mü?',
    'born_after_1990':     'Bu karakter 1990 sonrası doğdu mu?',
    'born_after_1980':     'Bu karakter 1980 sonrası doğdu mu?',
    'born_before_1960':    'Bu karakter 1960 öncesi doğdu mu?',
    'popularity_high':     'Bu karakter çok popüler mi?',
    'very_popular':        'Bu karakter neredeyse herkes tarafından tanınır mı?',
  };

  // ── Attribute metadata ─────────────────────────────────────────────────────
  // Groups: 0=fundamental, 1=profession, 2=source, 3=personal,
  //         4=physical,   5=age,         6=fame

  static const Map<String, _AttrMeta> _meta = {
    'is_fictional':        _AttrMeta(0, 0.95),
    'is_male':             _AttrMeta(0, 0.99),
    'is_turkish':          _AttrMeta(8, 0.95), // kendi grubu — diversity penalty almaz
    'is_singer':           _AttrMeta(1, 0.90),
    'is_actor':            _AttrMeta(1, 0.90),
    'is_football_player':  _AttrMeta(1, 0.92),
    'is_sportsman':        _AttrMeta(1, 0.85),
    'is_politician':       _AttrMeta(1, 0.85),
    'is_rapper':           _AttrMeta(1, 0.88),
    'is_youtuber':         _AttrMeta(1, 0.85),
    'is_director':         _AttrMeta(1, 0.82),
    'is_model':            _AttrMeta(1, 0.80),
    'is_comedian':         _AttrMeta(1, 0.85),
    'is_tv_host':          _AttrMeta(1, 0.82),
    'is_villain':          _AttrMeta(7, 0.88),
    'is_superhero':        _AttrMeta(7, 0.90),
    'is_musician':         _AttrMeta(1, 0.90),
    'is_athlete':          _AttrMeta(1, 0.88),
    'is_in_entertainment': _AttrMeta(1, 0.90),
    'from_movie':          _AttrMeta(2, 0.88),
    'from_anime':          _AttrMeta(2, 0.92),
    'from_tv_series':      _AttrMeta(2, 0.88),
    'from_fiction_media':  _AttrMeta(2, 0.90),
    'is_alive':            _AttrMeta(3, 0.80),
    'is_historical':       _AttrMeta(3, 0.88),
    'is_married':          _AttrMeta(3, 0.50, isPrivateLife: true),
    'has_children':        _AttrMeta(3, 0.45, isPrivateLife: true),
    'has_beard':           _AttrMeta(4, 0.92),
    'wears_glasses':       _AttrMeta(4, 0.90),
    'height_tall':         _AttrMeta(4, 0.65),
    'height_short':        _AttrMeta(4, 0.65),
    'age_under_35':        _AttrMeta(5, 0.62),
    'age_over_50':         _AttrMeta(5, 0.65),
    'age_under_25':        _AttrMeta(5, 0.60),
    'age_over_40':         _AttrMeta(5, 0.62),
    'age_over_60':         _AttrMeta(5, 0.68),
    'age_over_70':         _AttrMeta(5, 0.70),
    'born_after_1990':     _AttrMeta(5, 0.60),
    'born_after_1980':     _AttrMeta(5, 0.60),
    'born_before_1960':    _AttrMeta(5, 0.65),
    'popularity_high':     _AttrMeta(6, 0.85),
    'very_popular':        _AttrMeta(6, 0.90),
  };

  // Phase-boost [group][phase]:
  //   phase 0 = discovery  (q  0–4)
  //   phase 1 = refinement (q  5–11)
  //   phase 2 = precision  (q 12+)
  //
  // Fundamental group (0) in phase 0 → 2.45 (overrides table's 2.00).

  static const List<List<double>> _groupPhaseBoost = [
    [2.00, 1.20, 1.00], // 0 fundamental
    [1.40, 1.50, 1.20], // 1 profession
    [1.20, 1.10, 1.00], // 2 source
    [0.70, 1.30, 1.40], // 3 personal
    [0.50, 0.90, 1.30], // 4 physical
    [0.60, 1.20, 1.40], // 5 age
    [1.00, 1.00, 1.00], // 6 fame
    [1.30, 1.40, 1.20], // 7 fictional-traits (villain/superhero)
    [2.40, 1.10, 0.80], // 8 nationality (is_turkish) — sorulsun erken, gereksiz olunca düş
  ];

  // 5-answer probability model.
  //
  // P(answer | has_attr):  yes=0.60, probably=0.28, dk=0.08, pno=0.03, no=0.01
  // P(answer | not_attr):  yes=0.01, probably=0.03, dk=0.08, pno=0.28, no=0.60

  static const List<double> _weights  = [ 1.00,  0.67,  0.00, -0.67, -1.00];
  static const List<double> _pGivHas  = [ 0.60,  0.28,  0.08,  0.03,  0.01];
  static const List<double> _pGivNot  = [ 0.01,  0.03,  0.08,  0.28,  0.60];

  // ── Constructor ────────────────────────────────────────────────────────────

  GameEngine(
    List<Character> characters, {
    List<String>? attributes,
    Map<String, String>? questions,
    Map<String, double>? learnedScores,
  })  : _all        = characters,
        _candidates = List<Character>.from(characters),
        _attributes = attributes ?? kAllAttributes,
        _questions  = questions  ?? kAttributeQuestions {
    for (final c in _all) {
      _scores[c]  = learnedScores?[c.name] ?? 0.0;
      _popBias[c] = (c.popularityScore / 100.0) * 0.45;
    }
    for (final a in _attributes) {
      _attrDynMult[a] = 1.0;
    }
    _currentAttribute = _selectBestQuestion();
  }

  // ── Attribute value helper ────────────────────────────────────────────────

  int _attrVal(Character c, String attr) => c.getAttribute(attr);

  // ── Softmax probability distribution ──────────────────────────────────────
  // Adds decaying popularity bias so famous characters are favoured early but
  // pure answer evidence dominates by question 14.

  Map<Character, double> _computeProbs() {
    if (_candidates.isEmpty) return {};

    final decay = _questionCount < 14 ? (1.0 - _questionCount / 14.0) : 0.0;

    double maxScore = double.negativeInfinity;
    for (final c in _candidates) {
      final s = (_scores[c] ?? 0.0) + (_popBias[c] ?? 0.0) * decay;
      if (s > maxScore) maxScore = s;
    }

    double total = 0.0;
    final exps = <Character, double>{};
    for (final c in _candidates) {
      final s = (_scores[c] ?? 0.0) + (_popBias[c] ?? 0.0) * decay;
      final v = exp(s - maxScore);
      exps[c] = v;
      total += v;
    }

    if (total == 0) {
      final u = 1.0 / _candidates.length;
      return {for (final c in _candidates) c: u};
    }
    return {for (final en in exps.entries) en.key: en.value / total};
  }

  // ── Shannon entropy ────────────────────────────────────────────────────────

  static double _shannonEntropy(Iterable<double> probs) {
    double h = 0.0;
    for (final p in probs) {
      if (p > 1e-15) h -= p * log(p) / ln2;
    }
    return h;
  }

  // ── Information Gain — 5-way simulation ───────────────────────────────────
  //
  // Pool > 1500 → fast binary approximation.
  // Pool ≤ 1500 → full simulation over all 5 answer weights.
  //
  //   IG = H_now − Σ_i P(answer_i) · H( distribution | answer_i )

  double _informationGain(
    String attr,
    Map<Character, double> probs,
    double hCurrent,
  ) {
    double pHas = 0.0;
    for (final c in _candidates) {
      if (_attrVal(c, attr) == 1) pHas += probs[c] ?? 0.0;
    }
    final pNot = 1.0 - pHas;
    if (pHas < 1e-9 || pNot < 1e-9) return 0.0;

    // Fast binary approximation for large pools
    if (_candidates.length > 1500) {
      double ig = 0.0;
      if (pHas > 1e-15) ig -= pHas * log(pHas) / ln2;
      if (pNot > 1e-15) ig -= pNot * log(pNot) / ln2;
      return ig;
    }

    // Full 5-way simulation
    double expectedH = 0.0;
    for (int i = 0; i < _weights.length; i++) {
      final w       = _weights[i];
      final pAnswer = _pGivHas[i] * pHas + _pGivNot[i] * pNot;
      if (pAnswer < 1e-9) continue;

      if (w == 0.0) {
        expectedH += pAnswer * hCurrent;
        continue;
      }

      final ePos = exp(w);
      final eNeg = exp(-w);
      final tot  = pHas * ePos + pNot * eNeg;

      double h = 0.0;
      for (final c in _candidates) {
        final p = probs[c] ?? 0.0;
        if (p < 1e-15) continue;
        final scale = _attrVal(c, attr) == 1 ? ePos : eNeg;
        final np    = p * scale / tot;
        if (np > 1e-15) h -= np * log(np) / ln2;
      }
      expectedH += pAnswer * h;
    }

    return hCurrent - expectedH;
  }

  // ── Penalty helpers ────────────────────────────────────────────────────────

  double _cooldownPenalty(int group) {
    final cooledAt = _groupCooldownAt[group];
    if (cooledAt == null) return 1.0;
    return (_questionCount - cooledAt < _groupCooldownLen) ? 0.25 : 1.0;
  }

  double _privateLifePenalty(String attr) {
    final meta = _meta[attr];
    if (meta != null && meta.isPrivateLife &&
        _questionCount < _privateLifeSuppressUntil) {
      return _privateLifePenaltyMult;
    }
    return 1.0;
  }

  // ── Combined attribute score ───────────────────────────────────────────────
  //
  // score = IG × effectiveBoost × knowability × dynMult
  //         × diversityBoost × cooldownPenalty × privPenalty

  double _scoreAttribute(
    String attr,
    Map<Character, double> probs,
    double hCurrent,
  ) {
    final ig = _informationGain(attr, probs, hCurrent);
    if (ig < 0.01) return 0.0;

    final meta        = _meta[attr];
    final group       = meta?.group ?? 6;
    final knowability = meta?.knowability ?? 0.70;

    final phase = _questionCount < 5 ? 0 : _questionCount < 12 ? 1 : 2;
    final effectiveBoost = (phase == 0 && group == 0)
        ? 2.45
        : _groupPhaseBoost[group][phase];

    final dynMult = _attrDynMult[attr] ?? 1.0;

    double diversityBoost = 1.0;
    final recent = _history.length >= 2
        ? _history.sublist(_history.length - 2)
        : _history;
    for (final h in recent) {
      if ((_meta[h.attribute]?.group ?? 6) == group) {
        diversityBoost = 0.62;
        break;
      }
    }

    final cooldown   = _cooldownPenalty(group);
    final privPenalty = _privateLifePenalty(attr);

    return ig * effectiveBoost * knowability * dynMult
        * diversityBoost * cooldown * privPenalty;
  }

  // ── Differentiator question selection ─────────────────────────────────────
  // Used when candidate pool ≤ differentiatorAt.
  // Binary IG over the top-5 candidates with uniform priors,
  // weighted by knowability, cooldown, and private-life penalty.

  String _selectBestDifferentiatorQuestion() {
    final fallback = _attributes.firstWhere(
      (a) => !_asked.contains(a),
      orElse: () => _attributes.first,
    );

    final top5 = rankedCandidates.take(5).map((en) => en.key).toList();
    if (top5.length <= 1) return fallback;

    final uniformP = 1.0 / top5.length;

    double bestScore = double.negativeInfinity;
    String bestAttr  = fallback;

    for (final attr in _attributes) {
      if (_asked.contains(attr)) continue;

      double pHas = 0.0;
      for (final c in top5) {
        if (_attrVal(c, attr) == 1) pHas += uniformP;
      }
      final pNot = 1.0 - pHas;
      if (pHas < 1e-9 || pNot < 1e-9) continue;

      // Binary entropy = IG when prior is uniform
      double ig = 0.0;
      if (pHas > 1e-15) ig -= pHas * log(pHas) / ln2;
      if (pNot > 1e-15) ig -= pNot * log(pNot) / ln2;

      final meta        = _meta[attr];
      final group       = meta?.group ?? 6;
      final knowability = meta?.knowability ?? 0.70;
      final cooldown    = _cooldownPenalty(group);
      final privPenalty = _privateLifePenalty(attr);

      final s = ig * knowability * cooldown * privPenalty;
      if (s > bestScore) {
        bestScore = s;
        bestAttr  = attr;
      }
    }
    return bestAttr;
  }

  // ── Zorunlu erken sorular ──────────────────────────────────────────────────
  // PopBias bu üç soruyu bastırır; uniform IG ile sırala, popBias'tan bağımsız.

  // Sabit sıra: kurgusal mı → cinsiyet → milliyet. IG hesabı değil, tasarım kararı.
  static const List<String> _mandatoryEarly = ['is_fictional', 'is_male', 'is_turkish'];

  // ── Question selection ─────────────────────────────────────────────────────

  String _selectBestQuestion() {
    final fallback = _attributes.firstWhere(
      (a) => !_asked.contains(a),
      orElse: () => _attributes.first,
    );
    if (_candidates.length <= 1) return fallback;

    // İlk 3 soruda zorunlu temel filtreler — sabit sırayla, popBias etkisinden bağımsız
    if (_questionCount < _mandatoryEarly.length) {
      for (final a in _mandatoryEarly) {
        if (!_asked.contains(a)) return a;
      }
    }

    if (_candidates.length <= differentiatorAt) {
      return _selectBestDifferentiatorQuestion();
    }

    final probs    = _computeProbs();
    final hCurrent = _shannonEntropy(probs.values);

    double bestScore = double.negativeInfinity;
    String bestAttr  = fallback;

    for (final attr in _attributes) {
      if (_asked.contains(attr)) continue;
      final s = _scoreAttribute(attr, probs, hCurrent);
      if (s > bestScore) {
        bestScore = s;
        bestAttr  = attr;
      }
    }
    return bestAttr;
  }

  // ── Answer ─────────────────────────────────────────────────────────────────

  void answer(AnswerType ans) {
    final attr  = _currentAttribute;
    final group = _meta[attr]?.group ?? 6;

    _asked.add(attr);
    _history.add(AskedQuestion(attr, _questions[attr] ?? attr, ans));
    _questionCount++;

    if (ans == AnswerType.dontKnow) {
      _consecutiveDontKnow++;
      // Consecutive dontKnow streak → stronger decay
      final decay = _consecutiveDontKnow >= 2 ? 0.35 : 0.50;
      _attrDynMult[attr] = (_attrDynMult[attr] ?? 1.0) * decay;
      _groupCooldownAt[group] = _questionCount;
    } else {
      _consecutiveDontKnow = 0;
    }

    final w = ans.weight;
    if (w != 0.0) {
      for (final c in _candidates) {
        final hasAttr = _attrVal(c, attr) == 1;
        _scores[c] = (_scores[c] ?? 0.0) + w * (hasAttr ? 1.0 : -1.0);
      }
    }

    _candidates = _candidates
        .where((c) => (_scores[c] ?? 0.0) > eliminationThreshold)
        .toList();

    if (_questionCount < maxQuestions && _candidates.length > 1) {
      _currentAttribute = _selectBestQuestion();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  List<AskedQuestion> get history          => List.unmodifiable(_history);
  int                 get questionCount    => _questionCount;
  bool                get isMaxReached     => _questionCount >= maxQuestions;
  String              get currentAttribute => _currentAttribute;
  String              get currentQuestion  => _questions[_currentAttribute] ?? _currentAttribute;
  int                 get candidateCount   => _candidates.length;

  List<MapEntry<Character, double>> get rankedCandidates {
    final probs = _computeProbs();
    return _candidates
        .map((c) => MapEntry(c, probs[c] ?? 0.0))
        .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
  }

  Character get bestGuess {
    final r = rankedCandidates;
    return r.isNotEmpty ? r.first.key : _all.first;
  }

  double get confidence {
    final r = rankedCandidates;
    return r.isEmpty ? 0.0 : r.first.value;
  }

  List<Character> get top5 =>
      rankedCandidates.take(5).map((en) => en.key).toList();

  bool get shouldGuess {
    if (_candidates.length <= autoGuessAt) return true;
    if (_questionCount < 3) return false;

    final top = rankedCandidates;
    if (top.isEmpty || top.length == 1) return true;

    // Early dominance: top ≥ 10× third candidate after q3
    if (top.length >= 3 && top[2].value > 0 &&
        top[0].value / top[2].value >= 10.0) {
      return true;
    }
    if (_questionCount < 4) return false;

    // Strong probability concentration
    if (top[0].value >= 0.50) return true;

    // Clear lead over second place
    if (top[1].value > 0 && top[0].value / top[1].value >= 5.0) return true;

    // Late game — force a decision rather than exhausting all questions
    if (_questionCount >= 16) return true;

    return false;
  }

  double get entropy => _shannonEntropy(_computeProbs().values);

  // Most informative unasked attribute shared by >55% of top-10 candidates.
  String? get commonTrait {
    if (_candidates.length < 2) return null;
    final topN = min(10, _candidates.length);
    final top  = rankedCandidates.take(topN).toList();
    String? best;
    double  bestRatio = 0.55;
    for (final attr in _attributes) {
      if (_asked.contains(attr)) continue;
      final count = top.where((en) => _attrVal(en.key, attr) == 1).length;
      final ratio = count / top.length;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best      = attr;
      }
    }
    return best;
  }

  String? get hintText {
    final attr = commonTrait;
    if (attr == null) return null;
    final q    = _questions[attr] ?? attr;
    final body = q
        .replaceFirst('Bu karakter ', '')
        .replaceAll(' mı?', '').replaceAll(' mi?', '')
        .replaceAll(' mısın?', '').replaceAll('?', '');
    return 'İpucu: Aday listesinin büyük çoğunluğu "$body".';
  }

  // ── Debug info ─────────────────────────────────────────────────────────────

  Map<String, dynamic> get debugInfo => {
    'questionCount':  _questionCount,
    'candidateCount': _candidates.length,
    'topCandidate':   _candidates.isNotEmpty ? bestGuess.name : 'none',
    'confidence':     confidence,
    'entropy':        entropy,
    'currentAttr':    _currentAttribute,
    'groupCooldowns': Map<String, int>.fromEntries(
      _groupCooldownAt.entries.map((e) => MapEntry('g${e.key}', e.value)),
    ),
  };

  // ── Learning stub ──────────────────────────────────────────────────────────
  // Pass the resulting map as learnedScores: on the next GameEngine() call
  // to warm-start with prior knowledge.

  void learnFromWrongGuess(Character guessed, String? actualName) {
    // TODO: store score deltas in shared_preferences keyed by character name
    // e.g. decrement guessed.name by 0.5, increment actualName by 0.5
  }
}
