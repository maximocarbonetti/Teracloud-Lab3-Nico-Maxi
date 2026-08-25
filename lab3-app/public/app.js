/* =========================================================================
   Sovngarde Notes - logica del salon
   La ronda de tomos es una escena 3D (three.js) con los modelos GLB reales.
   ========================================================================= */

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const $ = (sel) => document.querySelector(sel);

const els = {
  canvas:      $('#ring-canvas'),
  stage:       $('.stage'),
  stageEmpty:  $('#stage-empty'),
  stageNote:   $('#stage-note'),
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

function cargarViajero() {
  try { viajero = localStorage.getItem('sovngarde:viajero') || ''; }
  catch { viajero = ''; }
}

function guardarViajero(nombre) {
  viajero = nombre;
  try { localStorage.setItem('sovngarde:viajero', nombre); } catch { /* modo privado */ }
}

/* ---------- Sonido de paginas ------------------------------------------ */

let audioCtx = null;

function sonidoPagina() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();

    const dur = 0.42, rate = audioCtx.sampleRate;
    const frames = Math.floor(rate * dur);
    const buffer = audioCtx.createBuffer(1, frames, rate);
    const data = buffer.getChannelData(0);

    for (let i = 0; i < frames; i++) {
      const t = i / frames;
      const a = Math.exp(-14 * t);
      const b = t > 0.34 ? Math.exp(-16 * (t - 0.34)) * 0.75 : 0;
      data[i] = (Math.random() * 2 - 1) * (a + b) * 0.5;
    }

    const src = audioCtx.createBufferSource();
    src.buffer = buffer;
    const bp = audioCtx.createBiquadFilter();
    bp.type = 'bandpass'; bp.frequency.value = 2600; bp.Q.value = 0.7;
    const hp = audioCtx.createBiquadFilter();
    hp.type = 'highpass'; hp.frequency.value = 900;
    const vol = audioCtx.createGain();
    vol.gain.value = 0.16;

    src.connect(bp).connect(hp).connect(vol).connect(audioCtx.destination);
    src.start();
  } catch { /* si el navegador bloquea el audio, la app sigue */ }
}

/* ---------- Utilidades -------------------------------------------------- */

function formatFecha(iso) {
  const d = new Date(iso);
  return isNaN(d) ? '' : d.toLocaleString('es-AR', { dateStyle: 'long', timeStyle: 'short' });
}

function esMia(nota) {
  return viajero && nota.autor &&
         nota.autor.trim().toLowerCase() === viajero.trim().toLowerCase();
}

function tituloDe(nota, max = 30) {
  let t = (nota.titulo || '').trim();
  if (!t || t === 'Tomo sin titulo') t = (nota.texto || '').trim();
  t = t.replace(/\s+/g, ' ');
  return t.length > max ? t.slice(0, max) + '...' : t;
}

function escapar(str) {
  const d = document.createElement('div');
  d.textContent = str == null ? '' : String(str);
  return d.innerHTML;
}

/* =========================================================================
   Escena 3D de la ronda
   ========================================================================= */

const MAX_EN_RONDA = 40; // limite por performance; el resto vive en las estanterias

const ring3d = {
  ok: false,
  scene: null, camera: null, renderer: null,
  grupo: null,          // gira sobre su eje Y
  modelos: {},          // plantillas GLB ya normalizadas
  tomos: [],            // { nota, obj, materiales, alturaBase }
  raycaster: new THREE.Raycaster(),
  puntero: new THREE.Vector2(),
  reloj: new THREE.Clock(),
  pausado: false,
  radio: 3,
};

function initEscena() {
  const { canvas } = els;

  ring3d.renderer = new THREE.WebGLRenderer({
    canvas, alpha: true, antialias: true,
  });
  ring3d.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  ring3d.renderer.outputColorSpace = THREE.SRGBColorSpace;
  ring3d.renderer.toneMapping = THREE.ACESFilmicToneMapping;
  ring3d.renderer.toneMappingExposure = 1.15;

  ring3d.scene = new THREE.Scene();

  ring3d.camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
  ring3d.camera.position.set(0, 1.15, 6);
  ring3d.camera.lookAt(0, 0, 0);

  // Luz: ambiente frio (aurora) + cenital calida + relleno frontal
  ring3d.scene.add(new THREE.HemisphereLight(0x9fe8ff, 0x101c26, 1.25));

  const key = new THREE.DirectionalLight(0xffe3ad, 2.1);
  key.position.set(3, 5, 4);
  ring3d.scene.add(key);

  const rim = new THREE.DirectionalLight(0x66e0c0, 1.1);
  rim.position.set(-4, 2, -3);
  ring3d.scene.add(rim);

  const fill = new THREE.DirectionalLight(0xffffff, 0.5);
  fill.position.set(0, 1, 8);
  ring3d.scene.add(fill);

  ring3d.grupo = new THREE.Group();
  ring3d.scene.add(ring3d.grupo);

  redimensionar();
  window.addEventListener('resize', redimensionar);

  canvas.addEventListener('pointerdown', alClickearCanvas);
  canvas.addEventListener('pointermove', alMoverPuntero);

  ring3d.renderer.setAnimationLoop(animar);
  ring3d.ok = true;
}

function redimensionar() {
  if (!ring3d.renderer) return;
  const w = els.stage.clientWidth;
  const h = els.stage.clientHeight;
  if (!w || !h) return;
  ring3d.renderer.setSize(w, h, false);
  ring3d.camera.aspect = w / h;
  ring3d.camera.updateProjectionMatrix();
  encuadrarCamara();
}

/* Centra, orienta y escala un modelo recien cargado.
   El eje mas delgado del libro pasa a ser Z, asi la tapa mira hacia +Z
   (hacia afuera de la ronda). */
function normalizarModelo(gltfScene, alturaObjetivo = 1.25) {
  const contenedor = new THREE.Group();
  const interno = new THREE.Group();
  interno.add(gltfScene);
  contenedor.add(interno);

  let caja = new THREE.Box3().setFromObject(interno);
  const tam = caja.getSize(new THREE.Vector3());
  const dims = [tam.x, tam.y, tam.z];
  const iMin = dims.indexOf(Math.min(...dims));

  if (iMin === 0) interno.rotation.y = Math.PI / 2;       // X delgado -> pasa a Z
  else if (iMin === 1) interno.rotation.x = -Math.PI / 2; // Y delgado -> pasa a Z

  // Recalcular ya rotado
  interno.updateMatrixWorld(true);
  caja = new THREE.Box3().setFromObject(interno);
  const tam2 = caja.getSize(new THREE.Vector3());
  const centro = caja.getCenter(new THREE.Vector3());

  interno.position.sub(centro);
  const escala = alturaObjetivo / tam2.y;
  contenedor.scale.setScalar(escala);

  contenedor.userData.tamano = tam2.clone().multiplyScalar(escala);
  return contenedor;
}

async function cargarModelos() {
  const loader = new GLTFLoader();
  const cargar = (url) => new Promise((res, rej) => loader.load(url, res, undefined, rej));

  const [mine, others] = await Promise.all([
    cargar('models/tome-mine.glb'),
    cargar('models/tome-others.glb'),
  ]);

  ring3d.modelos.mine = normalizarModelo(mine.scene);
  ring3d.modelos.others = normalizarModelo(others.scene);
}

/* Rotulo con titulo y autor, dibujado en un canvas y pegado sobre la tapa */
function crearRotulo(nota, ancho, alto) {
  const cv = document.createElement('canvas');
  cv.width = 640; cv.height = 200;
  const ctx = cv.getContext('2d');

  ctx.clearRect(0, 0, cv.width, cv.height);
  ctx.textAlign = 'center';
  ctx.shadowColor = 'rgba(0,0,0,.85)';
  ctx.shadowBlur = 10;
  ctx.shadowOffsetY = 3;

  ctx.fillStyle = '#f6e6bd';
  ctx.font = '700 62px Cinzel, Georgia, serif';
  const titulo = tituloDe(nota, 22);
  ctx.fillText(titulo, cv.width / 2, 84, cv.width - 40);

  ctx.fillStyle = 'rgba(240,205,140,.92)';
  ctx.font = '500 42px Cinzel, Georgia, serif';
  ctx.fillText((nota.autor || '').toUpperCase(), cv.width / 2, 150, cv.width - 60);

  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;

  const mat = new THREE.MeshBasicMaterial({
    map: tex, transparent: true, depthWrite: false,
  });

  const w = ancho * 0.78;
  const plano = new THREE.Mesh(new THREE.PlaneGeometry(w, w * (200 / 640)), mat);
  plano.position.y = -alto * 0.26;
  return plano;
}

/* Clona la plantilla y le da materiales propios, para poder atenuar o
   iluminar un tomo sin afectar a los demas. */
function instanciarTomo(nota) {
  const plantilla = esMia(nota) ? ring3d.modelos.mine : ring3d.modelos.others;
  const obj = plantilla.clone(true);
  const tam = plantilla.userData.tamano;

  const materiales = [];
  obj.traverse((n) => {
    if (n.isMesh) {
      n.material = n.material.clone();
      n.material.transparent = true;
      materiales.push({
        mat: n.material,
        emisivaBase: n.material.emissive ? n.material.emissive.clone() : null,
        intensidadBase: n.material.emissiveIntensity ?? 1,
      });
    }
  });

  const rotulo = crearRotulo(nota, tam.x, tam.y);
  rotulo.position.z = tam.z / 2 + 0.012;
  obj.add(rotulo);

  return { obj, materiales, tam };
}

function construirRonda() {
  if (!ring3d.ok) return;

  // Limpiar la ronda anterior
  for (const t of ring3d.tomos) {
    ring3d.grupo.remove(t.obj);
    t.obj.traverse((n) => {
      if (n.isMesh) {
        n.geometry?.dispose?.();
        n.material?.map?.dispose?.();
        n.material?.dispose?.();
      }
    });
  }
  ring3d.tomos = [];

  const enRonda = notas.slice(0, MAX_EN_RONDA);
  const total = enRonda.length;

  els.stageEmpty.hidden = total > 0;
  els.stageNote.textContent = notas.length > MAX_EN_RONDA
    ? `Se muestran los ${MAX_EN_RONDA} tomos mas recientes en la ronda.`
    : '';

  if (!total) { encuadrarCamara(); return; }

  // Radio segun cantidad, para que los tomos no se toquen
  const anchoTomo = (ring3d.modelos.mine.userData.tamano.x) * 1.35;
  ring3d.radio = Math.max(2.2, (total * anchoTomo) / (2 * Math.PI));

  enRonda.forEach((nota, i) => {
    const { obj, materiales } = instanciarTomo(nota);
    const ang = (i / total) * Math.PI * 2;

    obj.position.set(Math.sin(ang) * ring3d.radio, 0, Math.cos(ang) * ring3d.radio);
    obj.rotation.y = ang;              // la tapa mira hacia afuera
    obj.userData.notaId = String(nota.id);

    ring3d.grupo.add(obj);
    ring3d.tomos.push({ nota, obj, materiales, alturaBase: 0, alturaObjetivo: 0, resaltado: false });
  });

  encuadrarCamara();
  aplicarBusqueda();
}

/* Aleja la camara a medida que la ronda crece, para que entre entera */
function encuadrarCamara() {
  if (!ring3d.camera) return;
  const fov = THREE.MathUtils.degToRad(ring3d.camera.fov);
  const necesaria = (ring3d.radio + 1.1) / Math.tan(fov / 2);
  const dist = Math.max(4.2, necesaria / Math.min(1, ring3d.camera.aspect * 0.9));
  ring3d.camera.position.set(0, dist * 0.19, dist);
  ring3d.camera.lookAt(0, 0, 0);
}

function alMoverPuntero(e) {
  const r = els.canvas.getBoundingClientRect();
  ring3d.puntero.x = ((e.clientX - r.left) / r.width) * 2 - 1;
  ring3d.puntero.y = -((e.clientY - r.top) / r.height) * 2 + 1;
}

function alClickearCanvas(e) {
  if (!ring3d.ok || !ring3d.tomos.length) return;
  alMoverPuntero(e);
  ring3d.raycaster.setFromCamera(ring3d.puntero, ring3d.camera);

  const hits = ring3d.raycaster.intersectObjects(ring3d.grupo.children, true);
  if (!hits.length) return;

  let nodo = hits[0].object;
  while (nodo && !nodo.userData.notaId) nodo = nodo.parent;
  if (!nodo) return;

  const t = ring3d.tomos.find((x) => String(x.nota.id) === nodo.userData.notaId);
  if (t) abrirTomo(t.nota);
}

function animar() {
  const dt = ring3d.reloj.getDelta();

  if (!ring3d.pausado) ring3d.grupo.rotation.y += dt * 0.14;

  // Los tomos resaltados suben y flotan
  const t = ring3d.reloj.getElapsedTime();
  for (const tomo of ring3d.tomos) {
    const objetivo = tomo.resaltado ? 0.42 + Math.sin(t * 1.8) * 0.05 : 0;
    tomo.obj.position.y += (objetivo - tomo.obj.position.y) * Math.min(1, dt * 6);
  }

  ring3d.renderer.render(ring3d.scene, ring3d.camera);
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
    vacio.className = 'shelf-empty';
    vacio.textContent = '—';
    contenedor.appendChild(vacio);
    return;
  }

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

/* ---------- Buscador ---------------------------------------------------- */

function aplicarBusqueda() {
  const q = els.search.value.trim().toLowerCase();
  const tomosDom = document.querySelectorAll('.tome');

  if (!q) {
    ring3d.pausado = false;
    els.searchHint.textContent = '';
    for (const t of ring3d.tomos) { t.resaltado = false; atenuar(t, false); }
    tomosDom.forEach((el) => el.classList.remove('is-hit', 'is-dim'));
    return;
  }

  const coincide = (n) =>
    (n.titulo || '').toLowerCase().includes(q) ||
    (n.texto  || '').toLowerCase().includes(q) ||
    (n.autor  || '').toLowerCase().includes(q);

  const ids = new Set(notas.filter(coincide).map((n) => String(n.id)));

  ring3d.pausado = ids.size > 0;

  for (const t of ring3d.tomos) {
    const hit = ids.has(String(t.nota.id));
    t.resaltado = hit;
    atenuar(t, !hit);
  }

  tomosDom.forEach((el) => {
    const hit = ids.has(el.dataset.id);
    el.classList.toggle('is-hit', hit);
    el.classList.toggle('is-dim', !hit);
  });

  const n = ids.size;
  els.searchHint.textContent = n
    ? `${n} ${n === 1 ? 'tomo se eleva' : 'tomos se elevan'} de la ronda`
    : 'Ningun tomo responde a ese nombre';
}

function atenuar(tomo, apagar) {
  for (const m of tomo.materiales) {
    m.mat.opacity = apagar ? 0.28 : 1;
    if (m.emisivaBase) {
      m.mat.emissiveIntensity = tomo.resaltado ? m.intensidadBase + 0.55 : m.intensidadBase;
    }
  }
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

function cerrarTomo() { els.reader.hidden = true; }

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
    const nuevas = await res.json();

    // Solo reconstruir la escena 3D si realmente cambio algo
    const cambio = JSON.stringify(nuevas.map((n) => n.id)) !==
                   JSON.stringify(notas.map((n) => n.id));
    notas = nuevas;

    renderEstanterias();
    if (cambio) construirRonda();
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

/* ---------- Arranque ---------------------------------------------------- */

els.gateForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const nombre = els.gateName.value.trim();
  if (!nombre) return;
  guardarViajero(nombre);
  els.gate.hidden = true;
  arrancar();
});

async function arrancar() {
  try {
    initEscena();
    await cargarModelos();
  } catch (err) {
    console.error('[3d] No se pudieron cargar los modelos:', err);
    els.stageNote.textContent =
      'No se pudo cargar la ronda en 3D. Los tomos siguen disponibles en las estanterias.';
    ring3d.ok = false;
  }
  await cargarNotas();
}

cargarViajero();

if (!viajero) {
  els.gate.hidden = false;
  els.gateName.focus();
} else {
  arrancar();
}

// Refresco periodico: permite ver en vivo que las 2 tasks del frontend
// detras del ALB leen la misma base persistida en EFS.
setInterval(() => {
  if (els.reader.hidden && !els.search.value.trim()) cargarNotas();
}, 5000);
