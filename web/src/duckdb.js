import * as duckdb from "@duckdb/duckdb-wasm";

let db = null;
let conn = null;

export async function initDuckDB() {
  if (conn) {
    return conn;
  }

  const JSDELIVR_BUNDLES = duckdb.getJsDelivrBundles();
  const bundle = await duckdb.selectBundle(JSDELIVR_BUNDLES);

  const workerUrl = URL.createObjectURL(
    new Blob([`importScripts("${bundle.mainWorker}");`], {
      type: "application/javascript",
    })
  );

  const worker = new Worker(workerUrl);
  URL.revokeObjectURL(workerUrl);

  db = new duckdb.AsyncDuckDB(new duckdb.ConsoleLogger(), worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);

  await db.open({
    filesystem: {
      allowFullHTTPReads: true,
      reliableHeadRequests: true,
      forceFullHTTPReads: false,
    },
  });

  conn = await db.connect();
  
console.log("Creating player_game view...");

try {
  await conn.query(`
    CREATE OR REPLACE VIEW player_game AS
    SELECT * FROM read_parquet('http://localhost:5173/data/player_game_stats.parquet')
  `);

  console.log("View created");

  const tables = await conn.query("SHOW TABLES");
  console.log("Tables:", tables.toArray());

} catch (err) {
  console.error("View creation failed:", err);
}

  return conn;
}

export async function runQuery(sql) {
  if (!conn) {
    await initDuckDB();
  }

  const result = await conn.query(sql);
  return result.toArray().map((row) => row.toJSON());
}
