import '../models/character.dart';
import '../models/thing_entry.dart';
import '../models/any_result.dart';
import 'game_engine.dart' show GameEngine, AnswerType;
import 'thing_engine.dart';

class _RoutingStep {
  final String  question;
  final String? branch;    // null=GameEngine, 'continue'=keep routing, other=ThingEngine branch
  final String? thingAttr; // attribute pre-scored from the answer
  final int     skipOnNo;  // skip this many extra steps when answer is NO/probably_not
  const _RoutingStep(this.question, this.branch, [this.thingAttr, this.skipOnNo = 0]);
}

class UniversalEngine {
  // Routing asks the broadest discriminators first.
  // 'continue' branch: YES keeps routing (no branch yet); NO skips ahead by skipOnNo steps.
  static const List<_RoutingStep> _routingSteps = [
    // 0. Living — en doğal ilk soru; NO: person+animal atla (2 adım) → food'a geç
    _RoutingStep('Canlı bir şey mi?', 'continue', 'is_living', 2),
    // 1-2. Yalnızca living=YES ise ulaşılır
    _RoutingStep('Aklındaki şey bir kişi mi?', null, 'is_person'),
    _RoutingStep('Bir hayvan mı?', 'animal', 'is_animal'),
    // 3-5. Yiyecek / içecek / bitki
    _RoutingStep('Yiyecek mi?', 'plant_food', 'is_food'),
    _RoutingStep('İçecek mi?', 'plant_food', 'is_drink'),
    _RoutingStep('Bir bitki mi?', 'plant_food', 'is_plant'),
    // 6. Health — abstract'tan ÖNCE (health öğeleri is_abstract=1)
    _RoutingStep('Sağlıkla ilgili bir hastalık ya da belirti mi?', 'health_condition', 'is_health_condition'),
    // 7. Symbol — abstract'tan ÖNCE (symbol öğeleri is_abstract=1)
    _RoutingStep('Bir sembol ya da işaret mi?', 'symbol', 'is_symbol'),
    // 8. Abstract
    _RoutingStep('Soyut bir kavram veya duygu mu?', 'abstract_concept', 'is_abstract'),
    // 9. Vehicle
    _RoutingStep('Bir taşıt mı?', 'vehicle', 'is_vehicle'),
    // 10. Place
    _RoutingStep('Bir yer mi?', 'place_building', 'is_place'),
    // 11. Digital
    _RoutingStep('Elektronik cihaz veya yazılım mı?', 'digital_product', 'is_digital'),
    // 12. Brand
    _RoutingStep('Bir marka mı?', 'brand_product', 'is_brand'),
    // 13. Object
    _RoutingStep('Elle tutulabilen bir nesne mi?', 'object_tool_household', 'is_object'),
    // 14. Mythical/fictional
    _RoutingStep('Kurgusal veya efsanevi bir varlık mı?', 'mythical_symbolic_being', 'is_fictional'),
    // 15. Space
    _RoutingStep('Uzayla ilgili bir şey mi?', 'space_thing', 'is_space_related'),
    // 16. Natural
    _RoutingStep('Doğada bulunan bir fenomen mi?', 'natural_thing', 'is_found_in_nature'),
  ];

  final List<Character>  _characters;
  final List<ThingEntry> _things;

  int  _routerStep = 0;
  bool _inRouter   = true;

  final List<String> _negativeRouterAttrs = [];
  final List<String> _positiveRouterAttrs = [];

  GameEngine?  _gameEngine;
  ThingEngine? _thingEngine;

  UniversalEngine(this._characters, this._things);

  void _handleRouterAnswer(AnswerType ans) {
    final positive = ans == AnswerType.yes || ans == AnswerType.probably;
    final step = _routingSteps[_routerStep];

    if (positive) {
      if (step.branch == 'continue') {
        // Record the positive attr (e.g. is_living=YES) and keep routing
        if (step.thingAttr != null) _positiveRouterAttrs.add(step.thingAttr!);
        _routerStep++;
        if (_routerStep >= _routingSteps.length) _activateBranch('__all__');
      } else {
        // Save the terminal attr (e.g. is_vehicle, is_food) so ThingEngine
        // doesn't waste Q1 re-asking the branch-defining question
        if (step.thingAttr != null) _positiveRouterAttrs.add(step.thingAttr!);
        _activateBranch(step.branch);
      }
    } else {
      if (step.thingAttr != null) _negativeRouterAttrs.add(step.thingAttr!);
      _routerStep += 1 + step.skipOnNo;
      if (_routerStep >= _routingSteps.length) _activateBranch('__all__');
    }
  }

  void _activateBranch(String? branch) {
    _inRouter = false;
    if (branch == null) {
      _gameEngine = GameEngine(_characters);
    } else {
      final preAnswers = <String, AnswerType>{
        for (final a in _negativeRouterAttrs) a: AnswerType.no,
        for (final a in _positiveRouterAttrs) a: AnswerType.yes,
      };
      _thingEngine = ThingEngine(
        _things,
        forceBranch: branch == '__all__' ? null : branch,
        preAnswers: preAnswers.isEmpty ? null : preAnswers,
      );
    }
  }

  String get currentQuestion {
    if (_inRouter) return _routingSteps[_routerStep].question;
    if (_gameEngine != null) return _gameEngine!.currentQuestion;
    return _thingEngine!.currentQuestion;
  }

  void answer(AnswerType ans) {
    if (_inRouter) {
      _handleRouterAnswer(ans);
    } else if (_gameEngine != null) {
      _gameEngine!.answer(ans);
    } else {
      _thingEngine!.answer(ans);
    }
  }

  bool get shouldGuess {
    if (_inRouter) return false;
    if (_gameEngine != null) return _gameEngine!.shouldGuess;
    return _thingEngine!.shouldGuess;
  }

  bool get isMaxReached {
    if (_inRouter) return false;
    if (_gameEngine != null) return _gameEngine!.isMaxReached;
    return _thingEngine!.isMaxReached;
  }

  int get questionCount {
    if (_gameEngine != null) return _gameEngine!.questionCount;
    if (_thingEngine != null) return _thingEngine!.questionCount;
    return _routerStep;
  }

  int get candidateCount {
    if (_gameEngine != null) return _gameEngine!.candidateCount;
    if (_thingEngine != null) return _thingEngine!.candidateCount;
    return _characters.length + _things.length;
  }

  AnyResult get bestResult {
    if (_gameEngine != null) {
      final c = _gameEngine!.bestGuess;
      return AnyResult(
        name:        c.name,
        category:    c.category,
        description: '${c.nationality} • ${c.knownFor}',
        isPerson:    true,
      );
    }
    if (_thingEngine != null) return _thingEngine!.bestResult;
    return const AnyResult(name: '?', category: '', description: '', isPerson: false);
  }

  List<AnyResult> get top5Results {
    if (_gameEngine != null) {
      return _gameEngine!.top5.map((c) => AnyResult(
        name:        c.name,
        category:    c.category,
        description: '${c.nationality} • ${c.knownFor}',
        isPerson:    true,
      )).toList();
    }
    if (_thingEngine != null) {
      return _thingEngine!.top5.map((t) => t.toResult()).toList();
    }
    return [];
  }

  List<MapEntry<AnyResult, double>> get rankedResults {
    if (_gameEngine != null) {
      return _gameEngine!.rankedCandidates.take(10).map((e) => MapEntry(
        AnyResult(
          name:        e.key.name,
          category:    e.key.category,
          description: '${e.key.nationality} • ${e.key.knownFor}',
          isPerson:    true,
        ),
        e.value,
      )).toList();
    }
    if (_thingEngine != null) {
      return _thingEngine!.rankedCandidates.take(10).map((e) => MapEntry(
        e.key.toResult(),
        e.value,
      )).toList();
    }
    return [];
  }

  bool get isRouting => _inRouter;
}
