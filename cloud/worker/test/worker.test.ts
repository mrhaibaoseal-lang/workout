// 用 Node 內建的 SQLite 假裝 D1，跑一遍 Worker 的邏輯。
// 執行：node --test test/worker.test.ts   （Node 22.6 以上，加 --experimental-strip-types；Node 24 不用加）
import { test } from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { handle, IP_PER_MINUTE, KEEP_VERSIONS, MAX_BLOB_BYTES, USER_PER_MINUTE } from "../src/index.ts";

function fakeD1() {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../migrations/0001_init.sql", import.meta.url), "utf8"));
  const norm = (v: unknown) => (v instanceof ArrayBuffer ? new Uint8Array(v) : v);
  const make = (sql: string, args: unknown[] = []) => ({
    bind: (...a: unknown[]) => make(sql, a.map(norm)),
    first: async () => (db.prepare(sql).get(...(args as any[])) as any) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...(args as any[])) as any[] }),
    run: async () => db.prepare(sql).run(...(args as any[])),
    _run: () => db.prepare(sql).run(...(args as any[])),
  });
  return {
    prepare: (sql: string) => make(sql),
    batch: async (stmts: any[]) => {
      db.exec("BEGIN");
      try {
        for (const s of stmts) s._run();
        db.exec("COMMIT");
      } catch (e) {
        db.exec("ROLLBACK");
        throw e;
      }
      return [];
    },
    raw: db,
  } as any;
}

const ctx = { waitUntil() {} };
const token = (c: string) => c.repeat(43);
const req = (method: string, path: string, t?: string, body?: Uint8Array, ip = "1.1.1.1") =>
  new Request("https://sync.example" + path, {
    method,
    headers: { ...(t ? { Authorization: `Bearer ${t}` } : {}), "CF-Connecting-IP": ip },
    body: body as any,
  });

function bytes(n: number, seed = 7): Uint8Array {
  const out = new Uint8Array(n);
  for (let i = 0; i < n; i++) out[i] = (i * 31 + seed) & 255;
  return out;
}

test("沒帶 token、token 格式不對 → 401", async () => {
  const env = { DB: fakeD1() };
  assert.equal((await handle(req("GET", "/v1/blob"), env, ctx)).status, 401);
  assert.equal((await handle(req("GET", "/v1/blob", "short"), env, ctx)).status, 401);
});

test("上傳再下載：位元組完全一樣，也跨過多個分塊", async () => {
  const env = { DB: fakeD1() };
  const data = bytes(1_300_000);
  const put = await handle(req("PUT", "/v1/blob", token("a"), data), env, ctx);
  assert.equal(put.status, 200);
  const info = (await put.json()) as { version: number; size: number };
  assert.equal(info.version, 1);
  assert.equal(info.size, data.length);
  const got = await handle(req("GET", "/v1/blob", token("a")), env, ctx);
  assert.equal(got.status, 200);
  assert.equal(got.headers.get("X-Version"), "1");
  assert.deepEqual(new Uint8Array(await got.arrayBuffer()), data);
  assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS c FROM chunks").get().c, 3);
});

test("伺服器只存 token 的雜湊，資料庫裡找不到 token", async () => {
  const env = { DB: fakeD1() };
  await handle(req("PUT", "/v1/blob", token("b"), bytes(100)), env, ctx);
  const ids = env.DB.raw.prepare("SELECT user_id FROM versions").all() as { user_id: string }[];
  assert.equal(ids.length, 1);
  assert.equal(ids[0].user_id.length, 64);
  assert.notEqual(ids[0].user_id, token("b"));
});

test("只留最近 5 個版本，舊的連分塊一起刪", async () => {
  const env = { DB: fakeD1() };
  for (let i = 1; i <= 7; i++) {
    const r = await handle(req("PUT", "/v1/blob", token("c"), bytes(50 + i, i), `9.9.9.${i}`), env, ctx);
    assert.equal(r.status, 200);
  }
  const list = (await (await handle(req("GET", "/v1/blob/versions", token("c")), env, ctx)).json()) as {
    versions: { version: number; size: number }[];
  };
  assert.deepEqual(list.versions.map((v) => v.version), [7, 6, 5, 4, 3]);
  assert.equal(list.versions.length, KEEP_VERSIONS);
  assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS c FROM chunks").get().c, 5);
  assert.equal((await handle(req("GET", "/v1/blob?version=2", token("c")), env, ctx)).status, 404);
  const v4 = await handle(req("GET", "/v1/blob?version=4", token("c")), env, ctx);
  assert.deepEqual(new Uint8Array(await v4.arrayBuffer()), bytes(54, 4));
});

test("別人的 token 讀不到，也沒有備份的人回 404", async () => {
  const env = { DB: fakeD1() };
  await handle(req("PUT", "/v1/blob", token("d"), bytes(10)), env, ctx);
  assert.equal((await handle(req("GET", "/v1/blob", token("e")), env, ctx)).status, 404);
});

test("超過 5 MB → 413；空內容 → 400", async () => {
  const env = { DB: fakeD1() };
  assert.equal((await handle(req("PUT", "/v1/blob", token("f"), bytes(MAX_BLOB_BYTES + 1)), env, ctx)).status, 413);
  assert.equal((await handle(req("PUT", "/v1/blob", token("f"), new Uint8Array(0)), env, ctx)).status, 400);
  assert.equal((await handle(req("PUT", "/v1/blob", token("f"), bytes(MAX_BLOB_BYTES)), env, ctx)).status, 200);
});

test("頻率限制：同一個 token 一分鐘超過上限 → 429", async () => {
  const env = { DB: fakeD1() };
  let last = 200;
  for (let i = 0; i <= USER_PER_MINUTE; i++) {
    last = (await handle(req("GET", "/v1/blob/versions", token("g"), undefined, `8.8.${i}.1`), env, ctx)).status;
  }
  assert.equal(last, 429);
});

test("頻率限制：同一個 IP 亂猜 token → 429", async () => {
  const env = { DB: fakeD1() };
  let last = 200;
  for (let i = 0; i <= IP_PER_MINUTE; i++) {
    last = (await handle(req("GET", "/v1/blob", String.fromCharCode(97 + (i % 26)).repeat(43), undefined, "7.7.7.7"), env, ctx)).status;
  }
  assert.equal(last, 429);
});

test("不存在的路徑 404、不允許的方法 405", async () => {
  const env = { DB: fakeD1() };
  assert.equal((await handle(req("GET", "/"), env, ctx)).status, 404);
  assert.equal((await handle(req("DELETE", "/v1/blob", token("h")), env, ctx)).status, 405);
  assert.equal((await handle(req("PUT", "/v1/blob/versions", token("h")), env, ctx)).status, 405);
});
