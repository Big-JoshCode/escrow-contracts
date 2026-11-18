#!/usr/bin/env python3
"""Checks that docs/CONTRACT.md and README.md describe the bounty_escrow contract as it is.

Sources of truth: contracts/bounty_escrow/src/lib.rs (public entry points),
errors.rs (error numbers) and events.rs (event topics). Checks:

- every `pub fn` in the contract is named in docs/CONTRACT.md's "Entry points";
- the "Errors" list equals errors.rs exactly, names and numbers;
- every event topic is named in "Events";
- README.md states the current number of entry points.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CRATE = ROOT / "contracts" / "bounty_escrow" / "src"
CONTRACT_MD = ROOT / "docs" / "CONTRACT.md"
README = ROOT / "README.md"


def section(text: str, heading: str) -> str:
    m = re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not m:
        raise SystemExit(f"error: docs/CONTRACT.md has no '## {heading}' section")
    return m.group(1)


def main() -> int:
    lib = (CRATE / "lib.rs").read_text()
    errors_src = (CRATE / "errors.rs").read_text()
    events_src = (CRATE / "events.rs").read_text()
    fns = re.findall(r"^    pub fn (\w+)", lib, re.M)
    codes = dict(re.findall(r"^\s+(\w+) = (\d+),", errors_src, re.M))
    topics = re.findall(r'topics = \["bounty", "(\w+)"\]', events_src)

    doc = CONTRACT_MD.read_text()
    problems = []

    entry = section(doc, "Entry points")
    for fn in fns:
        if not re.search(rf"`[^`]*\b{fn}\b[^`]*`", entry):
            problems.append(f"entry point `{fn}` is not documented in docs/CONTRACT.md (Entry points)")

    doc_codes = dict(re.findall(r"\b([A-Za-z]+)=(\d+)\b", section(doc, "Errors")))
    for name, number in codes.items():
        if name not in doc_codes:
            problems.append(f"error {name}={number} is missing from docs/CONTRACT.md (Errors)")
        elif doc_codes[name] != number:
            problems.append(f"error {name} is {number} in errors.rs but {doc_codes[name]} in docs/CONTRACT.md")
    for name in doc_codes:
        if name not in codes:
            problems.append(f"docs/CONTRACT.md lists error {name}, which errors.rs does not define")

    events = section(doc, "Events")
    for topic in topics:
        if f"`{topic}`" not in events:
            problems.append(f"event `{topic}` is not documented in docs/CONTRACT.md (Events)")

    m = re.search(r"(\d+) entry points", README.read_text())
    if not m or int(m.group(1)) != len(fns):
        found = m.group(1) if m else "no count"
        problems.append(f"README.md says {found} entry points; the contract has {len(fns)}")

    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        return 1
    print(f"ok: docs match the contract ({len(fns)} entry points, {len(codes)} errors, {len(topics)} events)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
