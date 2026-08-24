/* =========================================================================
   Sovngarde Notes - logica del salon
   ========================================================================= */

const $ = (sel) => document.querySelector(sel);

const els = {
  ring:        $('#ring'),
  ringZoom:    $('#ring-zoom'),
  stageEmpty:  $('#stage-empty'),
  shelfMine:   $('#shelf-mine'),
  shelfOthers: $('#shelf-others'),
  countMine:   $('#count-mine'),
  countOthers: $('#count-others'),
  search:      $('#search'),
  searchHint:  $('#search-hint'),
  form:        $('#nota-form'),
  titulo:      $('#titulo'),
  texto:       $('#texto'),
  status:      $('#status-msg'),
  reader:      $('#reader'),
  gate:        $('#gate'),
  gateForm:    $('#gate-form'),
  gateName:    $('#gate-name'),
};

let notas = [];
let viajero = '';

/* ---------- Identidad del viajero -------------------------------------- */
// Sin sistema de auth: el nombre se guarda en el navegador y viaja en el
// POST. Es lo que permite separar "tus tomos" de "tomos de otros".

function cargarViajero() {
  try { viajero = localStorage.getItem('sovngarde:viajero') || ''; }
  catch { viajero = ''; }
}

function guardarViajero(nombre) {
  viajero = nombre;
  try { localStorage.setItem('sovngarde:viajero', nombre); } catch { /* modo privado */ }
}

/* ---------- Sonido de paginas ------------------------------------------ */
// Ruido blanco filtrado con una envolvente corta: suena a hoja pasando.
// Se sintetiza con Web Audio, sin archivos de audio.

let audioCtx = null;

function sonidoPagina() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();

    const dur = 0.42;
    const rate = audioCtx.sampleRate;
    const frames = Math.floor(rate * dur);
    const buffer = audioCtx.createBuffer(1, frames, rate);
    const data = buffer.getChannelData(0);

    // Dos rafagas de ruido, como dos hojas sucesivas
    for (let i = 0; i < frames; i++) {
      const t = i / frames;
      const rafagaA = Math.exp(-14 * t);
      const rafagaB = t > 0.34 ? Math.exp(-16 * (t - 0.34)) * 0.75 : 0;
      data[i] = (Math.random() * 2 - 1) * (rafagaA + rafagaB) * 0.5;
    }

    const src = audioCtx.createBufferSource();
    src.buffer = buffer;

    const paso = audioCtx.createBiquadFilter();
    paso.type = 'bandpass';
    paso.frequency.value = 2600;
    paso.Q.value = 0.7;

    const alto = audioCtx.createBiquadFilter();
    alto.type = 'highpass';
    alto.frequency.value = 900;

    const vol = audioCtx.createGain();
    vol.gain.value = 0.16;

    src.connect(paso).connect(alto).connect(vol).connect(audioCtx.destination);
    src.start();
  } catch { /* si el navegador bloquea el audio, la app sigue funcionando */ }
}

/* ---------- Utilidades -------------------------------------------------- */

function formatFecha(iso) {
  const d = new Date(iso);
  if (isNaN(d)) return '';
  return d.toLocaleString('es-AR', { dateStyle: 'long', timeStyle: 'short' });
}

function esMia(nota) {
  return viajero && nota.autor &&
         nota.autor.trim().toLowerCase() === viajero.trim().toLowerCase();
}

// Titulo a mostrar. Las notas viejas (anteriores a la columna "titulo")
// caen al primer fragmento del texto, para que nunca quede un lomo en blanco.
function tituloDe(nota, max = 30) {
  let t = (nota.titulo || '').trim();
  if (!t || t === 'Tomo sin titulo') {
    t = (nota.texto || '').trim().replace(/\s+/g, ' ');
  }
  t = t.replace(/\s+/g, ' ');
  return t.length > max ? t.slice(0, max) + '...' : t;
}

/* ---------- Ronda de libros -------------------------------------------- */

function renderRonda() {
  els.ring.innerHTML = '';

  const total = notas.length;
  els.stageEmpty.hidden = total > 0;

  if (!total) return;

  // El radio crece con la cantidad para que los tomos no se solapen.
  // 134px = ancho de la tapa (122, ver --book-w en CSS) + aire entre tomos.
  const radio = Math.max(195, Math.round((total * 134) / (2 * Math.PI)));
  const paso = 360 / total;

  // ...y la camara se aleja en la misma medida, para que la ronda entera
  // siga entrando en pantalla en vez de comerse las estanterias.
  const anchoDisponible = Math.min(els.ring.parentElement.parentElement.clientWidth || 560, 620);
  const zoom = Math.min(1, Math.max(0.16, anchoDisponible / (radio * 2.25)));
  els.ringZoom.style.setProperty('--ring-zoom', zoom.toFixed(3));

  notas.forEach((nota, i) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'rune-book' + (esMia(nota) ? ' is-mine' : '');
    btn.dataset.id = String(nota.id);
    btn.style.transform = `rotateY(${i * paso}deg) translateZ(${radio}px)`;
    btn.setAttribute('aria-label', `Abrir el tomo "${tituloDe(nota)}" de ${nota.autor}`);

    btn.innerHTML = `
      <span class="cover">
        <svg class="corner corner-tl"><use href="#book-corner"/></svg>
        <svg class="corner corner-tr"><use href="#book-corner"/></svg>
        <svg class="corner corner-br"><use href="#book-corner"/></svg>
        <svg class="corner corner-bl"><use href="#book-corner"/></svg>
        <svg class="emblem"><use href="#book-emblem"/></svg>
        <span class="plate">
          <span class="plate-title">${escapar(tituloDe(nota, 34))}</span>
          <span class="plate-author">${escapar(nota.autor)}</span>
        </span>
      </span>
      <span class="spine"></span>
      <span class="pages pages-right"></span>
      <span class="pages pages-left"></span>
      <span class="back"></span>`;

    btn.addEventListener('click', () => abrirTomo(nota));
    els.ring.appendChild(btn);
  });
}

/* ---------- Bibliotecas laterales -------------------------------------- */

function renderEstanterias() {
  const mias  = notas.filter(esMia);
  const otras = notas.filter((n) => !esMia(n));

  pintarEstante(els.shelfMine, mias);
  pintarEstante(els.shelfOthers, otras);

  els.countMine.textContent   = `${mias.length} ${mias.length === 1 ? 'tomo' : 'tomos'}`;
  els.countOthers.textContent = `${otras.length} ${otras.length === 1 ? 'tomo' : 'tomos'}`;
}

function pintarEstante(contenedor, lista) {
  contenedor.innerHTML = '';

  if (!lista.length) {
    const vacio = document.createElement('p');
    vacio.className = 'shelf-count';
    vacio.style.position = 'static';
    vacio.textContent = '—';
    contenedor.appendChild(vacio);
    return;
  }

  // Se muestran los 12 mas recientes para que la estanteria no desborde
  lista.slice(0, 12).forEach((nota) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'tome';
    btn.dataset.id = String(nota.id);
    btn.textContent = tituloDe(nota, 32);
    btn.title = `${tituloDe(nota, 80)} — ${nota.autor} — ${formatFecha(nota.fecha_creacion)}`;
    btn.addEventListener('click', () => abrirTomo(nota));
    contenedor.appendChild(btn);
  });
}

function escapar(str) {
  const d = document.createElement('div');
  d.textContent = str == null ? '' : String(str);
  return d.innerHTML;
}

/* ---------- Buscador ---------------------------------------------------- */

function aplicarBusqueda() {
  const q = els.search.value.trim().toLowerCase();
  const libros = document.querySelectorAll('.rune-book');
  const tomos  = document.querySelectorAll('.tome');

  if (!q) {
    els.ring.classList.remove('is-paused');
    els.searchHint.textContent = '';
    libros.forEach((b) => b.classList.remove('is-hit', 'is-dim'));
    tomos.forEach((t) => t.classList.remove('is-hit', 'is-dim'));
    return;
  }

  const idsCoinciden = new Set(
    notas
      .filter((n) =>
        (n.titulo || '').toLowerCase().includes(q) ||
        (n.texto  || '').toLowerCase().includes(q) ||
        (n.autor  || '').toLowerCase().includes(q))
      .map((n) => String(n.id))
  );

  // La ronda se detiene para poder leer los tomos que se elevan
  els.ring.classList.toggle('is-paused', idsCoinciden.size > 0);

  libros.forEach((b) => {
    const hit = idsCoinciden.has(b.dataset.id);
    b.classList.toggle('is-hit', hit);
    b.classList.toggle('is-dim', !hit);
  });

  tomos.forEach((t) => {
    const hit = idsCoinciden.has(t.dataset.id);
    t.classList.toggle('is-hit', hit);
    t.classList.toggle('is-dim', !hit);
  });

  const n = idsCoinciden.size;
  els.searchHint.textContent = n
    ? `${n} ${n === 1 ? 'tomo se eleva' : 'tomos se elevan'} de la ronda`
    : 'Ningun tomo responde a ese nombre';
}

/* ---------- Lector ------------------------------------------------------ */

function abrirTomo(nota) {
  els.reader.querySelector('.reader-tome-title').textContent = tituloDe(nota, 120);
  els.reader.querySelector('.reader-author').textContent = nota.autor || 'Viajero anonimo';
  els.reader.querySelector('.reader-date').textContent   = formatFecha(nota.fecha_creacion);
  els.reader.querySelector('.reader-id').textContent     = `Tomo n.º ${nota.id}`;
  els.reader.querySelector('.reader-text').textContent   = nota.texto || '';

  els.reader.hidden = false;
  sonidoPagina();
  els.reader.querySelector('.reader-close').focus();
}

function cerrarTomo() {
  els.reader.hidden = true;
}

els.reader.addEventListener('click', (e) => {
  if (e.target.hasAttribute('data-close')) cerrarTomo();
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !els.reader.hidden) cerrarTomo();
});

/* ---------- API --------------------------------------------------------- */

async function cargarNotas() {
  try {
    const res = await fetch('/api/notas');
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || 'No se pudo abrir la biblioteca.');
    }
    notas = await res.json();

    renderRonda();
    renderEstanterias();
    aplicarBusqueda();

    if (els.status.classList.contains('is-error')) {
      els.status.textContent = '';
      els.status.classList.remove('is-error');
    }
  } catch (err) {
    els.status.textContent = err.message;
    els.status.classList.add('is-error');
    els.status.classList.remove('is-good');
  }
}

els.form.addEventListener('submit', async (e) => {
  e.preventDefault();

  const texto  = els.texto.value.trim();
  const titulo = els.titulo.value.trim();
  if (!texto || !titulo) return;

  try {
    const res = await fetch('/api/notas', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ titulo, texto, autor: viajero }),
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || 'El tomo no pudo grabarse.');
    }

    els.texto.value = '';
    els.titulo.value = '';
    els.status.textContent = 'El tomo ya descansa en la biblioteca.';
    els.status.classList.add('is-good');
    els.status.classList.remove('is-error');
    sonidoPagina();

    await cargarNotas();
  } catch (err) {
    els.status.textContent = err.message;
    els.status.classList.add('is-error');
    els.status.classList.remove('is-good');
  }
});

els.search.addEventListener('input', aplicarBusqueda);

// El zoom depende del ancho disponible, asi que se recalcula al redimensionar
let resizeTimer;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(renderRonda, 180);
});

/* ---------- Arranque ---------------------------------------------------- */

els.gateForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const nombre = els.gateName.value.trim();
  if (!nombre) return;
  guardarViajero(nombre);
  els.gate.hidden = true;
  cargarNotas();
});

cargarViajero();

if (!viajero) {
  els.gate.hidden = false;
  els.gateName.focus();
} else {
  cargarNotas();
}

// Refresca cada 5s: sirve para ver en vivo que las 2 tasks del frontend
// detras del ALB leen la misma base persistida en EFS.
setInterval(() => {
  if (els.reader.hidden && !els.search.value.trim()) cargarNotas();
}, 5000);
