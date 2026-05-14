class Character {
  final String name;
  final int isMale;
  final int isFictional;
  final int age;
  final int isMarried;
  final int isTurkish;
  final int fromMovie;
  final int fromAnime;
  final int fromTvSeries;
  final int isPolitician;
  final int isActor;
  final int isSinger;
  final int isSportsman;
  final int isHistorical;
  final int popularityScore;
  final int heightCm;
  final int hasChildren;
  final int isAlive;
  final int birthYear;
  final String category;
  final String nationality;
  final int hasBeard;
  final int wearsGlasses;
  final int isFootballPlayer;
  final int isRapper;
  final int isYoutuber;
  final String knownFor;
  final int isDirector;
  final int isModel;
  final int isComedian;
  final int isTvHost;
  final int isVillain;
  final int isSuperhero;
  // New columns (col 33–50)
  final String burc;
  final int likesStrawberryMilk;
  final int hasDog;
  final int hasCat;
  final String favoriteFood;
  final double spotifyListenersMillion;
  final int playedForGalatasaray;
  final int playedForFenerbahce;
  final int playedForBesiktas;
  final int playedForRealMadrid;
  final int wonBallonDor;
  final int wonOscar;
  final int wonGrammy;
  final int divorced;
  final int hasFamousPartner;
  final int isBald;
  final int hasTattoo;
  final int knownFor80s;

  const Character({
    required this.name,
    required this.isMale,
    required this.isFictional,
    required this.age,
    required this.isMarried,
    required this.isTurkish,
    required this.fromMovie,
    required this.fromAnime,
    required this.fromTvSeries,
    required this.isPolitician,
    required this.isActor,
    required this.isSinger,
    required this.isSportsman,
    required this.isHistorical,
    required this.popularityScore,
    required this.heightCm,
    required this.hasChildren,
    required this.isAlive,
    required this.birthYear,
    required this.category,
    required this.nationality,
    required this.hasBeard,
    required this.wearsGlasses,
    required this.isFootballPlayer,
    required this.isRapper,
    required this.isYoutuber,
    required this.knownFor,
    this.isDirector              = 0,
    this.isModel                 = 0,
    this.isComedian              = 0,
    this.isTvHost                = 0,
    this.isVillain               = 0,
    this.isSuperhero             = 0,
    this.burc                    = '',
    this.likesStrawberryMilk     = 0,
    this.hasDog                  = 0,
    this.hasCat                  = 0,
    this.favoriteFood            = '',
    this.spotifyListenersMillion = 0,
    this.playedForGalatasaray    = 0,
    this.playedForFenerbahce     = 0,
    this.playedForBesiktas       = 0,
    this.playedForRealMadrid     = 0,
    this.wonBallonDor            = 0,
    this.wonOscar                = 0,
    this.wonGrammy               = 0,
    this.divorced                = 0,
    this.hasFamousPartner        = 0,
    this.isBald                  = 0,
    this.hasTattoo               = 0,
    this.knownFor80s             = 0,
  });

  int getAttribute(String attr) {
    switch (attr) {
      // ── Direct CSV fields ─────────────────────────────────────────────────
      case 'is_male':               return isMale;
      case 'is_fictional':          return isFictional;
      case 'is_married':            return isMarried;
      case 'is_turkish':            return isTurkish;
      case 'from_movie':            return fromMovie;
      case 'from_anime':            return fromAnime;
      case 'from_tv_series':        return fromTvSeries;
      case 'is_politician':         return isPolitician;
      case 'is_actor':              return isActor;
      case 'is_singer':             return isSinger;
      case 'is_sportsman':          return isSportsman;
      case 'is_historical':         return isHistorical;
      case 'has_children':          return hasChildren;
      case 'is_alive':              return isAlive;
      case 'has_beard':             return hasBeard;
      case 'wears_glasses':         return wearsGlasses;
      case 'is_football_player':    return isFootballPlayer;
      case 'is_rapper':             return isRapper;
      case 'is_youtuber':           return isYoutuber;
      case 'is_director':           return isDirector;
      case 'is_model':              return isModel;
      case 'is_comedian':           return isComedian;
      case 'is_tv_host':            return isTvHost;
      case 'is_villain':            return isVillain;
      case 'is_superhero':          return isSuperhero;
      case 'likes_strawberry_milk': return likesStrawberryMilk;
      case 'has_dog':               return hasDog;
      case 'has_cat':               return hasCat;
      case 'played_for_galatasaray':return playedForGalatasaray;
      case 'played_for_fenerbahce': return playedForFenerbahce;
      case 'played_for_besiktas':   return playedForBesiktas;
      case 'played_for_real_madrid':return playedForRealMadrid;
      case 'won_ballon_dor':        return wonBallonDor;
      case 'won_oscar':             return wonOscar;
      case 'won_grammy':            return wonGrammy;
      case 'divorced':              return divorced;
      case 'has_famous_partner':    return hasFamousPartner;
      case 'is_bald':               return isBald;
      case 'has_tattoo':            return hasTattoo;
      case 'known_for_80s':         return knownFor80s;
      // ── Threshold / derived ───────────────────────────────────────────────
      case 'age_under_25':          return age > 0 && age < 25 ? 1 : 0;
      case 'age_under_35':          return age > 0 && age < 35 ? 1 : 0;
      case 'age_over_40':           return age >= 40 ? 1 : 0;
      case 'age_over_50':           return age >= 50 ? 1 : 0;
      case 'age_over_60':           return age >= 60 ? 1 : 0;
      case 'age_over_70':           return age >= 70 ? 1 : 0;
      case 'born_after_1980':       return birthYear > 1980 ? 1 : 0;
      case 'born_after_1990':       return birthYear > 1990 ? 1 : 0;
      case 'born_before_1960':      return birthYear > 0 && birthYear < 1960 ? 1 : 0;
      case 'height_tall':           return heightCm >= 185 ? 1 : 0;
      case 'height_short':          return heightCm > 0 && heightCm <= 170 ? 1 : 0;
      case 'popularity_high':       return popularityScore >= 85 ? 1 : 0;
      case 'very_popular':          return popularityScore >= 95 ? 1 : 0;
      case 'spotify_over_10m':      return spotifyListenersMillion >= 10 ? 1 : 0;
      case 'spotify_over_50m':      return spotifyListenersMillion >= 50 ? 1 : 0;
      // ── Compound / logical ────────────────────────────────────────────────
      case 'from_fiction_media':    return (fromMovie == 1 || fromAnime == 1 || fromTvSeries == 1) ? 1 : 0;
      case 'is_musician':           return (isSinger == 1 || isRapper == 1) ? 1 : 0;
      case 'is_athlete':            return (isSportsman == 1 || isFootballPlayer == 1) ? 1 : 0;
      case 'is_in_entertainment':   return (isSinger == 1 || isActor == 1 || isYoutuber == 1) ? 1 : 0;
      case 'has_pet':               return (hasDog == 1 || hasCat == 1) ? 1 : 0;
      case 'played_for_big_three':  return (playedForGalatasaray == 1 || playedForFenerbahce == 1 || playedForBesiktas == 1) ? 1 : 0;
      case 'won_major_award':       return (wonBallonDor == 1 || wonOscar == 1 || wonGrammy == 1) ? 1 : 0;
      // ── Zodiac ────────────────────────────────────────────────────────────
      case 'burc_aslan':    return burc == 'Aslan' ? 1 : 0;
      case 'burc_akrep':    return burc == 'Akrep' ? 1 : 0;
      case 'burc_kova':     return burc == 'Kova' ? 1 : 0;
      case 'burc_boga':     return burc == 'Boğa' ? 1 : 0;
      case 'burc_yengec':   return burc == 'Yengeç' ? 1 : 0;
      case 'burc_balik':    return burc == 'Balık' ? 1 : 0;
      case 'burc_koc':      return burc == 'Koç' ? 1 : 0;
      case 'burc_ikizler':  return burc == 'İkizler' ? 1 : 0;
      case 'burc_basak':    return burc == 'Başak' ? 1 : 0;
      case 'burc_oglak':    return burc == 'Oğlak' ? 1 : 0;
      case 'burc_terazi':   return burc == 'Terazi' ? 1 : 0;
      case 'burc_koc2':     return burc == 'Koç' ? 1 : 0;
      // ── Favorite food ─────────────────────────────────────────────────────
      case 'food_kebap':    return favoriteFood.toLowerCase() == 'kebap' ? 1 : 0;
      case 'food_pizza':    return favoriteFood.toLowerCase() == 'pizza' ? 1 : 0;
      case 'food_sushi':    return favoriteFood.toLowerCase() == 'sushi' ? 1 : 0;
      case 'food_baklava':  return favoriteFood.toLowerCase() == 'baklava' ? 1 : 0;
      default:              return 0;
    }
  }

  factory Character.fromCsvRow(List<String> row) {
    return Character(
      name:             row[0],
      isMale:           _parseInt(row[1]),
      isFictional:      _parseInt(row[2]),
      age:              _parseInt(row[3]),
      isMarried:        _parseInt(row[4]),
      isTurkish:        _parseInt(row[5]),
      fromMovie:        _parseInt(row[6]),
      fromAnime:        _parseInt(row[7]),
      fromTvSeries:     _parseInt(row[8]),
      isPolitician:     _parseInt(row[9]),
      isActor:          _parseInt(row[10]),
      isSinger:         _parseInt(row[11]),
      isSportsman:      _parseInt(row[12]),
      isHistorical:     _parseInt(row[13]),
      popularityScore:  _parseInt(row[14]),
      heightCm:         _parseInt(row[15]),
      hasChildren:      _parseInt(row[16]),
      isAlive:          _parseInt(row[17]),
      birthYear:        _parseInt(row[18]),
      category:         row[19],
      nationality:      row[20],
      hasBeard:         _parseInt(row[21]),
      wearsGlasses:     _parseInt(row[22]),
      isFootballPlayer: _parseInt(row[23]),
      isRapper:         _parseInt(row[24]),
      isYoutuber:       _parseInt(row[25]),
      knownFor:         row.length > 26 ? row[26] : '',
      isDirector:       row.length > 27 ? _parseInt(row[27]) : 0,
      isModel:          row.length > 28 ? _parseInt(row[28]) : 0,
      isComedian:       row.length > 29 ? _parseInt(row[29]) : 0,
      isTvHost:         row.length > 30 ? _parseInt(row[30]) : 0,
      isVillain:        row.length > 31 ? _parseInt(row[31]) : 0,
      isSuperhero:      row.length > 32 ? _parseInt(row[32]) : 0,
      burc:                    row.length > 33 ? row[33] : '',
      likesStrawberryMilk:     row.length > 34 ? _parseInt(row[34]) : 0,
      hasDog:                  row.length > 35 ? _parseInt(row[35]) : 0,
      hasCat:                  row.length > 36 ? _parseInt(row[36]) : 0,
      favoriteFood:            row.length > 37 ? row[37] : '',
      spotifyListenersMillion: row.length > 38 ? _parseDouble(row[38]) : 0,
      playedForGalatasaray:    row.length > 39 ? _parseInt(row[39]) : 0,
      playedForFenerbahce:     row.length > 40 ? _parseInt(row[40]) : 0,
      playedForBesiktas:       row.length > 41 ? _parseInt(row[41]) : 0,
      playedForRealMadrid:     row.length > 42 ? _parseInt(row[42]) : 0,
      wonBallonDor:            row.length > 43 ? _parseInt(row[43]) : 0,
      wonOscar:                row.length > 44 ? _parseInt(row[44]) : 0,
      wonGrammy:               row.length > 45 ? _parseInt(row[45]) : 0,
      divorced:                row.length > 46 ? _parseInt(row[46]) : 0,
      hasFamousPartner:        row.length > 47 ? _parseInt(row[47]) : 0,
      isBald:                  row.length > 48 ? _parseInt(row[48]) : 0,
      hasTattoo:               row.length > 49 ? _parseInt(row[49]) : 0,
      knownFor80s:             row.length > 50 ? _parseInt(row[50]) : 0,
    );
  }

  static int    _parseInt(String s)  => int.tryParse(s.trim()) ?? 0;
  static double _parseDouble(String s) => double.tryParse(s.trim()) ?? 0;

  @override
  String toString() => name;
}
