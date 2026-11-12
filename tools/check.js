// Minimal Lua sanity check (no Lua interpreter on this machine): strips strings and comments, then
// checks that block keywords (function/if/for/while/do/repeat ... end/until) and brackets balance.
const fs = require("fs");
const file = process.argv[2];
let src = fs.readFileSync(file, "utf8");

// Strip long strings/comments, short comments, then quoted strings.
src = src.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, (m) => m.replace(/[^\n]/g, " "));
src = src.replace(/\[(=*)\[[\s\S]*?\]\1\]/g, (m) => m.replace(/[^\n]/g, " "));
src = src.replace(/--[^\n]*/g, "");
src = src.replace(/"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/g, '""');

const stack = [];
const errors = [];
const lines = src.split("\n");
const pairs = { ")": "(", "]": "[", "}": "{" };
lines.forEach((line, i) => {
  const n = i + 1;
  const tokens = line.match(/[A-Za-z_][A-Za-z0-9_]*|[()[\]{}]/g) || [];
  for (let t = 0; t < tokens.length; t++) {
    const tok = tokens[t];
    if (tok === "function" || tok === "if" || tok === "repeat") stack.push([tok, n]);
    else if (tok === "for" || tok === "while") { stack.push([tok, n]); }
    else if (tok === "do") {
      // 'do' closes the header of a for/while; otherwise it opens its own block.
      const top = stack[stack.length - 1];
      if (top && (top[0] === "for" || top[0] === "while") && !top[2]) top[2] = true;
      else stack.push(["do", n]);
    } else if (tok === "end") {
      const top = stack.pop();
      if (!top || top[0] === "repeat" || "([{".includes(top[0])) errors.push(`line ${n}: unexpected 'end'`);
    } else if (tok === "until") {
      const top = stack.pop();
      if (!top || top[0] !== "repeat") errors.push(`line ${n}: unexpected 'until'`);
    } else if ("([{".includes(tok)) stack.push([tok, n]);
    else if (pairs[tok]) {
      const top = stack.pop();
      if (!top || top[0] !== pairs[tok]) errors.push(`line ${n}: unexpected '${tok}' (open: ${top && top[0]} from line ${top && top[1]})`);
    }
  }
});
stack.forEach(([tok, n]) => errors.push(`line ${n}: '${tok}' never closed`));
if (errors.length) { console.error(errors.join("\n")); process.exit(1); }
console.log(`${file}: blocks and brackets balance`);
