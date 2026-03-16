-- Luacheck configuration for OHA (Open Hyper AI) Dota 2 bot framework
-- Targets Lua 5.1 (Dota 2 VScript engine)

std = "lua51"
max_line_length = false  -- Don't enforce line length (upstream code is what it is)

-- Dota 2 Bot Scripting API globals (read-only)
-- Reference: https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting
read_globals = {
    -- Core
    "GetBot", "GetTeam", "GetOpposingTeam", "GetTeamMember", "GetTeamPlayers",
    "GetScriptDirectory", "GetGameMode", "GetGameState",
    "DotaTime", "GameTime",
    "Vector", "RandomInt", "RandomFloat", "RandomVector",
    "RemapValClamped", "Clamp", "Min", "PointToLineDistance",

    -- Heroes
    "GetSelectedHeroName", "SelectHero", "IsHeroAlive", "IsPlayerBot",
    "IsPlayerInHeroSelectionControl", "IsTeamPlayer", "GetTeamForPlayer",
    "GetHeroKills", "GetHeroDeaths", "GetHeroAssists", "GetHeroLastSeenInfo",

    -- Units
    "GetUnitList", "GetUnitToLocationDistance", "GetUnitToUnitDistance",

    -- Buildings
    "GetTower", "GetBarracks", "GetAncient",

    -- Map
    "GetLaneFrontLocation", "GetLaneFrontAmount", "GetAmountAlongLane",
    "IsLocationPassable", "IsLocationVisible", "IsRadiusVisible",
    "GetHeightLevel", "GetTreeLocation", "GetShopLocation",
    "GetRuneSpawnLocation", "GetRuneStatus", "GetRuneType",
    "GetClosestOutpost", "GetGateNearLane",
    "GetRoshanDesire", "GetRoshanKillTime",
    "GetDroppedItemList",

    -- Items
    "GetItemCost", "GetItemStockCount", "GetItemComponents",
    "IsItemPurchasedFromSecretShop",
    "GetCourier", "GetCourierState",
    "GetGlyphCooldown",

    -- Creeps
    "GetBestLastHitCreep", "GetBestDenyCreep",
    "GetFurthestEnemyAttackRange",

    -- Chat
    "InstallChatCallback",

    -- Constants: Game State
    "GAME_STATE_HERO_SELECTION", "GAME_STATE_STRATEGY_TIME",
    "GAME_STATE_PRE_GAME", "GAME_STATE_GAME_IN_PROGRESS",

    -- Constants: Game Mode
    "GAMEMODE_CM", "GAMEMODE_REVERSE_CM", "GAMEMODE_1V1MID",
    "GAMEMODE_MO", "GAMEMODE_TURBO",

    -- Constants: Teams
    "TEAM_RADIANT", "TEAM_DIRE", "TEAM_NEUTRAL", "TEAM_NONE",

    -- Constants: Lanes
    "LANE_TOP", "LANE_MID", "LANE_BOT",

    -- Constants: Towers
    "TOWER_TOP_1", "TOWER_TOP_2", "TOWER_TOP_3",
    "TOWER_MID_1", "TOWER_MID_2", "TOWER_MID_3",
    "TOWER_BOT_1", "TOWER_BOT_2", "TOWER_BOT_3",
    "TOWER_BASE_1", "TOWER_BASE_2",

    -- Constants: Barracks
    "BARRACKS_TOP_MELEE", "BARRACKS_MID_MELEE", "BARRACKS_BOT_MELEE",

    -- Constants: Bot Modes
    "BOT_MODE_NONE", "BOT_MODE_LANING", "BOT_MODE_ATTACK",
    "BOT_MODE_ROAM", "BOT_MODE_RETREAT", "BOT_MODE_SECRET_SHOP",
    "BOT_MODE_SIDE_SHOP", "BOT_MODE_PUSH_TOWER_TOP",
    "BOT_MODE_PUSH_TOWER_MID", "BOT_MODE_PUSH_TOWER_BOT",
    "BOT_MODE_DEFEND_TOWER_TOP", "BOT_MODE_DEFEND_TOWER_BOT",
    "BOT_MODE_DEFEND_ALLY", "BOT_MODE_ASSEMBLE",
    "BOT_MODE_TEAM_ROAM", "BOT_MODE_FARM", "BOT_MODE_ROSHAN",
    "BOT_MODE_ITEM", "BOT_MODE_WARD", "BOT_MODE_RUNE",
    "BOT_MODE_OUTPOST", "BOT_MODE_GANK",
    "BOT_MODE_EVASIVE_MANEUVERS",

    -- Constants: Bot Mode Desire
    "BOT_MODE_DESIRE_NONE", "BOT_MODE_DESIRE_VERYLOW",
    "BOT_MODE_DESIRE_LOW", "BOT_MODE_DESIRE_MODERATE",
    "BOT_MODE_DESIRE_HIGH", "BOT_MODE_DESIRE_VERYHIGH",
    "BOT_MODE_DESIRE_ABSOLUTE",

    -- Constants: Bot Action Desire
    "BOT_ACTION_DESIRE_NONE", "BOT_ACTION_DESIRE_VERYLOW",
    "BOT_ACTION_DESIRE_LOW", "BOT_ACTION_DESIRE_MODERATE",
    "BOT_ACTION_DESIRE_HIGH", "BOT_ACTION_DESIRE_VERYHIGH",
    "BOT_ACTION_DESIRE_ABSOLUTE",

    -- Constants: Bot Action Types
    "BOT_ACTION_TYPE_IDLE", "BOT_ACTION_TYPE_ATTACK",
    "BOT_ACTION_TYPE_MOVE_TO", "BOT_ACTION_TYPE_DELAY",
    "BOT_ACTION_TYPE_PICK_UP_RUNE",

    -- Constants: Damage
    "DAMAGE_TYPE_PHYSICAL", "DAMAGE_TYPE_MAGICAL", "DAMAGE_TYPE_ALL",

    -- Constants: Items
    "ITEM_SLOT_TYPE_MAIN", "ITEM_SLOT_TYPE_BACKPACK",
    "ITEM_TARGET_TYPE_NONE",
    "PURCHASE_ITEM_SUCCESS",
    "SHOP_SECRET", "SHOP_SECRET2",

    -- Constants: Courier
    "COURIER_STATE_IDLE", "COURIER_STATE_AT_BASE", "COURIER_STATE_MOVING",
    "COURIER_STATE_RETURNING_TO_BASE", "COURIER_STATE_DEAD",
    "COURIER_ACTION_BURST", "COURIER_ACTION_RETURN_STASH_ITEMS",
    "COURIER_ACTION_SECRET_SHOP", "COURIER_ACTION_TAKE_STASH_ITEMS",
    "COURIER_ACTION_TRANSFER_ITEMS",

    -- Constants: Runes
    "RUNE_BOUNTY_1", "RUNE_BOUNTY_2", "RUNE_POWERUP_1", "RUNE_POWERUP_2",
    "RUNE_DOUBLEDAMAGE", "RUNE_HASTE", "RUNE_ILLUSION", "RUNE_INVISIBILITY",
    "RUNE_REGENERATION", "RUNE_ARCANE", "RUNE_SHIELD", "RUNE_WATER",
    "RUNE_STATUS_AVAILABLE", "RUNE_STATUS_MISSING", "RUNE_STATUS_UNKNOWN",

    -- Constants: Attributes
    "ATTRIBUTE_STRENGTH", "ATTRIBUTE_AGILITY", "ATTRIBUTE_INTELLECT",

    -- Constants: Unit Lists
    "UNIT_LIST_ALL", "UNIT_LIST_ALLIES", "UNIT_LIST_ENEMIES",
    "UNIT_LIST_ALLIED_HEROES", "UNIT_LIST_ENEMY_HEROES",
    "UNIT_LIST_ALLIED_CREEPS", "UNIT_LIST_ENEMY_CREEPS",
}

-- Engine callback globals that files are expected to DEFINE
-- (mode files define GetDesire/Think, ability files define *Think, etc.)
-- Also includes file-scoped helper globals used across most mode files.
globals = {
    -- Engine callbacks
    "GetDesire", "Think", "OnStart", "OnEnd",
    "AbilityLevelUpThink", "AbilityUsageThink", "ItemUsageThink",
    "BuybackUsageThink", "CourierUsageThink",
    "ItemPurchaseThink",
    "MinionThink",
    "UpdateLaneAssignments", "GetBotNames", "SelectHeroChatCallback",
    "AlignLanesBasedOnRoles",

    -- Common file-scoped helpers (forward-declared, used before definition)
    "GetDesireHelper",
}

-- Suppress warnings we don't care about
ignore = {
    "212",  -- Unused argument (common in callbacks with fixed signatures)
    "213",  -- Unused loop variable (common with pairs/ipairs)
    "611",  -- Line contains only whitespace
    "612",  -- Line contains trailing whitespace
    "614",  -- Trailing whitespace in comment
    "631",  -- Line too long
}

-- Per-file overrides

-- Mode files: allow file-scoped helper functions defined as globals
files["mode_farm_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "GetDesireHelper",
                "PickOneAnnouncer", "AnnounceMessages", "AttackTarget" },
    -- NOTE: GetDesie and Thnk are NOT listed here so luacheck flags them as non-standard globals
}

-- ability_item_usage_generic.lua: many file-scoped helper globals
files["ability_item_usage_generic.lua"] = {
    globals = {
        "AbilityLevelUpThink", "AbilityUsageThink", "ItemUsageThink",
        "BuybackUsageThink", "CourierUsageThink",
        "IsThereHealingInStash", "SetPairedItems",
        "PickOneAnnouncer", "AnnounceMessages",
    },
}

-- hero_selection.lua: many file-scoped helpers
files["hero_selection.lua"] = {
    globals = {
        "GetDesire", "Think", "UpdateLaneAssignments", "GetBotNames",
        "SelectHeroChatCallback", "OneVsOneLogic",
        "GetSelectedHumanHero", "GetHumanChatHero",
        "HandleLocaleSetting", "IsCMBannedHero",
    },
}

-- Mode files with helper functions defined at file scope
files["mode_laning_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "PickOneAnnouncer", "AnnounceMessages" },
}
files["mode_roam_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "ConsiderUseTango", "ConsiderHeroMoveOutsideFountain",
                "ConsiderGeneralRoamingInConditions", "ConsiderHelpAlly",
                "ThinkIndividualRoaming", "ThinkGeneralRoaming",
                "ThinkActualGankingInLanes", "CheckLaneToGank",
                "SetupTwinGates", "TinkerWaitInBaseAndHeal",
                "ConsiderFirstSpell", "DoTrample", "TrampleToBase",
                "GetTargetEnemy", "MoveAwayFromTarget",
                "IsInHealthyState", "HasSufficientMana",
                "GetMortimerKissesTarget", "ConsiderWaitInBaseToHeal",
                "CanBeAffectedByChainFrost", "GeneralReactToStackedDebuff",
                "ActualGankDesire", "CheckHighPriorityChannelAbility",
    },
}
files["mode_team_roam_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "GoPickUpItem", "TrySwapInvItemForSmoke",
                "TrySwapInvItemForClarity", "TrySwapInvItemForFlask",
                "TrySwapInvItemForCheese", "TrySwapInvItemForRefresherShard",
                "TrySwapInvItemForMoonshard", "TrySellOrDropItem",
                "SwapSmokeSupport", "AttackTarget",
                "ItemOpsDesire", "ItemOpsThink",
                "MoveAwayFromTarget", "GetTargetEnemy",
                "HasModifierThatNeedToAvoidEffects", "ConsiderHelpAlly",
    },
}
files["mode_retreat_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "IsInHealthyState", "HasModifierThatNeedToAvoidEffects",
                "CanBeAffectedByChainFrost", "DoTrample", "TrampleToBase",
                "AttackTarget",
    },
}
files["mode_retreat_generic_wip.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "CountNearByUnits",
    },
}
files["mode_side_shop_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "IsEnemyCloserToOutpostLoc", "IsSuitableToCaptureOutpost",
                "HasSufficientMana",
    },
}
files["mode_outpost_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd",
                "IsEnemyCloserToOutpostLoc", "IsSuitableToCaptureOutpost",
    },
}
files["mode_secret_shop_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd" },
}
files["mode_rune_generic.lua"] = {
    globals = { "GetDesire", "Think", "OnStart", "OnEnd" },
}

-- item_purchase_generic.lua
files["item_purchase_generic.lua"] = {
    globals = { "ItemPurchaseThink", "IsThereHealingInStash", "SetPairedItems" },
}

-- bot_generic.lua
files["bot_generic.lua"] = {
    globals = { "MinionThink" },
}

-- Skip TypeScriptToLua-generated files (can't edit, would drown in noise)
exclude_files = {
    "ts_libs/**",
    "FunLib/utils.lua",
    "FunLib/aba_role.lua",
    "FunLib/aba_site.lua",
    "FunLib/aba_defend.lua",
    "FunLib/aba_push.lua",
    "FunLib/aba_buff.lua",
    "FunLib/global_cache.lua",
    "FunLib/enemy_role_estimation.lua",
    "FunLib/captain_mode.lua",
    "FunLib/aba_hero_pos_weights.lua",
    "FunLib/aba_hero_roles_map.lua",
    -- FretBots VScript context (different API surface)
    "FretBots/**",
    "FretBots.lua",
    "Buff/**",
    -- Install scripts
    "Install-to-vscript/**",
}
