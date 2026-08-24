<?php // pagina principal del frontend
// Se conecta a MySQL usando las env vars que llegan desde Parameter Store
// (inyectadas por la task definition, ver modulo ecs-service / ssm-parameters).
// Siempre devuelve 200 (para no romper el health check del ALB), pero
// muestra si la conexion a la DB funciona o no.

header("Content-Type: text/html; charset=utf-8");

$db_host = getenv("DB_HOST") ?: "no configurado";
$db_port = getenv("DB_PORT") ?: "3306";
$db_name = getenv("DB_NAME") ?: "no configurado";
$db_user = getenv("DB_USER") ?: "no configurado";
$db_password = getenv("DB_PASSWORD") ?: "";

$db_status = "desconocido";
$db_ok = false;

if ($db_host !== "no configurado") {
    mysqli_report(MYSQLI_REPORT_OFF);
    $conn = @mysqli_connect($db_host, $db_user, $db_password, $db_name, (int) $db_port);
    if ($conn) {
        $db_ok = true;
        $db_status = "conectado a " . htmlspecialchars($db_host) . ":" . htmlspecialchars($db_port);
        mysqli_close($conn);
    } else {
        $db_status = "error de conexion: " . htmlspecialchars(mysqli_connect_error());
    }
} else {
    $db_status = "DB_HOST no seteado (variables de entorno no inyectadas)";
}
?>
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Lab3 - ECS/ALB/MySQL</title></head>
<body>
  <h1>Lab3 - Frontend PHP</h1>
  <p>Instancia: <?= htmlspecialchars(gethostname()) ?></p>
  <p>Estado de la base de datos: <strong><?= $db_ok ? "OK" : "FALLO" ?></strong></p>
  <p><?= $db_status ?></p>
</body>
</html>
