-- =====================================================================
-- KDirectory · tablas MySQL / MariaDB (Hostinger)
-- Normalmente NO hace falta: install.php las crea solo.
-- Úsalo solo si prefieres crearlas a mano en phpMyAdmin → Importar.
-- =====================================================================
CREATE TABLE IF NOT EXISTS k_rows (
  tbl         VARCHAR(20)  NOT NULL,
  id          VARCHAR(64)  NOT NULL,
  data        LONGTEXT     NOT NULL,
  division    VARCHAR(64)  NULL,
  deal_id     VARCHAR(64)  NULL,
  contact_id  VARCHAR(64)  NULL,
  company_id  VARCHAR(64)  NULL,
  filament_id VARCHAR(64)  NULL,
  changed_at  DATETIME(3)  NOT NULL,
  deleted     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (tbl, id),
  KEY k_changed (changed_at),
  KEY k_deal (tbl, deal_id),
  KEY k_contact (tbl, contact_id),
  KEY k_company (tbl, company_id),
  KEY k_filament (tbl, filament_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS k_users (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  email       VARCHAR(190) NOT NULL UNIQUE,
  pass_hash   VARCHAR(255) NOT NULL,
  fails       INT          NOT NULL DEFAULT 0,
  lock_until  DATETIME     NULL,
  reset_hash  CHAR(64)     NULL,
  reset_until DATETIME     NULL,
  last_login  DATETIME     NULL,
  created_at  DATETIME     NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS k_counters (
  name VARCHAR(40) PRIMARY KEY,
  val  INT NOT NULL DEFAULT 0
) ENGINE=InnoDB;
INSERT IGNORE INTO k_counters (name, val) VALUES ('deals', 0);

CREATE TABLE IF NOT EXISTS k_attempts (
  ip VARCHAR(64) NOT NULL,
  at DATETIME    NOT NULL,
  KEY k_ip (ip, at)
) ENGINE=InnoDB;
