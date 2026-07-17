# Bóveda de claves

Login con cuentas creadas solo por vos (sin registro público) + un pool de
claves con vencimiento que cualquier usuario logueado puede "sacar" una vez.
Al sacarla, se marca como usada y desaparece del pool.

## Archivos

- `index.html` — pantalla de login
- `dashboard.html` — pantalla donde el usuario saca su clave
- `schema.sql` — todo lo que hay que correr en Supabase (tabla + seguridad + función)
- `config.js` — acá van tus credenciales de Supabase

## Paso 1 — Crear el proyecto en Supabase

1. Entrá a [supabase.com](https://supabase.com) y creá una cuenta / proyecto nuevo (el plan gratuito alcanza para empezar).
2. Cuando el proyecto esté listo, andá a **SQL Editor** (menú lateral).
3. Abrí el archivo `schema.sql` de esta carpeta, copiá todo su contenido, pegalo en el editor y tocá **Run**.
   - Esto crea la tabla `keys`, las reglas de seguridad, y la función `claim_key()` que reparte las claves sin que dos personas se lleven la misma por accidente.
   - Al final del archivo hay 3 claves de ejemplo para probar. Borralas cuando cargues las tuyas reales.

## Paso 2 — Desactivar el registro público

Por defecto Supabase permite que cualquiera se registre solo. Para que **solo vos** puedas crear usuarios:

1. Andá a **Authentication → Providers → Email**.
2. Desactivá la opción **"Allow new users to sign up"**.

## Paso 3 — Crear usuarios manualmente

1. Andá a **Authentication → Users → Add user**.
2. Cargá el email y una contraseña para cada persona que quieras que tenga acceso.
3. Esa persona ya puede loguearse en `index.html` con esos datos — no necesita registrarse.

## Paso 4 — Conectar tu frontend

1. Andá a **Project Settings → API**.
2. Copiá el **Project URL** y la **anon public key**.
3. Pegalos en `config.js`:

```js
const SUPABASE_URL = "https://tu-proyecto.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

## Paso 5 — Cargar tus claves reales

En Supabase, andá a **Table Editor → keys** y agregá filas con:
- `code`: la clave en sí (ej. `AB12-CD34-EF56`)
- `expires_at`: fecha de vencimiento (ej. `2026-12-31 23:59:00+00`)
- Dejá `status` como `available`

También podés insertar muchas de una con SQL, por ejemplo:

```sql
insert into public.keys (code, expires_at) values
  ('XYZ1-XYZ2-XYZ3', now() + interval '15 days'),
  ('XYZ4-XYZ5-XYZ6', now() + interval '60 days');
```

## Paso 6 — Publicar el sitio

Estos son archivos estáticos (HTML/CSS/JS puro), así que podés subirlos tal cual a:
- **Netlify** o **Vercel** (arrastrar y soltar la carpeta)
- **GitHub Pages**
- Cualquier hosting que sirva archivos estáticos

No hace falta ningún servidor propio: toda la lógica de login y base de datos la maneja Supabase directamente desde el navegador del usuario, protegida por las reglas de seguridad (RLS) que ya vienen en `schema.sql`.

## Cómo funciona por dentro

- El login (`index.html`) usa `supabase.auth.signInWithPassword()` — no hay registro, solo entrada con cuentas que vos creaste.
- El dashboard (`dashboard.html`) llama a la función `claim_key()` en la base de datos. Esa función:
  1. Busca la clave disponible más antigua que no haya vencido.
  2. La bloquea (`for update skip locked`) para que si dos usuarios aprietan el botón al mismo tiempo, no se lleven la misma clave.
  3. La marca como `claimed` y se la devuelve al usuario.
- Las políticas de seguridad (RLS) impiden que alguien lea o modifique la tabla directamente desde las herramientas del navegador — todo pasa por la función controlada.
