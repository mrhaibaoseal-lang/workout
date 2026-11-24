/**
 * 練壯：端對端加密雲端備份。
 *
 * 伺服器只做三件事：收密文、給密文、列版本。
 * - 手機端在送出前就用 AES-256-GCM 加密（金鑰只在手機和使用者抄的恢復碼裡），這裡看不到明文，也沒有金鑰。
 * - 使用者 id = sha256(存取 token)；token 本身不存。
 * - 不記錄請求內容，也不 console.log 任何東西。
 *
 * API（都要 `Authorization: Bearer <token>`，token 是 43 字元的 base64url）：
 *   PUT  /v1/blob            body = 密文位元組（≤ 5 MB）→ { version, createdAt, size }
 *   GET  /v1/blob[?version=N] → 密文位元組（沒指定版本就是最新）；沒有備份回 404
 *   GET  /v1/blob/versions    → { versions: [{ version, createdAt, size }] }（最近 5 個，新的在前）
 */

export interface Env {
  DB: D1Database;
}

export const MAX_BLOB_BYTES = 5 * 1024 * 1024;
/** D1 單列上限 2 MB，所以切成小塊存 */
export const CHUNK_BYTES = 512 * 1024;
export const KEEP_VERSIONS = 5;
/** 每分鐘上限：每個使用者、每個 IP */
export const USER_PER_MINUTE = 30;
export const IP_PER_MINUTE = 60;

const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;

const BASE_HEADERS = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...BASE_HEADERS, "Content-Type": "application/json; charset=utf-8", ...extra },
  });
}

function fail(status: number, error: string, extra: Record<string, string> = {}): Response {
  return json({ error }, status, extra);
}

export function bearerToken(req: Request): string | null {
  const h = req.headers.get("Authorization") ?? "";
  const m = /^Bearer\s+(\S+)$/i.exec(h);
  if (!m) return null;
  return TOKEN_RE.test(m[1]) ? m[1] : null;
}

export async function userIdFor(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** 這一分鐘這個 key 已經用了幾次（含這次）。 */
async function hit(env: Env, key: string): Promise<number> {
  const bucket = Math.floor(Date.now() / 60_000);
  const row = await env.DB.prepare(
    "INSERT INTO rate (k, bucket, n) VALUES (?1, ?2, 1) ON CONFLICT (k, bucket) DO UPDATE SET n = n + 1 RETURNING n",
  )
    .bind(key, bucket)
    .first<{ n: number }>();
  return row?.n ?? 1;
}

async function cleanupRate(env: Env): Promise<void> {
  const bucket = Math.floor(Date.now() / 60_000);
  await env.DB.prepare("DELETE FROM rate WHERE bucket < ?1").bind(bucket - 10).run();
}

/** 讀請求內容，超過上限就停（不先整份讀進記憶體）。 */
export async function readLimited(req: Request, max: number): Promise<Uint8Array | null> {
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (declared > max) return null;
  if (!req.body) return new Uint8Array(0);
  const reader = req.body.getReader();
  const parts: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      return null;
    }
    parts.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.byteLength;
  }
  return out;
}

/** D1 讀 BLOB 可能給 ArrayBuffer 或數字陣列，統一成 Uint8Array。 */
export function toBytes(value: unknown): Uint8Array {
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  if (Array.isArray(value)) return Uint8Array.from(value as number[]);
  return new Uint8Array(0);
}

async function putBlob(env: Env, userId: string, body: Uint8Array): Promise<Response> {
  const cur = await env.DB.prepare("SELECT COALESCE(MAX(version), 0) AS v FROM versions WHERE user_id = ?1")
    .bind(userId)
    .first<{ v: number }>();
  const version = (cur?.v ?? 0) + 1;
  const createdAt = Date.now();
  const chunks = Math.max(1, Math.ceil(body.byteLength / CHUNK_BYTES));

  const stmts: D1PreparedStatement[] = [];
  for (let i = 0; i < chunks; i++) {
    const part = body.slice(i * CHUNK_BYTES, (i + 1) * CHUNK_BYTES);
    stmts.push(
      env.DB.prepare("INSERT INTO chunks (user_id, version, idx, data) VALUES (?1, ?2, ?3, ?4)").bind(
        userId,
        version,
        i,
        part.buffer,
      ),
    );
  }
  stmts.push(
    env.DB.prepare("INSERT INTO versions (user_id, version, created_at, size, chunks) VALUES (?1, ?2, ?3, ?4, ?5)").bind(
      userId,
      version,
      createdAt,
      body.byteLength,
      chunks,
    ),
  );
  // 只留最近 KEEP_VERSIONS 個
  stmts.push(
    env.DB.prepare("DELETE FROM chunks WHERE user_id = ?1 AND version <= ?2").bind(userId, version - KEEP_VERSIONS),
  );
  stmts.push(
    env.DB.prepare("DELETE FROM versions WHERE user_id = ?1 AND version <= ?2").bind(userId, version - KEEP_VERSIONS),
  );
  await env.DB.batch(stmts);
  return json({ version, createdAt, size: body.byteLength });
}

async function getBlob(env: Env, userId: string, wanted: number | null): Promise<Response> {
  const meta =
    wanted === null
      ? await env.DB.prepare(
          "SELECT version, created_at AS createdAt, size, chunks FROM versions WHERE user_id = ?1 ORDER BY version DESC LIMIT 1",
        )
          .bind(userId)
          .first<{ version: number; createdAt: number; size: number; chunks: number }>()
      : await env.DB.prepare(
          "SELECT version, created_at AS createdAt, size, chunks FROM versions WHERE user_id = ?1 AND version = ?2",
        )
          .bind(userId, wanted)
          .first<{ version: number; createdAt: number; size: number; chunks: number }>();
  if (!meta) return fail(404, "not_found");

  const rows = await env.DB.prepare("SELECT data FROM chunks WHERE user_id = ?1 AND version = ?2 ORDER BY idx")
    .bind(userId, meta.version)
    .all<{ data: unknown }>();
  const out = new Uint8Array(meta.size);
  let offset = 0;
  for (const row of rows.results ?? []) {
    const part = toBytes(row.data);
    out.set(part, offset);
    offset += part.byteLength;
  }
  if (offset !== meta.size) return fail(500, "corrupt");
  return new Response(out, {
    status: 200,
    headers: {
      ...BASE_HEADERS,
      "Content-Type": "application/octet-stream",
      "X-Version": String(meta.version),
      "X-Created-At": String(meta.createdAt),
    },
  });
}

async function listVersions(env: Env, userId: string): Promise<Response> {
  const rows = await env.DB.prepare(
    "SELECT version, created_at AS createdAt, size FROM versions WHERE user_id = ?1 ORDER BY version DESC LIMIT ?2",
  )
    .bind(userId, KEEP_VERSIONS)
    .all<{ version: number; createdAt: number; size: number }>();
  return json({ versions: rows.results ?? [] });
}

export async function handle(req: Request, env: Env, ctx: { waitUntil(p: Promise<unknown>): void }): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, "");
  if (path !== "/v1/blob" && path !== "/v1/blob/versions") return fail(404, "not_found");

  const allowed = path === "/v1/blob" ? ["GET", "PUT"] : ["GET"];
  if (!allowed.includes(req.method)) return fail(405, "method_not_allowed", { Allow: allowed.join(", ") });

  // 先擋 IP：連亂猜 token 的也算
  const ip = req.headers.get("CF-Connecting-IP") ?? "unknown";
  if ((await hit(env, `ip:${ip}`)) > IP_PER_MINUTE) return fail(429, "rate_limited", { "Retry-After": "60" });
  if (Math.random() < 0.02) ctx.waitUntil(cleanupRate(env));

  const token = bearerToken(req);
  if (!token) return fail(401, "unauthorized");
  const userId = await userIdFor(token);
  if ((await hit(env, `u:${userId}`)) > USER_PER_MINUTE) return fail(429, "rate_limited", { "Retry-After": "60" });

  if (path === "/v1/blob/versions") return listVersions(env, userId);

  if (req.method === "PUT") {
    const body = await readLimited(req, MAX_BLOB_BYTES);
    if (body === null) return fail(413, "too_large");
    if (body.byteLength === 0) return fail(400, "empty");
    return putBlob(env, userId, body);
  }

  const v = url.searchParams.get("version");
  if (v === null) return getBlob(env, userId, null);
  const n = Number(v);
  if (!Number.isInteger(n) || n < 1) return fail(400, "bad_version");
  return getBlob(env, userId, n);
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      return await handle(req, env, ctx);
    } catch {
      // 不把例外內容（可能含請求資料）寫進 log 或回給呼叫端
      return fail(500, "server_error");
    }
  },
} satisfies ExportedHandler<Env>;
