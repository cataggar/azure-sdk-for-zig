#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote


LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
REFERENCE = re.compile(r"(?<!!)\[([^\]]+)\]\[([^\]]*)\]")
DEFINITION = re.compile(r"(?m)^\s*\[([^\]]+)\]:\s*(\S+)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
ROOT = Path.cwd().resolve()


def tracked_markdown() -> list[Path]:
    raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.md"])
    return [Path(item.decode()) for item in raw.split(b"\0") if item]


def link_target(raw: str) -> str:
    value = raw.strip()
    if value.startswith("<"):
        end = value.find(">")
        return value[1:end] if end >= 0 else value
    match = re.match(r"""(\S+)(?:\s+["'(].*)?$""", value)
    return match.group(1) if match else value


def main() -> int:
    failures: list[str] = []
    for markdown in tracked_markdown():
        text = markdown.read_text(encoding="utf-8")
        definitions = {
            label.casefold(): (target, text[:start].count("\n") + 1)
            for label, target, start in (
                (match.group(1), match.group(2), match.start())
                for match in DEFINITION.finditer(text)
            )
        }
        for line_number, line in enumerate(text.splitlines(), 1):
            for match in LINK.finditer(line):
                validate_target(
                    markdown,
                    line_number,
                    link_target(match.group(1)),
                    failures,
                )
            for match in REFERENCE.finditer(line):
                label = (match.group(2) or match.group(1)).casefold()
                definition = definitions.get(label)
                if definition is None:
                    failures.append(
                        f"{markdown}:{line_number}: missing link definition [{label}]"
                    )

        for target, line_number in definitions.values():
            validate_target(markdown, line_number, link_target(target), failures)

    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print("documentation links valid")
    return 0


def validate_target(
    markdown: Path,
    line_number: int,
    target: str,
    failures: list[str],
) -> None:
    if not target or target.startswith("#") or SCHEME.match(target):
        return
    path_text = unquote(target.split("#", 1)[0].split("?", 1)[0])
    if not path_text:
        return
    resolved = (markdown.parent / path_text).resolve()
    if resolved != ROOT and ROOT not in resolved.parents:
        failures.append(
            f"{markdown}:{line_number}: link escapes repository {target}"
        )
    elif not resolved.exists():
        failures.append(f"{markdown}:{line_number}: missing link target {target}")


if __name__ == "__main__":
    raise SystemExit(main())
