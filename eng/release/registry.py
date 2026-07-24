#!/usr/bin/env python3
"""Read the release fields from eng/packages.zig without duplicating metadata."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


class RegistryError(RuntimeError):
    pass


@dataclass(frozen=True)
class Package:
    name: str
    ownership: str
    workspace_path: str | None
    historical_source_path: str
    branch: str
    version: str
    historical_names: tuple[str, ...]
    dependencies: tuple[str, ...]
    external_dependencies: tuple[str, ...]
    publish_paths: tuple[str, ...]
    test_command: str | None
    examples_command: str | None
    live_test_command: str | None
    regeneration_command: str | None

    @property
    def source_path(self) -> str:
        if self.workspace_path is None:
            raise RegistryError(f"{self.name}: package is not present in this workspace")
        return self.workspace_path


def _matching_brace(text: str, opening: int) -> int:
    depth = 0
    quote = False
    escape = False
    for index in range(opening, len(text)):
        char = text[index]
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                quote = False
            continue
        if char == '"':
            quote = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
    raise RegistryError("unbalanced braces in eng/packages.zig")


def _array_body(text: str, marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        raise RegistryError(f"missing registry marker: {marker}")
    opening = text.find("{", start)
    return text[opening + 1 : _matching_brace(text, opening)]


def _strings(text: str) -> tuple[str, ...]:
    return tuple(re.findall(r'"((?:[^"\\]|\\.)*)"', text))


def _field_string(block: str, field: str, default: str | None = None) -> str | None:
    match = re.search(
        rf"(?m)^\s*\.{re.escape(field)}\s*=\s*"
        r'("(?:[^"\\]|\\.)*"|null)\s*,',
        block,
    )
    if not match:
        return default
    value = match.group(1)
    if value == "null":
        return None
    return bytes(value[1:-1], "utf-8").decode("unicode_escape")


def _field_enum(block: str, field: str, default: str) -> str:
    match = re.search(
        rf"(?m)^\s*\.{re.escape(field)}\s*=\s*\.([A-Za-z_][A-Za-z0-9_]*)\s*,",
        block,
    )
    return match.group(1) if match else default


def _field_array(
    block: str,
    field: str,
    constants: dict[str, tuple[str, ...]],
) -> tuple[str, ...]:
    marker = re.search(
        rf"(?m)^\s*\.{re.escape(field)}\s*=\s*([^,]+|\&\.\{{)",
        block,
    )
    if not marker:
        return ()
    value_start = marker.start(1)
    tail = block[value_start:]
    if tail.startswith("&.{"):
        opening = value_start + 2
        return _strings(block[opening + 1 : _matching_brace(block, opening)])
    name = re.match(r"([A-Za-z_][A-Za-z0-9_]*)", tail)
    if name and name.group(1) in constants:
        return constants[name.group(1)]
    raise RegistryError(f"unsupported {field} expression in eng/packages.zig")


def load(path: Path) -> dict[str, Package]:
    text = path.read_text(encoding="utf-8")
    constants: dict[str, tuple[str, ...]] = {}
    for match in re.finditer(
        r"(?m)^const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*&\.\{",
        text,
    ):
        opening = text.find("{", match.start())
        constants[match.group(1)] = _strings(
            text[opening + 1 : _matching_brace(text, opening)]
        )

    body = _array_body(text, "pub const all = [_]Package{")
    packages: dict[str, Package] = {}
    cursor = 0
    while True:
        match = re.search(r"\.\s*\{", body[cursor:])
        if not match:
            break
        opening = cursor + match.end() - 1
        closing = _matching_brace(body, opening)
        block = body[opening + 1 : closing]
        cursor = closing + 1

        name = _field_string(block, "name")
        historical_source_path = _field_string(block, "historical_source_path")
        if historical_source_path is None:
            historical_source_path = _field_string(block, "source_path")
        workspace_path = _field_string(block, "workspace_path")
        if workspace_path is None and _field_string(block, "source_path") is not None:
            workspace_path = historical_source_path
        branch = _field_string(block, "branch")
        if not name or not historical_source_path or not branch:
            raise RegistryError(
                "package entry is missing name, historical_source_path, or branch"
            )
        package = Package(
            name=name,
            ownership=_field_enum(block, "ownership", "branch_owned"),
            workspace_path=workspace_path,
            historical_source_path=historical_source_path,
            branch=branch,
            version=_field_string(block, "version", "0.1.0") or "",
            historical_names=(
                _field_array(block, "historical_names", constants)
                or _field_array(block, "legacy_names", constants)
            ),
            dependencies=_field_array(block, "dependencies", constants),
            external_dependencies=_field_array(
                block, "external_dependencies", constants
            ),
            publish_paths=_field_array(block, "publish_paths", constants),
            test_command=_field_string(
                block, "test_command", "zig build test --summary all"
            ),
            examples_command=_field_string(block, "examples_command"),
            live_test_command=_field_string(block, "live_test_command"),
            regeneration_command=_field_string(block, "regeneration_command"),
        )
        if name in packages:
            raise RegistryError(f"duplicate package metadata: {name}")
        packages[name] = package

    if not packages:
        raise RegistryError("no package entries found in eng/packages.zig")
    for package in packages.values():
        unknown = set(package.dependencies) - packages.keys()
        if unknown:
            raise RegistryError(
                f"{package.name}: unknown dependencies: {sorted(unknown)}"
            )
    return packages
