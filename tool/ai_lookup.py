#!/usr/bin/env python3
"""One-symbol lookup for AI assistants working with harmony_ui.

Why: the repo has ~460 KB of prose. Loading it all wastes the context window
and, worse, surfaces stale fragments. This tool returns exactly one control's
contract plus the source anchors needed to verify it.

    python3 tool/ai_lookup.py OhosButton        # full, compact answer
    python3 tool/ai_lookup.py --search 下拉      # find a symbol by name/keyword
    python3 tool/ai_lookup.py --breaking        # all 12 migration items
    python3 tool/ai_lookup.py OhosButton --json # raw catalog record

Nothing here is cached twice: parameters/defaults come from catalog.json,
prose comes straight from the Dart source at file:line. If they ever disagree,
Dart source wins -- regenerate with `python3 tool/gen_ai_catalog.py`.
"""

from __future__ import annotations

import argparse
import difflib
import json
import sys
from pathlib import Path

from gen_ai_catalog import ROOT, doc_above  # type: ignore

CATALOG = ROOT / "doc" / "ai" / "catalog.json"


def load() -> dict:
    if not CATALOG.exists():
        sys.exit("catalog.json missing -- run: python3 tool/gen_ai_catalog.py")
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def source_doc(sym: dict) -> str:
    p = ROOT / sym["file"]
    if not p.exists():
        return ""
    lines = p.read_text(encoding="utf-8").splitlines()
    return doc_above(lines, sym["line"], limit=200)


def ctor_source(sym: dict, ctor: dict) -> str:
    p = ROOT / sym["file"]
    lines = p.read_text(encoding="utf-8").splitlines()
    start = max(0, ctor["line"] - 1)
    out = []
    for line in lines[start:start + 60]:
        out.append(line)
        stripped = line.rstrip()
        if stripped.endswith((");", "};")):
            break
        # `const X({` opens the named-parameter block, not the constructor
        # body. Only a bare '{' after the signature ends the signature.
        if stripped.endswith("{") and "({" not in stripped.replace(" ", ""):
            break
    return "\n".join(out).rstrip()


def fmt_symbol(cat: dict, sym: dict) -> str:
    out: list[str] = []
    out.append(
        f"harmony_ui {cat['version']} | {sym['name']} ({sym['kind']}"
        + (f", extends {sym['extends']}" if sym.get("extends") else "") + ")"
    )
    out.append(f"VERIFY AT SOURCE: {sym['file']}:{sym['line']}")
    out.append("import: package:harmony_ui/harmony_ui.dart  (barrel only)")
    if sym.get("summary"):
        out.append("summary: " + sym["summary"])
    if sym.get("deprecated"):
        out.append("*** DEPRECATED ***")
    out.append("")

    if sym.get("values"):
        out.append("ENUM VALUES: " + ", ".join(sym["values"]))
        out.append("")
    if sym.get("aliases"):
        out.append("TYPE ALIAS: " + sym["aliases"])
        out.append("")

    ctors = sym.get("constructors", [])
    if ctors:
        out.append("CONSTRUCTORS")
        for ct in ctors:
            flag = "  [LOW CONFIDENCE -- verify]" if ct.get("confidence") == "low" else ""
            out.append(f"  {ct['name']}  (line {ct['line']}){flag}")
            for p in ct["params"]:
                bits = [f"    {p['name']}"]
                bits.append(p.get("type") or "(inherited super param)")
                if p["required"]:
                    bits.append("REQUIRED")
                if p.get("default") is not None:
                    bits.append("= " + p["default"])
                if p.get("inherited"):
                    bits.append("super")
                out.append("  ".join(bits))
                if p.get("doc"):
                    out.append("      // " + p["doc"])
        out.append("")
        out.append("CONSTRUCTOR SOURCE (verbatim):")
        out.append(ctor_source(sym, ctors[0]))
        out.append("")
    elif sym.get("params"):
        out.append("FUNCTION PARAMETERS")
        for p in sym["params"]:
            out.append(
                f"    {p['name']}: {p.get('type') or '?'}"
                + (" REQUIRED" if p["required"] else "")
                + (f" = {p['default']}" if p.get("default") is not None else "")
            )
        out.append("")

    if sym.get("example"):
        out.append("COPYABLE EXAMPLE (from doc comment):")
        out.append("    " + sym["example"].replace("\n", "\n    "))
        out.append("")

    if sym.get("officialForms"):
        out.append(f"OFFICIAL FORMS ({len(sym['officialForms'])} rows in CONTROL-MATRIX):")
        for f in sym["officialForms"][:14]:
            out.append(f"  - {f['control']} | {f['form']} | basis: {f['basis']}")
        if len(sym["officialForms"]) > 14:
            out.append(f"  ... +{len(sym['officialForms']) - 14} more")
        out.append("")

    if sym.get("breaking"):
        out.append("BREAKING CHANGES (0.5.0 -> 0.6.0):")
        for b in sym["breaking"]:
            tag = "SILENT, NO COMPILE ERROR" if b["silentChange"] else "compile error"
            out.append(f"  #{b['no']} [{tag}] {b['change']}  <- {b['source']}")
        out.append("")

    invs = [
        i for i in cat.get("contract", {}).get("invariants", [])
        if sym["name"] in i.get("symbols", [])
    ]
    if invs:
        out.append("SEMANTIC INVARIANTS (compiler cannot check these):")
        for i in invs:
            out.append(f"  [{i['id']}/{i['severity']}] {i['rule']}")
            out.append(f"      why: {i['why']}")
        out.append("")
    out.append("GENERAL RULES (apply to every symbol):")
    for i in cat.get("contract", {}).get("invariants", []):
        if not i.get("symbols"):
            out.append(f"  [{i['id']}/{i['severity']}] {i['rule']}")
    out.append("")

    refs = sym.get("refs", {})
    if refs.get("exampleFiles") or refs.get("testFiles"):
        out.append("WORKING USAGE TO COPY FROM:")
        for f in refs.get("exampleFiles", []):
            out.append("  example: " + f)
        for f in refs.get("testFiles", []):
            out.append("  test:    " + f)
        out.append("")

    doc = source_doc(sym)
    if doc:
        out.append("SOURCE DOC COMMENT (verbatim from Dart, authoritative):")
        out.append("    " + doc.replace("\n", "\n    "))
    out.append("")
    out.append(
        "REMINDER: defaults above are a static scan. If a value looks wrong, "
        f"open {sym['file']}:{sym['line']} before writing code."
    )
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("symbol", nargs="?")
    ap.add_argument("--search", metavar="KEYWORD")
    ap.add_argument("--breaking", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    cat = load()
    by_name = {s["name"]: s for s in cat["symbols"]}

    if args.breaking:
        for b in cat["breakingChanges"]:
            flags = []
            if b["compileError"]:
                flags.append("compile error")
            if b["silentChange"]:
                flags.append("SILENT")
            print(
                f"#{b['no']:>2} [{' + '.join(flags) or 'no signal':<28}] "
                f"{', '.join(b['symbols']) or '?'} :: {b['change']}"
            )
        summary = cat.get("breakingSummary", {})
        print(
            "\ntotal: {} | compile errors: {} | NO compile error: {} | "
            "visual change after fixing: {}".format(
                summary.get("total", len(cat["breakingChanges"])),
                summary.get("compileErrorNos", []),
                summary.get("silentOnlyNos", []),
                summary.get("visualChangeNos", []),
            )
        )
        print("source: doc/MIGRATION-0.6.md (parsed on every run, not copied)")
        return 0

    if args.search:
        key = args.search.lower()
        def haystack(s: dict) -> str:
            parts = [
                s["name"], s["file"], s.get("summary") or "",
                s.get("example") or "",
                " ".join(f["control"] + " " + f["form"]
                         for f in s.get("officialForms", [])),
            ]
            return " ".join(parts).lower()

        hits = [s for s in cat["symbols"] if key in haystack(s)]
        if not hits:
            print(f"no symbol matches {args.search!r}")
            return 1
        for s in hits[:25]:
            print(
                f"{s['name']:<38} {s['kind']:<9} {s['file']}:{s['line']}"
                + ("  [breaking]" if s.get("breaking") else "")
            )
        print(f"\n{len(hits)} match(es). Run: python3 tool/ai_lookup.py <Symbol>")
        return 0

    if not args.symbol:
        ap.print_help()
        return 1

    sym = by_name.get(args.symbol)
    if not sym:
        all_names = [s["name"] for s in cat["symbols"]]
        close = difflib.get_close_matches(args.symbol, all_names, n=8, cutoff=0.55)
        print(f"'{args.symbol}' is NOT a public symbol in harmony_ui {cat['version']}.")
        print("Do not invent an Ohos* name. Closest real symbols:", ", ".join(close) or "(none)")
        print("Try: python3 tool/ai_lookup.py --search <keyword>")
        return 1

    if args.json:
        print(json.dumps(sym, ensure_ascii=False, indent=2))
    else:
        print(fmt_symbol(cat, sym))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
