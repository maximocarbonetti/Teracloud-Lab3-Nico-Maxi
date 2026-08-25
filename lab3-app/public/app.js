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
  chispas: null,     // efecto compartido, se mueve al tomo bajo el puntero
  aura: null,
  hover: null,       // tomo actualmente apuntado
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

  // Un solo juego de efectos, reutilizado: se reposiciona sobre el tomo
  // apuntado en vez de crear particulas por cada libro.
  ring3d.chispas = crearChispas();
  ring3d.aura = crearAura();
  ring3d.grupo.add(ring3d.chispas, ring3d.aura);

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

/* --- Texturas generadas al vuelo para chispas, auras y halos --- */

function texturaPunto(interior = 'rgba(255,255,255,1)', exterior = 'rgba(255,255,255,0)') {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 64;
  const ctx = cv.getContext('2d');
  const g = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
  g.addColorStop(0, interior);
  g.addColorStop(0.35, interior);
  g.addColorStop(1, exterior);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function texturaHalo() {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 256;
  const ctx = cv.getContext('2d');
  const g = ctx.createRadialGradient(128, 128, 10, 128, 128, 128);
  g.addColorStop(0,    'rgba(255,240,200,.85)');
  g.addColorStop(0.28, 'rgba(255,215,130,.42)');
  g.addColorStop(0.6,  'rgba(180,240,210,.16)');
  g.addColorStop(1,    'rgba(180,240,210,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 256, 256);
  const t = new THREE.CanvasTexture(cv);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

/* Chispas electricas: para los tomos propios, al pasar el puntero.
   Particulas rapidas que saltan y se reinician, en azul frio. */
function crearChispas() {
  const N = 70;
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(N * 3);
  const vel = new Float32Array(N * 3);
  const vida = new Float32Array(N);

  for (let i = 0; i < N; i++) vida[i] = Math.random();

  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));

  const mat = new THREE.PointsMaterial({
    size: 0.055,
    map: texturaPunto('rgba(215,245,255,1)'),
    color: 0x9fe4ff,
    transparent: true,
    opacity: 0,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    sizeAttenuation: true,
  });

  const pts = new THREE.Points(geo, mat);
  pts.visible = false;
  pts.userData = { vel, vida, N, caja: new THREE.Vector3(1, 1, 0.6) };
  return pts;
}

/* Aura de restauracion: para los tomos ajenos, al pasar el puntero.
   Anillo dorado que gira y motas que ascienden. */
function crearAura() {
  const grupo = new THREE.Group();

  const anillo = new THREE.Mesh(
    new THREE.TorusGeometry(0.72, 0.045, 8, 64),
    new THREE.MeshBasicMaterial({
      map: texturaPunto('rgba(255,235,170,1)'),
      color: 0xffd98a,
      transparent: true,
      opacity: 0,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    })
  );
  anillo.rotation.x = Math.PI / 2;
  grupo.add(anillo);

  const N = 34;
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(N * 3);
  const fase = new Float32Array(N);
  const radio = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    fase[i] = Math.random();
    radio[i] = 0.28 + Math.random() * 0.5;
  }
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));

  const motas = new THREE.Points(geo, new THREE.PointsMaterial({
    size: 0.07,
    map: texturaPunto('rgba(255,240,200,1)'),
    color: 0xffe6a8,
    transparent: true,
    opacity: 0,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  }));
  grupo.add(motas);

  grupo.visible = false;
  grupo.userData = { anillo, motas, fase, radio, N };
  return grupo;
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

  // Halo que se enciende cuando el tomo asciende por una busqueda
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({
    map: texturaHalo(),
    transparent: true,
    opacity: 0,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  }));
  halo.scale.setScalar(Math.max(tam.x, tam.y) * 2.4);
  halo.visible = false;
  obj.add(halo);

  return { obj, materiales, tam, halo };
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
  ring3d.hover = null;
  if (ring3d.chispas) ring3d.chispas.visible = false;
  if (ring3d.aura) ring3d.aura.visible = false;

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
    const inst = instanciarTomo(nota);
    const { obj, materiales } = inst;
    const ang = (i / total) * Math.PI * 2;

    obj.position.set(Math.sin(ang) * ring3d.radio, 0, Math.cos(ang) * ring3d.radio);
    obj.rotation.y = ang;              // la tapa mira hacia afuera
    obj.userData.notaId = String(nota.id);

    ring3d.grupo.add(obj);
    const { halo } = inst;
    ring3d.tomos.push({ nota, obj, materiales, halo, tam: inst.tam, resaltado: false });
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
  ring3d.punteroSucio = true;
}

/* Resuelve que tomo esta bajo el puntero y enciende el efecto que
   corresponda: chispas para los propios, aura para los ajenos. */
function actualizarHover() {
  if (!ring3d.punteroSucio) return;
  ring3d.punteroSucio = false;

  ring3d.raycaster.setFromCamera(ring3d.puntero, ring3d.camera);
  const objetivos = ring3d.tomos.map((t) => t.obj);
  const hits = ring3d.raycaster.intersectObjects(objetivos, true);

  let encontrado = null;
  if (hits.length) {
    let n = hits[0].object;
    while (n && !n.userData.notaId) n = n.parent;
    if (n) encontrado = ring3d.tomos.find((t) => String(t.nota.id) === n.userData.notaId) || null;
  }

  if (encontrado === ring3d.hover) return;
  ring3d.hover = encontrado;
  els.canvas.style.cursor = encontrado ? 'pointer' : 'grab';

  const { chispas, aura } = ring3d;
  chispas.visible = false;
  aura.visible = false;

  if (!encontrado) return;

  const propio = esMia(encontrado.nota);
  const efecto = propio ? chispas : aura;
  efecto.visible = true;
  efecto.position.copy(encontrado.obj.position);
  efecto.rotation.y = encontrado.obj.rotation.y;

  if (propio) {
    // Reiniciar las chispas para que la rafaga arranque desde el tomo
    const { vel, vida, N, caja } = chispas.userData;
    const tam = encontrado.tam || { x: 1, y: 1.4, z: 0.6 };
    caja.set(tam.x * 0.62, tam.y * 0.62, tam.z * 0.9);
    const pos = chispas.geometry.attributes.position.array;
    for (let i = 0; i < N; i++) {
      vida[i] = Math.random();
      pos[i*3]   = (Math.random() - 0.5) * caja.x * 2;
      pos[i*3+1] = (Math.random() - 0.5) * caja.y * 2;
      pos[i*3+2] = (Math.random() - 0.5) * caja.z * 2;
      vel[i*3]   = (Math.random() - 0.5) * 1.6;
      vel[i*3+1] = (Math.random() - 0.5) * 1.6;
      vel[i*3+2] = (Math.random() - 0.5) * 1.2;
    }
    chispas.geometry.attributes.position.needsUpdate = true;
  }
}

function alClickearCanvas(e) {
  if (!ring3d.ok || !ring3d.tomos.length) return;
  alMoverPuntero(e);
  ring3d.raycaster.setFromCamera(ring3d.puntero, ring3d.camera);

  const hits = ring3d.raycaster.intersectObjects(ring3d.tomos.map((t) => t.obj), true);
  if (!hits.length) return;

  let nodo = hits[0].object;
  while (nodo && !nodo.userData.notaId) nodo = nodo.parent;
  if (!nodo) return;

  const t = ring3d.tomos.find((x) => String(x.nota.id) === nodo.userData.notaId);
  if (t) abrirTomo(t.nota);
}

function animar() {
  const dt = Math.min(ring3d.reloj.getDelta(), 0.05);
  const t = ring3d.reloj.getElapsedTime();

  if (!ring3d.pausado) ring3d.grupo.rotation.y += dt * 0.14;

  actualizarHover();

  // Los tomos resaltados por la busqueda suben, flotan y encienden su halo
  for (const tomo of ring3d.tomos) {
    const objetivo = tomo.resaltado ? 0.42 + Math.sin(t * 1.8) * 0.05 : 0;
    tomo.obj.position.y += (objetivo - tomo.obj.position.y) * Math.min(1, dt * 6);

    if (tomo.halo) {
      const meta = tomo.resaltado ? 0.55 + Math.sin(t * 2.4) * 0.14 : 0;
      const m = tomo.halo.material;
      m.opacity += (meta - m.opacity) * Math.min(1, dt * 5);
      tomo.halo.visible = m.opacity > 0.01;
    }
  }

  animarChispas(dt);
  animarAura(dt, t);

  ring3d.renderer.render(ring3d.scene, ring3d.camera);
}

function animarChispas(dt) {
  const ch = ring3d.chispas;
  if (!ch || !ch.visible) {
    if (ch) ch.material.opacity = 0;
    return;
  }
  ch.material.opacity = Math.min(0.95, ch.material.opacity + dt * 5);

  const { vel, vida, N, caja } = ch.userData;
  const pos = ch.geometry.attributes.position.array;

  for (let i = 0; i < N; i++) {
    vida[i] -= dt * 1.6;
    if (vida[i] <= 0) {
      // Renace pegada a la tapa, con un nuevo impulso
      vida[i] = 0.5 + Math.random() * 0.5;
      pos[i*3]   = (Math.random() - 0.5) * caja.x * 1.7;
      pos[i*3+1] = (Math.random() - 0.5) * caja.y * 1.7;
      pos[i*3+2] = caja.z * (Math.random() > 0.5 ? 1 : -1) * 0.8;
      vel[i*3]   = (Math.random() - 0.5) * 1.8;
      vel[i*3+1] = (Math.random() - 0.5) * 1.8;
      vel[i*3+2] = (Math.random() - 0.5) * 1.3;
    }
    // Movimiento nervioso: el impulso se sacude en cada cuadro
    pos[i*3]   += vel[i*3]   * dt + (Math.random() - 0.5) * 0.02;
    pos[i*3+1] += vel[i*3+1] * dt + (Math.random() - 0.5) * 0.02;
    pos[i*3+2] += vel[i*3+2] * dt;
  }
  ch.geometry.attributes.position.needsUpdate = true;
}

function animarAura(dt, t) {
  const au = ring3d.aura;
  if (!au) return;
  const { anillo, motas, fase, radio, N } = au.userData;

  if (!au.visible) {
    anillo.material.opacity = 0;
    motas.material.opacity = 0;
    return;
  }

  anillo.material.opacity = Math.min(0.6, anillo.material.opacity + dt * 3);
  motas.material.opacity  = Math.min(0.85, motas.material.opacity + dt * 3);

  anillo.rotation.z += dt * 0.9;
  anillo.position.y = -0.55 + Math.sin(t * 1.5) * 0.05;
  const pulso = 1 + Math.sin(t * 2.2) * 0.06;
  anillo.scale.setScalar(pulso);

  const pos = motas.geometry.attributes.position.array;
  for (let i = 0; i < N; i++) {
    fase[i] += dt * 0.42;
    if (fase[i] > 1) fase[i] -= 1;
    const ang = i * 2.4 + t * 0.6;
    pos[i*3]   = Math.cos(ang) * radio[i];
    pos[i*3+1] = -0.6 + fase[i] * 1.5;
    pos[i*3+2] = Math.sin(ang) * radio[i];
  }
  motas.geometry.attributes.position.needsUpdate = true;
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
