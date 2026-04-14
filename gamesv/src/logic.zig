pub const Uuid = packed struct(u64) {
    pub const zero: Uuid = @bitCast(@as(u64, 0));

    player_id: u32,
    config_id: u24,
    object_type: ObjectType,

    pub const ObjectType = enum(u8) {
        _,

        pub fn fromFightObjType(fo: pb.FightObjType) ObjectType {
            const raw: u8 = @intCast(std.math.log2_int(u32, @intCast(@intFromEnum(fo))) + 1);
            return @enumFromInt(raw);
        }

        pub fn toFightObjType(ot: ObjectType) ?pb.FightObjType {
            const raw = @intFromEnum(ot);
            if (raw == 0) return null;

            const fo = @as(u32, 1) << @truncate(raw - 1);
            return std.enums.fromInt(pb.FightObjType, fo);
        }
    };

    pub fn hero(player_id: PlayerStore.ID, config_id: tables.hero.Id) Uuid {
        return .{
            .player_id = player_id.toInt(),
            .config_id = @intFromEnum(config_id),
            .object_type = .fromFightObjType(.FO_Hero),
        };
    }

    pub fn monster(id: u32, config_id: u24) Uuid {
        return .{
            .player_id = id,
            .config_id = config_id,
            .object_type = .fromFightObjType(.FO_Monster),
        };
    }

    pub inline fn toInt(uuid: Uuid) u64 {
        return @bitCast(uuid);
    }
};

pub const System = enum(u32) {
    mainMenu = 1,
    hero = 3,
    formation = 4,
    pet = 5,
    shop = 6,
    home = 7,
    product = 8,
    cook = 9,
    mount = 10,
    activation = 11,
    achievement = 12,
    bag = 13,
    task = 14,
    mail = 15,
    recover = 16,
    friend = 17,
    chat = 18,
    playerCard = 19,
    photo = 20,
    science = 21,
    skill = 22,
    star = 23,
    soulEssence = 24,
    accessory = 25,
    heroData = 26,
    dungeon = 27,
    climbTower = 28,
    signIn = 29,
    map = 30,
    adventure = 31,
    option = 32,
    handbook = 33,
    gameAct = 34,
    starManual = 35,
    announcement = 36,
    spritMaterial = 37,
    skillMaterial = 38,
    wildBoss = 39,
    equipMaterial = 40,
    weeklyBoss = 41,
    quickRoulette = 42,
    scanning = 43,
    heroFavorability = 50,
    present = 51,
    dorm = 53,
    journeyTask = 57,
    noviceTask = 58,
    announcemenet = 59,
    pamiTalk = 60,
    itemAccess = 71,
    mainBanner = 72,
    mod = 73,
    community = 74,
    petStationed = 91,
    multiDungeon = 95,
    specialPet = 96,
    assetMenu = 98,
    stamina = 99,
    ultimateSkill = 100,
    mountEditRoulette = 101,
    mapCollectionTrace = 102,
    bagSoulEssence = 131,
    bagAccessory = 132,
    bagFood = 134,
    mountSnackBag = 139,
    petPuzzleRoulette = 155,
    eradicatingCrop = 156,
    retireFarmLand = 157,
    productQuick = 164,
    homeCenter = 165,
    homeCenterProduction = 166,
    homeCenterCrop = 167,
    homeCenterCollection = 169,
    homeCenterPet = 170,
    homeCenterRanch = 171,
    petCatalog = 172,
    entrustTask = 173,
    playerDisplayHero = 190,
    playerRename = 191,
    playerDisplayText = 192,
    petDisplay = 193,
    spiritSwitchBag = 241,
    spiritUpgradeBag = 242,
    accessoryStrength = 251,
    accessoryStrengthBag = 252,
    heroDataStory = 261,
    heroDataVoice = 262,
    heroDataDrama = 263,
    goldResource = 270,
    heroResource = 271,
    soulEssenceResource = 272,
    petResource = 273,
    characterExpDungon = 361,
    spritExpDungon = 362,
    petExpDungon = 363,
    coinDungon = 364,
    spiritBreakDungon1 = 371,
    spiritBreakDungon2 = 372,
    spiritBreakDungon3 = 373,
    skillMaterialDungeon1 = 381,
    skillMaterialDungeon2 = 382,
    skillMaterialDungeon3 = 383,
    skillMaterialDungeon4 = 384,
    skillMaterialDungeon5 = 385,
    wildBossDungeon1 = 391,
    wildBossDungeon2 = 392,
    wildBossDungeon3 = 393,
    wildBossDungeon4 = 394,
    warriorResource = 401,
    assassinResource = 402,
    archerResource = 403,
    casterResource = 404,
    supporterResource = 405,
    weeklyBossDungeon1 = 411,
    petStrength = 501,
    petRankUp = 503,
    petGene = 504,
    petDecoration = 505,
    petRelease = 506,
    petFeed = 507,
    petBox = 508,
    moneyShopRecharge = 601,
    moneyShopYellow = 602,
    moneyShopGreen = 603,
    moneyShopGift = 604,
    moneyRaffleGoods = 605,
    moneyShopCity = 650,
    furnitureShop = 655,
    specialShop = 680,
    diamond = 690,
    homeLevel = 701,
    homeScience = 702,
    homeBag = 703,
    satietyBuilding = 704,
    homePlowLand = 705,
    heroStrength = 1001,
    skillStrength = 1002,
    soulEssenceStrength = 1003,
    soulEssenceAdvance = 1005,
    catchPet = 1006,
    tutorial = 1007,
    petDuelNpcType = 1010,
    petDuel = 1011,
    heroTalent = 1012,
    petFavor = 1013,
    renameHome = 1100,
    renameKibo = 1101,
    renameKiboBox = 1102,
    renameTeam = 1103,
    renameFriend = 1104,
    renameMapMark = 1105,
    renamePhotoTemplate = 1106,
    noviceDuelTask = 1107,
    kiboDuelAreaLevel = 1110,
    libraryBook = 1201,
    transactionCenter = 1301,
    rogue = 1401,
    homePlace = 1502,
    homeDormManage = 1503,
    wishlist = 1504,
    HomeRecipe = 1505,
    trainTask = 1731,
    petDuelTask = 1732,
    multiTeamDungeon = 1733,
    MultiTeamHub = 2000,
    NestCoop = 2001,
    PowerOfConnection = 3004,
    formationQuickHero = 4001,
    formationQuickPet = 4002,
    formationBaseHero = 4003,
    formationBasePet = 4004,
    heroWearPet = 4005,
    formationDownPet = 4006,
    waterMark = 9901,
    testingWaterMark = 9902,
    runeCompose = 10121,
    onlyChat = 99918,
};

pub const Services = @import("logic/Services.zig");

pub const math = @import("logic/math.zig");
pub const gameplay = @import("logic/gameplay.zig");
pub const PlayerStore = @import("logic/PlayerStore.zig");
pub const big_world = @import("logic/big_world.zig");

const tables = @import("tables.zig");
const pb = @import("proto").pb;
const std = @import("std");
