// Checks a release zip before it's uploaded (dev-routine's verifyPackage stage):
//   node tools/check-zip.js dist/WaterboyReimagined-1.2.0.zip [--version 1.2.0]
// One top-level WaterboyReimagined/ folder, the .toc's version filled in (not @project-version@), every file the
// .toc lists, LICENSE, and no dev files. Exits 0 when the zip is good.
const { execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");

const args = process.argv.slice(2);
const zip = args.find((a) => !a.startsWith("--") && args[args.indexOf(a) - 1] !== "--version");
const want = args.includes("--version") ? args[args.indexOf("--version") + 1] : null;
if (!zip || !fs.existsSync(zip)) { console.log("usage: node tools/check-zip.js <zip> [--version x.y.z]"); process.exit(2); }

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "wbr-zip-"));
const problems = [];
try {
  // Windows' own tar.exe (bsdtar) reads zip files; Git Bash's GNU tar, earlier on the PATH, doesn't.
  const tar = process.platform === "win32" ? path.join(process.env.SystemRoot || "C:\\Windows", "System32", "tar.exe") : "tar";
  execFileSync(tar, ["-xf", path.resolve(zip), "-C", dir]);
  const top = fs.readdirSync(dir);
  if (top.length !== 1 || top[0] !== "WaterboyReimagined") problems.push("top level is [" + top.join(", ") + "], not just WaterboyReimagined/");
  const addon = path.join(dir, "WaterboyReimagined");
  const tocPath = path.join(addon, "WaterboyReimagined.toc");
  if (!fs.existsSync(tocPath)) throw new Error("no WaterboyReimagined/WaterboyReimagined.toc");
  const toc = fs.readFileSync(tocPath, "utf8");
  const version = (toc.match(/^## Version:\s*(.+)$/m) || [])[1]?.trim();
  if (!version || version.includes("@project-version@")) problems.push("the .toc's version wasn't filled in: " + version);
  else if (want && version.replace(/^v/, "") !== want) problems.push(`.toc version ${version}, expected ${want}`);
  const listed = toc.split(/\r?\n/).filter((l) => l.trim() && !l.startsWith("#")).map((l) => l.trim());
  for (const f of listed) if (!fs.existsSync(path.join(addon, f))) problems.push("missing " + f);
  if (!fs.existsSync(path.join(addon, "LICENSE"))) problems.push("missing LICENSE");
  const all = [];
  const walk = (d, rel) => fs.readdirSync(d, { withFileTypes: true }).forEach((e) =>
    e.isDirectory() ? walk(path.join(d, e.name), rel + e.name + "/") : all.push(rel + e.name));
  walk(addon, "");
  const dev = all.filter((f) => /^(tools|docs|dist|\.devroutine)\//.test(f) || /\.(ps1|md|js|json)$/i.test(f) || /^\./.test(f));
  if (dev.length) problems.push("dev files: " + dev.join(", "));
  console.log(`${zip}: ${all.length} files, version ${version}`);
} catch (e) {
  problems.push(e.message);
} finally {
  fs.rmSync(dir, { recursive: true, force: true });
}
for (const p of problems) console.log("FAIL  " + p);
console.log(problems.length ? "RED: the zip isn't ready" : "GREEN: the zip is ready to upload");
process.exit(problems.length ? 1 : 0);
