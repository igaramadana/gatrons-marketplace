local sedangTerbuka = false
local idTokoAktif = nil
local daftarPed = {}

local function notifikasi(judul, deskripsi, tipe)
    lib.notify({
        title = judul or 'Marketplace',
        description = deskripsi or '',
        type = tipe or 'inform'
    })
end

local function muatModelPed(model)
    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    return hash
end

local function bukaMarketplace(idToko)
    if sedangTerbuka then return end
    sedangTerbuka = true
    idTokoAktif = idToko

    local data = lib.callback.await('gatrons_marketplace:ambilData', false, idToko)
    SetNuiFocus(true, true)
    SendNUIMessage({ aksi = 'buka', payload = data })
end

local function spawnPedToko(toko)
    local p = toko.ped
    local hash = muatModelPed(p.model)

    local ped = CreatePed(0, hash, p.coords.x, p.coords.y, p.coords.z - 1.0, p.heading, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    if p.scenario and p.scenario ~= '' then
        TaskStartScenarioInPlace(ped, p.scenario, 0, true)
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            label = toko.target.label,
            icon = toko.target.icon,
            distance = toko.target.distance or 2.0,
            onSelect = function()
                bukaMarketplace(toko.id)
            end
        }
    })

    daftarPed[#daftarPed + 1] = ped
end

local function tutupMarketplace()
    if not sedangTerbuka then return end
    sedangTerbuka = false
    idTokoAktif = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ aksi = 'tutup' })
end

RegisterNUICallback('tutup', function(_, cb)
    tutupMarketplace()
    cb(true)
end)

RegisterNUICallback('beli', function(data, cb)
    if not idTokoAktif then
        cb(true)
        return
    end
    local namaItem = data.item
    local jumlah = tonumber(data.qty) or 1

    local hasil = lib.callback.await('gatrons_marketplace:beliItem', false, idTokoAktif, namaItem, jumlah)
    if hasil and hasil.sukses then
        notifikasi('Marketplace', hasil.pesan, 'success')
        SendNUIMessage({ aksi = 'updateStok', item = namaItem, stok = hasil.stok })
    else
        notifikasi('Marketplace', (hasil and hasil.pesan) or 'Gagal', 'error')
    end

    cb(true)
end)

RegisterNUICallback('jual', function(data, cb)
    if not idTokoAktif then
        cb(true)
        return
    end
    local namaItem = data.item
    local jumlah = tonumber(data.qty) or 1

    local hasil = lib.callback.await('gatrons_marketplace:jualItem', false, idTokoAktif, namaItem, jumlah)
    if hasil and hasil.sukses then
        notifikasi('Marketplace', hasil.pesan, 'success')
        SendNUIMessage({ aksi = 'updateStok', item = namaItem, stok = hasil.stok })
    else
        notifikasi('Marketplace', (hasil and hasil.pesan) or 'Gagal', 'error')
    end

    cb(true)
end)

CreateThread(function()
    for _, toko in ipairs(Config.Toko) do
        spawnPedToko(toko)
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if sedangTerbuka and IsControlJustReleased(0, 322) then
            tutupMarketplace()
        end
    end
end)
