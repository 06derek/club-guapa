# GUAPA · FES Acatlán

Sitio del Grupo Universitario de Algoritmia y Programación Avanzada (TanStack Start + React + Tailwind).

## Desarrollo local

```sh
bun install        # o: npm install
bun run dev        # http://localhost:8080
bun run test
```

## Despliegue en Cloudflare Workers

El proyecto se compila con Vite y `@cloudflare/vite-plugin`, y se publica con Wrangler.
**Siempre compila antes de publicar**: `wrangler deploy` por sí solo no puede empaquetar la app
(da errores como `Could not resolve "#tanstack-router-entry"`).

### Desde tu computadora

```sh
npx wrangler login
npm run deploy     # = vite build && wrangler deploy
```

### Desde GitHub (Cloudflare Workers Builds)

En Cloudflare: **Workers & Pages → Create → Import a repository** y elige este repositorio.

| Ajuste | Valor |
| --- | --- |
| Project name | `guapa-club` (debe coincidir con `name` en `wrangler.jsonc`) |
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |
| Root directory | `/` |

### Configuración

- `wrangler.jsonc` → `vars`: dirección del backend y clave publicable que usa el servidor.
- `.env.production`: los mismos valores públicos para el navegador (se incrustan al compilar).
- Solo valores públicos en esos archivos. Para claves privadas usa `npx wrangler secret put NOMBRE`.

Después del primer despliegue, agrega la dirección del sitio (por ejemplo `https://guapa-club.<tu-cuenta>.workers.dev`
o tu dominio) a las direcciones permitidas de inicio de sesión del backend, para que los enlaces de
confirmación y de recuperar contraseña regresen a tu sitio.
