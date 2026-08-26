# Decisiones de módulos: propios vs comunidad

Este documento explica, módulo por módulo, por qué se escribió uno propio en
lugar de usar uno de la comunidad (o viceversa).

## Criterio general

El enunciado permite usar módulos de la comunidad (por ejemplo
`terraform-aws-modules`) pero exige módulos propios para los componentes clave
de la solución (red, ECS, ALB, EFS, MySQL).

Nuestro criterio fue:

- **Módulo propio** cuando el componente es parte central de lo que se está
  evaluando, cuando la lógica está acoplada al diseño puntual de esta
  arquitectura, o cuando el recurso es lo bastante chico como para que un
  módulo genérico agregue más superficie que valor.
- **Módulo de la comunidad** cuando el componente es un patrón estándar, sin
  lógica propia del proyecto, y el módulo ya resuelve casos borde que nosotros
  tendríamos que reimplementar.

## Módulos propios

| Módulo | Por qué propio |
|---|---|
| `network` | Componente clave exigido por el enunciado. El diseño de subnets públicas/privadas por AZ, el NAT (conmutable entre uno compartido y uno por AZ) y las route tables están armados para esta arquitectura. `terraform-aws-modules/vpc` habría funcionado, pero implementarlo nosotros es justamente lo que se evalúa. |
| `ecs-cluster` | Componente clave. El cluster usa **EC2 launch type** (no Fargate), con ASG + launch template + capacity provider y *managed termination protection*. Esa combinación es específica del requerimiento y los módulos genéricos tienden a asumir Fargate. |
| `ecs-service` | Componente clave y el más acoplado al diseño: dos servicios con network modes distintos (frontend en `bridge` para puertos dinámicos detrás del ALB, MySQL en `awsvpc` para poder registrar un A record en Cloud Map), volumen EFS por access point, y secretos inyectados desde Parameter Store. Ningún módulo genérico modela esta combinación. |
| `alb` | Componente clave. Poco código y muy específico: redirect 80→443, listener HTTPS con el cert de ACM y un target group `instance` (obligatorio con `bridge` + puertos dinámicos). |
| `efs` | Componente clave. Mount targets por AZ + access point con UID/GID de MySQL: la parte que importa es el access point, que los módulos genéricos exponen de forma más indirecta. |
| `security-groups` | Se hizo propio para que la cadena de permisos quede explícita y legible como documentación viva: ALB → frontend → MySQL → EFS, cada capa abierta sólo a la anterior. Un módulo genérico habría dispersado esa intención en variables. |
| `acm` | Certificado + registros de validación DNS + espera de validación. Son 3 recursos; un módulo externo agregaba una dependencia para muy poco. |
| `dns` | Hosted zone (crear o reusar) + registro alias al ALB. Igual que `acm`: mínimo y muy atado a nuestro flujo. |
| `ecr` | Repositorio + lifecycle policy de imágenes. Chico y con política de retención propia. |
| `ssm-parameters` | Los parámetros y su jerarquía (`/lab3/dev/db/*`) son propios del proyecto, no un patrón reutilizable de terceros. |
| `cicd` | Pipeline completo (CodeStar Connection + CodeBuild + CodePipeline + notificación). Muy atado a nuestro `buildspec.yml` y a nuestro servicio ECS. |
| `observability` | Las alarmas se eligieron en base a los KPIs de esta arquitectura puntual, no de un catálogo genérico. |
| `notifications` | Un topic SNS + suscripciones + la topic policy que habilita a CodeStar Notifications y CloudWatch. Trivial en tamaño. |

## Dónde tendría sentido un módulo de la comunidad

Si este proyecto creciera, los primeros candidatos a reemplazar por módulos de
la comunidad serían:

- **`network` → `terraform-aws-modules/vpc/aws`**: es el caso más claro. Ese
  módulo ya resuelve VPC endpoints, flow logs, IPv6, subnets de base de datos y
  varias topologías de NAT que nosotros no cubrimos. Para un entorno productivo
  real lo usaríamos; acá lo escribimos nosotros porque es parte de lo evaluado.
- **`security-groups` → `terraform-aws-modules/security-group/aws`**: es un
  patrón estándar sin lógica de negocio; el módulo de la comunidad trae reglas
  predefinidas por servicio (mysql, https, etc.) que ahorran errores de puertos.
- **`alb` → `terraform-aws-modules/alb/aws`**: útil si hiciera falta manejar
  muchas rules, listeners y target groups; con un solo servicio detrás no
  compensa.

## Nota sobre la decisión final

Optamos por 100% módulos propios para esta entrega. La razón principal es que
el objetivo del lab es demostrar que sabemos construir y componer los módulos,
y que la interfaz de cada uno (variables de entrada, outputs) sea explícita y
entendible por un tercero. La contrapartida —menos casos borde cubiertos que un
módulo mantenido por la comunidad— está documentada arriba junto con los
candidatos concretos a migrar.
