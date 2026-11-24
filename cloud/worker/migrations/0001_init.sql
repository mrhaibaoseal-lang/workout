-- 練壯雲端備份：伺服器只存密文。user_id = sha256(存取 token) 的十六進位，token 本身不存。
-- D1 單列上限 2 MB，所以一份備份（最大 5 MB）切成 ≤ 512 KB 的小塊存。

CREATE TABLE IF NOT EXISTS versions (
  user_id    TEXT    NOT NULL,
  version    INTEGER NOT NULL,   -- 每個使用者從 1 開始遞增
  created_at INTEGER NOT NULL,   -- 毫秒
  size       INTEGER NOT NULL,   -- 密文總位元組
  chunks     INTEGER NOT NULL,
  PRIMARY KEY (user_id, version)
);

CREATE TABLE IF NOT EXISTS chunks (
  user_id TEXT    NOT NULL,
  version INTEGER NOT NULL,
  idx     INTEGER NOT NULL,
  data    BLOB    NOT NULL,
  PRIMARY KEY (user_id, version, idx)
);

-- 簡單的頻率限制：每個 key（使用者或 IP）每分鐘一列
CREATE TABLE IF NOT EXISTS rate (
  k      TEXT    NOT NULL,
  bucket INTEGER NOT NULL,       -- 分鐘（unix 分鐘數）
  n      INTEGER NOT NULL,
  PRIMARY KEY (k, bucket)
);
