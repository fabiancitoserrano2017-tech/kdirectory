# KDirectory (antes KASTOR Central) · v3

La app es `index.html` y el servidor `api.php` (PHP + MySQL de Hostinger). Logo en `logo/`. Todo vive en tu hosting: datos, usuarios y fotos. Pasos de instalación: **GUIA_SUBIR_KDIRECTORY.md**.

## Qué cambió respecto a la v2
- **Menú corto:** Inicio · Líneas (Design, Code, Tech) · Ventas · Taller · BM · Equipo. Cada área tiene sus pestañas arriba. Ajustes queda abajo en la barra lateral.
- **Venta rápida:** cliente + productos + cobro + entrega + cola de impresión en **un solo formulario**. El pedido detallado (cotización) sigue existiendo en Ventas → Pedidos.
- **Inicio = "Para hacer hoy":** pedidos sin seguimiento, saldos por cobrar, entregas atrasadas, tareas vencidas y filamento bajo, con un toque para resolver cada uno.
- **Divisiones Design / Code / Tech** (Lab y Works pasan a Tech). Prefijos de catálogo: DS- · TCH- · CD-.
- **Celular:** barra inferior con las 5 áreas, botón ＋ flotante, formularios tipo hoja, pedidos por etapa.
- **Ayuda (?)** en cada pantalla en lugar de Kas flotando sobre el contenido. Textos sin jerga.
- **Catálogo Maestro integrado:** misma estructura que el Sheet (Identificación · Producción · Costos · Archivos · Personalización), fotos de cada producto, links a MakerWorld y a la carpeta de Drive, colores disponibles y rentabilidad (costo, margen y ganancia por hora de impresora) con la misma fórmula del Sheet.
- **Líneas de negocio:** un apartado por línea con su color — Design naranja (por producto), Code verde (por proyecto), Tech navy (por encargo) — con cobrado, en curso, por cobrar, ticket, meta y lo que más se vende.
- **BM (Business Management)** reemplaza a "Dinero": Cobros, Gastos y Resultados. *Socios y caja* se eliminó.
- **Barra lateral blanca** (o casi negra en modo oscuro); sin azul en la interfaz.
- La versión anterior quedó como `version-v2.html` (por si hay que volver).

## Equipo y accesos
| Persona | Cargo | Ve | Edita |
|---|---|---|---|
| Juan David | Founder · usuario maestro | Todo | Todo + Ajustes + accesos |
| Fabián | Founder | Todo | Todo + Ajustes |
| Natalia | COO (accionista 20%) | Todo | Todo menos Kastor Code (lectura) |
| Yohana | CMO | Todo + **Panel CMO** en Design | Todo menos Kastor Code (lectura) |
| Iris Arteaga | CTO | Todo menos BM + **Panel CTO** en Code | Kastor Code y lo general |

Los paneles CMO y CTO solo le aparecen a esa persona. Los permisos los aplica el **servidor** (`api.php`), no solo la pantalla: Iris no recibe datos de BM y nadie fuera de Juan David cambia accesos.
En modo demo, toca tu nombre abajo a la izquierda → *Ver como…* para probar la vista de cada persona.

## Catálogo Maestro
- **Primera carga:** Taller → Catálogo → *Actualizar desde el Maestro* y sube el Excel (`CATALOGO_MAESTRO.xlsx`, hojas DESIGN y TECH). También está *Ajustes → Importar y respaldo → Cargar copia incluida* (74 productos, versión del 26-oct-2026).
- **Para actualizar:** edita el Sheet como siempre, descárgalo como .xlsx y vuelve a subirlo. Actualiza por código (DS-/TCH-/CD-); lo que no está en el Sheet (fotos subidas en la app, notas) se conserva.
- **Fotos:** la carpeta `fotos/` trae 49 fotos sacadas del Drive (una por producto, nombre = código). Si un producto nuevo no tiene foto en `fotos/`, súbela desde su ficha (botón *Subir foto*): se guarda en `uploads/productos/` del hosting.
- **Colores:** en el Sheet, la celda pintada sin X = color disponible; la X tacha el color. Orden de columnas: Negro, Rojo, Naranja, Amarillo, Verde, Azul, Rosa, Blanco, Morado, Café.
- **Costo** = peso × 0,16 + horas × 1,5 + insumos + diseño × 21 ÷ 15 + post-procesado × 21 (por unidad). Se ajusta en Ajustes → Parámetros.

## Instalación y archivos
Ver **GUIA_SUBIR_KDIRECTORY.md**. Resumen: crear base MySQL en hPanel → subir el zip → llenar `config.php` → abrir `install.php` (crea tablas y usuario maestro) → borrar `install.php`.

| Archivo | Para qué |
|---|---|
| `index.html` | La app |
| `api.php` | Servidor: sesiones, permisos, guardado, fotos, contraseñas |
| `config.php` | Datos de la base MySQL (protegido, no se descarga) |
| `install.php` | Instalación inicial; se borra después |
| `kdirectory-mysql.sql` | Tablas (install.php lo usa solo) |
| `uploads/` | Fotos subidas desde la app (no ejecuta código) |
| `fotos/` | 49 fotos del Catálogo Maestro |
| `version-supabase.html` | Versión anterior con Supabase, solo para sacar un respaldo |
| `supabase-*.sql` | Ya no se usan |

Seguridad: contraseñas cifradas (bcrypt), sesión en cookie HttpOnly/Secure, bloqueo tras 5 intentos fallidos, protección CSRF y permisos por persona en el servidor. Los cambios de un compañero llegan solos cada 15 s.

## Modo demo
`index.html?demo` abre datos de ejemplo guardados solo en el navegador. Sirve para probar sin tocar la base real.

## Mapa
| Área | Pestañas |
|---|---|
| Inicio | Para hacer hoy, pedidos en curso, próximas entregas, cobrado vs gastado |
| Ventas | Pedidos (tablero/lista) · Clientes · Empresas |
| Taller | Impresión (cola de la A1) · Catálogo · Filamento |
| BM | Cobros · Gastos (y recurrentes) · Resultados |
| Equipo | Tareas · Calendario y contenido · Metas |
| Ajustes | Parámetros de costos · Equipo · Mensajes de WhatsApp · Importar y respaldo |

Atajos: **Ctrl K** busca cualquier cosa; la campana junta los avisos.
