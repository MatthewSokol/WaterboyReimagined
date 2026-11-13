// The release gate (RELEASING.md): reads what the game saved on the last /reload, logout or exit (Mechanic's
// self-test results, the addon's test journal, BugGrabber's errors) and says whether Waterboy Reimagined is green.
//   node tools/release-check.js [--wtf "<path to _forever_\WTF\Account>"] [--no-mechanic]
// Run it when the game exits: node <wow-mod-dev>/scripts/wow-env.js watch -- node tools/release-check.js
// --no-mechanic is for the pass with Mechanic disabled: its results aren't required then.
// Needs !BugGrabber (with BugSack), and Mechanic (!Mechanic + Mechanic) unless --no-mechanic. Setup once: (cd tools && npm install)
// GREEN means: results saved after the newest code change, the installed copy matches the repo, the versions match,
// every self-test passed, no journal entry for this build failed, and BugGrabber has no Waterboy Reimagined error
// since the newest code change. Exit 0 = GREEN.
const { lua, lauxlib, lualib, to_luastring } = require("fengari");
const fs = require("fs"), path = require("path");

const ADDON = "WaterboyReimagined";
const root = path.join(__dirname, "..");
const src = path.join(root, ADDON);
const argWtf = process.argv.indexOf("--wtf");
const wtf = argWtf > 0 ? process.argv[argWtf + 1]
  : process.env.WBR_WTF || "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account";
const installed = path.join(wtf, "..", "..", "Interface", "AddOns", ADDON);
const noMechanic = process.argv.includes("--no-mechanic");

const problems = [], notes = [];
// Lua tables arrive as arrays, or as objects when empty or sparse
const arr = (x) => Array.isArray(x) ? x : Object.values(x || {});
const fmtAge = (ms) => ms < 90e3 ? Math.round(ms / 1e3) + "s" : ms < 90 * 60e3 ? Math.round(ms / 60e3) + " min" : (ms / 36e5).toFixed(1) + " h";

// Run a SavedVariables file in a Lua VM and return one of its globals as a plain JS value.
const TO_JSON = fs.readFileSync(path.join(__dirname, "sv-to-json.lua"), "utf8");
function loadSV(file, name) {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const bytes = fs.readFileSync(file);
  if (lauxlib.luaL_loadbuffer(L, bytes, null, to_luastring(path.basename(file))) !== 0 || lua.lua_pcall(L, 0, 0, 0) !== 0) {
    throw new Error("can't read " + path.basename(file) + ": " + lua.lua_tojsstring(L, -1));
  }
  lua.lua_pushstring(L, to_luastring(name)); lua.lua_setglobal(L, to_luastring("__WANT_NAME"));
  if (lauxlib.luaL_dostring(L, to_luastring(TO_JSON)) !== 0) throw new Error(lua.lua_tojsstring(L, -1));
  lua.lua_getglobal(L, to_luastring("__OUT"));
  return JSON.parse(lua.lua_tojsstring(L, -1));
}
const readSV = (file, name) => {
  try { return loadSV(file, name) || {}; } catch (e) { problems.push(e.message); return {}; }
};

// The account's SavedVariables folder written most recently (by Mechanic or the addon). Never printed by name.
let svDir;
try {
  svDir = fs.readdirSync(wtf)
    .flatMap((a) => ["!Mechanic.lua", ADDON + ".lua"].map((f) => path.join(wtf, a, "SavedVariables", f)))
    .filter((f) => fs.existsSync(f))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs).map(path.dirname)[0];
} catch { /* reported below */ }
if (!svDir) {
  console.log(`Nothing saved under ${wtf.replace(/Account.*$/, "Account")}\\<ACCOUNT>\\SavedVariables yet.`);
  console.log("Log in with the addon enabled, /reload, then run this again.");
  process.exit(1);
}

// Newest change to the addon's code: results saved before it are from an older build.
const codeFiles = fs.readdirSync(src).map((f) => path.join(src, f));
const newestCode = Math.max(...codeFiles.map((f) => fs.statSync(f).mtimeMs));

// 1. The installed copy is this repo's (the install fills in the .toc's @project-version@, so that line is skipped)
const norm = (f) => fs.readFileSync(f).toString("latin1").replace(/\r\n/g, "\n").replace(/^## Version:.*$/m, "");
const differs = codeFiles.filter((f) => {
  const g = path.join(installed, path.basename(f));
  return !fs.existsSync(g) || norm(f) !== norm(g);
}).map((f) => path.basename(f));
if (differs.length) problems.push("installed copy differs from the repo: " + differs.join(", ") + " (run install.ps1, then /reload)");
const installedToc = path.join(installed, ADDON + ".toc");
const version = fs.existsSync(installedToc)
  ? (fs.readFileSync(installedToc, "utf8").match(/^## Version:\s*(.+)$/m) || [])[1]?.trim() : null;
console.log(`Release check for Waterboy Reimagined ${version || "(not installed)"}`);

// 2. Mechanic's saved data for this addon (the profile synced most recently)
const mechFile = path.join(svDir, "!Mechanic.lua");
const mech = fs.existsSync(mechFile) ? readSV(mechFile, "MechanicDB") : {};
let data, lastSync = 0, profileLabel;
for (const [name, p] of Object.entries(mech.profiles || {})) {
  const d = p && p.addonData && p.addonData[ADDON];
  if (d && (p.lastSync || 0) >= lastSync) { data = d; lastSync = p.lastSync || 0; profileLabel = name === "Default" ? "Default" : "a character profile"; }
}
if (data && noMechanic && lastSync * 1000 < newestCode - 2000) data = null; // an older run's results: not this pass
if (!data) {
  if (noMechanic) notes.push("Mechanic's results not read (--no-mechanic)");
  else problems.push("Mechanic has no current Waterboy Reimagined results: log in with !Mechanic and Mechanic enabled, then /reload (or pass --no-mechanic for the pass without it)");
} else {
  console.log(`  Mechanic profile: ${profileLabel}, last sync ${fmtAge(Date.now() - lastSync * 1000)} ago`);
  if (lastSync * 1000 < newestCode - 2000) problems.push("Mechanic's results are older than the newest code change: /reload in game, then run this again");
  if (data.version !== version) problems.push(`in-game version ${data.version} isn't the installed ${version}`);

  // 3. Self-tests
  const expected = [...fs.readFileSync(path.join(src, "Mechanic.lua"), "utf8").matchAll(/^\s+id = "(\w+)", name =/gm)].map((m) => m[1]);
  const tests = data.tests || {};
  console.log(`\nSelf-tests (${Object.keys(tests).length} of ${expected.length}):`);
  for (const id of expected) {
    const t = tests[id];
    if (!t) { problems.push(`self-test ${id} has no result`); console.log(`  MISSING ${id}`); continue; }
    if (!t.passed) problems.push(`self-test failed: ${t.name || id}: ${t.message}`);
    console.log(`  ${t.passed ? "PASS" : "FAIL"}  ${t.name || id}: ${t.message}`);
    for (const d of arr(t.details)) {
      if (d.status === "fail" || d.status === "warn") {
        console.log(`        ${d.status}: ${d.label} = ${d.value}`);
        if (d.status === "warn") notes.push(`${t.name || id}: ${d.label} = ${d.value}`);
      }
    }
  }

  // 4. What the addon said (last lines Mechanic kept)
  const logs = arr(data.logs);
  console.log(`\nLast ${Math.min(15, logs.length)} of ${logs.length} log lines:`);
  for (const l of logs.slice(-15)) console.log("  " + String(l).replace(/\r?\n/g, " / "));
}

// 5. The test journal: steps this build proved since the newest code change (TESTING.md's [journal: id] rows)
const svFile = path.join(svDir, ADDON + ".lua");
const journal = fs.existsSync(svFile) ? arr(readSV(svFile, "WaterboyReimaginedDB").journal) : [];
const current = journal.filter((e) => e && e.v === version && e.t * 1000 >= newestCode - 2000);
const steps = {};
for (const e of current) {
  const s = steps[e.step] || (steps[e.step] = { ok: 0, fail: 0, info: "" });
  if (e.ok) s.ok++; else { s.fail++; problems.push(`journal: ${e.step} failed: ${e.info}`); }
  s.info = e.info;
}
const wanted = [...new Set([...fs.readFileSync(path.join(root, "TESTING.md"), "utf8").matchAll(/\[journal: ([\w-]+)\]/g)].map((m) => m[1]))]
  .filter((id) => id !== "id"); // the intro's placeholder
console.log(`\nTest journal (${current.length} entries for ${version}, ${journal.length} kept):`);
for (const id of wanted) {
  const s = steps[id];
  if (id === "no-taint") console.log(`  ${s && s.fail ? "FAIL" : "ok  "}  no-taint: ${s && s.fail ? s.fail + " blocked action(s), last " + s.info : "no blocked actions"}`);
  else console.log(`  ${!s ? "--  " : s.fail ? "FAIL" : "ok  "}  ${id}: ${!s ? "not proven yet" : `${s.ok} ok, ${s.fail} failed (last: ${s.info})`}`);
}

// 6. Lua errors caught by BugGrabber
const bgFile = path.join(svDir, "!BugGrabber.lua");
if (!fs.existsSync(bgFile)) {
  problems.push("no !BugGrabber.lua: install !BugGrabber (with BugSack) so Lua errors are caught");
} else {
  const bg = readSV(bgFile, "BugGrabberDB");
  const ours = arr(bg.errors).filter((e) => e && typeof e === "object").filter((e) => [e.message, e.stack, e.locals].some((s) => typeof s === "string" && s.includes(ADDON)));
  const when = (e) => {
    const m = /^(\d+)\/(\d+)\/(\d+) (\d+):(\d+):(\d+)$/.exec(e.time || "");
    return m ? new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime() : 0;
  };
  const recent = ours.filter((e) => when(e) >= newestCode - 2000);
  console.log(`\nLua errors from Waterboy Reimagined: ${recent.length} since the newest code change (${ours.length} kept in all)`);
  for (const e of recent.slice(0, 5)) {
    console.log(`  x${e.counter || 1}  ${e.time}  ${String(e.message).split("\n")[0]}`);
    problems.push("Lua error: " + String(e.message).split("\n")[0]);
  }
}

console.log("");
if (notes.length) { console.log("Look at (not blocking):"); for (const n of notes) console.log("  - " + n); console.log(""); }
if (problems.length) {
  console.log("RED:");
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
console.log("GREEN: in-game checks pass");
