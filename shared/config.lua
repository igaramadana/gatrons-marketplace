Config = {}

Config.Debug = false

Config.UI = {
    judul = 'Marketplace Kota',
    mataUang = 'Rp. '
}

Config.Batas = {
    maksQtyPerTransaksi = 100
}

Config.Kategori = {
    mining  = { label = 'Hasil Tambang', icon = '⛏️' },
    lumber  = { label = 'Hasil Lumberjack', icon = '🪓' },
    general = { label = 'Umum', icon = '🛒' },
}

Config.Toko = {
    {
        id = 'grove_shop',
        ped = {
            model = 'a_m_m_business_01',
            coords = vector3(-47.522, -1756.857, 29.421),
            heading = 47.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
        target = {
            label = 'Buka Marketplace Kota',
            icon = 'fa-solid fa-store',
            distance = 2.0
        },

        item = {
            -- UMUM (bisa beli/jual)
            water = { label = 'Air Mineral', buyPrice = 15, sellPrice = 8, stokAwal = 200, stokMaks = 500, kategori = 'general' },
            bread = { label = 'Roti', buyPrice = 20, sellPrice = 10, stokAwal = 150, stokMaks = 400, kategori = 'general' },

            -- MINING (jual doang)
            iron_ore = { label = 'Bijih Besi', buyPrice = 0, sellPrice = 75, stokAwal = 0, stokMaks = 5000, kategori = 'mining' },
            gold_ore = { label = 'Bijih Emas', buyPrice = 0, sellPrice = 150, stokAwal = 0, stokMaks = 2500, kategori = 'mining' },

            -- LUMBERJACK (jual doang)
            wood = { label = 'Kayu', buyPrice = 0, sellPrice = 60, stokAwal = 0, stokMaks = 6000, kategori = 'lumber' },
            processed_wood = { label = 'Kayu Olahan', buyPrice = 0, sellPrice = 110, stokAwal = 0, stokMaks = 3000, kategori = 'lumber' },
        }
    }
}
