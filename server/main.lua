local ESX = exports['es_extended']:getSharedObject()

-- CACHE_STOK[idToko][namaItem] = stok
local CACHE_STOK = {}

local function debugCetak(...)
    if Config.Debug then
        print('[gatrons_marketplace]', ...)
    end
end

local function rapikanJumlah(jumlah)
    jumlah = tonumber(jumlah) or 0
    if jumlah < 1 then return 0 end
    if jumlah > Config.Batas.maksQtyPerTransaksi then
        return Config.Batas.maksQtyPerTransaksi
    end
    return math.floor(jumlah)
end

local function ambilToko(idToko)
    for _, toko in ipairs(Config.Toko) do
        if toko.id == idToko then
            return toko
        end
    end
    return nil
end

local function ambilConfigItem(idToko, namaItem)
    local toko = ambilToko(idToko)
    if not toko or not toko.item then return nil end
    return toko.item[namaItem]
end

local function pastikanCacheToko(idToko)
    if not CACHE_STOK[idToko] then
        CACHE_STOK[idToko] = {}
    end
end

-- Pastikan semua item di config punya row di DB (kalau belum ada)
local function pastikanBarisDBUntukToko(toko)
    local idToko = toko.id
    local daftarNilai = {}

    for namaItem, cfg in pairs(toko.item) do
        local stokAwal = tonumber(cfg.stokAwal) or 0
        daftarNilai[#daftarNilai + 1] = string.format("('%s','%s',%d)", idToko, namaItem, stokAwal)
    end

    if #daftarNilai == 0 then return end

    local sql = ([[
    INSERT INTO marketplace_stock (id_toko, nama_item, stok)
    VALUES %s
    ON DUPLICATE KEY UPDATE stok = stok
  ]]):format(table.concat(daftarNilai, ","))

    MySQL.query(sql, {}, function()
        debugCetak('DB siap untuk toko:', idToko)
    end)
end

-- Load stok dari DB ke cache
local function muatCacheStok()
    -- 1) pastikan row exist
    for _, toko in ipairs(Config.Toko) do
        pastikanBarisDBUntukToko(toko)
    end

    -- 2) load semua stok
    MySQL.query('SELECT id_toko, nama_item, stok FROM marketplace_stock', {}, function(baris)
        CACHE_STOK = {}

        for _, r in ipairs(baris or {}) do
            pastikanCacheToko(r.id_toko)
            CACHE_STOK[r.id_toko][r.nama_item] = tonumber(r.stok) or 0
        end

        -- 3) safety fallback
        for _, toko in ipairs(Config.Toko) do
            pastikanCacheToko(toko.id)
            for namaItem, cfg in pairs(toko.item) do
                if CACHE_STOK[toko.id][namaItem] == nil then
                    CACHE_STOK[toko.id][namaItem] = tonumber(cfg.stokAwal) or 0
                end
            end
        end

        debugCetak('Cache stok berhasil dimuat')
    end)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    muatCacheStok()
end)

-- ===== Kirim data ke NUI =====
lib.callback.register('gatrons_marketplace:ambilData', function(source, idToko)
    local toko = ambilToko(idToko)
    if not toko then
        return {
            judul = Config.UI.judul,
            mataUang = Config.UI.mataUang,
            idToko = idToko,
            kategori = Config.Kategori,
            item = {}
        }
    end

    pastikanCacheToko(idToko)

    local daftarItem = {}
    for namaItem, cfg in pairs(toko.item) do
        daftarItem[#daftarItem + 1] = {
            nama = namaItem,
            label = cfg.label or namaItem,
            hargaBeli = cfg.buyPrice or 0,
            hargaJual = cfg.sellPrice or 0,
            stok = CACHE_STOK[idToko][namaItem] or 0,
            stokMaks = cfg.stokMaks or 0,
            kategori = cfg.kategori or 'general',
        }
    end

    return {
        judul = Config.UI.judul,
        mataUang = Config.UI.mataUang,
        idToko = idToko,
        kategori = Config.Kategori,
        item = daftarItem
    }
end)

-- ===== BELI (stok berkurang, atomic) =====
lib.callback.register('gatrons_marketplace:beliItem', function(source, idToko, namaItem, jumlah)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { sukses = false, pesan = 'Player tidak ditemukan' } end

    local cfg = ambilConfigItem(idToko, namaItem)
    if not cfg then return { sukses = false, pesan = 'Item tidak valid' } end

    jumlah = rapikanJumlah(jumlah)
    if jumlah <= 0 then return { sukses = false, pesan = 'Jumlah tidak valid' } end

    local hargaBeli = tonumber(cfg.buyPrice) or 0
    if hargaBeli <= 0 then return { sukses = false, pesan = 'Item ini tidak dijual' } end

    local total = hargaBeli * jumlah
    if xPlayer.getMoney() < total then
        return { sukses = false, pesan = 'Uang kamu tidak cukup' }
    end

    if not exports.ox_inventory:CanCarryItem(source, namaItem, jumlah) then
        return { sukses = false, pesan = 'Inventory penuh' }
    end

    -- Atomic: stok >= jumlah
    local terpengaruh = MySQL.update.await(
        'UPDATE marketplace_stock SET stok = stok - ? WHERE id_toko = ? AND nama_item = ? AND stok >= ?',
        { jumlah, idToko, namaItem, jumlah }
    )

    if terpengaruh ~= 1 then
        return { sukses = false, pesan = 'Stok tidak cukup' }
    end

    xPlayer.removeMoney(total)
    exports.ox_inventory:AddItem(source, namaItem, jumlah)

    pastikanCacheToko(idToko)
    CACHE_STOK[idToko][namaItem] = (CACHE_STOK[idToko][namaItem] or 0) - jumlah
    if CACHE_STOK[idToko][namaItem] < 0 then CACHE_STOK[idToko][namaItem] = 0 end

    return {
        sukses = true,
        pesan = ('Berhasil beli %sx %s'):format(jumlah, cfg.label or namaItem),
        stok = CACHE_STOK[idToko][namaItem]
    }
end)

-- ===== JUAL (stok bertambah, atomic + stokMaks) =====
lib.callback.register('gatrons_marketplace:jualItem', function(source, idToko, namaItem, jumlah)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { sukses = false, pesan = 'Player tidak ditemukan' } end

    local cfg = ambilConfigItem(idToko, namaItem)
    if not cfg then return { sukses = false, pesan = 'Item tidak valid' } end

    jumlah = rapikanJumlah(jumlah)
    if jumlah <= 0 then return { sukses = false, pesan = 'Jumlah tidak valid' } end

    local hargaJual = tonumber(cfg.sellPrice) or 0
    if hargaJual <= 0 then return { sukses = false, pesan = 'Item ini tidak bisa dijual' } end

    local punya = exports.ox_inventory:GetItemCount(source, namaItem)
    if punya < jumlah then return { sukses = false, pesan = 'Item kamu kurang' } end

    local stokMaks = tonumber(cfg.stokMaks) or 0

    -- Atomic: kalau stokMaks==0 unlimited, else stok+jumlah <= stokMaks
    local terpengaruh = MySQL.update.await(
        'UPDATE marketplace_stock SET stok = stok + ? WHERE id_toko = ? AND nama_item = ? AND (? = 0 OR stok + ? <= ?)',
        { jumlah, idToko, namaItem, stokMaks, jumlah, stokMaks }
    )

    if terpengaruh ~= 1 then
        return { sukses = false, pesan = 'Toko tidak bisa menampung stok sebanyak itu' }
    end

    local terhapus = exports.ox_inventory:RemoveItem(source, namaItem, jumlah)
    if not terhapus then
        MySQL.update.await(
            'UPDATE marketplace_stock SET stok = stok - ? WHERE id_toko = ? AND nama_item = ? AND stok >= ?',
            { jumlah, idToko, namaItem, jumlah }
        )
        return { sukses = false, pesan = 'Gagal menghapus item dari inventory' }
    end

    xPlayer.addMoney(hargaJual * jumlah)

    pastikanCacheToko(idToko)
    CACHE_STOK[idToko][namaItem] = (CACHE_STOK[idToko][namaItem] or 0) + jumlah

    return {
        sukses = true,
        pesan = ('Berhasil jual %sx %s'):format(jumlah, cfg.label or namaItem),
        stok = CACHE_STOK[idToko][namaItem]
    }
end)
