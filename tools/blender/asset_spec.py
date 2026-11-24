"""Read the project's small YAML mapping/list subset, without Blender add-ons.

Supports indented mappings, scalar lists, flow mappings/lists and quoted scalars.
Flow collections may span lines. Rejects anchors, tags and block scalars.
No eval or network.
"""
import hashlib
from pathlib import Path
import re

from common import PARTS, ROOT

DEFAULT_SPEC = ROOT / 'assets/specs/k2_shieldman.yml'


def _uncomment(line):
    quote = None
    for i, ch in enumerate(line):
        if ch in ('"', "'"):
            if quote == ch:
                quote = None
            elif quote is None:
                quote = ch
        if ch == '#' and quote is None and (i == 0 or line[i - 1].isspace()):
            return line[:i]
    return line


def _scalar(value):
    value = value.strip()
    if value.startswith('{'):
        if not value.endswith('}'):
            raise ValueError('Unclosed inline mapping')
        return dict(_entry(field) for field in _flow_items(value[1:-1]))
    if value.startswith('['):
        if not value.endswith(']'):
            raise ValueError('Unclosed inline list')
        return [_scalar(field) for field in _flow_items(value[1:-1])]
    if value.startswith(('&', '*', '!', '|', '>')):
        raise ValueError(f'Unsupported YAML scalar: {value}')
    if value.startswith(('"', "'")):
        # A quoted colour embedded in Chinese prose is still a plain scalar.
        if value.endswith(value[0]) and value.count(value[0]) == 2:
            return value[1:-1]
        raise ValueError(f'Unsupported quoted scalar: {value}')
    if re.fullmatch(r'-?\d+(\.\d+)?', value):
        return float(value) if '.' in value else int(value)
    if value in ('true', 'false'):
        return value == 'true'
    return value


def _flow_items(value):
    quote, stack, start = None, [], 0
    for i, ch in enumerate(value):
        if ch in ('"', "'"):
            if quote == ch:
                quote = None
            elif quote is None:
                quote = ch
        elif quote is None:
            if ch in '{[':
                stack.append(ch)
            elif ch in '}]':
                if not stack or stack.pop() != {'}': '{', ']': '['}[ch]:
                    raise ValueError('Mismatched flow collection')
            elif ch == ',' and not stack:
                yield value[start:i].strip()
                start = i + 1
    if quote or stack:
        raise ValueError('Unclosed flow collection or quote')
    if value[start:].strip():
        yield value[start:].strip()


def _entry(text):
    key, sep, value = text.partition(':')
    if not sep or not re.fullmatch(r'[A-Za-z_][\w-]*', key.strip()):
        raise ValueError(f'Unsupported YAML mapping: {text}')
    return key.strip(), _scalar(value) if value.strip() else None


def load_spec(path=DEFAULT_SPEC):
    path = Path(path).resolve()
    lines = []
    pending = 0
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        if '\t' in raw:
            raise ValueError(f'{path}:{number}: use spaces for indentation')
        clean = _uncomment(raw).rstrip()
        if clean.strip():
            # A continued flow mapping/list is one logical YAML line. Preserve
            # its starting indentation for the block parser below.
            if lines and pending:
                indent, text, first = lines[-1]
                lines[-1] = (indent, text + ' ' + clean.strip(), first)
            else:
                lines.append((len(clean) - len(clean.lstrip()), clean.lstrip(), number))
            pending = 0
            quote = None
            for ch in lines[-1][1]:
                if ch in ('"', "'"):
                    if quote == ch:
                        quote = None
                    elif quote is None:
                        quote = ch
                elif quote is None:
                    pending += (ch in '{[') - (ch in '}]')
            if pending < 0:
                raise ValueError(f'{path}:{number}: unexpected flow closing bracket')
    if not lines or pending:
        raise ValueError(f'{path}: empty file or unclosed flow collection')

    def block(index, indent):
        sequence = lines[index][1].startswith('- ')
        result = [] if sequence else {}
        while index < len(lines) and lines[index][0] == indent:
            _, text, number = lines[index]
            index += 1
            if sequence:
                if not text.startswith('- '):
                    raise ValueError(f'{path}:{number}: mixed list and mapping')
                result.append(_scalar(text[2:]))
            else:
                key, value = _entry(text)
                if key in result:
                    raise ValueError(f'{path}:{number}: duplicate key {key}')
                if value is None:
                    if index >= len(lines) or lines[index][0] <= indent:
                        raise ValueError(f'{path}:{number}: empty mapping')
                    value, index = block(index, lines[index][0])
                result[key] = value
            if index < len(lines) and lines[index][0] > indent:
                raise ValueError(f'{path}:{lines[index][2]}: unexpected indentation')
        return result, index

    spec, end = block(0, 0)
    assert end == len(lines)
    assert re.fullmatch(r'[a-z][a-z0-9_]*', spec['id']), 'Unsafe asset id'
    heights = list(spec['proportions']['landmarks_from_ground'].values())
    assert all(0 < h <= 1 for h in heights) and heights == sorted(heights)
    assert 0 < spec['triangle_budget']['target'] <= spec['triangle_budget']['max']
    for part in spec['parts'].values():
        for key, value in part.items():
            if key.endswith('uv_part'):
                assert value in PARTS, f'Unknown UV part {value}; keep the atlas contract'
    spec['_path'] = path
    spec['_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    return spec
