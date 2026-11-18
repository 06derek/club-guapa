# Roadmap GUAPA (MVP)

- [x] Migración a este proyecto: páginas, diseño, base de datos y reglas
- [ ] Importar datos y usuarios del proyecto anterior — espera exportaciones del cliente
- [x] Preparar despliegue en Cloudflare Workers (configuración lista y probada)
- [ ] Conectar GitHub y Cloudflare, y añadir la dirección del sitio a las direcciones permitidas de inicio de sesión — lo hace el cliente
- [ ] Probar flujo con sesión (equipos, admin) con una cuenta UNAM real

- [x] Etapa 0: sistema de diseño claro/oscuro, layout, navegación, 404, landing y páginas públicas
- [x] Etapa 1: registro (solo UNAM), login, logout, perfiles, roles, guardias de rutas
- [ ] Asignar primer administrador — espera el correo del cliente
- [x] Etapa 2: admin registra actividades y horarios
- [x] Etapa 4: miembros y equipos (crear, agregar máx. 5, ver, admin renombra/borra)

## MVP aprobado (17 nov)
- [ ] Admin edita contacto: correo, ubicación, Facebook y Discord (pie de página y Contacto)
- [ ] Recursos: página pública + admin agrega/edita/borra
- [ ] Perfil: editar datos y vincular Codeforces
- [ ] Scoreboard por periodo
- [ ] Mis competencias (registro e historial)
- [ ] Calendario público + admin agrega competencias
- [ ] Estadísticas personales
- [ ] Admin: desactivar usuarios
- [ ] Primer administrador: la cuenta del usuario (aprobado)

## Continuación según SRS (17 nov) — supuestos por defecto mientras no haya respuesta a Q1–Q17
- [ ] Perfil editable (RF-022), abandonar equipo (RF-038), borrar actividades/horarios (RF-009)
- [ ] Etapa 3: recursos (enlaces, categorías, búsqueda, públicos/solo miembros, CRUD admin)
- [ ] Etapa 5: vincular Codeforces y sincronizar (manual + automática)
- [ ] Etapa 6: Scoreboard por periodo
- [ ] Etapa 7: competencias externas (registro, historial, filtros, editar/borrar, catálogo de plataformas)
- [ ] Etapa 8: estadísticas personales, historial combinado, estadísticas de equipo
- [ ] Etapa 9: calendario público (Codeforces automático + competencias del club)
- [ ] Etapa 10: admin usuarios (desactivar), competencias de todos, auditoría
- [ ] Etapa 11: tema de evento (RF-089), pruebas de reglas
