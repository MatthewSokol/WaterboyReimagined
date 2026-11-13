// Offline half of the release "green run" (RELEASING.md): every check that doesn't need the game.
//   node tools/verify.js            all code checks
//   node tools/verify.js --release  also checks the version is ready to ship (changelog entry, clean tree, tag)
// Prints GREEN or RED and exits 0 or 1. Setup once: (cd tools && npm install)
const { execFileSync } = require("child_process");
const fs = require("fs"), path = require("path");

const root = path.join(__dirname, "..");
const addon = path.join(root, "WaterboyReimagined");
const release = process.argv.includes("--release");
const results = [];
const check = (name, ok, info) => results.push({ name, ok, info });
const node = (args) => {
  try { return { ok: true, out: execFileSync(process.execPath, args, { cwd: root, encoding: "utf8", stdio: "pipe" }) }; }
  catch (e) { return { ok: false, out: (e.stdout || "") + (e.stderr || "") }; }
};
const git = (...args) => {
  try { return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: "pipe" }).trim(); } catch { return null; }
};

// 1. The .toc and the files it loads
const toc = fs.readFileSync(path.join(addon, "WaterboyReimagined.toc"), "utf8");
const tocFiles = toc.split(/\r?\n/).filter((l) => l.trim() && !l.startsWith("#")).map((l) => l.trim());
// The packager (and release.ps1, install.ps1) fill the version in from the git tag.
const tocVersion = (toc.match(/^## Version:\s*(.+)$/m) || [])[1]?.trim();
check(".toc version", tocVersion === "@project-version@", tocVersion ? `## Version: ${tocVersion}` : "no ## Version: line");
const missing = tocFiles.filter((f) => !fs.existsSync(path.join(addon, f)));
check(".toc files exist", missing.length === 0, missing.length ? "missing: " + missing.join(", ") : tocFiles.length + " files");
const luaOnDisk = fs.readdirSync(addon).filter((f) => f.endsWith(".lua"));
const unlisted = luaOnDisk.filter((f) => !tocFiles.includes(f));
check("every .lua is in the .toc", unlisted.length === 0, unlisted.length ? "not loaded: " + unlisted.join(", ") : "yes");

// 2. Blocks and brackets
for (const f of luaOnDisk) {
  const r = node([path.join("tools", "check.js"), path.join("WaterboyReimagined", f)]);
  check("brackets " + f, r.ok, r.ok ? "balanced" : r.out.trim());
}

// 3. The addon in a Lua VM: smoke, migration, the Mechanic hooks and the test journal
if (!fs.existsSync(path.join(__dirname, "node_modules", "fengari"))) {
  check("Lua VM tests", false, "run (cd tools && npm install) first");
} else {
  const BAD = /^(ERROR|LOAD ERROR|COMPILE ERROR|HARNESS)/m;
  const runs = [
    ["smoke", "", "smoke.lua"],
    ["migration", "", "smoke-migrate.lua"],
    ["Mechanic hooks", path.join("tools", "stub-mechanic.lua"), "smoke-mechanic.lua"],
    ["test journal", "", "smoke-journal.lua"],
  ];
  for (const [name, pre, script] of runs) {
    const r = node([path.join("tools", "harness.js"), "WaterboyReimagined", pre, path.join("tools", script)]);
    const lines = r.out.split(/\r?\n/);
    const bad = lines.filter((l) => BAD.test(l) || /^test .*: FAIL/.test(l) || l === "registered: false");
    const loaded = lines.filter((l) => l.startsWith("loaded ")).length;
    check(name + " test", r.ok && bad.length === 0 && loaded === tocFiles.length,
      bad.length ? bad.slice(0, 3).join(" | ") : `${loaded}/${tocFiles.length} files loaded, no errors`);
  }
}

// 4. Ready to ship (--release only)
if (release) {
  const changelog = fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8");
  // The version being released is the top ## [x.y.z] entry; the tag vx.y.z comes from it.
  const version = (changelog.match(/^## \[(?!Unreleased\])([^\]]+)\]/m) || [])[1];
  check("CHANGELOG has a release entry", !!version, version ? `top entry ${version}` : "no ## [x.y.z] - date entry");
  const pending = (changelog.match(/^## \[Unreleased\][^\n]*\n([\s\S]*?)(?=^## \[|(?![\s\S]))/m) || [])[1] || "";
  check("[Unreleased] is empty", pending.trim() === "", pending.trim() ? "merge it as a candidate first (dev-routine)" : "yes");
  check("working tree clean", git("status", "--porcelain") === "", git("status", "--porcelain") || "clean");
  const branch = git("branch", "--show-current");
  check("on main", branch === "main", branch);
  const tagged = git("rev-parse", "-q", "--verify", `refs/tags/v${version}^{commit}`);
  check(`tag v${version}`, !tagged || tagged === git("rev-parse", "HEAD"),
    tagged ? (tagged === git("rev-parse", "HEAD") ? "on this commit" : "already used by another commit: pick the next version") : "not made yet");
}

let green = true;
for (const r of results) {
  if (!r.ok) green = false;
  console.log(`${r.ok ? "ok  " : "FAIL"}  ${r.name}: ${r.info}`);
}
console.log(green ? "\nGREEN: offline checks pass" : "\nRED: fix the FAIL lines above");
process.exit(green ? 0 : 1);
