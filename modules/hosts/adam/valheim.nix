{
  flake.modules.nixos.adam.services.homelab.valheim = {
    enable = true;
    serverName = "Die geilsten Gamer e.V. (nicht offiziell)";
    public = true;
    extraEnvironment = {
      # Keep both ID formats for legacy and platform-prefixed admin checks.
      ADMINLIST_IDS = "76561198111376416 Steam_76561198111376416";
      SERVER_ARGS = "-modifier combat normal";
      VPCFG_Game_enabled = "false";

      # Experience modifiers add percentages: +900 gives 10x skill gain.
      VPCFG_Experience_enabled = "true";
      VPCFG_Experience_swords = "900";
      VPCFG_Experience_knives = "900";
      VPCFG_Experience_clubs = "900";
      VPCFG_Experience_polearms = "900";
      VPCFG_Experience_spears = "900";
      VPCFG_Experience_blocking = "900";
      VPCFG_Experience_axes = "900";
      VPCFG_Experience_bows = "900";
      VPCFG_Experience_elementalMagic = "900";
      VPCFG_Experience_bloodMagic = "900";
      VPCFG_Experience_unarmed = "900";
      VPCFG_Experience_pickaxes = "900";
      VPCFG_Experience_woodCutting = "900";
      VPCFG_Experience_crossbows = "900";
      VPCFG_Experience_jump = "900";
      VPCFG_Experience_sneak = "900";
      VPCFG_Experience_run = "900";
      VPCFG_Experience_swim = "900";
      VPCFG_Experience_fishing = "900";
      VPCFG_Experience_cooking = "900";
      VPCFG_Experience_farming = "900";
      VPCFG_Experience_crafting = "900";
      VPCFG_Experience_ride = "900";

      # V+ modifiers are percentage changes: +100 doubles, -100 removes.
      VPCFG_Gathering_enabled = "true";
      VPCFG_Gathering_dropChance = "900";
      VPCFG_Gathering_wood = "900";
      VPCFG_Gathering_fineWood = "900";
      VPCFG_Gathering_coreWood = "900";
      VPCFG_Gathering_elderBark = "900";
      VPCFG_Gathering_yggdrasilWood = "900";
      VPCFG_Gathering_blackwood = "900";
      VPCFG_Gathering_stone = "900";
      VPCFG_Gathering_grausten = "900";
      VPCFG_Gathering_blackMarble = "900";
      VPCFG_Gathering_copperOre = "900";
      VPCFG_Gathering_tinOre = "900";
      VPCFG_Gathering_ironScrap = "900";
      VPCFG_Gathering_silverOre = "900";
      VPCFG_Gathering_copperScrap = "900";
      VPCFG_Gathering_flametalOre = "900";
      VPCFG_Gathering_chitin = "900";
      VPCFG_Gathering_feather = "900";
      VPCFG_Gathering_proustitePowder = "900";

      VPCFG_Pickable_enabled = "true";
      VPCFG_Pickable_edibles = "900";
      VPCFG_Pickable_flowersAndIngredients = "900";
      VPCFG_Pickable_materials = "900";
      VPCFG_Pickable_valuables = "900";
      VPCFG_Pickable_surtlingCores = "900";
      VPCFG_Pickable_blackCores = "900";
      VPCFG_Pickable_questItems = "900";

      VPCFG_Beehive_enabled = "true";
      # Seconds per honey: 120 gives 10x production; capacity scales with it.
      VPCFG_Beehive_honeyProductionSpeed = "120";
      VPCFG_Beehive_maximumHoneyPerBeehive = "40";

      VPCFG_Items_enabled = "true";
      VPCFG_Items_itemStackMultiplier = "700";
      VPCFG_Items_noTeleportPrevention = "true";

      # The global loot multiplier also multiplies trophies and boss rewards.
      VPCFG_LootDrop_enabled = "true";
      VPCFG_LootDrop_lootDropAmountMultiplier = "900";
      # Drop chances saturate at 100%, even when the multiplier exceeds it.
      VPCFG_LootDrop_lootDropChanceMultiplier = "900";

      VPCFG_Inventory_enabled = "true";
      VPCFG_Inventory_playerInventoryRows = "8";
      VPCFG_Inventory_woodChestRows = "10";
      VPCFG_Inventory_personalChestRows = "20";
      VPCFG_Inventory_ironChestRows = "20";
      VPCFG_Inventory_blackmetalChestRows = "20";

      VPCFG_CraftFromChest_enabled = "true";
      VPCFG_CraftFromChest_checkFromWorkbench = "true";
      VPCFG_CraftFromChest_range = "40";

      VPCFG_Workbench_enabled = "true";
      VPCFG_Workbench_workbenchRange = "100";
      # Otherwise spawn suppression inherits the expanded build radius.
      VPCFG_Workbench_workbenchEnemySpawnRange = "20";

      VPCFG_Kiln_enabled = "true";
      # productionSpeed is seconds per item: 7.5/15 seconds doubles throughput.
      VPCFG_Kiln_productionSpeed = "7.5";
      VPCFG_Kiln_autoFuel = "true";
      VPCFG_Kiln_autoDeposit = "true";
      VPCFG_Kiln_autoRange = "10";
      VPCFG_Kiln_dontProcessFineWood = "true";
      VPCFG_Kiln_dontProcessRoundLog = "true";
      VPCFG_Kiln_stopAutoFuelThreshold = "200";

      VPCFG_Smelter_enabled = "true";
      VPCFG_Smelter_productionSpeed = "15";
      VPCFG_Smelter_autoFuel = "true";
      VPCFG_Smelter_autoDeposit = "true";
      VPCFG_Smelter_autoRange = "10";

      VPCFG_Furnace_enabled = "true";
      VPCFG_Furnace_productionSpeed = "15";
      VPCFG_Furnace_autoFuel = "true";
      VPCFG_Furnace_autoDeposit = "true";
      VPCFG_Furnace_autoRange = "10";

      VPCFG_Player_enabled = "true";
      VPCFG_Player_baseMaximumWeight = "1000";
      VPCFG_Player_baseMegingjordBuff = "500";
      VPCFG_Player_deathPenaltyMultiplier = "-100";
      VPCFG_Player_autoRepair = "true";
      VPCFG_Player_cropNotifier = "true";
      VPCFG_Player_reequipItemsAfterSwimming = "true";

      VPCFG_Map_enabled = "true";
      VPCFG_Map_shareMapProgression = "true";
      VPCFG_Map_displayCartsAndBoats = "true";

      VPCFG_FireSource_enabled = "true";
      VPCFG_FireSource_torches = "true";
    };
  };
}
