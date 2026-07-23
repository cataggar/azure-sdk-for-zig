#!/usr/bin/env python3
"""Small, syntax-aware helpers for the repository's build.zig.zon shape."""

from __future__ import annotations

from dataclasses import dataclass
import re


class ZonError(RuntimeError):
    pass


@dataclass(frozen=True)
class Dependency:
    name: str
    start: int
    end: int
    indent: str
    path: str | None
    url: str | None
    package_hash: str | None


@dataclass(frozen=True)
class Manifest:
    name: str
    version: str
    fingerprint: str
    minimum_zig_version: str
    dependencies: dict[str, Dependency]
    paths: tuple[str, ...]
    dependencies_open: int
    dependencies_close: int


SEMVER = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\Z"
)


def parse_semver(value: str) -> tuple[int, int, int]:
    match = SEMVER.fullmatch(value)
    if not match:
        raise ZonError(f"malformed release version: {value!r}")
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def _matching_brace(text: str, opening: int) -> int:
    depth = 0
    quote = False
    escape = False
    line_comment = False
    for index in range(opening, len(text)):
        char = text[index]
        if line_comment:
            if char == "\n":
                line_comment = False
            continue
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                quote = False
            continue
        if char == "/" and index + 1 < len(text) and text[index + 1] == "/":
            line_comment = True
        elif char == '"':
            quote = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
    raise ZonError("unbalanced braces in build.zig.zon")


def _required_string(text: str, field: str, identifier: bool = False) -> str:
    value = (
        r"\.([A-Za-z_][A-Za-z0-9_]*)"
        if identifier
        else r'"((?:[^"\\]|\\.)*)"'
    )
    match = re.search(
        rf"(?m)^\s*\.{re.escape(field)}\s*=\s*{value}\s*,", text
    )
    if not match:
        raise ZonError(f"missing or malformed .{field}")
    return match.group(1)


def _optional_string(text: str, field: str) -> str | None:
    match = re.search(
        rf'(?m)^\s*\.{re.escape(field)}\s*=\s*"((?:[^"\\]|\\.)*)"\s*,',
        text,
    )
    return match.group(1) if match else None


def _uncommented_strings(text: str) -> tuple[str, ...]:
    values: list[str] = []
    index = 0
    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue
        if text[index] != '"':
            index += 1
            continue
        index += 1
        value: list[str] = []
        while index < len(text):
            char = text[index]
            if char == "\\" and index + 1 < len(text):
                value.extend((char, text[index + 1]))
                index += 2
                continue
            if char == '"':
                values.append("".join(value))
                index += 1
                break
            value.append(char)
            index += 1
        else:
            raise ZonError("unterminated string in .paths")
    return tuple(values)


def _required_fingerprint(text: str) -> str:
    match = re.search(
        r"(?m)^\s*\.fingerprint\s*=\s*(0x[0-9a-fA-F]+)\s*,",
        text,
    )
    if not match:
        raise ZonError("missing or malformed .fingerprint")
    return match.group(1)


def _field_block(text: str, field: str) -> tuple[int, int]:
    match = re.search(
        rf"(?m)^\s*\.{re.escape(field)}\s*=\s*\.\{{", text
    )
    if not match:
        raise ZonError(f"missing .{field} block")
    opening = text.find("{", match.start())
    return opening, _matching_brace(text, opening)


def parse(text: str) -> Manifest:
    name = _required_string(text, "name", identifier=True)
    version = _required_string(text, "version")
    fingerprint = _required_fingerprint(text)
    minimum_zig_version = _required_string(text, "minimum_zig_version")
    if not minimum_zig_version.strip():
        raise ZonError(".minimum_zig_version must not be empty")
    dependencies_open, dependencies_close = _field_block(text, "dependencies")
    paths_open, paths_close = _field_block(text, "paths")
    paths = _uncommented_strings(text[paths_open + 1 : paths_close])

    dependencies: dict[str, Dependency] = {}
    body_start = dependencies_open + 1
    body = text[body_start:dependencies_close]
    cursor = 0
    entry_pattern = re.compile(
        r"(?m)^([ \t]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\.\{"
    )
    while True:
        match = entry_pattern.search(body, cursor)
        if not match:
            break
        opening = body_start + body.find("{", match.start())
        closing = _matching_brace(text, opening)
        comma = closing + 1
        while comma < len(text) and text[comma] in " \t":
            comma += 1
        if comma >= len(text) or text[comma] != ",":
            raise ZonError(f"dependency {match.group(2)} is missing a trailing comma")
        end = comma + 1
        block = text[opening + 1 : closing]
        dependency = Dependency(
            name=match.group(2),
            start=body_start + match.start(),
            end=end,
            indent=match.group(1),
            path=_optional_string(block, "path"),
            url=_optional_string(block, "url"),
            package_hash=_optional_string(block, "hash"),
        )
        if dependency.name in dependencies:
            raise ZonError(f"duplicate dependency: {dependency.name}")
        dependencies[dependency.name] = dependency
        cursor = end - body_start

    return Manifest(
        name=name,
        version=version,
        fingerprint=fingerprint,
        minimum_zig_version=minimum_zig_version,
        dependencies=dependencies,
        paths=paths,
        dependencies_open=dependencies_open,
        dependencies_close=dependencies_close,
    )


def rewrite_internal_dependencies(
    text: str,
    pins: dict[str, tuple[str, str]],
) -> str:
    manifest = parse(text)
    replacements: list[tuple[int, int, str]] = []
    for name, (url, package_hash) in pins.items():
        dependency = manifest.dependencies.get(name)
        if dependency is None:
            raise ZonError(f"missing internal dependency: {name}")
        if dependency.path is None or dependency.url is not None:
            raise ZonError(f"{name}: source dependency must be a local path")
        replacement = (
            f'{dependency.indent}.{name} = .{{\n'
            f'{dependency.indent}    .url = "{url}",\n'
            f'{dependency.indent}    .hash = "{package_hash}",\n'
            f"{dependency.indent}}},"
        )
        replacements.append((dependency.start, dependency.end, replacement))
    for start, end, replacement in sorted(replacements, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def rewrite_internal_paths(text: str, paths: dict[str, str]) -> str:
    manifest = parse(text)
    replacements: list[tuple[int, int, str]] = []
    for name, path in paths.items():
        dependency = manifest.dependencies.get(name)
        if dependency is None:
            raise ZonError(f"missing internal dependency: {name}")
        if (
            dependency.path is not None
            or dependency.url is None
            or dependency.package_hash is None
        ):
            raise ZonError(f"{name}: staged dependency must be an immutable pin")
        replacement = (
            f'{dependency.indent}.{name} = .{{\n'
            f'{dependency.indent}    .path = "{path}",\n'
            f"{dependency.indent}}},"
        )
        replacements.append((dependency.start, dependency.end, replacement))
    for start, end, replacement in sorted(replacements, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text
