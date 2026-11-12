// In-game half of the release "green run" (RELEASING.md): reads what Mechanic and BugGrabber saved on the last
// /reload or logout and says whether Waterboy Reimagined is green.
//   node tools/mechanic-report.js [--wtf "<path to _forever_\WTF\Account>"]
// Needs the Mechanic dev addon (!Mechanic + Mechanic) and !BugGrabber installed in game. Setup once: (cd tools && npm install)
// GREEN means: Mechanic saved after the newest code change, the installed copy matches the repo, the versions
// match, every self-test passed, and BugGrabber has no Waterboy Reimagined error since the newest code change.
const { lua, lauxlib, lualib, to_luastring } = require("fengari");
const fs = require("fs"), path = require("path");

const ADDON = "WaterboyReimagined";
const root = path.join(__dirname, "..");
const src = path.join(root, ADDON);
const argWtf = process.argv.indexOf("--wtf");
const wtf = argWtf > 0 ? process.argv[argWtf + 1]
  : process.env.WBR_WTF || "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account";
const installed = path.join(wtf, "..", "..", "Interface", "AddOns", ADDON);

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

// The account folder holding Mechanic's saved file (the newest if there are several). Never printed by name.
let account;
try {
  account = fs.readdirSync(wtf)
    .map((a) => path.join(wtf, a, "SavedVariables", "!Mechanic.lua"))
    .filter((f) => fs.existsSync(f))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0];
} catch { /* reported below */ }
if (!account) {
  console.log(`No !Mechanic.lua under ${wtf.replace(/Account.*$/, "Account")}\\<ACCOUNT>\\SavedVariables.`);
  console.log("Install Mechanic (both !Mechanic and Mechanic folders), log in, /reload, then run this again.");
  process.exit(1);
}
const svDir = path.dirname(account);

// Newest change to the addon's code: results saved before it are from an older build.
const codeFiles = fs.readdirSync(src).map((f) => path.join(src, f));
const newestCode = Math.max(...codeFiles.map((f) => fs.statSync(f).mtimeMs));

// 1. The installed copy is this repo's
const norm = (f) => fs.readFileSync(f).toString("latin1").replace(/\r\n/g, "\n");
const differs = codeFiles.filter((f) => {
  const g = path.join(installed, path.basename(f));
  return !fs.existsSync(g) || norm(f) !== norm(g);
}).map((f) => path.basename(f));
if (differs.length) problems.push("installed copy differs from the repo: " + differs.join(", ") + " (run install.ps1, then /reload)");

// 2. Mechanic's saved data for this addon (the profile synced most recently)
const savedAt = fs.statSync(account).mtimeMs;
const readSV = (file, name) => {
  try { return loadSV(file, name) || {}; } catch (e) { problems.push(e.message); return {}; }
};
const db = readSV(account, "MechanicDB");
let data, lastSync = 0, profileLabel;
for (const [name, p] of Object.entries(db.profiles || {})) {
  const d = p && p.addonData && p.addonData[ADDON];
  if (d && (p.lastSync || 0) >= lastSync) { data = d; lastSync = p.lastSync || 0; profileLabel = name === "Default" ? "Default" : "a character profile"; }
}
console.log(`Mechanic report for Waterboy Reimagined`);
console.log(`  saved file: <ACCOUNT>\\SavedVariables\\!Mechanic.lua, written ${fmtAge(Date.now() - savedAt)} ago`);
if (!data) {
  problems.push("Mechanic has no Waterboy Reimagined data yet: log in with both addons enabled, then /reload");
} else {
  console.log(`  Mechanic profile: ${profileLabel}, last sync ${fmtAge(Date.now() - lastSync * 1000)} ago`);
  if (lastSync * 1000 < newestCode - 2000) problems.push("results are older than the newest code change: /reload in game, then run this again");
  const toc = fs.readFileSync(path.join(src, ADDON + ".toc"), "utf8");
  const tocVersion = (toc.match(/^## Version:\s*(.+)$/m) || [])[1]?.trim();
  if (data.version !== tocVersion) problems.push(`in-game version ${data.version} isn't the repo's ${tocVersion}`);

  // 3. Self-tests
  const expected = [...fs.readFileSync(path.join(src, "Mechanic.lua"), "utf8").matchAll(/^\s+id = "(\w+)", name =/gm)].map((m) => m[1]);
  const tests = data.tests || {};
  console.log(`\nSelf-tests (${Object.keys(tests).length} of ${expected.length}):`);
  for (const id of expected) {
    const t = tests[id];
    if (!t) { problems.push(`self-test ${id} has no result`); console.log(`  MISSING ${id}`); continue; }
    const tag = t.passed ? "PASS" : "FAIL";
    if (!t.passed) problems.push(`self-test failed: ${t.name || id}: ${t.message}`);
    console.log(`  ${tag}  ${t.name || id}: ${t.message}`);
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

// 5. Lua errors caught by BugGrabber
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
