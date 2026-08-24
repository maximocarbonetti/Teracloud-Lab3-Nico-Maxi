<?php // healthcheck endpoint
// Endpoint liviano, sin tocar la DB, para health checks dedicados si hace falta.
header("Content-Type: text/plain");
http_response_code(200);
echo "ok";
