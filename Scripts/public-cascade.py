#!/usr/bin/env python3
"""Promote top-level types and their direct members in MeditateAndNoteCore to
`public`, using brace depth rather than indentation.

Depth is the only reliable signal: indentation is ambiguous in Swift and a
previous indentation-based version injected `public` inside function bodies.

Visibility rules this encodes:
  - depth 0 type declarations -> public
  - depth 0 extensions -> public (so their members can be promoted)
  - depth 1 members of a type -> public, unless the container is a protocol
    (protocol members take no modifier) or a public extension (they inherit it)
  - depth 1 `enum case` -> never public
  - depth >= 2 -> never touched (function bodies, closures, nested members)

Anything a regex cannot see is left to compiler diagnostics, which are
authoritative. Run from a clean tree; it is idempotent but is not a formatter.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore"
SELF_MODULE = "MeditateAndNoteCore"

ACCESS = r"(?:public|private|fileprivate|internal|open|package)"
MODS = r"(?:static|lazy|weak|unowned|nonisolated|final|mutating|override|convenience|required|indirect|class|@\w+)"
KIND = r"(?:final\s+(?:class|actor)|class|actor|struct|enum|protocol)"
TOP_TYPE = re.compile(rf"^(?:public\s+)?{KIND}\s+(\w+)", re.M)
TOP_EXT = re.compile(r"^extension\s+(\w+)\b")
MEMBER = re.compile(rf"^\s+(?:{MODS}\s+)*(?:let|var|func|init|subscript|typealias|associatedtype|{KIND})\b")
ACCESSED = re.compile(rf"^\s+(?:@[A-Za-z]+\s+)*(?:{ACCESS})\b")
CASE = re.compile(r"^\s+(?:@\w+\s+)*(?:indirect\s+)?case\s")
DECL_KIND = re.compile(rf"^(?:public\s+)?{KIND}\s+(\w+)")
EXT_KIND = re.compile(r"^extension\s")


def already_public(line):
    return re.match(r"^public\b", line) is not None


def container_for_depth0(line):
    """Return 'protocol' | 'enum' | 'extension' | 'type' for a depth-0 decl."""
    if EXT_KIND.match(line):
        return "extension"
    m = re.match(rf"^(?:public\s+)?{KIND}\s+(\w+)", line)
    if not m:
        return None
    kind = re.match(rf"^(?:public\s+)?{KIND}", line).group(0)
    # enums behave like types here: `case` is excluded separately by CASE.
    return "protocol" if "protocol" in kind else "type"


def run(paths):
    changed = []
    for path in paths:
        lines = path.read_text().splitlines()
        out, touched = [], False
        depth = 0
        container = None
        in_public_ext = False

        for line in lines:
            stripped = line.strip()
            if stripped == f"import {SELF_MODULE}":
                touched = True
                depth += line.count("{") - line.count("}")
                continue

            if depth == 0:
                if container_for_depth0(line) is not None:
                    kind = container_for_depth0(line)
                    if not already_public(line):
                        line = f"public {line}"
                        touched = True
                    container = kind
                    in_public_ext = kind == "extension" and already_public(line)
            elif depth == 1 and container in ("type", "extension") and not in_public_ext:
                if CASE.match(line):
                    pass
                elif MEMBER.match(line) and not ACCESSED.match(line):
                    indent = line[:len(line) - len(line.lstrip())]
                    line = f"{indent}public {stripped}"
                    touched = True

            out.append(line)
            depth += line.count("{") - line.count("}")

        if touched:
            path.write_text("\n".join(out) + "\n")
            changed.append(path)
    return changed


if __name__ == "__main__":
    args = sys.argv[1:]
    paths = [Path(a) for a in args] if args else sorted(ROOT.rglob("*.swift"))
    changed = run(paths)
    print(f"{len(changed)} files touched")
    for c in changed:
        print(f"  {c.relative_to(ROOT) if ROOT in c.parents else c}")