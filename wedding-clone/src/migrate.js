const fs = require("fs");
const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const { pool } = require("./db");

async function run() {
  const file = path.resolve(__dirname, "..", "db", "schema_simple.sql");
  const sql = fs.readFileSync(file, "utf8");
  await pool.query(sql);
  console.log("Migration applied: db/schema_simple.sql");
}

run()
  .catch((err) => {
    console.error("Migration failed:", err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
