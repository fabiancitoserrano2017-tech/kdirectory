<?php
/* =====================================================================
   KDirectory · API (PHP 8 + MySQL/MariaDB)
   Un solo punto de entrada. Sesiones con cookie HttpOnly, contraseñas con
   password_hash, permisos por persona iguales a los de la app.
   ===================================================================== */
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');
header('Referrer-Policy: same-origin');

$CFG = require __DIR__ . '/config.php';
$secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
session_name('kdsess');
session_set_cookie_params(['lifetime' => 60 * 60 * 24 * 30, 'path' => '/', 'secure' => $secure, 'httponly' => true, 'samesite' => 'Lax']);
ini_set('session.gc_maxlifetime', (string)(60 * 60 * 24 * 30));
session_start();

const TABLES = ['settings','team','products','companies','contacts','deals','items','payments','recurring','expenses','dividends','filaments','moves','jobs','activities','tasks','events','content','goals'];
const FIN = ['payments','expenses','recurring','dividends'];
const ROLES = ['master','founder','coo','cmo','cto'];

function out($d, int $code = 200): never { http_response_code($code); echo json_encode($d, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); exit; }
function fail(string $m, int $code = 400): never { out(['error' => $m], $code); }
function db(): PDO {
  static $p = null; global $CFG;
  if (!$p) {
    try {
      $p = new PDO("mysql:host={$CFG['db_host']};dbname={$CFG['db_name']};charset=utf8mb4", $CFG['db_user'], $CFG['db_pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false]);
      $p->exec("SET time_zone = '+00:00'");
    } catch (Throwable $e) { fail('No se pudo conectar a la base de datos. Revisa config.php.', 500); }
  }
  return $p;
}
function q(string $sql, array $a = []): PDOStatement { $s = db()->prepare($sql); $s->execute($a); return $s; }
function body(): array { static $b = null; if ($b === null) { $raw = file_get_contents('php://input') ?: ''; $b = $raw !== '' ? (json_decode($raw, true) ?? []) : []; } return $b; }
function installed(): bool { try { q("SELECT 1 FROM k_users LIMIT 1"); return true; } catch (Throwable $e) { return false; } }
function now3(): string { return (string)q("SELECT DATE_FORMAT(UTC_TIMESTAMP(3), '%Y-%m-%d %H:%i:%s.%f')")->fetchColumn(); }
function lower(?string $s): string { return mb_strtolower(trim((string)$s)); }

/* ---------- quién soy y qué puedo ---------- */
function me(): ?array {
  static $me = false;
  if ($me !== false) return $me;
  $me = null;
  if (empty($_SESSION['email'])) return null;
  $email = lower($_SESSION['email']);
  foreach (q("SELECT data FROM k_rows WHERE tbl='team' AND deleted=0")->fetchAll() as $r) {
    $t = json_decode($r['data'], true) ?: [];
    if (lower($t['email'] ?? '') === $email && ($t['active'] ?? true) !== false) {
      $acc = in_array($t['access'] ?? '', ROLES, true) ? $t['access'] : 'none';
      $me = ['email' => $email, 'name' => $t['name'] ?? $email, 'role' => $acc, 'team_id' => $t['id'] ?? null];
      return $me;
    }
  }
  $me = ['email' => $email, 'name' => $email, 'role' => 'none', 'team_id' => null];
  return $me;
}
function role(): string { $m = me(); return $m ? $m['role'] : 'none'; }
function can_admin(): bool { return in_array(role(), ['master','founder'], true); }
function can_code(): bool { return in_array(role(), ['master','founder','cto'], true); }
function can_bm(): bool { return in_array(role(), ['master','founder','coo','cmo'], true); }
function require_member(): void { if (!me()) fail('Inicia sesión', 401); if (role() === 'none') fail('Tu usuario no tiene acceso a KDirectory. Pide a Juan David que te dé acceso en Ajustes → Equipo.', 403); }
function deal_div(?string $dealId): ?string {
  static $cache = [];
  if (!$dealId) return null;
  if (!array_key_exists($dealId, $cache)) $cache[$dealId] = q("SELECT division FROM k_rows WHERE tbl='deals' AND id=? AND deleted=0", [$dealId])->fetchColumn() ?: null;
  return $cache[$dealId];
}
function div_ok(?string $div): bool { return ($div ?? '') !== 'code' || can_code(); }
function can_read(string $t, array $r, array $dealDivs): bool {
  $dd = isset($r['deal_id']) && $r['deal_id'] ? ($dealDivs[$r['deal_id']] ?? null) : null;
  return match ($t) {
    'payments' => can_bm() || $dd === 'code',
    'expenses' => can_bm() || ($r['division'] ?? null) === 'code' || $dd === 'code',
    'recurring', 'dividends' => can_bm(),
    default => true,
  };
}
function can_write(string $t, ?array $r): bool {
  if (!$r) return true;
  $dd = deal_div($r['deal_id'] ?? null);
  return match ($t) {
    'settings', 'team' => can_admin(),
    'products', 'deals' => div_ok($r['division'] ?? null),
    'items', 'jobs', 'activities', 'tasks' => div_ok($dd),
    'payments' => (can_bm() && div_ok($dd)) || (can_code() && $dd === 'code'),
    'expenses' => (can_bm() && div_ok($r['division'] ?? $dd)) || (can_code() && (($r['division'] ?? null) === 'code' || $dd === 'code')),
    'recurring' => can_bm(),
    'dividends' => can_admin(),
    default => true,
  };
}
function deny_msg(string $t): string {
  if ($t === 'settings' || $t === 'team') return 'Solo los founders cambian los ajustes y el equipo.';
  if (in_array($t, FIN, true) && !can_bm()) return 'Tu perfil no tiene acceso a BM.';
  return 'Kastor Code es solo lectura para ti: lo editan Iris y los founders.';
}

/* ---------- filas ---------- */
function get_row(string $t, string $id): ?array {
  $d = q("SELECT data FROM k_rows WHERE tbl=? AND id=? AND deleted=0", [$t, $id])->fetchColumn();
  return $d ? json_decode($d, true) : null;
}
function valid_id($id): bool { return is_string($id) && preg_match('/^[A-Za-z0-9_.\-]{1,64}$/', $id) === 1; }
function save_row(string $t, array $row, string $now): array {
  if (!in_array($t, TABLES, true)) fail('Tabla desconocida');
  if (!valid_id($row['id'] ?? null)) fail('Id inválido');
  $old = get_row($t, $row['id']);
  if (!can_write($t, $old) || !can_write($t, $row)) fail(deny_msg($t), 403);
  if ($t === 'team' && role() !== 'master') {
    $oa = $old['access'] ?? null; $na = $row['access'] ?? null;
    if (($oa ?: null) !== ($na ?: null) || ($old && lower($old['email'] ?? '') !== lower($row['email'] ?? '') && $oa)) fail('Solo el usuario maestro cambia accesos y correos con acceso.', 403);
  }
  if ($t === 'deals') {
    if ($old && isset($old['number'])) $row['number'] = $old['number'];
    elseif (empty($row['number'])) { q("UPDATE k_counters SET val=LAST_INSERT_ID(val+1) WHERE name='deals'"); $row['number'] = (int)db()->lastInsertId(); }
    else { $row['number'] = (int)$row['number']; q("UPDATE k_counters SET val=GREATEST(val,?) WHERE name='deals'", [$row['number']]); }
  }
  $json = json_encode($row, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  if (strlen($json) > 300000) fail('Registro demasiado grande');
  $s = fn($k) => isset($row[$k]) && is_string($row[$k]) && $row[$k] !== '' ? substr($row[$k], 0, 64) : null;
  q("INSERT INTO k_rows (tbl,id,data,division,deal_id,contact_id,company_id,filament_id,changed_at,deleted)
     VALUES (?,?,?,?,?,?,?,?,?,0)
     ON DUPLICATE KEY UPDATE data=VALUES(data),division=VALUES(division),deal_id=VALUES(deal_id),contact_id=VALUES(contact_id),
       company_id=VALUES(company_id),filament_id=VALUES(filament_id),changed_at=VALUES(changed_at),deleted=0",
    [$t, $row['id'], $json, $s('division'), $s('deal_id'), $s('contact_id'), $s('company_id'), $s('filament_id'), $now]);
  return $row;
}
function tomb(string $t, string $id, string $now): void { q("UPDATE k_rows SET deleted=1, data='{}', changed_at=? WHERE tbl=? AND id=?", [$now, $t, $id]); }
function tomb_where(string $t, string $col, string $val, string $now): void { q("UPDATE k_rows SET deleted=1, data='{}', changed_at=? WHERE tbl=? AND $col=? AND deleted=0", [$now, $t, $val]); }
function null_ref(string $t, string $col, string $val, string $now): void {
  foreach (q("SELECT id,data FROM k_rows WHERE tbl=? AND $col=? AND deleted=0", [$t, $val])->fetchAll() as $r) {
    $d = json_decode($r['data'], true) ?: []; $d[$col] = null;
    q("UPDATE k_rows SET data=?, $col=NULL, changed_at=? WHERE tbl=? AND id=?", [json_encode($d, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $now, $t, $r['id']]);
  }
}
function rows_payload(?string $since): array {
  $deals = []; foreach (q("SELECT id,division FROM k_rows WHERE tbl='deals' AND deleted=0")->fetchAll() as $d) $deals[$d['id']] = $d['division'];
  $sql = "SELECT tbl,id,data,deleted FROM k_rows" . ($since ? " WHERE changed_at > DATE_SUB(?, INTERVAL 3 SECOND)" : " WHERE deleted=0");
  $res = array_fill_keys(TABLES, []); $gone = [];
  foreach (q($sql, $since ? [$since] : [])->fetchAll() as $r) {
    if ((int)$r['deleted'] === 1) { $gone[] = [$r['tbl'], $r['id']]; continue; }
    $d = json_decode($r['data'], true); if (!$d) continue;
    if (!can_read($r['tbl'], $d, $deals)) continue;
    $res[$r['tbl']][] = $d;
  }
  return ['tables' => $res, 'deleted' => $gone];
}

/* ---------- correo ---------- */
function send_mail(string $to, string $subject, string $text): bool {
  global $CFG;
  $from = $CFG['mail_from'] ?? 'no-reply@localhost';
  $headers = "From: KDirectory <$from>\r\nReply-To: $from\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n";
  return @mail($to, '=?UTF-8?B?' . base64_encode($subject) . '?=', $text, $headers, '-f' . $from);
}

/* ---------- rutas ---------- */
$a = $_GET['a'] ?? '';
$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'POST' && ($_SERVER['HTTP_X_KD'] ?? '') !== '1') fail('Solicitud no permitida', 403); // anti-CSRF
if (!installed()) out(['installed' => false]);

switch ($a) {
  case 'me': {
    $m = me();
    out(['installed' => true, 'email' => $m['email'] ?? null, 'role' => $m['role'] ?? null, 'name' => $m['name'] ?? null]);
  }
  case 'login': {
    if ($method !== 'POST') fail('Método');
    $b = body(); $email = lower($b['email'] ?? ''); $pw = (string)($b['password'] ?? '');
    $ip = substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 64);
    $n = (int)q("SELECT COUNT(*) FROM k_attempts WHERE ip=? AND at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE)", [$ip])->fetchColumn();
    if ($n >= 20) fail('Demasiados intentos. Espera 15 minutos.', 429);
    $u = q("SELECT * FROM k_users WHERE email=?", [$email])->fetch();
    if ($u && $u['lock_until'] && strtotime($u['lock_until'] . ' UTC') > time()) fail('Usuario bloqueado por intentos fallidos. Espera 10 minutos.', 429);
    if (!$u || !password_verify($pw, $u['pass_hash'])) {
      q("INSERT INTO k_attempts (ip,at) VALUES (?,UTC_TIMESTAMP())", [$ip]);
      if ($u) q("UPDATE k_users SET fails=fails+1, lock_until=IF(fails+1>=5, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE), NULL) WHERE id=?", [$u['id']]);
      fail('Correo o contraseña incorrectos.', 401);
    }
    q("UPDATE k_users SET fails=0, lock_until=NULL, last_login=UTC_TIMESTAMP() WHERE id=?", [$u['id']]);
    if (password_needs_rehash($u['pass_hash'], PASSWORD_DEFAULT)) q("UPDATE k_users SET pass_hash=? WHERE id=?", [password_hash($pw, PASSWORD_DEFAULT), $u['id']]);
    session_regenerate_id(true);
    $_SESSION['email'] = $email;
    $m = me();
    out(['ok' => true, 'email' => $email, 'role' => $m['role'], 'name' => $m['name']]);
  }
  case 'logout': { $_SESSION = []; session_destroy(); out(['ok' => true]); }
  case 'load': {
    require_member(); $now = now3();
    $p = rows_payload(null); out(['tables' => $p['tables'], 'cursor' => $now, 'me' => me()]);
  }
  case 'changes': {
    require_member(); $now = now3(); $since = (string)($_GET['since'] ?? '');
    if (!preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d+)?$/', $since)) fail('Cursor inválido');
    $p = rows_payload($since); out(['tables' => $p['tables'], 'deleted' => $p['deleted'], 'cursor' => $now, 'role' => role()]);
  }
  case 'upsert': {
    if ($method !== 'POST') fail('Método'); require_member();
    $b = body(); $t = (string)($b['t'] ?? ''); $row = $b['row'] ?? null; if (!is_array($row)) fail('Fila inválida');
    $now = now3(); db()->beginTransaction();
    try { $r = save_row($t, $row, $now); db()->commit(); } catch (Throwable $e) { if (db()->inTransaction()) db()->rollBack(); throw $e; }
    out(['row' => $r]);
  }
  case 'upsert_many': {
    if ($method !== 'POST') fail('Método'); require_member();
    $b = body(); $t = (string)($b['t'] ?? ''); $rows = $b['rows'] ?? null;
    if (!is_array($rows) || count($rows) > 2000) fail('Filas inválidas');
    $now = now3(); db()->beginTransaction();
    try { $out = []; foreach ($rows as $row) { if (!is_array($row)) continue; $out[] = save_row($t, $row, $now); } db()->commit(); }
    catch (Throwable $e) { if (db()->inTransaction()) db()->rollBack(); throw $e; }
    out(['rows' => $out]);
  }
  case 'delete': {
    if ($method !== 'POST') fail('Método'); require_member();
    $b = body(); $t = (string)($b['t'] ?? ''); $id = $b['id'] ?? null;
    if (!in_array($t, TABLES, true) || !valid_id($id)) fail('Datos inválidos');
    $old = get_row($t, $id); if (!$old) out(['ok' => true]);
    if (!can_write($t, $old)) fail(deny_msg($t), 403);
    $now = now3(); db()->beginTransaction();
    try {
      tomb($t, $id, $now);
      if ($t === 'deals') { foreach (['items','activities','tasks'] as $c) tomb_where($c, 'deal_id', $id, $now); foreach (['payments','jobs','expenses'] as $c) null_ref($c, 'deal_id', $id, $now); }
      if ($t === 'filaments') tomb_where('moves', 'filament_id', $id, $now);
      if ($t === 'contacts') { foreach (['activities','tasks'] as $c) tomb_where($c, 'contact_id', $id, $now); foreach (['deals'] as $c) null_ref($c, 'contact_id', $id, $now); }
      if ($t === 'companies') { tomb_where('activities', 'company_id', $id, $now); foreach (['deals','contacts'] as $c) null_ref($c, 'company_id', $id, $now); }
      db()->commit();
    } catch (Throwable $e) { if (db()->inTransaction()) db()->rollBack(); throw $e; }
    out(['ok' => true]);
  }
  case 'upload': {
    if ($method !== 'POST') fail('Método'); require_member();
    if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) fail('No llegó la imagen');
    if ($_FILES['file']['size'] > 6 * 1024 * 1024) fail('La imagen pesa más de 6 MB');
    $info = @getimagesize($_FILES['file']['tmp_name']);
    $ext = match ($info['mime'] ?? '') { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', default => null };
    if (!$ext) fail('Solo imágenes JPG, PNG o WEBP');
    $dir = __DIR__ . '/uploads/productos'; if (!is_dir($dir)) mkdir($dir, 0755, true);
    $name = bin2hex(random_bytes(10)) . '.' . $ext;
    if (!move_uploaded_file($_FILES['file']['tmp_name'], "$dir/$name")) fail('No se pudo guardar la imagen', 500);
    out(['url' => 'uploads/productos/' . $name]);
  }
  case 'change_password': {
    if ($method !== 'POST') fail('Método'); if (!me()) fail('Inicia sesión', 401);
    $b = body(); $u = q("SELECT * FROM k_users WHERE email=?", [me()['email']])->fetch();
    if (!$u || !password_verify((string)($b['old'] ?? ''), $u['pass_hash'])) fail('La contraseña actual no es correcta');
    $new = (string)($b['new'] ?? ''); if (mb_strlen($new) < 8) fail('La nueva contraseña debe tener al menos 8 caracteres');
    q("UPDATE k_users SET pass_hash=? WHERE id=?", [password_hash($new, PASSWORD_DEFAULT), $u['id']]);
    out(['ok' => true]);
  }
  case 'set_password': { // founders: crear o cambiar el acceso de una persona del equipo
    if ($method !== 'POST') fail('Método'); require_member(); if (!can_admin()) fail('Solo los founders dan accesos.', 403);
    $b = body(); $email = lower($b['email'] ?? ''); $pw = (string)($b['password'] ?? '');
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) fail('Correo inválido');
    if (mb_strlen($pw) < 8) fail('La contraseña debe tener al menos 8 caracteres');
    $inTeam = false; foreach (q("SELECT data FROM k_rows WHERE tbl='team' AND deleted=0")->fetchAll() as $r) { $t = json_decode($r['data'], true) ?: []; if (lower($t['email'] ?? '') === $email) $inTeam = true; }
    if (!$inTeam) fail('Primero guarda ese correo en la ficha de la persona (Ajustes → Equipo).');
    q("INSERT INTO k_users (email,pass_hash,created_at) VALUES (?,?,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE pass_hash=VALUES(pass_hash), fails=0, lock_until=NULL", [$email, password_hash($pw, PASSWORD_DEFAULT)]);
    out(['ok' => true]);
  }
  case 'users': { require_member(); if (!can_admin()) fail('Solo founders', 403); out(['users' => q("SELECT email,last_login FROM k_users ORDER BY email")->fetchAll()]); }
  case 'reset_request': {
    if ($method !== 'POST') fail('Método');
    $email = lower(body()['email'] ?? '');
    $u = q("SELECT id FROM k_users WHERE email=?", [$email])->fetch();
    if ($u) {
      $tok = bin2hex(random_bytes(24));
      q("UPDATE k_users SET reset_hash=?, reset_until=DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR) WHERE id=?", [hash('sha256', $tok), $u['id']]);
      $link = rtrim($CFG['app_url'], '/') . '/?reset=' . $tok;
      send_mail($email, 'KDirectory · cambiar contraseña', "Hola,\n\nPara crear una contraseña nueva entra aquí (vale 1 hora):\n$link\n\nSi no lo pediste, ignora este correo.\n\nKASTOR Directory");
    }
    out(['ok' => true]);
  }
  case 'reset': {
    if ($method !== 'POST') fail('Método');
    $b = body(); $tok = (string)($b['token'] ?? ''); $pw = (string)($b['password'] ?? '');
    if (mb_strlen($pw) < 8) fail('La contraseña debe tener al menos 8 caracteres');
    $u = q("SELECT id,email FROM k_users WHERE reset_hash=? AND reset_until > UTC_TIMESTAMP()", [hash('sha256', $tok)])->fetch();
    if (!$u) fail('El enlace venció o ya se usó. Pide otro.');
    q("UPDATE k_users SET pass_hash=?, reset_hash=NULL, reset_until=NULL, fails=0, lock_until=NULL WHERE id=?", [password_hash($pw, PASSWORD_DEFAULT), $u['id']]);
    out(['ok' => true]);
  }
  default: fail('Acción desconocida', 404);
}
