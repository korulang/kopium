#!/usr/bin/env node
// Test harness for the membrane + worldmodel commit-msg gate.
// Drives the REAL hook inside a throwaway git repo, one case at a time.
//   node hook-test.mjs <path-to-commit-msg.cjs>
// Exit 0 iff every case matches its expected accept/reject.

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { execFileSync, execSync } from "node:child_process";

const HOOK = process.argv[2];
if (!HOOK || !fs.existsSync(HOOK)) { console.error("usage: hook-test.mjs <commit-msg.cjs>"); process.exit(2); }
const HOOK_ABS = path.resolve(HOOK);

// belief-class signal defs the interlock reads (membrane: true)
const SIGNALS = {
  contradiction: "membrane: true",
  correction: "membrane: true",
  "regime-change": "membrane: true",
  momentum: "membrane: false",
};

function freshRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "membrane-hooktest-"));
  const git = (a) => execFileSync("git", ["-C", dir, ...a], { encoding: "utf8" });
  git(["init", "-q"]);
  git(["config", "user.email", "t@t"]);
  git(["config", "user.name", "t"]);
  fs.mkdirSync(path.join(dir, "signals"), { recursive: true });
  for (const [n, m] of Object.entries(SIGNALS))
    fs.writeFileSync(path.join(dir, "signals", `${n}.signal`),
      `name: ${n}\nkind: inferred\nshape: categorical\nface: in\n${m}\nnote: test\n`);
  fs.mkdirSync(path.join(dir, "concepts"), { recursive: true });
  fs.writeFileSync(path.join(dir, "concepts", ".gitkeep"), "");
  git(["add", "."]);
  git(["commit", "-qm", "seed", "--no-verify"]);
  return { dir, git };
}

// Run the hook against a message; return {code, msg-after}
function runHook(dir, message, { stage, remove } = {}) {
  const git = (a) => execFileSync("git", ["-C", dir, ...a], { encoding: "utf8" });
  if (stage) for (const [rel, content] of Object.entries(stage)) {
    const p = path.join(dir, rel);
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, content);
    git(["add", rel]);
  }
  // Staged DELETIONS, which `stage` cannot express and `move` cannot be tested
  // without: custody-out is a concept file leaving the tree.
  if (remove) for (const rel of remove) git(["rm", "-q", rel]);
  const msgFile = path.join(dir, ".git", "COMMIT_EDITMSG");
  fs.writeFileSync(msgFile, message);
  let code = 0, out = "";
  try {
    out = execSync(`node ${JSON.stringify(HOOK_ABS)} ${JSON.stringify(msgFile)}`,
      { cwd: dir, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] });
  } catch (e) { code = e.status ?? 1; out = (e.stdout || "") + (e.stderr || ""); }
  return { code, out, msgAfter: fs.readFileSync(msgFile, "utf8") };
}

// prior blob sha of a committed concept, for evolve/occludes
function priorBlob(dir, rel) {
  return execFileSync("git", ["-C", dir, "rev-parse", `HEAD:${rel}`], { encoding: "utf8" }).trim();
}

const WM_OK = "## World Model\nSignals: acknowledged-none";
const WM_CONTRA = "## World Model\nSignal: contradiction — belief X flipped";
const WM_ROUTINE = "## World Model\nSignal: momentum value=0.7";

// A shape-wall-compliant OKF fragment: frontmatter (type/id/provenance/ts) +
// a prose body, id == filename stem. Fixtures use this so the lineage-path
// cases satisfy the fragment-shape wall too.
const frag = (id, body = "the belief prose") =>
  `---\ntype: belief\nid: ${id}\nprovenance: hook-test\nts: 2026-07-11\n---\n\n# ${id}\n\n${body}\n`;

const cases = [
  // --- World Model gate (unchanged) ---
  { name: "WM: missing section → REJECT", expect: "reject",
    msg: "chore: x\n" },
  { name: "WM: acknowledged-none + membrane none → ACCEPT", expect: "accept",
    msg: `chore: x\n\n${WM_OK}\n\n## Membrane\nEvolution: acknowledged-none\n` },

  // --- Universal Membrane gate (NEW) ---
  { name: "[PIN] no Membrane section, nothing staged → REJECT", expect: "reject",
    msg: `chore: x\n\n${WM_OK}\n` },
  { name: "[PIN] interlock: belief signal + Evolution:acknowledged-none → REJECT", expect: "reject",
    msg: `feat: x\n\n${WM_CONTRA}\n\n## Membrane\nEvolution: acknowledged-none\n` },
  { name: "[PIN] interlock: belief signal + no concept staged → REJECT", expect: "reject",
    msg: `feat: x\n\n${WM_CONTRA}\n` },
  { name: "routine signal (membrane:false) + none → ACCEPT", expect: "accept",
    msg: `chore: x\n\n${WM_ROUTINE}\n\n## Membrane\nEvolution: acknowledged-none\n` },

  // --- lineage path (existing behavior must survive) ---
  { name: "create: staged concept + Action create → ACCEPT", expect: "accept",
    stage: { "concepts/frag-new.md": frag("frag-new") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-new\n` },
  { name: "staged concept but NO Membrane section → REJECT", expect: "reject",
    stage: { "concepts/frag-new.md": frag("frag-new") },
    msg: `feat: x\n\n${WM_OK}\n` },
  { name: "interlock positive: belief signal + gardened create → ACCEPT", expect: "accept",
    stage: { "concepts/frag-new.md": frag("frag-new") },
    msg: `feat: x\n\n${WM_CONTRA}\n\n## Membrane\nAction: create\nConcept: frag-new\n` },

  // --- mechanical scaffolding (NEW): auto-derive Occludes for a lone evolve ---
  { name: "[MECH] evolve, Occludes omitted, one concept modified → ACCEPT + auto-filled",
    expect: "accept", checkMsg: (m) => /^Occludes:\s*[0-9a-f]{7,40}\b/m.test(m),
    seedConcept: { rel: "concepts/frag-ev.md", content: frag("frag-ev", "old belief") },
    stage: { "concepts/frag-ev.md": frag("frag-ev", "NEW belief") },
    msg: `evolve: x\n\n${WM_OK}\n\n## Membrane\nAction: evolve\nConcept: frag-ev\n` },

  // --- fragment SHAPE wall (NEW): frag-*.md must be well-formed OKF ---
  { name: "[SHAPE] compliant frontmatter + body → ACCEPT", expect: "accept",
    stage: { "concepts/frag-ok.md": frag("frag-ok") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-ok\n` },
  { name: "[SHAPE] missing 'ts' field → REJECT (names field + fix)", expect: "reject",
    expectOut: /frag-bad\.md: missing frontmatter field 'ts' — add 'ts:/,
    stage: { "concepts/frag-bad.md": "---\ntype: belief\nid: frag-bad\nprovenance: t\n---\n\nbody\n" },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-bad\n` },
  { name: "[SHAPE] no frontmatter at all → REJECT", expect: "reject",
    expectOut: /frag-bare\.md: missing OKF frontmatter/,
    stage: { "concepts/frag-bare.md": "# just a title\n\nbody\n" },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-bare\n` },
  { name: "[SHAPE] id != filename stem → REJECT", expect: "reject",
    expectOut: /frag-mismatch\.md: frontmatter 'id: frag-other' must equal the filename stem/,
    stage: { "concepts/frag-mismatch.md": frag("frag-other") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-mismatch\n` },
  { name: "[SHAPE] empty body → REJECT", expect: "reject",
    expectOut: /frag-nobody\.md: no prose body after the frontmatter/,
    stage: { "concepts/frag-nobody.md": "---\ntype: belief\nid: frag-nobody\nprovenance: t\nts: 2026-07-11\n---\n\n" },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-nobody\n` },
  { name: "[SHAPE] non-frag concept file is NOT shape-walled → ACCEPT", expect: "accept",
    stage: { "concepts/index.md": "# an index, not a fragment\n" },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: index\n` },

  // --- COVERAGE WALL: the declaration must name EVERY staged concept ---------
  // The gate used to check a declaration's shape and never its reach, so a
  // commit could stage many concepts, declare one, and the rest rode through
  // undeclared. Found 2026-08-04 on a real 25-concept commit that passed.
  { name: "[COVER] 3 staged, 1 declared → REJECT (names the undeclared)", expect: "reject",
    expectOut: /named nowhere in the declaration[\s\S]*frag-cov-b[\s\S]*frag-cov-c/,
    stage: { "concepts/frag-cov-a.md": frag("frag-cov-a"),
             "concepts/frag-cov-b.md": frag("frag-cov-b"),
             "concepts/frag-cov-c.md": frag("frag-cov-c") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-cov-a\n` },
  { name: "[COVER] 3 staged, all 3 named in a Concept list → ACCEPT", expect: "accept",
    stage: { "concepts/frag-cov-a.md": frag("frag-cov-a"),
             "concepts/frag-cov-b.md": frag("frag-cov-b"),
             "concepts/frag-cov-c.md": frag("frag-cov-c") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: create\nConcept: frag-cov-a, frag-cov-b, frag-cov-c\n` },
  { name: "[COVER] a parent named in Parents: counts as covered → ACCEPT", expect: "accept",
    seedConcept: { rel: "concepts/frag-par-one.md", content: frag("frag-par-one") },
    remove: ["concepts/frag-par-one.md"],
    stage: { "concepts/frag-par-two.md": frag("frag-par-two"),
             "concepts/frag-child.md": frag("frag-child") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: merge\nConcept: frag-child\nParents: frag-par-one, frag-par-two\n` },

  // --- MOVE: custody, not content -------------------------------------------
  // The only legal way a concept file may leave a tree. Legal because it is not
  // a deletion: the content stays reachable in history, and a move that also
  // EDITS is refused, so custody and content stay separately answerable.
  { name: "[MOVE] custody-out: a seeded concept leaves the tree → ACCEPT", expect: "accept",
    seedConcept: { rel: "concepts/frag-moving.md", content: frag("frag-moving") },
    remove: ["concepts/frag-moving.md"],
    msg: `chore: x\n\n${WM_OK}\n\n## Membrane\nAction: move\nConcept: frag-moving\nCustody: here -> ../other\n` },
  { name: "[MOVE] that also EDITS the content → REJECT", expect: "reject",
    expectOut: /Action move must PRESERVE content/,
    seedConcept: { rel: "concepts/frag-moving.md", content: frag("frag-moving") },
    stage: { "concepts/frag-moving.md": frag("frag-moving", "SILENTLY REWRITTEN while claiming a move") },
    msg: `chore: x\n\n${WM_OK}\n\n## Membrane\nAction: move\nConcept: frag-moving\nCustody: here -> ../other\n` },
  { name: "[MOVE] without Custody: → REJECT", expect: "reject",
    expectOut: /Action move requires Custody:/,
    seedConcept: { rel: "concepts/frag-moving.md", content: frag("frag-moving") },
    remove: ["concepts/frag-moving.md"],
    msg: `chore: x\n\n${WM_OK}\n\n## Membrane\nAction: move\nConcept: frag-moving\n` },

  // --- the verb set is taught from the same object it is enforced from -------
  { name: "[VERBS] an unknown Action names all six → REJECT", expect: "reject",
    expectOut: /create\/evolve\/merge\/split\/correct\/move/,
    stage: { "concepts/frag-verb.md": frag("frag-verb") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: retire\nConcept: frag-verb\n` },
  { name: "[VERBS] help text teaches six verbs and Custody, not five", expect: "reject",
    expectOut: /# create \| evolve \| merge \| split \| correct \| move[\s\S]*Custody:/,
    stage: { "concepts/frag-verb.md": frag("frag-verb") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction: retire\nConcept: frag-verb\n` },

  // --- trailer whitespace is part of the grammar ------------------------------
  // Aligned trailers produce a second spelling of one field and silently break
  // `git log --grep="Concept: frag-<id>"`, which reports the miss as "no
  // trajectory" rather than as a bad query.
  { name: "[GRAMMAR] aligned trailers are normalised to one spelling → ACCEPT", expect: "accept",
    checkMsg: (m) => /^Concept: frag-align$/m.test(m) && !/^Concept: {2,}/m.test(m),
    stage: { "concepts/frag-align.md": frag("frag-align") },
    msg: `feat: x\n\n${WM_OK}\n\n## Membrane\nAction:     create\nConcept:    frag-align\n` },
];

let pass = 0, fail = 0;
for (const c of cases) {
  const { dir, git } = freshRepo();
  if (c.seedConcept) {
    const p = path.join(dir, c.seedConcept.rel);
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, c.seedConcept.content);
    git(["add", c.seedConcept.rel]);
    git(["commit", "-qm", "seed concept", "--no-verify"]);
  }
  const r = runHook(dir, c.msg, { stage: c.stage, remove: c.remove });
  const got = r.code === 0 ? "accept" : "reject";
  let ok = got === c.expect;
  if (ok && c.checkMsg) ok = c.checkMsg(r.msgAfter);
  if (ok && c.expectOut) ok = c.expectOut.test(r.out);
  console.log(`${ok ? "✓" : "✗"} ${c.name}  [expect ${c.expect}, got ${got}${c.checkMsg ? `, msgcheck ${c.checkMsg(r.msgAfter)}` : ""}]`);
  if (!ok) { fail++; console.log("    ↳ hook output:\n" + r.out.split("\n").map(l => "      " + l).join("\n")); }
  else pass++;
  fs.rmSync(dir, { recursive: true, force: true });
}
console.log(`\n${pass}/${pass + fail} passed`);
process.exit(fail ? 1 : 0);
