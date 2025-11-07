ConfigRegions = {}

-- Preset enemy list can be reused in groups
ConfigRegions.Enemies = {
    ['DEFAULT'] = {
        "mp_u_m_m_bountytarget_001","mp_u_m_m_bountytarget_002","mp_u_m_m_bountytarget_003","mp_u_m_m_bountytarget_004",
        "mp_u_m_m_bountytarget_005","mp_u_m_m_bountytarget_006","mp_u_m_m_bountytarget_007","mp_u_m_m_bountytarget_008",
        "mp_u_m_m_bountytarget_009","mp_u_m_m_bountytarget_010","mp_u_m_m_bountytarget_011","mp_u_m_m_bountytarget_012",
        "mp_u_m_m_bountytarget_013","mp_u_m_m_bountytarget_014","mp_u_m_m_bountytarget_015","mp_u_m_m_bountytarget_016",
        "mp_u_m_m_bountytarget_017","mp_u_m_m_bountytarget_018","mp_u_m_m_bountytarget_019","mp_u_m_m_bountytarget_020",
        "mp_u_m_m_bountytarget_021","mp_u_m_m_bountytarget_022","mp_u_m_m_bountytarget_023","mp_u_m_m_bountytarget_024",
        "mp_u_m_m_bountytarget_025","mp_u_m_m_bountytarget_026","mp_u_m_m_bountytarget_027","mp_u_m_m_bountytarget_028",
        "mp_u_m_m_bountytarget_029","mp_u_m_m_bountytarget_030","mp_u_m_m_bountytarget_031","mp_u_m_m_bountytarget_032",
        "mp_u_m_m_bountytarget_033","mp_u_m_m_bountytarget_034","mp_u_m_m_bountytarget_035","mp_u_m_m_bountytarget_036",
        "mp_u_m_m_bountytarget_037","mp_u_m_m_bountytarget_038","mp_u_m_m_bountytarget_039","mp_u_m_m_bountytarget_040",
        "mp_u_m_m_bountytarget_041","mp_u_m_m_bountytarget_042","mp_u_m_m_bountytarget_043","mp_u_m_m_bountytarget_044",
        "mp_u_m_m_bountytarget_045","mp_u_m_m_bountytarget_046","mp_u_m_m_bountytarget_047","mp_u_m_m_bountytarget_048",
        "mp_u_m_m_bountytarget_049","mp_u_m_m_bountytarget_050","mp_u_m_m_bountytarget_051","mp_u_m_m_bountytarget_052",
        "mp_u_m_m_bountytarget_053","mp_u_m_m_bountytarget_054","mp_u_m_m_bountytarget_055",
        "mp_u_f_m_bountytarget_001","mp_u_f_m_bountytarget_002","mp_u_f_m_bountytarget_003","mp_u_f_m_bountytarget_004",
        "mp_u_f_m_bountytarget_005","mp_u_f_m_bountytarget_006","mp_u_f_m_bountytarget_007","mp_u_f_m_bountytarget_008",
        "mp_u_f_m_bountytarget_009","mp_u_f_m_bountytarget_010","mp_u_f_m_bountytarget_011","mp_u_f_m_bountytarget_012",
        "mp_u_f_m_bountytarget_013","mp_u_f_m_bountytarget_014","mp_u_f_m_bountytarget_015",
        "a_m_m_valcriminals_01","g_m_m_unicriminals_01","g_m_m_unicriminals_02",
        "MP_G_M_M_UniCriminals_01","MP_G_M_M_UniCriminals_02","MP_G_M_M_UNICRIMINALS_03","MP_G_M_M_UNICRIMINALS_04",
        "MP_G_M_M_UNICRIMINALS_05","MP_G_M_M_UNICRIMINALS_06","MP_G_M_M_UNICRIMINALS_07","MP_G_M_M_UNICRIMINALS_08",
        "MP_G_M_M_UNICRIMINALS_09","re_laramiegangrustling_males_01"
    }
}

ConfigRegions.Groups = {
    ["Wolves"] = {
        Animals = { "A_C_Wolf", "a_c_wolf_medium" },
        Settings = {
            Timofday = "Night",
            SpawnCountPer = .5, -- TotalSpawnCount / SpawnCountPer = FinalSpawnCount
        }
    },
    ["Default"] = {
        Peds = ConfigRegions.Enemies['DEFAULT'],
        Settings = {
            Timofday = "Anytime", -- Day, Night, Anytime
            Melee = "Common", MeleeChance = 100,
            Sidearms = "Common", SidearmsChance = 100,
            Longarms = "Common", LongarmsChance = 50,
            Horse = true -- mount only for secondary formation
        }
    },
}


ConfigRegions.Regions = {
    -- ============================================
    -- NEW HANOVER
    -- ============================================
    ["HEARTLANDS"] = {
        RegionHash = 131399519,
        ZoneTypeId = 10,
        Name = "Heartlands",
        EnemyGroups = {
            ["Group1"] = {
                Peds = {
                    "rcsp_odriscolls2_females_01",
                    "u_m_m_bht_odriscolldrunk",
                    "u_m_m_bht_odriscollsleeping",
                    "u_m_m_odriscollbrawler_01",
                },
                Animals = { "re_lostdog_dogs_01", "A_C_DogAmericanFoxhound_01" },
                Settings = {
                    Timofday = "Anytime", -- Day, Night, Anytime
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Common", SidearmsChance = 100,
                    Longarms = "Common", LongarmsChance = 50,
                    DogSpawnChance = 30, -- per-human companion spawn chance
                    Horse = true -- mount only for secondary formation
                }
            },
        }
    },
    ["ROANOKE_RIDGE"] = {
        RegionHash = 178647645,
        ZoneTypeId = 10,
        Name = "Roanoke Ridge",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "cs_swampfreak",
                    "rcsp_poisonedwell_males_01",
                    "rcsp_poisonedwell_females_01",
                    "g_m_m_unigrays_02",
                    "g_m_m_uniinbred_01",
                    "g_f_m_uniduster_01",
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Mountain", SidearmsChance = 20,
                    Longarms = "Mountain", LongarmsChance = 0,
                    Horse = false
                }
            }
        }
    },

    -- ============================================
    -- WEST ELIZABETH
    -- ============================================
    ["GREAT_PLAINS"] = {
        RegionHash = 476637847,
        ZoneTypeId = 10,
        Name = "Great Plains",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = ConfigRegions.Enemies['DEFAULT'],
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Common", SidearmsChance = 100,
                    Longarms = "Common", LongarmsChance = 50
                }
            }
        }
    },
    ["BIG_VALLEY"] = {
        RegionHash = 822658194,
        ZoneTypeId = 10,
        Name = "Big Valley",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "re_stalkinghunter_males_01",
                    "casp_hunting02_males_01",
                    "a_m_m_huntertravelers_cool_01",
                    "MP_G_M_M_ANIMALPOACHERS_01",
                    "mp_u_m_m_animalpoacher_02",
                    "mp_u_m_m_animalpoacher_09",
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Common", SidearmsChance = 100,
                    Longarms = "Mountain", LongarmsChance = 50
                }
            }
        }
    },
    ["TALL_TREES"] = {
        RegionHash = 1684533001,
        ZoneTypeId = 10,
        Name = "Tall Trees",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "u_m_m_bht_skinnerbrother",
                    "u_m_m_bht_skinnersearch"
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Mountain", SidearmsChance = 100,
                    Longarms = "Mountain", LongarmsChance = 50
                }
            }
        }
    },

    -- ============================================
    -- NEW AUSTIN
    -- ============================================
    ["HENNIGANS_STEAD"] = {
        RegionHash = 892930832,
        ZoneTypeId = 10,
        Name = "Hennigan's Stead",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = ConfigRegions.Enemies['DEFAULT'],
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Banditos", SidearmsChance = 100,
                    Longarms = "Banditos", LongarmsChance = 50
                }
            }
        }
    },
    ["CHOLLA_SPRINGS"] = {
        RegionHash = -108848014,
        ZoneTypeId = 10,
        Name = "Cholla Springs",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "g_m_m_unibanditos_01" },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Banditos", SidearmsChance = 100,
                    Longarms = "Banditos", LongarmsChance = 50
                }
            }
        }
    },
    ["GAPTOOTH_RIDGE"] = {
        RegionHash = -2066240242,
        ZoneTypeId = 10,
        Name = "Gaptooth Ridge",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "MP_G_M_M_REDBENGANG_01",
                    "MP_G_M_M_UniAfricanAmericanGang_01"
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Banditos", SidearmsChance = 100,
                    Longarms = "Banditos", LongarmsChance = 50
                }
            }
        }
    },
    ["RIO_BRAVO"] = {
        RegionHash = -2145992129,
        ZoneTypeId = 10,
        Name = "Rio Bravo",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "MP_G_M_M_OWLHOOTFAMILY_01", "MP_G_F_M_OWLHOOTFAMILY_01" },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Banditos", SidearmsChance = 100,
                    Longarms = "Banditos", LongarmsChance = 50
                }
            }
        }
    },

    -- ============================================
    -- LEMOYNE
    -- ============================================
    ["SCARLETT_MEADOWS"] = {
        RegionHash = -864275692,
        ZoneTypeId = 10,
        Name = "Scarlett Meadows",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "g_m_m_unicriminals_01", "g_m_m_unicriminals_02" },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Common", SidearmsChance = 100,
                    Longarms = "Common", LongarmsChance = 50
                }
            }
        }
    },
    ["BAYOU_NWA"] = {
        RegionHash = 2025841068,
        ZoneTypeId = 10,
        Name = "Bayou Nwa",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "MP_G_F_M_LAPERLEGANG_01",
                    "mp_u_f_m_bountytarget_001","mp_u_f_m_bountytarget_002","mp_u_f_m_bountytarget_003",
                    "mp_u_f_m_bountytarget_004","mp_u_f_m_bountytarget_005","mp_u_f_m_bountytarget_006",
                    "mp_u_f_m_bountytarget_007","mp_u_f_m_bountytarget_008","mp_u_f_m_bountytarget_009",
                    "mp_u_f_m_bountytarget_010","mp_u_f_m_bountytarget_011","mp_u_f_m_bountytarget_012",
                    "mp_u_f_m_bountytarget_013","mp_u_f_m_bountytarget_014","mp_u_f_m_bountytarget_015"
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Outlaws", SidearmsChance = 100,
                    Longarms = "Shotguns", LongarmsChance = 25
                }
            }
        }
    },
    ["BLUEWATER_MARSH"] = {
        RegionHash = 1308232528,
        ZoneTypeId = 10,
        Name = "Bluewater Marsh",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "g_m_m_uniswamp_01" },
                Settings = {
                    Timofday = "Night",
                    Melee = "Swamp", MeleeChance = 100,
                    Sidearms = nil, SidearmsChance = 100,
                    Longarms = "Swamp", LongarmsChance = 20
                }
            }
        }
    },
    ["Marsh1"] = {
        RegionHash = 10200028,
        ZoneTypeId = 11,
        Priority = true,
        Name = "Marsh1",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "g_m_m_uniswamp_01" },
                Settings = {
                    Timofday = "Night",
                    Melee = "Swamp", MeleeChance = 100,
                    Sidearms = nil, SidearmsChance = 100,
                    Longarms = "Swamp", LongarmsChance = 20
                }
            }
        }
    },
    ["Marsh2"] = {
        RegionHash = -557290573,
        ZoneTypeId = 5,
        Priority = true,
        Name = "Marsh2",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = { "g_m_m_uniswamp_01" },
                Settings = {
                    Timofday = "Night",
                    Melee = "Swamp", MeleeChance = 100,
                    Sidearms = nil, SidearmsChance = 100,
                    Longarms = "Swamp", LongarmsChance = 20
                }
            }
        }
    },

    -- ============================================
    -- AMBARINO
    -- ============================================
    ["GRIZZLIES_EAST"] = {
        RegionHash = 1645618177,
        ZoneTypeId = 10,
        Name = "Grizzlies East",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "re_stalkinghunter_males_01",
                    "casp_hunting02_males_01",
                    "a_m_m_huntertravelers_cool_01",
                    "MP_G_M_M_ANIMALPOACHERS_01",
                    "mp_u_m_m_animalpoacher_02",
                    "mp_u_m_m_animalpoacher_09",
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Mountain", SidearmsChance = 100,
                    Longarms = "Mountain", LongarmsChance = 50
                }
            }
        }
    },
    ["GRIZZLIES_WEST"] = {
        RegionHash = -120156735,
        ZoneTypeId = 10,
        Name = "Grizzlies West",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = {
                    "re_stalkinghunter_males_01",
                    "casp_hunting02_males_01",
                    "a_m_m_huntertravelers_cool_01",
                    "MP_G_M_M_ANIMALPOACHERS_01",
                    "mp_u_m_m_animalpoacher_02",
                    "mp_u_m_m_animalpoacher_09",
                },
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Mountain", SidearmsChance = 100,
                    Longarms = "Mountain", LongarmsChance = 50
                }
            }
        }
    },
    ["CUMBERLAND_FOREST"] = {
        RegionHash = 1835499550,
        ZoneTypeId = 10,
        Name = "Cumberland Forest",
        EnemyGroups = {
            ["Group1"] =  {
                Peds = ConfigRegions.Enemies['DEFAULT'],
                Settings = {
                    Timofday = "Anytime",
                    Melee = "Common", MeleeChance = 100,
                    Sidearms = "Common", SidearmsChance = 100,
                    Longarms = "Mountain", LongarmsChance = 50
                }
            }
        }
    },
}