FROM php:8.2-apache

# mysqli es requerido por src/index.php para probar la conexion a MySQL
RUN docker-php-ext-install mysqli

COPY src/ /var/www/html/

# El ALB y la task definition (ecs-service) esperan el contenedor
# escuchando en el puerto 80 (var.frontend_container_port default = 80)
EXPOSE 80

CMD ["apache2-foreground"]
