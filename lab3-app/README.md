# Sovngarde Notes — frontend

Anotador colaborativo con tematica nordica. Es el servicio `frontend` que
corre en el cluster ECS detras del ALB (2 tasks), y persiste las notas en la
task de MySQL, cuyo volumen vive en EFS.

## Stack

- Node.js 20 + Express (sirve la API y los archivos estaticos)
- mysql2 para la conexion a la base
- Frontend sin framework: HTML, CSS y JS plano. Todo el arte (aurora,
  libros, dragon, cofre) es SVG/CSS original, sin assets externos.

## Estructura

```
lab3-app/
├── Dockerfile          imagen del contenedor (Node 20 alpine)
├── buildspec.yml       pasos de build para CodeBuild
├── server.js           API + servidor estatico
├── package.json
└── public/
    ├── index.html
    ├── style.css
    ├── app.js
    └── img/
        └── teracloud.png   <- hay que agregarlo a mano (ver abajo)
```

## Variables de entorno

Llegan desde Parameter Store, inyectadas como `secrets` en la task
definition (ver `frontend_secrets` en `environments/dev/main.tf`).

Se aceptan dos juegos de nombres, para no depender de como esten mapeados:

| Proposito | Nombres aceptados            |
|-----------|------------------------------|
| Host      | `DB_HOST` o `MYSQL_HOST`     |
| Puerto    | `DB_PORT` o `MYSQL_PORT`     |
| Base      | `DB_NAME` o `MYSQL_DATABASE` |
| Usuario   | `DB_USER` o `MYSQL_USER`     |
| Password  | `DB_PASSWORD` o `MYSQL_PASSWORD` |

`PORT` es opcional y por defecto vale **80**, que es el puerto que espera el
target group del ALB.

## Endpoints

| Metodo | Ruta          | Descripcion                                  |
|--------|---------------|----------------------------------------------|
| GET    | `/health`     | Devuelve 200 apenas el server HTTP esta arriba, aunque MySQL todavia no responda. Evita que el target group tumbe tasks sanas por un problema transitorio de la base. |
| GET    | `/api/notas`  | Lista las notas, mas recientes primero        |
| POST   | `/api/notas`  | Crea una nota. Body: `{ "texto": "...", "autor": "..." }` |

## Esquema

```sql
CREATE TABLE notas (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  texto          VARCHAR(1000) NOT NULL,
  autor          VARCHAR(80) NOT NULL DEFAULT 'Viajero anonimo',
  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

La tabla se crea sola al arrancar. Si ya existia sin la columna `autor`,
se agrega automaticamente con un `ALTER TABLE` (el error 1060 de columna
duplicada se ignora, significa que la migracion ya se aplico).

## Identidad del autor

No hay sistema de login. La app pide el nombre del visitante la primera vez
y lo guarda en el navegador (`localStorage`), y lo manda en cada POST. Eso
es lo que permite separar en pantalla "tus tomos" de "tomos de otros".

## Falta agregar: el logo

El estandarte que cuelga del dragon carga `public/img/teracloud.png`.
Hay que copiar ahi el logo de Teracloud con ese nombre exacto (PNG con
fondo transparente, ~200x90 px).

Si el archivo no existe la app no se rompe: el cartel muestra la palabra
"teracloud" en texto.

## Probar en local

```bash
npm install
DB_HOST=localhost DB_USER=root DB_PASSWORD=secret DB_NAME=app PORT=3000 npm start
```

Sin una base levantada el sitio igual carga; la API responde 503 con un
mensaje claro hasta que MySQL este disponible.
