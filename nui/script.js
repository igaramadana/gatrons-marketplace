const app = document.getElementById('app');
const judulEl = document.getElementById('judul');
const daftarEl = document.getElementById('daftar');
const btnTutup = document.getElementById('btnTutup');
const tabBeli = document.getElementById('tabBeli');
const tabJual = document.getElementById('tabJual');
const cari = document.getElementById('cari');
const barKategori = document.getElementById('barKategori');

let status = {
  mode: 'beli',             // beli | jual
  mataUang: '$',
  item: [],
  kategori: {},
  query: '',
  kategoriJual: 'all',       // all | mining | lumber | general
};

function kirimNui(event, data = {}) {
  fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function urlGambarItem(namaItem) {
  return `https://cfx-nui-ox_inventory/web/images/${namaItem}.png`;
}

function setMode(mode) {
  status.mode = mode;

  if (mode === 'beli') {
    tabBeli.className = "px-4 py-3 rounded-xl bg-emerald-600/90 hover:bg-emerald-600 transition text-sm font-medium";
    tabJual.className = "px-4 py-3 rounded-xl bg-white/10 hover:bg-white/15 transition text-sm font-medium";
    status.kategoriJual = 'all';
  } else {
    tabJual.className = "px-4 py-3 rounded-xl bg-sky-600/90 hover:bg-sky-600 transition text-sm font-medium";
    tabBeli.className = "px-4 py-3 rounded-xl bg-white/10 hover:bg-white/15 transition text-sm font-medium";
  }

  renderKategori();
  renderDaftar();
}

function renderKategori() {
  if (status.mode !== 'jual') {
    barKategori.classList.add('hidden');
    barKategori.innerHTML = '';
    return;
  }

  barKategori.classList.remove('hidden');

  const daftarKey = Object.keys(status.kategori || {});

  const tombol = (key, label) => {
    const aktif = status.kategoriJual === key;
    return `
      <button onclick="pilihKategori('${key}')"
        class="px-3 py-2 rounded-xl text-sm border transition
          ${aktif ? 'bg-white/15 border-white/20' : 'bg-white/5 hover:bg-white/10 border-white/10'}">
        ${label}
      </button>
    `;
  };

  let html = '';
  html += tombol('all', 'Semua');

  for (const k of daftarKey) {
    const c = status.kategori[k] || {};
    const label = `${c.icon ? c.icon + ' ' : ''}${c.label || k}`;
    html += tombol(k, label);
  }

  barKategori.innerHTML = html;
}

window.pilihKategori = function(key) {
  status.kategoriJual = key;
  renderDaftar();
};

function renderDaftar() {
  const q = (status.query || '').toLowerCase().trim();

  const hasil = status.item.filter(it => {
    const nama = (it.nama || '').toLowerCase();
    const label = (it.label || '').toLowerCase();

    if (q && !nama.includes(q) && !label.includes(q)) return false;

    if (status.mode === 'beli') {
      if ((it.hargaBeli || 0) <= 0) return false;
    } else {
      if ((it.hargaJual || 0) <= 0) return false;

      if (status.kategoriJual !== 'all') {
        const kat = it.kategori || 'general';
        if (kat !== status.kategoriJual) return false;
      }
    }

    return true;
  });

  daftarEl.innerHTML = hasil.map(it => {
    const harga = status.mode === 'beli' ? it.hargaBeli : it.hargaJual;

    const disable = (status.mode === 'jual')
      ? (harga <= 0)
      : ((it.stok ?? 0) <= 0 || harga <= 0);

    const labelKat = (status.kategori[it.kategori]?.label) || it.kategori || 'general';

    return `
      <div class="rounded-2xl bg-white/5 border border-white/10 overflow-hidden">
        <div class="p-4 flex gap-4">
          <div class="w-16 h-16 rounded-xl bg-black/30 border border-white/10 flex items-center justify-center overflow-hidden">
            <img src="${urlGambarItem(it.nama)}" class="w-full h-full object-contain"
              onerror="this.style.display='none'; this.parentElement.innerHTML='<span class=\\'text-xs text-zinc-500\\'>no img</span>';" />
          </div>

          <div class="flex-1">
            <div class="flex items-start justify-between gap-2">
              <div>
                <div class="font-semibold">${it.label}</div>
                <div class="text-xs text-zinc-400">${it.nama}</div>
                ${status.mode === 'jual' ? `<div class="text-xs text-zinc-500 mt-1">Kategori: ${labelKat}</div>` : ''}
              </div>
              <div class="text-right">
                <div class="font-semibold">${status.mataUang}${harga}</div>
                <div class="text-xs text-zinc-400">Stok: <span data-stok="${it.nama}">${it.stok ?? 0}</span></div>
              </div>
            </div>

            <div class="mt-3 flex items-center gap-2">
              <input type="number" min="1" value="1" id="qty-${it.nama}"
                class="w-24 px-3 py-2 rounded-xl bg-zinc-950/60 border border-white/10 outline-none focus:border-white/20 text-sm" />

              <button
                ${disable ? 'disabled' : ''}
                onclick="aksiTransaksi('${it.nama}')"
                class="flex-1 px-4 py-2 rounded-xl text-sm font-medium transition
                  ${disable ? 'bg-white/5 text-zinc-500 cursor-not-allowed'
                    : (status.mode==='beli' ? 'bg-emerald-600/90 hover:bg-emerald-600' : 'bg-sky-600/90 hover:bg-sky-600')}">
                ${status.mode === 'beli' ? 'Beli' : 'Jual'}
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

window.aksiTransaksi = function(namaItem) {
  const qtyEl = document.getElementById(`qty-${namaItem}`);
  const jumlah = parseInt(qtyEl?.value || '1', 10) || 1;

  if (status.mode === 'beli') kirimNui('beli', { item: namaItem, qty: jumlah });
  else kirimNui('jual', { item: namaItem, qty: jumlah });
};

btnTutup.addEventListener('click', () => kirimNui('tutup'));
tabBeli.addEventListener('click', () => setMode('beli'));
tabJual.addEventListener('click', () => setMode('jual'));

cari.addEventListener('input', (e) => {
  status.query = e.target.value;
  renderDaftar();
});

window.addEventListener('message', (event) => {
  const data = event.data || {};
  const aksi = data.aksi;

  if (aksi === 'buka') {
    const payload = data.payload || {};
    status.mataUang = payload.mataUang || '$';
    status.item = payload.item || [];
    status.kategori = payload.kategori || {};

    judulEl.textContent = payload.judul || 'Marketplace';

    status.query = '';
    status.kategoriJual = 'all';
    cari.value = '';

    app.classList.remove('hidden');
    setMode('beli');
  }

  if (aksi === 'tutup') {
    app.classList.add('hidden');
  }

  if (aksi === 'updateStok') {
    const namaItem = data.item;
    const stok = data.stok;

    const it = status.item.find(x => x.nama === namaItem);
    if (it) it.stok = stok;

    const el = document.querySelector(`[data-stok="${namaItem}"]`);
    if (el) el.textContent = String(stok);
  }
});
