const form = document.getElementById('nota-form');
const textarea = document.getElementById('texto');
const statusMsg = document.getElementById('status-msg');
const notasList = document.getElementById('notas-list');

function formatFecha(iso) {
  const d = new Date(iso);
  return d.toLocaleString('es-AR', { dateStyle: 'short', timeStyle: 'short' });
}

function render(notas) {
  notasList.innerHTML = '';
  if (!notas.length) {
    notasList.innerHTML = '<p>No hay notas todavía. ¡Creá la primera!</p>';
    return;
  }
  for (const nota of notas) {
    const div = document.createElement('div');
    div.className = 'nota';
    div.innerHTML = `
      <span>${nota.texto}</span>
      <span class="fecha">#${nota.id} — ${formatFecha(nota.fecha_creacion)}</span>
    `;
    notasList.appendChild(div);
  }
}

async function cargarNotas() {
  try {
    const res = await fetch('/api/notas');
    if (!res.ok) throw new Error('No se pudieron cargar las notas');
    const notas = await res.json();
    render(notas);
    statusMsg.textContent = '';
  } catch (err) {
    statusMsg.textContent = err.message;
  }
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const texto = textarea.value.trim();
  if (!texto) return;

  try {
    const res = await fetch('/api/notas', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ texto }),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || 'No se pudo guardar la nota');
    }
    textarea.value = '';
    statusMsg.textContent = '';
    await cargarNotas();
  } catch (err) {
    statusMsg.textContent = err.message;
  }
});

cargarNotas();
// Refresca la lista cada 5s -> útil para ver en vivo que ambas tasks del
// frontend (detrás del ALB) leen la misma base de datos persistida en EFS.
setInterval(cargarNotas, 5000);
