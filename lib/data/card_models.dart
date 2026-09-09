import 'package:flutter/painting.dart';

import '../game/faction_colors.dart';

enum Faction { wei, shu, wu, other }

enum TroopType { cavalry, spear, bow, siege, infantry }

class CardFace {
  const CardFace({
    required this.id,
    required this.nameZh,
    required this.faction,
    required this.cost,
    required this.troop,
    required this.force,
    required this.intel,
    required this.skills,
    required this.strategyName,
    required this.strategyMorale,
    required this.strategyEffect,
    required this.portraitAsset,
    required this.source,
  });

  final String id;
  final String nameZh;
  final Faction faction;
  final double cost;
  final TroopType troop;
  /// Display string — may be "10+" or "—" for gap.
  final String force;
  final String intel;
  final List<String> skills;
  final String strategyName;
  final int strategyMorale;
  final String strategyEffect;
  final String portraitAsset;
  final String source;

  Color get factionColor {
    switch (faction) {
      case Faction.wei:
        return FactionColors.wei;
      case Faction.shu:
        return FactionColors.shu;
      case Faction.wu:
        return FactionColors.wu;
      case Faction.other:
        return FactionColors.other;
    }
  }

  String get troopLabel {
    switch (troop) {
      case TroopType.cavalry:
        return '騎';
      case TroopType.spear:
        return '槍';
      case TroopType.bow:
        return '弓';
      case TroopType.siege:
        return '攻城';
      case TroopType.infantry:
        return '步';
    }
  }
}

/// Cost6 day-1 decks — sourced from `/workspace/three-kingdoms/cost6-card-face-copy.md`.
class Cost6Roster {
  static const List<CardFace> all = [
    // 魏
    CardFace(
      id: 'caocao',
      nameZh: '曹操',
      faction: Faction.wei,
      cost: 2.5,
      troop: TroopType.cavalry,
      force: '8',
      intel: '10',
      skills: ['伏', '魅'],
      strategyName: '覇者の求心',
      strategyMorale: 6,
      strategyEffect: '範圍內的魏味方所有武力上升',
      portraitAsset: 'assets/portraits/caocao.png',
      source: '[wiki] 天魏-3',
    ),
    CardFace(
      id: 'caoren',
      nameZh: '曹仁',
      faction: Faction.wei,
      cost: 1.5,
      troop: TroopType.cavalry,
      force: '6',
      intel: '5',
      skills: [],
      strategyName: '神速戦法',
      strategyMorale: 4,
      strategyEffect: '自身武力與移動速度上升',
      portraitAsset: 'assets/portraits/caoren.png',
      source: '[wiki] 天魏-025 UC',
    ),
    CardFace(
      id: 'zhanghe',
      nameZh: '張郃',
      faction: Faction.wei,
      cost: 2.0,
      troop: TroopType.spear,
      force: '7',
      intel: '7',
      skills: ['勇猛'],
      strategyName: '魏武の強兵',
      strategyMorale: 3,
      strategyEffect: '自身武力長時間上升',
      portraitAsset: 'assets/portraits/zhanghe.png',
      source: '[wiki] 天魏-3',
    ),
    // 蜀
    CardFace(
      id: 'liubei',
      nameZh: '劉備',
      faction: Faction.shu,
      cost: 2.0,
      troop: TroopType.spear,
      force: '6',
      intel: '7',
      skills: ['復活', '魅力', '募兵'],
      strategyName: '劉備の大徳',
      strategyMorale: 6,
      strategyEffect: '範圍內的蜀味方所有武力上升',
      portraitAsset: 'assets/portraits/liubei.png',
      source: '[wiki] 天蜀-4',
    ),
    CardFace(
      id: 'zhangfei',
      nameZh: '張飛',
      faction: Faction.shu,
      cost: 2.0,
      troop: TroopType.spear,
      force: '9',
      intel: '1',
      skills: ['勇猛'],
      strategyName: '強化戦法',
      strategyMorale: 4,
      strategyEffect: '自身武力上升',
      portraitAsset: 'assets/portraits/zhangfei.png',
      source: '[wiki] 天蜀-3',
    ),
    CardFace(
      id: 'zhaoyun',
      nameZh: '趙雲',
      faction: Faction.shu,
      cost: 2.0,
      troop: TroopType.cavalry,
      force: '7',
      intel: '7',
      skills: ['募兵'],
      strategyName: '神速戦法',
      strategyMorale: 4,
      strategyEffect: '自身武力與移動速度上升',
      portraitAsset: 'assets/portraits/zhaoyun.png',
      source: '[wiki] 天蜀-2',
    ),
    // 吳
    CardFace(
      id: 'sunquan',
      nameZh: '孫權',
      faction: Faction.wu,
      cost: 1.5,
      troop: TroopType.bow,
      force: '4',
      intel: '7',
      skills: ['防柵', '魅力'],
      strategyName: '若き王の手腕',
      strategyMorale: 6,
      strategyEffect: '範圍內的吳味方所有武力上升',
      portraitAsset: 'assets/portraits/sunquan.png',
      source: '[wiki] 天呉-2',
    ),
    CardFace(
      id: 'zhouyu',
      nameZh: '周瑜',
      faction: Faction.wu,
      cost: 2.0,
      troop: TroopType.bow,
      force: '6',
      intel: '10',
      skills: ['伏兵', '魅力'],
      strategyName: '赤壁の大火',
      strategyMorale: 7,
      strategyEffect: '範圍內敵受炎傷害；傷害隨雙方知力上下',
      portraitAsset: 'assets/portraits/zhouyu.png',
      source: '[wiki] 天呉-1',
    ),
    CardFace(
      id: 'chengpu',
      nameZh: '程普',
      faction: Faction.wu,
      cost: 1.5,
      troop: TroopType.bow,
      force: '5',
      intel: '6',
      skills: ['防柵'],
      strategyName: '遠弓戦法',
      strategyMorale: 4,
      strategyEffect: '自身武力與射程上升',
      portraitAsset: 'assets/portraits/chengpu.png',
      source: '[wiki] 天呉-3',
    ),
    CardFace(
      id: 'zhanghong',
      nameZh: '張紘',
      faction: Faction.wu,
      cost: 1.0,
      troop: TroopType.spear,
      force: '2',
      intel: '8',
      skills: ['伏兵'],
      strategyName: '浄化の計',
      strategyMorale: 3,
      strategyEffect: '消去範圍內味方身上、由敵計略造成的效果',
      portraitAsset: 'assets/portraits/zhanghong.png',
      source: '[wiki] 天呉-026 UC',
    ),
    // 他國
    CardFace(
      id: 'lvbu',
      nameZh: '呂布',
      faction: Faction.other,
      cost: 3.0,
      troop: TroopType.cavalry,
      force: '10+',
      intel: '1',
      skills: ['勇猛'],
      strategyName: '天下無双',
      strategyMorale: 6,
      strategyEffect: '自身武力大幅上升；並回復兵力、移動速度與知力上升',
      portraitAsset: 'assets/portraits/lvbu.png',
      source: '[wiki] 天群雄-3',
    ),
    CardFace(
      id: 'zhanglu',
      nameZh: '張魯',
      faction: Faction.other,
      cost: 1.0,
      troop: TroopType.bow,
      force: '2',
      intel: '6',
      skills: [],
      strategyName: '五斗米道',
      strategyMorale: 4,
      strategyEffect: '復活1支已撤退的群雄味方（多支時隨機）；出現在自城內',
      portraitAsset: 'assets/portraits/zhanglu.png',
      source: '[wiki] 天群雄-018 C',
    ),
    CardFace(
      id: 'zhangliang',
      nameZh: '張梁',
      faction: Faction.other,
      cost: 1.0,
      troop: TroopType.infantry,
      force: '5',
      intel: '1',
      skills: [],
      strategyName: '黄巾の群れ',
      strategyMorale: 3,
      strategyEffect: '自身兵力回復',
      portraitAsset: 'assets/portraits/zhangliang.png',
      source: '[wiki] 天群雄-017 C',
    ),
    CardFace(
      id: 'chenlan',
      nameZh: '陳蘭',
      faction: Faction.other,
      cost: 1.0,
      troop: TroopType.siege,
      force: '3',
      intel: '4',
      skills: [],
      strategyName: '香車戦法',
      strategyMorale: 2,
      strategyEffect: '移動速度上升；效果中強制前進',
      portraitAsset: 'assets/portraits/chenlan.png',
      source: '[wiki] 天群雄-2；[official] 大戦3',
    ),
  ];

  static List<CardFace> byFaction(Faction f) =>
      all.where((c) => c.faction == f).toList(growable: false);
}
