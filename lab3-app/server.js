const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// --- Configuración de conexión a MySQL ---
// Todas estas variables vienen del entorno (task definition -> Parameter Store).
// Nunca deben estar hardcodeadas acá.
const dbConfig = {
  host: process.env.MYSQL_HOST,
  port: process.env.MYSQL_PORT || 3306,
  database: process.env.MYSQL_DATABASE,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  waitForConnections: true,
  connectionLimit: 5,
};

let pool;
let dbReady = false;

// Crea el pool de conexiones y la tabla si no existe.
// Reintenta cada 5s por si la task de MySQL todavía no está lista
// (por ejemplo, durante un arranque en frío o un reemplazo de task).
async function initDb() {
  try {
    pool = mysql.createPool(dbConfig);

    // Prueba real de conexión
    const conn = await pool.getConnection();
    await conn.query(`
      CREATE TABLE IF NOT EXISTS notas (
        id INT AUTO_INCREMENT PRIMARY KEY,
        texto VARCHAR(1000) NOT NULL,
        fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
    conn.release();

    dbReady = true;
    console.log(`[db] Conectado a MySQL en ${dbConfig.host}:${dbConfig.port}, tabla "notas" lista.`);
  } catch (err) {
    dbReady = false;
    console.error(`[db] No se pudo conectar/inicializar (${err.code || err.message}). Reintentando en 5s...`);
    setTimeout(initDb, 5000);
  }
}

initDb();

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// --- Health check ---
// Usado por el Target Group del ALB. Devuelve 200 apenas el server HTTP está
// arriba, independientemente del estado de la DB, para no tumbar el target
// group por un problema transitorio de MySQL.
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', db: dbReady ? 'connected' : 'connecting' });
});

// --- API: listar notas ---
app.get('/api/notas', async (req, res) => {
  if (!dbReady) {
    return res.status(503).json({ error: 'Base de datos no disponible todavía' });
  }
  try {
    const [rows] = await pool.query(
      'SELECT id, texto, fecha_creacion FROM notas ORDER BY fecha_creacion DESC'
    );
    res.json(rows);
  } catch (err) {
    console.error('[api] Error al listar notas:', err.message);
    res.status(500).json({ error: 'Error al consultar la base de datos' });
  }
});

// --- API: crear nota ---
app.post('/api/notas', async (req, res) => {
  if (!dbReady) {
    return res.status(503).json({ error: 'Base de datos no disponible todavía' });
  }
  const { texto } = req.body;
  if (!texto || !texto.trim()) {
    return res.status(400).json({ error: 'El texto de la nota no puede estar vacío' });
  }
  try {
    const [result] = await pool.query('INSERT INTO notas (texto) VALUES (?)', [texto.trim()]);
    res.status(201).json({ id: result.insertId, texto: texto.trim() });
  } catch (err) {
    console.error('[api] Error al crear nota:', err.message);
    res.status(500).json({ error: 'Error al guardar la nota' });
  }
});

app.listen(PORT, () => {
  console.log(`[server] Anotador escuchando en el puerto ${PORT}`);
});
