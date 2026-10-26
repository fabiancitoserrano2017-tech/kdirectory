# Subir KDirectory a Hostinger · paso a paso

Todo queda en tu hosting: la app, la base de datos MySQL, los usuarios y las fotos. Ya no se usa Supabase.
Tiempo estimado: 20–30 min.

## 0. Lo que necesitas
- `subir-a-hostinger.zip`: index.html, api.php, install.php, config.php, kdirectory-mysql.sql, .htaccess, uploads/ y fotos/
- `CATALOGO_MAESTRO.xlsx`
- El correo de cada persona: Juan David, Fabián, Natalia, Yohana, Iris

## 1. Crear la base de datos
1. hPanel → **Bases de datos → Administración (Management)**.
2. En *Crear nueva base de datos MySQL*:
   - Nombre de la base: `kdirectory`
   - Usuario: `kdirectory`
   - Contraseña: genera una fuerte y **cópiala**.
   - **Crear**.
3. Abajo, en la lista, anota los nombres **completos**; Hostinger les pone un prefijo, por ejemplo `u123456789_kdirectory`.
   No hace falta entrar a phpMyAdmin: las tablas se crean solas en el paso 4.

## 2. Subdominio y SSL
1. hPanel → **Dominios → Subdominios** → crea `central` para `kastor.es` (carpeta `public_html/central`).
2. hPanel → **Seguridad → SSL** → instala el certificado para `central.kastor.es`. Puede tardar unos minutos.

## 3. Subir los archivos
1. hPanel → **Archivos → Administrador de archivos** → entra a `public_html/central`.
2. **Subir** → `subir-a-hostinger.zip` → clic derecho → **Extraer** aquí mismo → borra el zip.
   Si no ves `.htaccess`, activa *Mostrar archivos ocultos*.
3. Clic derecho en **`config.php` → Editar**. Llena tus datos y guarda:
```php
'db_host'   => 'localhost',
'db_name'   => 'u123456789_kdirectory',   // nombre completo de la base
'db_user'   => 'u123456789_kdirectory',   // usuario completo
'db_pass'   => 'la contraseña del paso 1',
'app_url'   => 'https://central.kastor.es',
'mail_from' => 'no-reply@kastor.es',
```

## 4. Instalar (una sola vez)
1. Abre `https://central.kastor.es/install.php`.
2. Si dice *Conexión correcta*, pon tu nombre, correo y contraseña. Ese usuario es el **maestro** (Juan David). Luego toca **Instalar**.
   Si dice *No conecta*, revisa `config.php`: casi siempre es el prefijo `u…_` o la contraseña.
3. **Borra `install.php`** en el Administrador de archivos. Si alguien lo abre después, ya no hace nada, pero es mejor que no esté.

## 5. Primer ingreso (Juan David)
1. Entra a `https://central.kastor.es` con tu correo y contraseña.
2. Elige **Empezar con la base de KASTOR**. Carga el equipo (los 5 con su cargo y acceso), el calendario comercial y las tareas. Tu usuario queda unido a "Juan David", sin duplicarse.
3. **Taller → Catálogo → Actualizar desde el Maestro** → sube `CATALOGO_MAESTRO.xlsx` → *Importar*.
4. **Equipo → Metas:** pon la meta del mes por línea.

## 6. Dar acceso al equipo
Para cada persona: **Ajustes → Equipo** → toca su fila.
1. Pon su **correo** y revisa su **acceso** → *Guardar*.
2. Vuelve a abrir su ficha → **Dar acceso / cambiar contraseña**. La app propone una contraseña y la **copia** junto con el link y el usuario.
3. Pégasela por WhatsApp. Al entrar, la cambia en su menú (su nombre abajo a la izquierda) → **Cambiar mi contraseña**.

En *Ajustes → Equipo → Usuarios con contraseña* ves quién ya tiene acceso y su último ingreso.

## 7. Correo para "¿Olvidaste tu contraseña?" (recomendado)
hPanel → **Correos** → crea `no-reply@kastor.es`. Debe ser el mismo de `mail_from` en `config.php`.
Sin ese correo, el enlace puede no llegar o caer en spam. Igual siempre puedes darle una contraseña nueva a cualquiera desde Ajustes → Equipo.

## 8. ¿Tenías datos en Supabase?
1. En tu PC abre `version-supabase.html` (la versión anterior conectada a Supabase).
2. Ingresa → **Ajustes → Importar y respaldo → Descargar respaldo .json**.
3. En KDirectory nuevo: **Ajustes → Importar y respaldo → Restaurar respaldo v2** → elige ese archivo.
   Trae pedidos, clientes, cobros, gastos, etc., con sus números.
   Las fotos que estaban en Supabase siguen mostrándose mientras ese proyecto exista. Las nuevas se guardan en `uploads/` de tu hosting.
Si no había nada importante, sáltate este paso.

## 9. Comprobar
- [ ] Juan David ve Ajustes; Natalia y Yohana **no**.
- [ ] Iris ve el **Panel CTO** en Líneas → Code y **no** ve BM.
- [ ] Yohana ve el **Panel CMO** en Líneas → Design.
- [ ] Natalia y Yohana ven Code con la etiqueta "lectura".
- [ ] Una venta rápida aparece en otra computadora en menos de 15 s, sin recargar. Bórrala después.
- [ ] Subir una foto a un producto funciona (queda en `uploads/productos/`).
- [ ] `https://central.kastor.es/config.php` muestra **403 / Prohibido** (bien protegido).

## Mantenimiento
- **Actualizar la app:** reemplaza solo `index.html` (y `api.php` si te mando uno nuevo). **Nunca** reemplaces `config.php`.
- **Respaldo:** hPanel → **Archivos → Copias de seguridad** respalda archivos y base de datos automáticamente (plan Business). Además, una vez al mes: Ajustes → Importar y respaldo → *Descargar respaldo .json*.
- **Persona que sale:** en Ajustes → Equipo desactívala o quítale el acceso. Deja de entrar al instante, aunque conozca su contraseña.
- **Ver la base:** hPanel → Bases de datos → **phpMyAdmin**. La tabla `k_rows` guarda todo, `k_users` los usuarios (contraseñas cifradas). No hace falta tocarla.
