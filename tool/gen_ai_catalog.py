#!/usr/bin/env python3
"""Generate the machine-readable AI catalog for harmony_ui.

Usage (run from anywhere):

    python3 tool/gen_ai_catalog.py           # regenerate doc/ai/* and llms.txt
    python3 tool/gen_ai_catalog.py --check  # fail if generated files are stale
    python3 tool/gen_ai_catalog.py --stats  # print extraction coverage

Why this exists
---------------
The repository already has very good human prose (README 63 KB, a 102 KB
shape matrix, a 20 KB migration guide, ~460 KB in total). An AI assistant
cannot load that wholesale, so it retrieves fragments -- and a stale fragment
is worse than no documentation at all. This script turns the *existing*
sources into one deterministic, machine-readable index.

Three rules keep the catalog trustworthy:

1. ``lib/harmony_ui.dart`` (the barrel) is the only definition of "public".
   A symbol in ``lib/src`` that is not exported is not offered to an AI.
2. Output is fully deterministic: no timestamps, stable ordering. That is
   what makes ``--check`` a real drift gate instead of a noisy one.
3. The catalog is an INDEX, not the source of truth. Every symbol carries
   ``file`` + ``line`` pointing back to Dart source, and anything the static
   scan is unsure about is marked with low confidence instead of guessed.
   An AI should verify against those anchors before writing code.

Only stdlib is used; no Dart SDK / pub get is required in CI.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BARREL = ROOT / "lib" / "harmony_ui.dart"
PUBSPEC = ROOT / "pubspec.yaml"
AI_DIR = ROOT / "doc" / "ai"
CATALOG = AI_DIR / "catalog.json"
INDEX_MD = AI_DIR / "API-INDEX.md"
LLMS = ROOT / "llms.txt"
CONTRACT = AI_DIR / "contract.json"
MIGRATION = ROOT / "doc" / "MIGRATION-0.6.md"
MATRIX = ROOT / "doc" / "CONTROL-MATRIX.md"
README = ROOT / "README.md"

SCHEMA_VERSION = 1


# --------------------------------------------------------------------------
# low level: masking, bracket matching, doc comments
# --------------------------------------------------------------------------

def mask_literals(src: str) -> str:
    """Replace comments and string bodies with spaces, preserving offsets.

    Keeping offsets identical means positions found in the masked text can be
    used to slice the original text. Newlines are preserved for line numbers.
    """
    out = list(src)
    n = len(src)
    i = 0
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            if j < 0:
                j = n
            for k in range(i, j):
                out[k] = " "
            i = j
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        elif c in ("'", '"'):
            triple = src[i:i + 3] == c * 3
            j = i + (3 if triple else 1)
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if triple and src[j:j + 3] == c * 3:
                    j += 3
                    break
                if not triple and src[j] == c:
                    j += 1
                    break
                if not triple and src[j] == "\n":
                    break
                j += 1
            for k in range(i, min(j, n)):
                if out[k] != "\n":
                    out[k] = " "
            i = j
        else:
            i += 1
    return "".join(out)


def match_bracket(masked: str, start: int, opening: str, closing: str) -> int:
    """Index of the bracket closing the one at ``start``; -1 if unbalanced."""
    depth = 0
    for i in range(start, len(masked)):
        if masked[i] == opening:
            depth += 1
        elif masked[i] == closing:
            depth -= 1
            if depth == 0:
                return i
    return -1


def split_top_level(text: str, sep: str = ",") -> list[str]:
    """Split on ``sep`` at bracket depth zero, ignoring strings."""
    masked = mask_literals(text)
    parts: list[str] = []
    depth = 0
    start = 0
    for i, ch in enumerate(masked):
        if ch in "([{<":
            # A bare '<' is usually a generic argument, not a bracket. Dart
            # generics never contain a top-level comma we care about unless
            # nested, so counting it is safe for splitting parameters.
            depth += 1
        elif ch in ")]}>":
            depth = max(0, depth - 1)
        elif ch == sep and depth == 0:
            parts.append(text[start:i])
            start = i + 1
    parts.append(text[start:])
    return [p.strip() for p in parts if p.strip()]


def doc_above(lines: list[str], idx: int, limit: int = 60) -> str:
    """Collect the contiguous ``///`` block above line ``idx`` (1-based)."""
    collected: list[str] = []
    j = idx - 2
    seen_annotation = False
    while j >= 0 and len(collected) < limit:
        stripped = lines[j].strip()
        if stripped.startswith("///"):
            # Drop only the single conventional space after `///`; keep any
            # further indentation so code fences stay faithful to source.
            tail = stripped[3:]
            collected.append(tail[1:] if tail.startswith(" ") else tail)
            j -= 1
            continue
        if stripped.startswith("@") and not collected:
            seen_annotation = True
            j -= 1
            continue
        if stripped == "" and collected and not seen_annotation:
            break
        if stripped == "" and not collected:
            break
        # An annotation between doc and declaration is fine.
        if stripped.startswith("@") and collected:
            j -= 1
            continue
        break
    return "\n".join(reversed(collected)).strip()


def dart_example(doc: str) -> str | None:
    m = re.search(r"```dart\s*\n(.*?)```", doc, re.S)
    if not m:
        return None
    return m.group(1).rstrip() or None


def first_sentence(doc: str) -> str:
    plain = re.sub(r"```.*?```", "", doc, flags=re.S)
    plain = re.sub(r"\s+", " ", plain).strip()
    plain = re.sub(r"\[([^\]]+)\]", r"\1", plain)
    return plain[:100]


# --------------------------------------------------------------------------
# source parsing
# --------------------------------------------------------------------------

CLASS_RE = re.compile(
    r"^(?:abstract\s+|final\s+|base\s+|sealed\s+|mixin\s+)*class\s+(\w+)"
)
ENUM_RE = re.compile(r"^enum\s+(\w+)")
TYPEDEF_RE = re.compile(r"^typedef\s+(\w+)")
FUNC_RE = re.compile(r"^([\w<>?,\s]+?)\s+([a-z]\w*)\s*(?:<[^>]*>)?\s*\(")
DECL_PREFIXES = (
    "import ", "export ", "library", "part ", "class ", "enum ", "typedef ",
    "abstract ", "final ", "const ", "@", "///", "//", "extension ",
)


def public_files() -> list[str]:
    """Only files exported from the barrel count as public API."""
    text = BARREL.read_text(encoding="utf-8")
    files = re.findall(r"^export\s+'([^']+)';", text, re.M)
    return ["lib/" + f for f in files]


def field_docs_and_types(body_lines: list[str]) -> tuple[dict[str, str], dict[str, str]]:
    """Collect only *class-level* field declarations.

    Method-local `final` declarations must be ignored. A naive "every line
    starting with final" scan picks up e.g. `final double? explicit =
    optionWidth;` inside a method and reports `optionWidth` with the bogus
    type `double? explicit =`. Bracket depth 0 relative to the class body is
    the reliable discriminator.
    """
    types: dict[str, str] = {}
    docs: dict[str, str] = {}
    depth = 0
    for i, line in enumerate(body_lines, 1):
        stripped = line.strip()
        if depth == 0:
            m = re.match(r"^final\s+([\w<>?,\s.]+?)\s+(\w+)\s*;\s*$", stripped)
            if m:
                name = m.group(2)
                types[name] = re.sub(r"\s+", " ", m.group(1)).strip()
                d = doc_above(body_lines, i)
                if d:
                    docs[name] = first_sentence(d)[:120]
        masked_line = mask_literals(line)
        depth += (
            masked_line.count("{") + masked_line.count("(")
            - masked_line.count("}") - masked_line.count(")")
        )
        depth = max(0, depth)
    return types, docs


def parse_params(raw: str, types: dict[str, str], docs: dict[str, str]) -> list[dict]:
    """Parse a Dart parameter list into name/required/default/type records."""
    body = raw.strip()
    # Unwrap the named-parameter braces if present.
    if body.startswith("{"):
        end = match_bracket(mask_literals(body), 0, "{", "}")
        if end > 0:
            body = body[1:end]
    params: list[dict] = []
    for chunk in split_top_level(body):
        piece = chunk.strip()
        if not piece or piece.startswith("//"):
            continue
        required = bool(re.search(r"\brequired\b", piece))
        default_match = re.search(r"\s=\s(.+)$", piece, re.S)
        default = default_match.group(1).strip() if default_match else None
        head = piece[:default_match.start()].strip() if default_match else piece
        head = re.sub(r"\brequired\b", "", head).strip()

        inherited = head.startswith("super.")
        name: str | None = None
        declared_type = None
        m_this = re.search(r"\bthis\.(\w+)", head)
        if m_this:
            name = m_this.group(1)
        elif inherited:
            name = head.split(".", 1)[1].strip()
        else:
            m_typed = re.match(r"^(.*?)\s+(\w+)$", head, re.S)
            if m_typed:
                declared_type = re.sub(r"\s+", " ", m_typed.group(1)).strip()
                name = m_typed.group(2)
        if not name:
            continue
        rec: dict = {
            "name": name,
            "required": required,
            "type": types.get(name) or declared_type,
        }
        if default is not None:
            rec["default"] = re.sub(r"\s+", " ", default).strip()
        if inherited:
            rec["inherited"] = True
        if name in docs:
            rec["doc"] = docs[name]
        params.append(rec)
    return params


def parse_file(rel: str) -> list[dict]:
    path = ROOT / rel
    src = path.read_text(encoding="utf-8")
    masked = mask_literals(src)
    lines = src.splitlines()
    mlines = masked.splitlines()
    symbols: list[dict] = []

    for idx, mline in enumerate(mlines, 1):
        cm = CLASS_RE.match(mline)
        em = ENUM_RE.match(mline)
        tm = TYPEDEF_RE.match(mline)
        # Top-level functions only. FUNC_RE's return-type character class
        # includes whitespace, so an indented class method would otherwise
        # match as a function declaration.
        fm = FUNC_RE.match(mline) if (
            mline[:1] not in (" ", "\t")
            and not mline.lstrip().startswith(("_", "@"))
        ) else None

        kind = None
        name = None
        if cm:
            kind, name = "class", cm.group(1)
        elif em:
            kind, name = "enum", em.group(1)
        elif tm:
            kind, name = "typedef", tm.group(1)
        elif fm and not mline.startswith(DECL_PREFIXES):
            ret, name = fm.group(1).strip(), fm.group(2)
            if not name.startswith("_") and ret and not ret.startswith("return"):
                kind = "function"

        if not kind or not name or name.startswith("_"):
            continue

        doc = doc_above(lines, idx)
        rec: dict = {
            "name": name,
            "kind": kind,
            "file": rel,
            "line": idx,
            "summary": first_sentence(doc),
        }
        if doc:
            rec["doc"] = doc
        example = dart_example(doc)
        if example:
            rec["example"] = example
        if re.search(r"@[Dd]eprecated", "\n".join(lines[max(0, idx - 6):idx])):
            rec["deprecated"] = True

        header = mline.strip()
        if kind == "class":
            ext = re.search(r"\bextends\s+([\w<>,?\s]+?)(?:\s+(?:with|implements)\b|\s*\{|$)", header)
            if ext:
                rec["extends"] = ext.group(1).strip()
        elif kind == "typedef":
            tm2 = re.search(r"=\s*([^;]+)", mline)
            if tm2:
                rec["aliases"] = tm2.group(1).strip()
        elif kind == "function":
            rec["returns"] = fm.group(1).strip()

        # Locate the declaration body / signature. Class and enum bodies are
        # delimited by their first '{'; searching for '(' first would land on
        # a constructor's named-parameter block instead of the class body.
        decl_offset = sum(len(x) + 1 for x in lines[:idx - 1])
        if kind in ("class", "enum"):
            brace = masked.find("{", decl_offset)
            body_end = match_bracket(masked, brace, "{", "}") if brace >= 0 else -1
            if body_end > 0:
                body_src = src[brace + 1:body_end]
                body_lines = body_src.splitlines()
                if kind == "enum":
                    vals = []
                    for piece in split_top_level(body_src):
                        vm = re.match(r"^(\w+)", piece.strip())
                        if vm:
                            vals.append(vm.group(1))
                    rec["values"] = vals
                else:
                    types, fdocs = field_docs_and_types(body_lines)
                    ctors = []
                    ctor_re = re.compile(
                        r"^\s*(?P<prefix>const\s+|factory\s+)?"
                        + re.escape(name) + r"(?:\.(?P<named>\w+))?\s*\("
                    )
                    for bi, bline in enumerate(body_lines, 1):
                        cm2 = ctor_re.match(bline)
                        if not cm2:
                            continue
                        abs_offset = brace + 1 + sum(
                            len(x) + 1 for x in body_lines[:bi - 1]
                        )
                        lp = masked.find("(", abs_offset)
                        if lp < 0 or lp >= abs_offset + len(bline) + 1:
                            continue
                        rp = match_bracket(masked, lp, "(", ")")
                        if rp < 0:
                            continue
                        nm = cm2.group("named")
                        params = parse_params(src[lp + 1:rp], types, fdocs)
                        # A static method call can look like a named ctor, but
                        # it never binds fields / super params / defaults.
                        confident = (
                            nm is None
                            or cm2.group("prefix") is not None
                            or any(
                                p.get("inherited") or p.get("default") is not None
                                or p["required"] for p in params
                            )
                        )
                        entry: dict = {
                            "name": f"{name}.{nm}" if nm else name,
                            "line": src[:lp].count("\n") + 1,
                            "params": params,
                        }
                        if not confident:
                            entry["confidence"] = "low"
                            entry["note"] = (
                                "May be a static method call rather than a "
                                "constructor; verify at the source line."
                            )
                        ctors.append(entry)
                    if ctors:
                        rec["constructors"] = ctors
                    if types:
                        rec["fields"] = [
                            {"name": k, "type": v} for k, v in sorted(types.items())
                        ]
        elif kind == "function":
            lp = masked.find("(", decl_offset)
            rp = match_bracket(masked, lp, "(", ")") if lp >= 0 else -1
            if rp > 0:
                rec["params"] = parse_params(src[lp + 1:rp], {}, {})

        # Upstream provenance clues extracted from doc comments (never guessed).
        if doc:
            hints: dict[str, list[str]] = {}
            for key, pattern in (
                ("apiDocs", r"`([\w-]+\.md)`"),
                ("resourceTables", r"`([\w_]+\.json)`"),
                ("tokens", r"`(sys\.[\w.]+)`"),
                ("designTopics", r"《([^》]+)》"),
                ("upstreamSymbols", r"`(Hds[A-Z]\w*|ts-[\w-]+|Ohos[A-Z]\w*Variant)`"),
            ):
                found = sorted(set(re.findall(pattern, doc)))
                if found:
                    hints[key] = found
            if hints:
                rec["upstream"] = hints
        symbols.append(rec)
    return symbols


# --------------------------------------------------------------------------
# cross references and derived facts
# --------------------------------------------------------------------------

def read_lines(rel: str) -> list[str]:
    p = ROOT / rel
    return p.read_text(encoding="utf-8").splitlines() if p.exists() else []


def parse_migration() -> list[dict]:
    """The 12 breaking changes come from the migration table, not from memory."""
    out = []
    for line in read_lines(str(MIGRATION.relative_to(ROOT))):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 5 or not cells[0].isdigit():
            continue
        syms = re.findall(r"`(Ohos\w+)`", cells[1])
        out.append({
            "no": int(cells[0]),
            "symbols": syms,
            "change": re.sub(r"`|\*\*", "", cells[2]),
            "compileError": "✅" in cells[3],
            "silentChange": "✅" in cells[4],
            "source": f"doc/MIGRATION-0.6.md#{cells[0]}",
        })
    return out


def parse_matrix() -> dict[str, list[dict]]:
    """Compress the 102 KB shape matrix into per-symbol rows."""
    out: dict[str, list[dict]] = {}
    section = ""
    for line in read_lines(str(MATRIX.relative_to(ROOT))):
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        if not line.startswith("|") or set(line.replace("|", "").strip()) <= set("- "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4:
            continue
        for sym in sorted(set(re.findall(r"\b(Ohos[A-Z]\w*)", cells[3]))):
            out.setdefault(sym, []).append({
                "control": cells[0],
                "form": cells[1],
                "basis": cells[2],
                "implementation": cells[3][:220],
                "section": section,
            })
    return out


def collect_refs(symbols: list[dict]) -> None:
    readme = read_lines("README.md")
    migration_lines = read_lines("doc/MIGRATION-0.6.md")
    example_files = sorted((ROOT / "example" / "lib").rglob("*.dart"))
    test_files = sorted((ROOT / "test").rglob("*.dart")) + sorted(
        (ROOT / "example" / "test").rglob("*.dart")
    )
    example_text = {
        str(p.relative_to(ROOT)): p.read_text(encoding="utf-8") for p in example_files
    }
    test_text = {
        str(p.relative_to(ROOT)): p.read_text(encoding="utf-8") for p in test_files
    }
    for rec in symbols:
        name = rec["name"]
        refs: dict = {}
        rl = [i + 1 for i, l in enumerate(readme) if name in l]
        ml = [i + 1 for i, l in enumerate(migration_lines) if name in l]
        if rl:
            refs["readmeLines"] = rl[:12]
        if ml:
            refs["migrationLines"] = ml[:12]
        pattern = re.compile(r"\b" + re.escape(name) + r"\b")
        refs["exampleFiles"] = sorted(f for f, t in example_text.items() if pattern.search(t))[:8]
        refs["testFiles"] = sorted(f for f, t in test_text.items() if pattern.search(t))[:8]
        rec["refs"] = refs


def load_contract() -> dict:
    if not CONTRACT.exists():
        return {}
    return json.loads(CONTRACT.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

def version() -> str:
    m = re.search(r"^version:\s*(\S+)", PUBSPEC.read_text(encoding="utf-8"), re.M)
    return m.group(1) if m else "unknown"


def build() -> tuple[dict, dict[str, str]]:
    files = public_files()
    symbols: list[dict] = []
    for rel in files:
        if (ROOT / rel).exists():
            symbols.extend(parse_file(rel))
    symbols.sort(key=lambda r: (r["file"], r["line"]))
    collect_refs(symbols)

    breaking = parse_migration()
    # Never hard-code "how many breaking changes are silent": derive it from
    # the table. Prose in README / older notes says 2 or 3 depending on
    # whether only the audit round is counted; the table is the authority.
    breaking_summary = {
        "total": len(breaking),
        "compileErrorNos": [b["no"] for b in breaking if b["compileError"]],
        "silentOnlyNos": [b["no"] for b in breaking if not b["compileError"]],
        "visualChangeNos": [b["no"] for b in breaking if b["silentChange"]],
        "note": (
            "silentOnlyNos produce no compile error at all. visualChangeNos "
            "still change appearance even after the compile error is fixed."
        ),
    }
    matrix = parse_matrix()
    by_name: dict[str, dict] = {}
    for rec in symbols:
        by_name.setdefault(rec["name"], rec)
        if rec["name"] in matrix:
            rec["officialForms"] = [
                {"control": f["control"], "form": f["form"], "basis": f["basis"]}
                for f in matrix[rec["name"]]
            ]
            rec["officialFormsCount"] = len(matrix[rec["name"]])
        hits = [b for b in breaking if rec["name"] in b["symbols"]]
        if hits:
            rec["breaking"] = [
                {"no": b["no"], "change": b["change"],
                 "compileError": b["compileError"], "silentChange": b["silentChange"],
                 "source": b["source"]}
                for b in hits
            ]

    contract = load_contract()
    # Validate that hand-written contract rules still point at real symbols.
    unknown = []
    for rule in contract.get("invariants", []):
        for sym in rule.get("symbols", []):
            if sym not in by_name:
                unknown.append(f"{rule.get('id', '?')}: {sym}")
    for b in breaking:
        for sym in b["symbols"]:
            if sym not in by_name:
                unknown.append(f"MIGRATION #{b['no']}: {sym}")

    counts = {
        "publicFiles": len(files),
        "symbols": len(symbols),
        "classes": sum(1 for s in symbols if s["kind"] == "class"),
        "enums": sum(1 for s in symbols if s["kind"] == "enum"),
        "typedefs": sum(1 for s in symbols if s["kind"] == "typedef"),
        "functions": sum(1 for s in symbols if s["kind"] == "function"),
        "constructors": sum(len(s.get("constructors", [])) for s in symbols),
        "withExample": sum(1 for s in symbols if "example" in s),
        "withOfficialForms": sum(1 for s in symbols if "officialForms" in s),
        "withBreakingChange": sum(1 for s in symbols if "breaking" in s),
        "lowConfidenceConstructors": sum(
            1 for s in symbols for c in s.get("constructors", [])
            if c.get("confidence") == "low"
        ),
    }
    def slim_symbol(rec: dict) -> dict:
        """Index-sized record. Full doc text is deliberately NOT copied here:
        duplicating 81 files of prose would make the catalog heavier than the
        README it replaces. Read the prose from `file:line` on demand instead.
        """
        keys = (
            "name", "kind", "file", "line", "extends", "returns", "values",
            "aliases", "deprecated", "summary", "example", "constructors",
            "params", "upstream", "officialForms", "officialFormsCount",
            "breaking", "refs",
        )
        out = {k: rec[k] for k in keys if k in rec}
        if "refs" in out:
            out["refs"] = {
                k: v for k, v in out["refs"].items()
                if k in ("exampleFiles", "testFiles")
            }
        return out

    catalog = {
        "schemaVersion": SCHEMA_VERSION,
        "package": "harmony_ui",
        "version": version(),
        "publicEntry": "package:harmony_ui/harmony_ui.dart",
        "generatedBy": "tool/gen_ai_catalog.py",
        "truthAnchor": (
            "Every record carries file+line into Dart source. This catalog is an "
            "index, not the source of truth: verify values at those anchors or "
            "run `python3 tool/ai_lookup.py <Symbol>` before relying on them."
        ),
        "howToUse": [
            "Never invent an Ohos* symbol name. Resolve it against symbols[].name first; the barrel lib/harmony_ui.dart is the only public boundary.",
            "Read constructors[].params for names, required flags and defaults. Defaults are static-scan results and may be marked low confidence.",
            "Check breaking[] and contract.invariants[] before emitting code for an upgrade. See breakingSummary.silentOnlyNos: those changes produce no compile error at all.",
            "officialForms[] comes from the official shape matrix and is grouped by device class. Do not apply wearable values to phone/tablet layouts.",
            "For full prose (why a parameter exists, official provenance, known non-goals), read the source at file:line -- it is not duplicated in this catalog.",
            "Prefer `python3 tool/ai_lookup.py <Symbol>` over loading this whole file when working on one control.",
        ],
        "counts": counts,
        "designSlugs": sorted(
            p.name.split("-")[0] for p in (ROOT / "doc" / "reference" / "design").glob("*.md")
        ),
        "uxSpecSlugs": sorted(
            p.stem for p in (ROOT / "doc" / "ux-specs").glob("*.md")
        ),
        "breakingChanges": breaking,
        "breakingSummary": breaking_summary,
        "contract": contract,
        "symbols": [slim_symbol(s) for s in symbols],
        "unresolvedContractSymbols": sorted(set(unknown)),
    }

    # ---- API-INDEX.md: compact enough to fit in a small context window ----
    md = [
        "# AI API index (generated)",
        "",
        f"> harmony_ui {version()} | {counts['symbols']} public symbols in "
        f"{counts['publicFiles']} exported files. Generated by "
        "`tool/gen_ai_catalog.py` -- do not edit by hand.",
        "> Every line points back to Dart source. Query one symbol with "
        "`python3 tool/ai_lookup.py OhosButton`.",
        "",
        "`✓` = has a copyable Dart example in its doc comment; "
        "`⚠` = affected by a 0.5.0 -> 0.6.0 breaking change; "
        "`S` = silent (no compile error).",
        "",
    ]
    current_file = None
    for s in symbols:
        if s["file"] != current_file:
            current_file = s["file"]
            md += ["", f"## `{current_file}`", ""]
        bits = [f"`{s['name']}`", s["kind"]]
        if s.get("extends"):
            bits.append("extends " + s["extends"])
        ctors = s.get("constructors") or ([{"params": s.get("params", [])}] if s.get("params") else [])
        if ctors:
            sig = []
            for p in ctors[0]["params"][:14]:
                piece = p["name"]
                if p.get("required"):
                    piece = "required " + piece
                if p.get("default") is not None:
                    piece += "=" + p["default"]
                sig.append(piece)
            more = len(ctors[0]["params"]) - 14
            bits.append("(" + ", ".join(sig) + (f", +{more}" if more > 0 else "") + ")")
        if s.get("values"):
            bits.append("{" + ", ".join(s["values"][:8]) + ("..." if len(s["values"]) > 8 else "") + "}")
        flags = []
        if "example" in s:
            flags.append("✓")
        if s.get("officialForms"):
            flags.append(f"{len(s['officialForms'])} forms")
        if s.get("breaking"):
            flags.append("⚠" + ",".join(str(b["no"]) for b in s["breaking"]))
            if any(b["silentChange"] for b in s["breaking"]):
                flags.append("S")
        line = "- " + " | ".join(bits)
        if flags:
            line += " | " + " ".join(flags)
        line += f" | `{s['file']}:{s['line']}`"
        md.append(line)

    # ---- llms.txt ----
    llms = [
        "# harmony_ui",
        "",
        "> HarmonyOS design language widgets for Flutter, targeting HarmonyOS 7 "
        "and Flutter 3.50. 42 official controls, "
        f"{counts['symbols']} public symbols, version {version()}. "
        "Import only `package:harmony_ui/harmony_ui.dart`.",
        "",
        "## Start here (small, safe to load)",
        "",
        "- [AGENTS.md](AGENTS.md): rules for AI coding agents -- import boundary, forbidden patterns, verification commands.",
        "- [AI API index](doc/ai/API-INDEX.md): one compact line per public symbol with constructor defaults and source anchors.",
        "- [Machine-readable catalog](doc/ai/catalog.json): full API index, official shape matrix, breaking changes, cross references.",
        "- [Semantic contract](doc/ai/contract.json): invariants that a compiler cannot check (theme / e-ink / policy).",
        "- [AI-friendly roadmap](doc/ai/AI-FRIENDLY-ROADMAP.md): how this layer is meant to grow.",
        "",
        "## Migration and specification",
        "",
        f"- [0.5.0 to 0.6.0 migration](doc/MIGRATION-0.6.md): {breaking_summary['total']} breaking changes; {len(breaking_summary['silentOnlyNos'])} produce no compile error.",
        "- [Control shape matrix](doc/CONTROL-MATRIX.md): official forms per device class. Large; prefer `catalog.json` -> `officialForms`.",
        "- [0.6 audit](doc/AUDIT-0.6.md): per-control conformance verdicts.",
        "- [Upstream mirror README](doc/reference/README.md): how the official specs are mirrored and refreshed.",
        "",
        "## Optional (large; do not load wholesale)",
        "",
        "- [README](README.md): overview, install, coverage table, 27 Dart snippets.",
        "- [CHANGELOG](CHANGELOG.md): full history.",
        "- [Roadmap](doc/ROADMAP-0.6.md): historical planning document.",
        "",
    ]
    outputs = {
        str(CATALOG): json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        str(INDEX_MD): "\n".join(md) + "\n",
        str(LLMS): "\n".join(llms) + "\n",
    }
    return catalog, outputs


def main() -> int:
    args = set(sys.argv[1:])
    catalog, outputs = build()
    AI_DIR.mkdir(parents=True, exist_ok=True)

    if "--stats" in args:
        print(json.dumps(catalog["counts"], ensure_ascii=False, indent=2))
        print("unresolvedContractSymbols:", catalog["unresolvedContractSymbols"])
        return 0

    if catalog["unresolvedContractSymbols"]:
        print("ERROR: contract / migration references symbols not in the public API:", file=sys.stderr)
        for item in catalog["unresolvedContractSymbols"]:
            print("  " + item, file=sys.stderr)
        return 2

    if "--check" in args:
        stale = []
        for path, content in outputs.items():
            p = Path(path)
            if not p.exists() or p.read_text(encoding="utf-8") != content:
                stale.append(str(p.relative_to(ROOT)))
        if stale:
            print("ERROR: generated AI catalog is stale:", file=sys.stderr)
            for s in stale:
                print("  " + s, file=sys.stderr)
            print("Run: python3 tool/gen_ai_catalog.py", file=sys.stderr)
            return 1
        print("OK: AI catalog is up to date (%d outputs)." % len(outputs))
        return 0

    for path, content in outputs.items():
        Path(path).write_text(content, encoding="utf-8")
        print("wrote", Path(path).relative_to(ROOT), len(content.encode()), "bytes")
    print(json.dumps(catalog["counts"], ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
