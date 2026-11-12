// Loads the addon in a Lua VM (fengari) with stubbed WoW API, then runs a script that fires events and
// slash commands. Usage: node tools/harness.js WaterboyReimagined [SavedVariables.lua] tools/smoke.lua
// Setup once: (cd tools && npm install)
const { lua, lauxlib, lualib, to_luastring } = require("fengari");
const fs = require("fs"), path = require("path");
const [dir, sv, ...script] = process.argv.slice(2);
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
function run(src, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring(name)) !== 0 || lua.lua_pcall(L, 0, 0, 0) !== 0) {
    console.log("HARNESS ERROR " + name + ": " + lua.lua_tojsstring(L, -1)); lua.lua_pop(L, 1);
  }
}
run(fs.readFileSync(path.join(__dirname, "wowstub.lua"), "utf8"), "wowstub");
if (sv) run(fs.readFileSync(sv, "utf8"), "SavedVariables");
const toc = fs.readFileSync(path.join(dir, "WaterboyReimagined.toc"), "utf8").split(/\r?\n/).filter(l => l && !l.startsWith("#"));
for (const f of toc) {
  lua.lua_getglobal(L, to_luastring("LOADFILE"));
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(dir, f), "utf8")));
  lua.lua_pushstring(L, to_luastring(f));
  if (lua.lua_pcall(L, 2, 0, 0) !== 0) { console.log("HARNESS " + lua.lua_tojsstring(L, -1)); lua.lua_pop(L, 1); }
}
run(fs.readFileSync(script[0], "utf8"), "script");
