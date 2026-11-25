#!/usr/bin/env python3
"""美术资产自动检查工具（T63）。

只读扫描 art/（以及可选的 assets/sprites/），不改图片。能做程序判定的项目：
  * 提示词清单 <-> 产物文件的一致性（缺少 / 多出来）
  * PNG 合法性、文件大小、尺寸与长宽比（长宽比 ±10%）
  * 主图与备选、不同角色之间的感知重复（dHash + 16x16 色彩块 RMS）
  * RESULTS-*.json 的结构、status 枚举、checklist 不通过项
  * 明确要求暗背景的图四角亮度；透明精灵的 alpha

输出：reports/art-qa/<时间>.md（可用 --out 指定；默认按任务卡）。
仅使用 Python 标准库 + macOS 自带 sips；不依赖 Pillow。sips 只负责缩略，
PNG 完整性、像素解码和哈希都由本脚本完成。

用法：
  python3 -I tools/art/check_assets.py --selftest
  python3 -I tools/art/check_assets.py
  python3 -I tools/art/check_assets.py --out reports/agents/art-qa.md
"""
from __future__ import annotations

import argparse
import dataclasses
import datetime as _dt
import fnmatch
import hashlib
import json
import math
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

PNG_SIG = b"\x89PNG\r\n\x1a\n"
ALLOWED_STATUS = {"in_review", "accepted", "rejected"}
FAIL_WORDS = {"不通过", "失败", "fail", "failed", "false", "no", "reject", "rejected"}
PASS_WORDS = {"通过", "pass", "passed", "true", "yes", "ok", "accepted"}
PENDING_WORDS = {"待定", "待确认", "未判定", "未检查", "review", "review_required", "pending", "null", "none", "n/a"}
DARK_MAX_DEFAULT = 90.0
ASPECT_TOL_DEFAULT = 0.10
MIN_BYTES_DEFAULT = 200 * 1024
SPRITE_MIN_BYTES_DEFAULT = 8 * 1024
DUP_RMS_SAME = 2.5
DUP_RMS_CROSS = 4.0
DUP_DHASH = 12


# ---------------------------------------------------------------------------
# 数据结构
# ---------------------------------------------------------------------------


@dataclass
class Options:
    root: Path
    art: Path
    include_archive: bool = False
    min_bytes: int = MIN_BYTES_DEFAULT
    sprite_min_bytes: int = SPRITE_MIN_BYTES_DEFAULT
    aspect_tol: float = ASPECT_TOL_DEFAULT
    dark_max: float = DARK_MAX_DEFAULT
    transparent_globs: list[str] = dataclasses.field(default_factory=list)
    quiet: bool = False


@dataclass
class Issue:
    level: str          # lead / review
    code: str
    message: str
    paths: list[str] = dataclasses.field(default_factory=list)
    detail: str = ""


@dataclass
class Spec:
    prompt_rel: str
    target_rel: str
    group: str
    ratio: float | None
    target_w: int | None
    target_h: int | None
    dark: bool | None
    transparent: bool | None
    source: str
    text: str


@dataclass
class PNGInfo:
    rel: str
    path: Path
    size: int = 0
    width: int = 0
    height: int = 0
    bit_depth: int = 0
    color_type: int = -1
    interlace: int = 0
    has_alpha: bool = False
    valid: bool = False
    error: str = ""
    sha256: str = ""
    corners: float | None = None
    dhash: int | None = None
    block_vec: tuple[float, ...] | None = None
    alpha_corners: float | None = None
    alpha_coverage: float | None = None
    alpha_max: int | None = None
    thumb_ok: bool = False
    preview: bool = False


@dataclass
class AssetRow:
    rel: str
    is_main: bool
    is_alt: bool
    is_sprite: bool
    width: int = 0
    height: int = 0
    size: int = 0
    status: str = "pass"       # pass / review / fail
    spec_label: str = "—"
    notes: str = ""
    checks: list[str] = dataclasses.field(default_factory=list)
    fail_codes: list[str] = dataclasses.field(default_factory=list)
    preview: bool = False


@dataclass
class DuplicatePair:
    a: str
    b: str
    same_group: bool
    exact: bool
    dhash: int
    rms: float


@dataclass
class ResultFinding:
    path: str
    label: str
    note: str
    kind: str  # fail / pending


@dataclass
class Report:
    root: Path
    art: Path
    generated_at: str
    options: Options
    issues: list[Issue]
    assets: list[AssetRow]
    duplicates: list[DuplicatePair]
    top_pairs: list[DuplicatePair]
    check_findings: list[ResultFinding]
    stats: dict
    environment: dict
    notes: list[str]

    @property
    def lead_issues(self) -> list[Issue]:
        return [i for i in self.issues if i.level == "lead"]

    @property
    def review_issues(self) -> list[Issue]:
        return [i for i in self.issues if i.level != "lead"]


# ---------------------------------------------------------------------------
# PNG 读取：完整性 + 像素解码
# ---------------------------------------------------------------------------


def _png_channels(color_type: int) -> int:
    return {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type, 0)


def inspect_png(path: Path, rel: str) -> PNGInfo:
    """检查签名、chunk CRC、IDAT zlib 流与扫描行长度。不解像素。"""
    info = PNGInfo(rel=rel, path=path)
    try:
        data = path.read_bytes()
    except OSError as exc:
        info.error = f"读取失败: {exc}"
        return info
    info.size = len(data)
    info.sha256 = hashlib.sha256(data).hexdigest()
    if not data.startswith(PNG_SIG):
        info.error = "PNG 签名不正确"
        return info
    pos = 8
    idat: list[bytes] = []
    seen_ihdr = False
    seen_iend = False
    seen_plte = False
    trns = False
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        end = pos + 12 + length
        if end > len(data):
            info.error = f"chunk {ctype!r} 被截断"
            return info
        payload = data[pos + 8:pos + 8 + length]
        crc_stored = struct.unpack(">I", data[pos + 8 + length:end])[0]
        if zlib.crc32(ctype + payload) & 0xFFFFFFFF != crc_stored:
            info.error = f"chunk {ctype!r} CRC 不匹配"
            return info
        if ctype == b"IHDR":
            if length != 13:
                info.error = "IHDR 长度不正确"
                return info
            (info.width, info.height, info.bit_depth, info.color_type,
             _comp, _filt, info.interlace) = struct.unpack(">IIBBBBB", payload)
            seen_ihdr = True
            info.has_alpha = info.color_type in (4, 6)
        elif ctype == b"PLTE":
            seen_plte = True
        elif ctype == b"tRNS":
            trns = True
            info.has_alpha = True
        elif ctype == b"IDAT":
            idat.append(payload)
        elif ctype == b"IEND":
            seen_iend = True
            pos = end
            break
        pos = end
    if not seen_ihdr:
        info.error = "缺少 IHDR"
        return info
    if not seen_iend:
        info.error = "缺少 IEND（文件可能截断）"
        return info
    if info.width <= 0 or info.height <= 0:
        info.error = "尺寸为 0"
        return info
    if info.color_type not in (0, 2, 3, 4, 6):
        info.error = f"不支持的颜色类型 {info.color_type}"
        return info
    if info.bit_depth not in (1, 2, 4, 8, 16):
        info.error = f"不支持的位深 {info.bit_depth}"
        return info
    if info.color_type == 3 and not seen_plte:
        info.error = "调色板 PNG 缺少 PLTE"
        return info
    if not idat:
        info.error = "缺少 IDAT"
        return info
    try:
        raw = zlib.decompress(b"".join(idat))
    except zlib.error as exc:
        info.error = f"IDAT zlib 解压失败: {exc}"
        return info
    channels = _png_channels(info.color_type)
    stride = (info.width * channels * info.bit_depth + 7) // 8
    if info.interlace == 0:
        expected = info.height * (1 + stride)
        if len(raw) != expected:
            info.error = f"解压后扫描行长度 {len(raw)} != {expected}"
            return info
        for y in range(info.height):
            f = raw[y * (1 + stride)]
            if f > 4:
                info.error = f"第 {y} 行过滤器类型非法: {f}"
                return info
    # 调色板 alpha 表存在也算透明通道
    if trns:
        info.has_alpha = True
    info.valid = True
    return info


def decode_png_rgba(data: bytes) -> tuple[int, int, bytes]:
    """把 PNG 解成 8-bit RGBA。支持 8/16-bit、非隔行；失败抛 ValueError。"""
    if not data.startswith(PNG_SIG):
        raise ValueError("不是 PNG")
    pos = 8
    width = height = bit_depth = color_type = interlace = 0
    idat: list[bytes] = []
    plte = b""
    trns = b""
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            (width, height, bit_depth, color_type, _c, _f, interlace) = struct.unpack(">IIBBBBB", payload)
        elif ctype == b"PLTE":
            plte = payload
        elif ctype == b"tRNS":
            trns = payload
        elif ctype == b"IDAT":
            idat.append(payload)
        elif ctype == b"IEND":
            break
        pos += 12 + length
    if interlace != 0:
        raise ValueError("暂不支持隔行 PNG")
    if bit_depth not in (8, 16):
        raise ValueError(f"暂不支持位深 {bit_depth}")
    channels = _png_channels(color_type)
    if channels == 0:
        raise ValueError(f"不支持的颜色类型 {color_type}")
    bpp = channels * (bit_depth // 8)
    stride = width * bpp
    raw = zlib.decompress(b"".join(idat))
    expected = height * (1 + stride)
    if len(raw) != expected:
        raise ValueError("扫描行长度不正确")
    rows: list[bytearray] = []
    prev = bytearray(stride)
    pos = 0
    for _y in range(height):
        f = raw[pos]
        pos += 1
        row = bytearray(raw[pos:pos + stride])
        pos += stride
        if f == 1:
            for i in range(bpp, stride):
                row[i] = (row[i] + row[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                left = row[i - bpp] if i >= bpp else 0
                row[i] = (row[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[i] = (row[i] + pr) & 0xFF
        elif f != 0:
            raise ValueError(f"非法过滤器 {f}")
        rows.append(row)
        prev = row

    out = bytearray(width * height * 4)

    def sample(row: bytearray, idx: int) -> int:
        return row[idx * 2] if bit_depth == 16 else row[idx]

    for y, row in enumerate(rows):
        base = y * width * 4
        for x in range(width):
            j = base + x * 4
            if color_type == 0:
                v = sample(row, x)
                a = 255
                if len(trns) >= 2:
                    key = struct.unpack(">H", trns[:2])[0]
                    if (v << 8 if bit_depth == 16 else v) == key:
                        a = 0
                out[j:j + 4] = bytes((v, v, v, a))
            elif color_type == 2:
                r = sample(row, x * 3)
                g = sample(row, x * 3 + 1)
                b = sample(row, x * 3 + 2)
                a = 255
                if len(trns) >= 6:
                    key = struct.unpack(">HHH", trns[:6])
                    if (r, g, b) == (key[0] >> 8 if bit_depth == 16 else key[0],
                                     key[1] >> 8 if bit_depth == 16 else key[1],
                                     key[2] >> 8 if bit_depth == 16 else key[2]):
                        a = 0
                out[j:j + 4] = bytes((r, g, b, a))
            elif color_type == 3:
                idx = row[x]
                if idx * 3 + 2 >= len(plte):
                    raise ValueError("调色板索引越界")
                r, g, b = plte[idx * 3:idx * 3 + 3]
                a = trns[idx] if idx < len(trns) else 255
                out[j:j + 4] = bytes((r, g, b, a))
            elif color_type == 4:
                v = sample(row, x * 2)
                a = sample(row, x * 2 + 1)
                out[j:j + 4] = bytes((v, v, v, a))
            elif color_type == 6:
                out[j:j + 4] = bytes((sample(row, x * 4), sample(row, x * 4 + 1),
                                      sample(row, x * 4 + 2), sample(row, x * 4 + 3)))
    return width, height, bytes(out)


def _luma(r: float, g: float, b: float) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def box_resize_rgba(w: int, h: int, rgba: bytes, out_w: int = 64, out_h: int = 64) -> tuple[int, int, bytes]:
    if w <= 0 or h <= 0:
        raise ValueError("空图")
    out = bytearray(out_w * out_h * 4)
    for oy in range(out_h):
        y0 = oy * h // out_h
        y1 = max(y0 + 1, (oy + 1) * h // out_h)
        for ox in range(out_w):
            x0 = ox * w // out_w
            x1 = max(x0 + 1, (ox + 1) * w // out_w)
            n = (y1 - y0) * (x1 - x0)
            sr = sg = sb = sa = 0
            for y in range(y0, y1):
                base = (y * w + x0) * 4
                for x in range(x1 - x0):
                    j = base + x * 4
                    sr += rgba[j]
                    sg += rgba[j + 1]
                    sb += rgba[j + 2]
                    sa += rgba[j + 3]
            j = (oy * out_w + ox) * 4
            out[j:j + 4] = bytes((sr // n, sg // n, sb // n, sa // n))
    return out_w, out_h, bytes(out)


def thumb_rgba(path: Path, tmpdir: Path, index: int, size: int = 64) -> tuple[int, int, bytes] | None:
    """优先用 sips 缩略；失败则纯 Python 解码后缩放。"""
    sips = shutil.which("sips")
    if sips:
        out = tmpdir / f"thumb-{index}.png"
        try:
            proc = subprocess.run(
                [sips, "-z", str(size), str(size), str(path), "--out", str(out)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60,
            )
            if proc.returncode == 0 and out.is_file():
                data = out.read_bytes()
                w, h, rgba = decode_png_rgba(data)
                if (w, h) != (size, size):
                    w, h, rgba = box_resize_rgba(w, h, rgba, size, size)
                return w, h, rgba
        except (OSError, subprocess.SubprocessError, ValueError):
            pass
    try:
        w, h, rgba = decode_png_rgba(path.read_bytes())
        return box_resize_rgba(w, h, rgba, size, size)
    except (OSError, ValueError, zlib.error):
        return None


def _sample_luma_grid(w: int, h: int, rgba: bytes, gw: int, gh: int) -> list[float]:
    grid: list[float] = []
    for gy in range(gh):
        y0 = gy * h // gh
        y1 = max(y0 + 1, (gy + 1) * h // gh)
        for gx in range(gw):
            x0 = gx * w // gw
            x1 = max(x0 + 1, (gx + 1) * w // gw)
            total = 0.0
            n = 0
            for y in range(y0, y1):
                base = (y * w + x0) * 4
                for x in range(x1 - x0):
                    j = base + x * 4
                    a = rgba[j + 3] / 255.0
                    r = rgba[j] * a + 128 * (1 - a)
                    g = rgba[j + 1] * a + 128 * (1 - a)
                    b = rgba[j + 2] * a + 128 * (1 - a)
                    total += _luma(r, g, b)
                    n += 1
            grid.append(total / max(1, n))
    return grid


def _sample_rgb_grid(w: int, h: int, rgba: bytes, gw: int, gh: int) -> list[float]:
    grid: list[float] = []
    for gy in range(gh):
        y0 = gy * h // gh
        y1 = max(y0 + 1, (gy + 1) * h // gh)
        for gx in range(gw):
            x0 = gx * w // gw
            x1 = max(x0 + 1, (gx + 1) * w // gw)
            sr = sg = sb = 0
            n = 0
            for y in range(y0, y1):
                base = (y * w + x0) * 4
                for x in range(x1 - x0):
                    j = base + x * 4
                    a = rgba[j + 3] / 255.0
                    sr += rgba[j] * a + 128 * (1 - a)
                    sg += rgba[j + 1] * a + 128 * (1 - a)
                    sb += rgba[j + 2] * a + 128 * (1 - a)
                    n += 1
            grid.extend((sr / max(1, n), sg / max(1, n), sb / max(1, n)))
    return grid


def fingerprint(info: PNGInfo, thumb: tuple[int, int, bytes]) -> None:
    w, h, rgba = thumb
    info.thumb_ok = True
    # 四角亮度（每角取 1/8 边长）
    block = max(1, min(w, h) // 8)
    corners: list[float] = []
    for ox, oy in ((0, 0), (w - block, 0), (0, h - block), (w - block, h - block)):
        total = 0.0
        n = 0
        for y in range(max(0, oy), min(h, oy + block)):
            for x in range(max(0, ox), min(w, ox + block)):
                j = (y * w + x) * 4
                if rgba[j + 3] < 16:
                    continue
                total += _luma(rgba[j], rgba[j + 1], rgba[j + 2])
                n += 1
        if n:
            corners.append(total / n)
    info.corners = sum(corners) / len(corners) if corners else None
    # alpha 统计：四角块平均值 + 全图覆盖率
    vals = rgba[3::4]
    corner_alphas: list[float] = []
    for ox, oy in ((0, 0), (w - block, 0), (0, h - block), (w - block, h - block)):
        s = 0
        n = 0
        for y in range(max(0, oy), min(h, oy + block)):
            for x in range(max(0, ox), min(w, ox + block)):
                s += rgba[(y * w + x) * 4 + 3]
                n += 1
        if n:
            corner_alphas.append(s / n)
    info.alpha_corners = sum(corner_alphas) / len(corner_alphas) if corner_alphas else None
    info.alpha_coverage = sum(1 for v in vals if v > 16) / max(1, len(vals))
    info.alpha_max = max(vals) if vals else 0
    # 8x8 dHash（9x8 灰度网格，横向比较）
    g = _sample_luma_grid(w, h, rgba, 9, 8)
    bits = 0
    for y in range(8):
        for x in range(8):
            bits = (bits << 1) | (1 if g[y * 9 + x] > g[y * 9 + x + 1] else 0)
    info.dhash = bits
    # 16x16 色彩块均值（用于区分“同版式不同角色”和真正复制）
    info.block_vec = tuple(_sample_rgb_grid(w, h, rgba, 16, 16))


def _rms(a: tuple[float, ...], b: tuple[float, ...]) -> float:
    if not a or not b or len(a) != len(b):
        return 999.0
    s = 0.0
    for x, y in zip(a, b):
        d = x - y
        s += d * d
    return math.sqrt(s / len(a))


def _hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


# ---------------------------------------------------------------------------
# 提示词规格
# ---------------------------------------------------------------------------


def extract_format(text: str) -> str:
    m = re.search(r"FORMAT\s*:\s*(.*?)(?=\n[A-Z][A-Z0-9 _-]{2,}:|\Z)", text, re.S | re.I)
    return m.group(1).strip() if m else ""


def parse_format(text: str) -> tuple[int | None, int | None, float | None]:
    """从提示词里找目标像素尺寸和长宽比。优先 FORMAT 段。"""
    fmt = extract_format(text)
    for source in (fmt, text):
        m = re.search(r"(?<![\d.])(\d{2,5})\s*[x×]\s*(\d{2,5})(?![\d.])", source)
        if m:
            w, h = int(m.group(1)), int(m.group(2))
            if w > 0 and h > 0:
                return w, h, w / h
    for source in (fmt, text):
        m = re.search(r"(?<![\d.])(\d{1,2})\s*:\s*(\d{1,2})(?![\d.])", source)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > 0 and b > 0:
                return None, None, a / b
    return None, None, None


def classify_dark(text: str) -> bool | None:
    """判断提示词是否明确要求暗背景。

    只看 FORMAT 段和 Background/Scene 行，避免把通用画风句
    “Background is a dark ink-navy / sea-grey painted field”套到剧情插画上。
    """
    low = text.lower()
    if "parchment" in low and re.search(
        r"parchment[^.\n]{0,60}(background|chart|map|field)|(?:background|chart|map|field)[^.\n]{0,60}parchment",
        low,
    ):
        return False
    fmt = extract_format(text)
    candidates: list[str] = [fmt] if fmt else []
    for line in text.splitlines():
        s = line.strip()
        if re.match(r"^(background|scene)\s*[:：]", s, re.I):
            candidates.append(s)
        if re.search(
            r"(solid perfectly flat dark navy background|flat solid #0b101a background|"
            r"dark ink-navy / gray-sea background|near-black navy background|"
            r"flat uniform ink-navy background)",
            s, re.I,
        ):
            return True
    for c in candidates:
        if re.search(r"(dark|black|ink-navy|near-black|nearly black)[^.\n]{0,60}(background|backdrop|field)", c, re.I):
            return True
        if re.search(r"(background|backdrop|field)[^.\n]{0,40}(dark|black|ink-navy|near-black|nearly black)", c, re.I):
            return True
    return None


def classify_transparent(text: str) -> bool | None:
    low = text.lower()
    if re.search(r"transparent\s+(background|png|canvas)|alpha\s+(channel|transparency)|with alpha", low):
        return True
    return None


def norm_ref(root: Path, ref: object) -> str | None:
    if not isinstance(ref, str) or not ref.strip():
        return None
    s = ref.strip().replace("\\", "/")
    p = Path(s)
    if p.is_absolute():
        try:
            return p.resolve().relative_to(root.resolve()).as_posix()
        except (OSError, ValueError):
            return None
    return s.lstrip("./")


def _read_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def load_specs(root: Path, art: Path) -> tuple[list[Spec], list[Issue]]:
    specs: list[Spec] = []
    issues: list[Issue] = []
    reuse: dict[str, str] = {}
    chars_json = art / "prompts" / "characters.json"
    if chars_json.is_file():
        try:
            doc = _read_json(chars_json)
            for ch in doc.get("characters", []):
                if isinstance(ch, dict) and ch.get("id") and ch.get("reuse_hero"):
                    reuse[ch["id"]] = ch["reuse_hero"]
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            issues.append(Issue("review", "manifest.characters_json", f"characters.json 读取失败: {exc}", [str(chars_json)]))

    def add(prompt_rel: str, target_rel: str | None, text: str, source: str) -> None:
        if not target_rel:
            issues.append(Issue("lead", "manifest.unmapped_prompt",
                                f"提示词无法映射到产物: {prompt_rel}", [prompt_rel]))
            return
        w, h, ratio = parse_format(text)
        specs.append(Spec(
            prompt_rel=prompt_rel,
            target_rel=target_rel,
            group=target_rel,
            ratio=ratio,
            target_w=w,
            target_h=h,
            dark=classify_dark(text),
            transparent=classify_transparent(text),
            source=source,
            text=text,
        ))

    for prompt_dir in sorted((art / "prompts").glob("rendered*")):
        if not prompt_dir.is_dir():
            continue
        for p in sorted(prompt_dir.glob("*.txt")):
            rel = p.relative_to(root).as_posix()
            stem = p.stem
            if "__" not in stem:
                issues.append(Issue("lead", "manifest.unmapped_prompt",
                                    f"提示词命名不符合 <前缀>__<类型>: {rel}", [rel]))
                continue
            prefix, kind = stem.split("__", 1)
            target: str | None = None
            if prefix.startswith("CHAR-"):
                if kind == "hero" and prefix in reuse:
                    target = norm_ref(root, reuse[prefix])
                else:
                    target = f"art/chars/{prefix}/{kind}.png"
            elif prefix == "UNITS":
                target = f"art/units/{kind}.png"
            elif prefix == "STORY":
                target = f"art/story/{kind}/scene.png"
            elif prefix == "ENDING":
                target = f"art/story/ENDING-{kind}/ending.png"
            else:
                issues.append(Issue("lead", "manifest.unmapped_prompt",
                                    f"未知提示词前缀: {rel}", [rel]))
                continue
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError as exc:
                issues.append(Issue("lead", "manifest.prompt_read", f"提示词读取失败: {rel}: {exc}", [rel]))
                continue
            add(rel, target, text, "rendered")

    # art/style/STYLE-RESULTS.json
    style_path = art / "style" / "STYLE-RESULTS.json"
    if style_path.is_file():
        try:
            doc = _read_json(style_path)
            for rec in doc if isinstance(doc, list) else []:
                if not isinstance(rec, dict):
                    continue
                target = norm_ref(root, rec.get("file"))
                text = rec.get("prompt") if isinstance(rec.get("prompt"), str) else ""
                if target:
                    add(f"{style_path.relative_to(root).as_posix()}#{rec.get('id', '?')}",
                        target, text, "style_results")
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            issues.append(Issue("lead", "manifest.style_results", f"STYLE-RESULTS.json 读取失败: {exc}", [str(style_path)]))

    # art/ui/RESULTS.json
    ui_path = art / "ui" / "RESULTS.json"
    if ui_path.is_file():
        try:
            doc = _read_json(ui_path)
            for rec in doc if isinstance(doc, list) else []:
                if not isinstance(rec, dict):
                    continue
                text = rec.get("prompt") if isinstance(rec.get("prompt"), str) else ""
                files = rec.get("files") if isinstance(rec.get("files"), list) else []
                for f in files:
                    target = norm_ref(root, f)
                    if target:
                        add(f"{ui_path.relative_to(root).as_posix()}#{rec.get('id', '?')}",
                            target, text, "ui_results")
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            issues.append(Issue("lead", "manifest.ui_results", f"UI RESULTS.json 读取失败: {exc}", [str(ui_path)]))

    # art/prompts/compare/index.json
    idx_path = art / "prompts" / "compare" / "index.json"
    if idx_path.is_file():
        try:
            doc = _read_json(idx_path)
            for row in doc if isinstance(doc, list) else []:
                if not (isinstance(row, list) and len(row) >= 2):
                    continue
                char, style = str(row[0]), str(row[1])
                prompt = art / "prompts" / "compare" / f"{char}_{style}.txt"
                target = f"art/compare/{char}_{style}.png"
                if prompt.is_file():
                    text = prompt.read_text(encoding="utf-8", errors="replace")
                    add(prompt.relative_to(root).as_posix(), target, text, "compare")
                else:
                    issues.append(Issue("lead", "manifest.unmapped_prompt",
                                        f"对比提示词缺失: {prompt.relative_to(root).as_posix()}",
                                        [prompt.relative_to(root).as_posix()]))
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            issues.append(Issue("lead", "manifest.compare_index", f"compare/index.json 读取失败: {exc}", [str(idx_path)]))

    return specs, issues


# ---------------------------------------------------------------------------
# RESULTS
# ---------------------------------------------------------------------------


def discover_results(root: Path, art: Path, include_archive: bool) -> list[Path]:
    out: list[Path] = []
    for p in sorted(art.rglob("*RESULTS*.json")):
        rel = p.relative_to(root).as_posix()
        if not include_archive and rel.startswith("art/archive/"):
            continue
        out.append(p)
    return out


def iter_result_docs(root: Path, art: Path, include_archive: bool) -> list[tuple[str, object]]:
    docs: list[tuple[str, object]] = []
    for p in discover_results(root, art, include_archive):
        rel = p.relative_to(root).as_posix()
        try:
            docs.append((rel, _read_json(p)))
        except (OSError, ValueError, json.JSONDecodeError):
            docs.append((rel, None))
    return docs


def load_alt_map(root: Path, art: Path, include_archive: bool) -> dict[str, str]:
    alt_map: dict[str, str] = {}
    for _rel, doc in iter_result_docs(root, art, include_archive):
        if doc is None:
            continue
        recs = doc if isinstance(doc, list) else doc.get("items", [doc]) if isinstance(doc, dict) else []
        for rec in recs:
            if not isinstance(rec, dict):
                continue
            main = rec.get("file") or rec.get("selected_path")
            if not main and isinstance(rec.get("files"), list) and rec["files"]:
                main = rec["files"][0]
            main_rel = norm_ref(root, main) if main else None
            if not main_rel:
                continue
            alts = []
            if isinstance(rec.get("alts"), list):
                alts.extend(rec["alts"])
            if rec.get("alternate_path"):
                alts.append(rec["alternate_path"])
            for a in alts:
                ar = norm_ref(root, a)
                if ar:
                    alt_map[ar] = main_rel
    return alt_map


def flatten_checks(node: object, label: str = "") -> list[tuple[str, dict]]:
    out: list[tuple[str, dict]] = []
    if isinstance(node, dict):
        if any(k in node for k in ("result", "status", "passed")):
            return [(label, node)]
        for k, v in node.items():
            if k in ("method", "notes", "note", "evidence"):
                continue
            out.extend(flatten_checks(v, str(k)))
    elif isinstance(node, list):
        for item in node:
            if isinstance(item, str):
                continue
            out.extend(flatten_checks(item, label))
    return out


def check_value(entry: dict) -> str | None:
    for key in ("result", "status", "passed"):
        if key not in entry:
            continue
        v = entry.get(key)
        if isinstance(v, bool):
            return "pass" if v else "fail"
        if v is None:
            return "pending"
        s = str(v).strip().lower()
        if s in FAIL_WORDS:
            return "fail"
        if s in PENDING_WORDS:
            return "pending"
        if s in PASS_WORDS:
            return "pass"
    return None


def check_label(entry: dict, fallback: str) -> str:
    for key in ("criterion", "requirement", "item"):
        v = entry.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
        if isinstance(v, int):
            return f"item {v}"
    return fallback or "checklist"


def check_note(entry: dict) -> str:
    for key in ("note", "evidence", "notes"):
        v = entry.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def validate_results(root: Path, art: Path, include_archive: bool) -> tuple[list[Issue], list[ResultFinding], dict, list[str]]:
    issues: list[Issue] = []
    findings: list[ResultFinding] = []
    stats = {
        "files": 0,
        "records": 0,
        "status_counts": Counter(),
        "checklist_entries": 0,
        "fails": 0,
        "pending": 0,
        "unstructured_self_check": 0,
    }
    notes: list[str] = []
    for rel, doc in iter_result_docs(root, art, include_archive):
        stats["files"] += 1
        if doc is None:
            issues.append(Issue("lead", "results.parse", f"RESULTS 不是合法 JSON: {rel}", [rel]))
            continue
        top_status: str | None = None
        top_invalid = False
        if isinstance(doc, dict):
            recs = doc.get("items") if isinstance(doc.get("items"), list) else [doc]
            top_status = doc.get("status") if isinstance(doc.get("status"), str) else None
            if top_status and top_status not in ALLOWED_STATUS:
                top_invalid = True
                issues.append(Issue("lead", "results.invalid_status",
                                    f"status 非法: {top_status!r}（只允许 in_review / accepted / rejected）",
                                    [rel], f"{rel} 顶层"))
                stats["status_counts"][top_status] += 1
        elif isinstance(doc, list):
            recs = doc
        else:
            issues.append(Issue("lead", "results.parse", f"RESULTS 顶层不是数组或对象: {rel}", [rel]))
            continue
        for idx, rec in enumerate(recs):
            if not isinstance(rec, dict):
                issues.append(Issue("lead", "results.parse", f"RESULTS 第 {idx + 1} 条不是对象: {rel}", [rel]))
                continue
            stats["records"] += 1
            status = rec.get("status") if isinstance(rec.get("status"), str) else top_status
            if status:
                stats["status_counts"][status] += 1
            if not status:
                issues.append(Issue("lead", "results.missing_status",
                                    f"缺少 status: {rel} 第 {idx + 1} 条", [rel]))
            elif status not in ALLOWED_STATUS:
                if not (top_invalid and not isinstance(rec.get("status"), str)):
                    issues.append(Issue("lead", "results.invalid_status",
                                        f"status 非法: {status!r}（只允许 in_review / accepted / rejected）",
                                        [rel], f"{rel} 第 {idx + 1} 条"))
            main_files: list[str] = []
            for key in ("file", "selected_path"):
                v = rec.get(key)
                if isinstance(v, str) and v:
                    main_files.append(v)
            for key in ("files", "outputs"):
                v = rec.get(key)
                if isinstance(v, list):
                    main_files.extend(x for x in v if isinstance(x, str) and x)
            alt_files: list[str] = []
            if isinstance(rec.get("alts"), list):
                alt_files.extend(x for x in rec["alts"] if isinstance(x, str) and x)
            if isinstance(rec.get("alternate_path"), str):
                alt_files.append(rec["alternate_path"])
            if not main_files:
                issues.append(Issue("lead", "results.missing_field",
                                    f"缺少文件字段（file/files/selected_path）: {rel} 第 {idx + 1} 条", [rel]))
            for f in main_files:
                fr = norm_ref(root, f)
                if not fr:
                    continue
                if not (root / fr).is_file():
                    issues.append(Issue("lead", "results.missing_file",
                                        f"RESULTS 引用的文件不存在: {fr}", [rel, fr]))
            for f in alt_files:
                fr = norm_ref(root, f)
                if not fr:
                    continue
                if not (root / fr).is_file():
                    issues.append(Issue("lead", "results.missing_alt",
                                        f"RESULTS 引用的备选图不存在: {fr}", [rel, fr]))
            checklist = rec.get("checklist")
            self_check = rec.get("self_check")
            if checklist is None and self_check is None:
                issues.append(Issue("review", "results.missing_checklist",
                                    f"缺少 checklist / self_check: {rel} 第 {idx + 1} 条", [rel]))
            entries: list[tuple[str, dict]] = []
            if isinstance(checklist, dict):
                entries.append(("checklist", checklist))
            elif isinstance(checklist, list):
                entries.extend(flatten_checks(checklist, "checklist"))
            if isinstance(self_check, dict):
                sub = flatten_checks(self_check, "self_check")
                if sub:
                    entries.extend(sub)
                else:
                    stats["unstructured_self_check"] += 1
            elif isinstance(self_check, list):
                sub = flatten_checks(self_check, "self_check")
                if sub:
                    entries.extend(sub)
                else:
                    stats["unstructured_self_check"] += 1
            for fallback, entry in entries:
                stats["checklist_entries"] += 1
                result = check_value(entry)
                label = check_label(entry, fallback)
                note = check_note(entry)
                display = main_files[0] if main_files else (alt_files[0] if alt_files else rel)
                if result == "fail":
                    stats["fails"] += 1
                    findings.append(ResultFinding(display, label, note, "fail"))
                    issues.append(Issue("lead", "results.checklist_fail",
                                        f"checklist 不通过: {display} — {label}", [rel],
                                        note or f"{rel} 第 {idx + 1} 条"))
                elif result == "pending":
                    stats["pending"] += 1
                    findings.append(ResultFinding(display, label, note, "pending"))
                    issues.append(Issue("review", "results.checklist_pending",
                                        f"checklist 待确认: {display} — {label}", [rel],
                                        note or f"{rel} 第 {idx + 1} 条"))
            # 提示词 hash
            prompt_pairs: list[tuple[str, str]] = []
            if isinstance(rec.get("prompt_file"), str) and isinstance(rec.get("prompt_sha256"), str):
                prompt_pairs.append((rec["prompt_file"], rec["prompt_sha256"]))
            nested = rec.get("prompt")
            if isinstance(nested, dict) and isinstance(nested.get("path"), str) and isinstance(nested.get("sha256"), str):
                prompt_pairs.append((nested["path"], nested["sha256"]))
            for pf, expected in prompt_pairs:
                pfr = norm_ref(root, pf)
                if not pfr:
                    continue
                pp = root / pfr
                if not pp.is_file():
                    issues.append(Issue("lead", "results.prompt_missing",
                                        f"RESULTS 引用的提示词不存在: {pfr}", [rel, pfr]))
                    continue
                actual = hashlib.sha256(pp.read_bytes()).hexdigest()
                if actual != expected:
                    issues.append(Issue("lead", "results.prompt_hash",
                                        f"提示词 sha256 与 RESULTS 登记不一致: {pfr}", [rel, pfr],
                                        f"登记 {expected[:12]}… / 实际 {actual[:12]}…"))
    if stats["unstructured_self_check"]:
        notes.append(f"{stats['unstructured_self_check']} 条 RESULTS 的 self_check 是文字清单，"
                     "没有机器可读的 result/status，按“字段存在”处理，未计入不通过。")
    return issues, findings, stats, notes


# ---------------------------------------------------------------------------
# 扫描与检查
# ---------------------------------------------------------------------------


def rel_path(root: Path, p: Path) -> str:
    try:
        return p.resolve().relative_to(root.resolve()).as_posix()
    except (OSError, ValueError):
        return p.as_posix()


def infer_group(rel: str) -> str | None:
    """从 alt/ 路径推断主图路径；RESULTS 没有登记时的兜底。"""
    if "/alt/" not in rel:
        return None
    main = rel.replace("/alt/", "/", 1)
    name = Path(main).name
    stem = name[:-4] if name.lower().endswith(".png") else name
    # scène-v1 / hero-v2 / kit_frames_A / EDMUND_A_v2
    stem = re.sub(r"[-_](?:v\d+|[A-Z])$", "", stem)
    parent = Path(main).parent.as_posix()
    return f"{parent}/{stem}.png"


def scan_assets(root: Path, art: Path, specs: list[Spec], alt_map: dict[str, str], opts: Options) -> tuple[list[AssetRow], list[Issue], list[PNGInfo], list[str]]:
    specs_by_target: dict[str, list[Spec]] = defaultdict(list)
    for s in specs:
        specs_by_target[s.target_rel].append(s)
    issues: list[Issue] = []
    assets: list[AssetRow] = []
    infos: list[PNGInfo] = []
    notes: list[str] = []

    paths: list[tuple[Path, bool]] = []
    for p in sorted(art.rglob("*.png")):
        rel = rel_path(root, p)
        if not opts.include_archive and rel.startswith("art/archive/"):
            continue
        paths.append((p, rel.startswith("art/sprites/")))
    for base in (root / "assets" / "sprites", art / "sprites"):
        if base.is_dir():
            for p in sorted(base.rglob("*.png")):
                paths.append((p, True))
    # 去重
    seen: set[str] = set()
    unique_paths: list[tuple[Path, bool]] = []
    for p, is_spr in paths:
        rel = rel_path(root, p)
        if rel in seen:
            continue
        seen.add(rel)
        unique_paths.append((p, is_spr))

    with tempfile.TemporaryDirectory(prefix="art-qa-") as td:
        tmpdir = Path(td)
        for index, (p, is_sprite) in enumerate(unique_paths):
            rel = rel_path(root, p)
            is_alt = "/alt/" in rel
            is_reference = "/references/" in rel
            is_archive = rel.startswith("art/archive/")
            is_main = not (is_alt or is_reference or is_archive or is_sprite)
            info = inspect_png(p, rel)
            info.preview = any(tok in rel for tok in ("preview", "parts", "_uv", "comparison", "view_"))
            infos.append(info)
            row = AssetRow(rel=rel, is_main=is_main, is_alt=is_alt, is_sprite=is_sprite,
                           width=info.width, height=info.height, size=info.size, preview=info.preview)
            if not info.valid:
                issues.append(Issue("lead", "spec.invalid_png",
                                    f"不是合法 PNG: {rel}", [rel], info.error))
                row.status = "fail"
                row.fail_codes.append("invalid_png")
                row.notes = info.error
                assets.append(row)
                continue
            thumb = thumb_rgba(p, tmpdir, index)
            if thumb:
                fingerprint(info, thumb)
            else:
                issues.append(Issue("review", "spec.thumb_failed",
                                    f"无法读取像素，跳过背景/重复检查: {rel}", [rel]))
                row.status = "review"
                row.fail_codes.append("thumb_failed")
            threshold = opts.sprite_min_bytes if is_sprite else opts.min_bytes
            if info.size < threshold:
                issues.append(Issue("lead", "spec.too_small",
                                    f"文件过小（{info.size} B < {threshold} B），可能是空图: {rel}", [rel]))
                row.status = "fail"
                row.fail_codes.append("too_small")
                row.checks.append(f"文件 {info.size / 1024:.0f}KB")
            # 规格：主图 / alt 继承主图规格
            spec_group = rel if rel in specs_by_target else alt_map.get(rel)
            if spec_group is None:
                spec_group = infer_group(rel)
            group_specs = specs_by_target.get(spec_group, []) if spec_group else []
            if not group_specs and rel in specs_by_target:
                group_specs = specs_by_target[rel]
            ratios = {round(s.ratio, 6) for s in group_specs if s.ratio}
            if len(ratios) > 1:
                issues.append(Issue("review", "spec.ratio_conflict",
                                    f"同一产物的提示词长宽比不一致: {rel}", [rel],
                                    " / ".join(sorted(str(x) for x in ratios))))
            target_ratio = next(iter(ratios)) if ratios else None
            target_w = next((s.target_w for s in group_specs if s.target_w), None)
            target_h = next((s.target_h for s in group_specs if s.target_h), None)
            if target_ratio and info.height:
                actual_ratio = info.width / info.height
                err = abs(actual_ratio - target_ratio) / target_ratio
                if err > opts.aspect_tol:
                    issues.append(Issue("lead", "spec.aspect",
                                        f"长宽比不符: {rel} 实际 {actual_ratio:.3f}，规格 {target_ratio:.3f}（偏差 {err * 100:.1f}% > {opts.aspect_tol * 100:.0f}%）",
                                        [rel]))
                    row.status = "fail"
                    row.fail_codes.append("aspect")
                elif target_w and (info.width, info.height) != (target_w, target_h):
                    row.notes = (row.notes + "；" if row.notes else "") + \
                        f"规格 {target_w}x{target_h}，实际 {info.width}x{info.height}（等比缩放）"
                if target_w:
                    row.spec_label = f"{target_w}x{target_h} ({target_ratio:.3f})"
                else:
                    row.spec_label = f"比例 {target_ratio:.3f}"
                row.checks.append(f"比例 {actual_ratio:.3f}")
            elif target_ratio:
                row.spec_label = f"{target_ratio:.3f}"
                row.checks.append("比例未知")
            else:
                row.spec_label = "无规格"
            # 暗背景
            dark_values = {s.dark for s in group_specs if s.dark is not None}
            if True in dark_values:
                if False in dark_values:
                    issues.append(Issue("review", "background.conflict",
                                        f"提示词对背景要求冲突（既有暗背景又有浅色背景）: {rel}", [rel]))
                if info.corners is None:
                    issues.append(Issue("review", "background.unknown",
                                        f"要求暗背景但无法计算四角亮度: {rel}", [rel]))
                elif info.corners > opts.dark_max:
                    issues.append(Issue("lead", "background.too_bright",
                                        f"暗背景不达标: {rel} 四角平均亮度 {info.corners:.1f} > {opts.dark_max:.0f}",
                                        [rel]))
                    row.status = "fail"
                    row.fail_codes.append("background")
                else:
                    row.checks.append(f"暗背景 {info.corners:.0f}")
            # 透明
            transparent_req = ((is_sprite and not info.preview)
                               or any(s.transparent is True for s in group_specs)
                               or any(fnmatch.fnmatch(rel, pat) for pat in opts.transparent_globs))
            if transparent_req:
                if not info.has_alpha:
                    issues.append(Issue("lead", "transparency.no_alpha",
                                        f"要求透明背景/alpha，但没有 alpha 通道: {rel}", [rel]))
                    row.status = "fail"
                    row.fail_codes.append("no_alpha")
                else:
                    if info.alpha_corners is None or info.alpha_corners > 16:
                        issues.append(Issue("lead", "transparency.corners",
                                            f"透明精灵四角 alpha 偏高: {rel} 平均 {info.alpha_corners if info.alpha_corners is not None else '?'}",
                                            [rel]))
                        row.status = "fail"
                        row.fail_codes.append("alpha_corners")
                    if info.alpha_coverage is not None and info.alpha_coverage < 0.01:
                        issues.append(Issue("lead", "transparency.empty",
                                            f"透明精灵几乎全透明（覆盖率 {info.alpha_coverage * 100:.2f}%）: {rel}",
                                            [rel]))
                        row.status = "fail"
                        row.fail_codes.append("alpha_empty")
                    if info.alpha_max is not None and info.alpha_max < 200:
                        issues.append(Issue("lead", "transparency.no_subject",
                                            f"透明精灵没有不透明主体（max alpha {info.alpha_max}）: {rel}",
                                            [rel]))
                        row.status = "fail"
                        row.fail_codes.append("alpha_subject")
                    if not row.fail_codes:
                        row.checks.append(f"alpha {info.alpha_corners:.0f}/{info.alpha_coverage * 100:.0f}%")
            # 清单
            if is_main and rel not in specs_by_target:
                issues.append(Issue("review", "manifest.extra_product",
                                    f"产物没有对应提示词（多出来的主图）: {rel}", [rel]))
                if row.status == "pass":
                    row.status = "review"
                row.fail_codes.append("extra")
                row.notes = (row.notes + "；" if row.notes else "") + "未登记提示词"
            if is_alt and rel not in alt_map:
                issues.append(Issue("review", "manifest.unregistered_alt",
                                    f"备选图未在 RESULTS 登记: {rel}", [rel]))
                if row.status == "pass":
                    row.status = "review"
                row.fail_codes.append("unregistered_alt")
            row.checks.append(f"{info.width}x{info.height}")
            assets.append(row)

    # 清单缺少产物（按 target 去重）
    for target, group_specs in sorted(specs_by_target.items()):
        if not (root / target).is_file():
            prompts = ", ".join(sorted({s.prompt_rel for s in group_specs}))
            issues.append(Issue("lead", "manifest.missing_product",
                                f"提示词缺少产物: {target}", [target],
                                f"来源: {prompts}"))

    return assets, issues, infos, notes


def compute_duplicates(root: Path, assets: list[AssetRow], infos: list[PNGInfo],
                       specs_by_target: dict[str, list[Spec]], alt_map: dict[str, str]) -> tuple[list[DuplicatePair], list[DuplicatePair]]:
    usable = [i for i in infos if i.valid and i.thumb_ok and not i.preview
              and "/references/" not in i.rel
              and i.dhash is not None and i.block_vec is not None]
    exact_groups: dict[str, list[str]] = defaultdict(list)
    for i in usable:
        exact_groups[i.sha256].append(i.rel)
    suspicious: list[DuplicatePair] = []
    all_pairs: list[DuplicatePair] = []
    # 同组判断：主图和 alt 映射到同一 target
    def group_of(rel: str) -> str:
        if rel in specs_by_target:
            return rel
        return alt_map.get(rel, infer_group(rel) or rel)

    seen_exact: set[tuple[str, str]] = set()
    for sha, rels in exact_groups.items():
        if len(rels) < 2:
            continue
        for i in range(len(rels)):
            for j in range(i + 1, len(rels)):
                a, b = sorted((rels[i], rels[j]))
                if (a, b) in seen_exact:
                    continue
                seen_exact.add((a, b))
                pair = DuplicatePair(a, b, group_of(a) == group_of(b), True, 0, 0.0)
                suspicious.append(pair)
                all_pairs.append(pair)
    for i in range(len(usable)):
        for j in range(i + 1, len(usable)):
            a, b = usable[i], usable[j]
            if a.sha256 == b.sha256:
                continue
            d = _hamming(a.dhash or 0, b.dhash or 0)
            same = group_of(a.rel) == group_of(b.rel)
            if not same and d > 32:
                continue
            rms = _rms(a.block_vec or (), b.block_vec or ())
            pair = DuplicatePair(a.rel, b.rel, same, False, d, rms)
            all_pairs.append(pair)
            if same:
                if rms <= DUP_RMS_SAME:
                    suspicious.append(pair)
            else:
                if (rms <= DUP_RMS_CROSS and d <= DUP_DHASH) or rms <= DUP_RMS_SAME:
                    suspicious.append(pair)
    # 去重
    uniq: dict[tuple[str, str], DuplicatePair] = {}
    for p in suspicious:
        key = tuple(sorted((p.a, p.b)))
        uniq[key] = p
    suspicious = sorted(uniq.values(), key=lambda p: (p.exact is False, p.rms, p.dhash))
    all_pairs.sort(key=lambda p: (p.rms, p.dhash))
    return suspicious, all_pairs[:15]


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------


def run_check(opts: Options) -> Report:
    root = opts.root
    art = opts.art
    generated = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    if not art.is_dir():
        raise SystemExit(f"art 目录不存在: {art}")
    specs, spec_issues = load_specs(root, art)
    specs_by_target: dict[str, list[Spec]] = defaultdict(list)
    for s in specs:
        specs_by_target[s.target_rel].append(s)
    alt_map = load_alt_map(root, art, opts.include_archive)
    result_issues, findings, result_stats, result_notes = validate_results(root, art, opts.include_archive)
    assets, asset_issues, infos, scan_notes = scan_assets(root, art, specs, alt_map, opts)

    duplicates, top_pairs = compute_duplicates(root, assets, infos, specs_by_target, alt_map)
    dup_issues: list[Issue] = []
    for p in duplicates:
        level = "lead"
        code = "duplicate.exact" if p.exact else "duplicate.near"
        tag = "完全相同" if p.exact else f"感知哈希过近 (dHash {p.dhash}, 色彩 RMS {p.rms:.2f})"
        dup_issues.append(Issue(level, code,
                                f"疑似重复: {p.a} ↔ {p.b} — {tag}", [p.a, p.b],
                                "同一资产的备选" if p.same_group else "不同资产之间"))
    issues = spec_issues + result_issues + asset_issues + dup_issues
    # RESULTS 里已标“不通过/待确认”的资产不再算程序通过
    by_rel = {a.rel: a for a in assets}
    for f in findings:
        fr = norm_ref(root, f.path)
        a = by_rel.get(fr) if fr else None
        if not a:
            continue
        if a.status == "pass":
            a.status = "review"
        a.fail_codes.append("checklist_fail" if f.kind == "fail" else "checklist_pending")
        a.notes = (a.notes + "；" if a.notes else "") + \
            ("checklist 不通过" if f.kind == "fail" else "checklist 待确认")
    # 汇总统计
    main_assets = [a for a in assets if a.is_main]
    alt_assets = [a for a in assets if a.is_alt]
    sprite_assets = [a for a in assets if a.is_sprite]
    stats = {
        "prompt_files": sum(1 for s in specs if s.source == "rendered"),
        "specs": len(specs),
        "unique_targets": len(specs_by_target),
        "missing_products": sum(1 for i in issues if i.code == "manifest.missing_product"),
        "extra_products": sum(1 for i in issues if i.code == "manifest.extra_product"),
        "unregistered_alts": sum(1 for i in issues if i.code == "manifest.unregistered_alt"),
        "png_total": len(assets),
        "png_valid": sum(1 for a in assets if "invalid_png" not in a.fail_codes),
        "png_invalid": sum(1 for a in assets if "invalid_png" in a.fail_codes),
        "main_total": len(main_assets),
        "alt_total": len(alt_assets),
        "sprite_total": len(sprite_assets),
        "too_small": sum(1 for i in issues if i.code == "spec.too_small"),
        "aspect_fail": sum(1 for i in issues if i.code == "spec.aspect"),
        "aspect_checked": sum(1 for a in assets if a.spec_label != "无规格"),
        "aspect_pass": sum(1 for a in assets if a.spec_label != "无规格" and "aspect" not in a.fail_codes),
        "dark_pass": sum(1 for a in assets if any(x.startswith("暗背景") for x in a.checks)),
        "dark_fail": sum(1 for i in issues if i.code == "background.too_bright"),
        "alpha_pass": sum(1 for a in assets if any(x.startswith("alpha ") for x in a.checks)),
        "alpha_fail": sum(1 for i in issues if i.code.startswith("transparency.")),
        "duplicates": len(duplicates),
        "result_files": result_stats["files"],
        "result_records": result_stats["records"],
        "checklist_fails": result_stats["fails"],
        "checklist_pending": result_stats["pending"],
        "invalid_status": sum(1 for i in issues if i.code == "results.invalid_status"),
        "missing_fields": sum(1 for i in issues if i.code in ("results.missing_field", "results.missing_status")),
        "result_missing_files": sum(1 for i in issues if i.code in ("results.missing_file", "results.missing_alt")),
        "prompt_hash_errors": sum(1 for i in issues if i.code == "results.prompt_hash"),
    }
    env = {
        "python": sys.version.split()[0],
        "sips": "未找到",
        "pillow": "未使用（脚本只依赖标准库）",
        "git": "",
    }
    sips = shutil.which("sips")
    if sips:
        try:
            proc = subprocess.run([sips, "--version"], capture_output=True, text=True, timeout=10)
            env["sips"] = (proc.stdout or proc.stderr).strip().splitlines()[0] if (proc.stdout or proc.stderr).strip() else sips
        except (OSError, subprocess.SubprocessError):
            env["sips"] = sips
    try:
        proc = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, timeout=10)
        if proc.returncode == 0:
            env["git"] = proc.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    notes = result_notes + scan_notes
    if not opts.include_archive:
        notes.append("art/archive/ 为历史低模产物，默认不纳入清单、重复和背景检查。")
    notes.append("剧情插画/结局图的光照由场景决定，未按“暗背景”强制检查；只检查提示词明确要求暗背景的资产。")
    notes.append("像素尺寸与提示词目标不同但长宽比在 ±10% 内的，记为等比缩放，不判失败。")
    notes.append("rendered_v2/ 与 rendered/ 的提示词共用同一产物路径；脚本只能确认路径存在，"
                 "不能判断文件是否已按 v2 提示词重生成。")
    notes.append("assets/sprites/ 里的 preview/parts/uv/comparison/view 历史管线预览图只查 PNG 与文件大小，"
                 "不参与重复、暗背景和透明检查；其余精灵默认检查 alpha，也可用 --transparent-glob 指定。")
    return Report(
        root=root, art=art, generated_at=generated, options=opts,
        issues=issues, assets=assets, duplicates=duplicates, top_pairs=top_pairs,
        check_findings=findings, stats=stats, environment=env, notes=notes,
    )


# ---------------------------------------------------------------------------
# 报告
# ---------------------------------------------------------------------------


def _md_code(s: str) -> str:
    return "`" + s.replace("`", "'") + "`"


def _short(s: str, n: int = 180) -> str:
    s = " ".join(s.split())
    return s if len(s) <= n else s[: n - 1] + "…"


def render_markdown(report: Report) -> str:
    s = report.stats
    lead = report.lead_issues
    review = report.review_issues
    lines: list[str] = []
    lines.append(f"# 美术资产自动检查 — {report.generated_at}")
    lines.append("")
    lines.append(f"- 根目录：`{report.root}`")
    lines.append(f"- 扫描范围：`{report.art}`" + (" + `assets/sprites/`" if (report.root / 'assets/sprites').is_dir() else ""))
    lines.append(f"- 结论：**{len(lead)} 项硬性失败 / {len(review)} 项需人工确认**；"
                 f"PNG {s['png_valid']}/{s['png_total']} 合法，提示词 {s['prompt_files']} 份，"
                 f"RESULTS {s['result_records']} 条")
    lines.append(f"- 工具：Python {report.environment['python']} 标准库；缩略用 {report.environment['sips']}；Pillow 未使用")
    if report.environment.get("git"):
        lines.append(f"- 生成时 HEAD：`{report.environment['git']}`")
    lines.append("")
    lines.append("## 摘要")
    lines.append("")
    lines.append("| 项目 | 结果 |")
    lines.append("|---|---|")
    lines.append(f"| 提示词文件（rendered*） | {s['prompt_files']} |")
    lines.append(f"| 提示词规格（含 style/ui/compare） | {s['specs']} |")
    lines.append(f"| 唯一产物路径 | {s['unique_targets']} |")
    lines.append(f"| 缺少产物 | {s['missing_products']} |")
    lines.append(f"| 多余主图 | {s['extra_products']} |")
    lines.append(f"| 未登记备选图 | {s['unregistered_alts']} |")
    lines.append(f"| PNG 总数 / 合法 | {s['png_total']} / {s['png_valid']} |")
    lines.append(f"| 主图 / 备选 / 精灵 | {s['main_total']} / {s['alt_total']} / {s['sprite_total']} |")
    lines.append(f"| 长宽比异常 | {s['aspect_fail']} |")
    lines.append(f"| 文件过小 | {s['too_small']} |")
    lines.append(f"| 疑似重复对 | {s['duplicates']} |")
    lines.append(f"| RESULTS 文件 / 记录 | {s['result_files']} / {s['result_records']} |")
    lines.append(f"| status 非法 | {s['invalid_status']} |")
    lines.append(f"| RESULTS 引用文件缺失 | {s['result_missing_files']} |")
    lines.append(f"| checklist 不通过 / 待确认 | {s['checklist_fails']} / {s['checklist_pending']} |")
    lines.append(f"| 暗背景通过 / 失败 | {s['dark_pass']} / {s['dark_fail']} |")
    lines.append(f"| 透明通过 / 失败 | {s['alpha_pass']} / {s['alpha_fail']} |")
    lines.append("")

    lines.append("## 需要 Lead 看")
    lines.append("")
    if not lead and not review:
        lines.append("无。所有程序可判定项目通过。")
    else:
        if lead:
            lines.append(f"### 硬性失败（{len(lead)}）")
            lines.append("")
            for cat, title in (
                ("manifest", "清单"), ("spec", "规格"), ("duplicate", "重复"),
                ("results", "RESULTS"), ("background", "背景"), ("transparency", "透明"),
                ("tool", "工具"),
            ):
                items = [i for i in lead if i.code.split(".")[0] == cat]
                if not items:
                    continue
                lines.append(f"**{title}**")
                lines.append("")
                for i in items:
                    extra = f" — {_short(i.detail)}" if i.detail else ""
                    lines.append(f"- {_short(i.message, 300)}{extra}")
                lines.append("")
            others = [i for i in lead if i.code.split(".")[0] not in
                      {"manifest", "spec", "duplicate", "results", "background", "transparency", "tool"}]
            if others:
                lines.append("**其他**")
                lines.append("")
                for i in others:
                    lines.append(f"- {_short(i.message, 300)}")
                lines.append("")
        if review:
            lines.append(f"### 需人工确认（{len(review)}）")
            lines.append("")
            for i in review:
                extra = f" — {_short(i.detail)}" if i.detail else ""
                lines.append(f"- {_short(i.message, 300)}{extra}")
            lines.append("")

    lines.append("## 程序已判定通过")
    lines.append("")
    passed_checks: list[str] = []
    if s["png_invalid"] == 0:
        passed_checks.append(f"PNG 完整性：{s['png_total']} 个文件签名、chunk CRC、zlib 流和扫描行长度全部通过")
    existing = s["unique_targets"] - s["missing_products"]
    passed_checks.append(f"提示词清单：{existing}/{s['unique_targets']} 个目标路径存在产物；多余主图 {s['extra_products']} 个")
    if s["aspect_checked"]:
        if s["aspect_fail"] == 0:
            passed_checks.append(f"长宽比：{s['aspect_checked']} 张有规格的图全部在 ±10% 内")
        else:
            passed_checks.append(f"长宽比：{s['aspect_pass']}/{s['aspect_checked']} 张通过；{s['aspect_fail']} 张异常见上")
    if s["too_small"] == 0:
        passed_checks.append(f"文件大小：没有小于阈值的图（art {report.options.min_bytes // 1024}KB / 精灵 {report.options.sprite_min_bytes // 1024}KB）")
    if s["duplicates"] == 0:
        passed_checks.append("重复检测：没有发现完全相同或感知哈希过近的图对")
    else:
        passed_checks.append(f"重复检测：{s['png_total']} 张中仅 {s['duplicates']} 对达到提醒阈值，见上")
    if s["invalid_status"] == 0:
        passed_checks.append("RESULTS status：全部为 in_review / accepted / rejected")
    else:
        passed_checks.append(f"RESULTS 结构：{s['result_records']} 条记录有文件与 status 字段；status 枚举异常 {s['invalid_status']} 处见上")
    if s["checklist_fails"] == 0:
        passed_checks.append("RESULTS checklist：没有“不通过”项")
    else:
        passed_checks.append(f"RESULTS checklist：{s['result_records']} 条记录已解析；{s['checklist_fails']} 个“不通过”/ {s['checklist_pending']} 个待确认已单列")
    if s["dark_fail"] == 0:
        passed_checks.append(f"暗背景：明确要求暗背景的 {s['dark_pass']} 张四角平均亮度均 ≤ {report.options.dark_max:.0f}")
    if s["alpha_fail"] == 0:
        if s["alpha_pass"]:
            passed_checks.append(f"透明精灵：{s['alpha_pass']} 张 alpha 检查通过")
        else:
            passed_checks.append("透明精灵：当前没有要求透明背景的正式资产（--selftest 覆盖 alpha 正反例）")
    for c in passed_checks:
        lines.append(f"- {c}")
    if not passed_checks:
        lines.append("- 无")
    lines.append("")
    pass_rows = [a for a in report.assets if a.is_main and a.status == "pass"]
    if pass_rows:
        lines.append(f"### 通过的主图（{len(pass_rows)}）")
        lines.append("")
        lines.append("| 资产 | 尺寸 | 长宽比 | 规格 | 备注 |")
        lines.append("|---|---:|---:|---|---|")
        for a in pass_rows:
            ratio = f"{a.width / a.height:.3f}" if a.height else "—"
            notes = _short(a.notes, 90) if a.notes else " — "
            lines.append(f"| {_md_code(a.rel)} | {a.width}×{a.height} | {ratio} | {a.spec_label} | {notes} |")
        lines.append("")
    else:
        lines.append("（没有可列为通过的主图）")
        lines.append("")

    lines.append("## 明细")
    lines.append("")
    lines.append("### 感知重复最近邻")
    lines.append("")
    if report.top_pairs:
        lines.append("| RMS | dHash | 同组 | A | B |")
        lines.append("|---:|---:|---|---|---|")
        for p in report.top_pairs:
            lines.append(f"| {p.rms:.2f} | {p.dhash} | {'是' if p.same_group else '否'} | {_md_code(p.a)} | {_md_code(p.b)} |")
    else:
        lines.append("无可用指纹（或没有成对图片）。")
    lines.append("")
    lines.append("### checklist 不通过 / 待确认")
    lines.append("")
    if report.check_findings:
        lines.append("| 类型 | 文件 | 检查项 | 备注 |")
        lines.append("|---|---|---|---|")
        for f in report.check_findings:
            lines.append(f"| {'不通过' if f.kind == 'fail' else '待确认'} | {_md_code(f.path)} | {_short(f.label, 100)} | {_short(f.note, 160) or '—'} |")
    else:
        lines.append("无。")
    lines.append("")
    lines.append("### 说明")
    lines.append("")
    for n in report.notes:
        lines.append(f"- {n}")
    lines.append("")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# selftest
# ---------------------------------------------------------------------------


def _png_chunk(ctype: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + ctype + payload + struct.pack(">I", zlib.crc32(ctype + payload) & 0xFFFFFFFF)


def make_png(width: int, height: int, color_type: int, rows: list[bytes], level: int = 6) -> bytes:
    raw = b"".join(b"\x00" + row for row in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    return PNG_SIG + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", zlib.compress(raw, level)) + _png_chunk(b"IEND", b"")


def make_rgb_noise(path: Path, w: int, h: int, seed: int, corners: int | None = None,
                   corner_size: int = 0, level: int = 6) -> bytes:
    rnd = random.Random(seed)
    rows: list[bytes] = []
    for y in range(h):
        row = bytearray(rnd.randbytes(w * 3))
        if corners is not None:
            for x in range(w):
                if (x < corner_size or x >= w - corner_size or y < corner_size or y >= h - corner_size):
                    j = x * 3
                    row[j:j + 3] = bytes((corners, corners, corners))
        rows.append(bytes(row))
    data = make_png(w, h, 2, rows, level)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def make_rgba_sprite(path: Path, w: int, h: int, transparent: bool) -> bytes:
    rows: list[bytes] = []
    for y in range(h):
        row = bytearray()
        for x in range(w):
            if transparent and not (w // 4 <= x < 3 * w // 4 and h // 4 <= y < 3 * h // 4):
                row += bytes((0, 0, 0, 0))
            else:
                row += bytes((40, 180, 160, 255))
        rows.append(bytes(row))
    data = make_png(w, h, 6, rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def selftest() -> int:
    checks: list[str] = []
    with tempfile.TemporaryDirectory(prefix="artqa-selftest-") as td:
        root = Path(td)
        art = root / "art"
        prompts = art / "prompts" / "rendered"
        prompts.mkdir(parents=True)
        (art / "chars").mkdir(parents=True)
        (root / "assets" / "sprites").mkdir(parents=True)

        def prompt(name: str, w: int, h: int, dark: bool = True, extra: str = "") -> None:
            p = prompts / f"{name}.txt"
            bg = "dark painted background" if dark else "plain background"
            p.write_text(f"FORMAT: 2:3 ({w}x{h}), {bg}. {extra}\n", encoding="utf-8")

        prompt("CHAR-A__hero", 600, 900)
        prompt("CHAR-A__turnaround", 1024, 576)
        prompt("CHAR-B__hero", 600, 900)
        prompt("CHAR-C__hero", 600, 900)
        prompt("CHAR-E__hero", 600, 900)
        prompt("CHAR-F__hero", 600, 900)
        prompt("CHAR-G__hero", 600, 900)

        make_rgb_noise(art / "chars/CHAR-A/hero.png", 600, 900, 1, corners=18, corner_size=40)
        make_rgb_noise(art / "chars/CHAR-A/turnaround.png", 1024, 576, 2, corners=20, corner_size=30)
        # 同一批像素、不同压缩级别：字节不同但感知上完全相同
        make_rgb_noise(art / "chars/CHAR-A/alt/hero-v2.png", 600, 900, 1, corners=18,
                       corner_size=40, level=9)
        make_rgb_noise(art / "chars/CHAR-B/hero.png", 512, 512, 3, corners=20, corner_size=30)
        (art / "chars/CHAR-E/hero.png").parent.mkdir(parents=True, exist_ok=True)
        (art / "chars/CHAR-E/hero.png").write_bytes(b"not a png")
        make_rgb_noise(art / "chars/CHAR-D/hero.png", 600, 900, 4, corners=20, corner_size=30)
        make_rgb_noise(art / "chars/CHAR-F/hero.png", 32, 48, 5, corners=20, corner_size=4)
        make_rgb_noise(art / "chars/CHAR-G/hero.png", 600, 900, 6, corners=240, corner_size=60)
        make_rgba_sprite(root / "assets/sprites/good.png", 128, 128, True)
        make_rgba_sprite(root / "assets/sprites/bad.png", 128, 128, False)

        results = [
            {
                "file": "art/chars/CHAR-A/hero.png",
                "prompt_file": "art/prompts/rendered/CHAR-A__hero.txt",
                "status": "accepted",
                "checklist": [{"item": "线条", "result": "通过", "note": "ok"}],
            },
            {
                "file": "art/chars/CHAR-B/hero.png",
                "status": "review_required",
                "checklist": [{"item": "比例", "result": "通过"}],
            },
            {
                "file": "art/chars/CHAR-A/turnaround.png",
                "status": "in_review",
                "checklist": [{"item": "三视图", "result": "不通过", "note": "等高不满足"}],
            },
            {
                "file": "art/chars/CHAR-MISSING/hero.png",
                "status": "rejected",
                "checklist": [{"item": "x", "result": "通过"}],
            },
            {
                "file": "art/chars/CHAR-D/hero.png",
                "status": "in_review",
            },
        ]
        (art / "chars/RESULTS-TEST.json").write_text(json.dumps(results, ensure_ascii=False), encoding="utf-8")

        opts = Options(root=root, art=art, min_bytes=200 * 1024, sprite_min_bytes=100,
                       aspect_tol=0.10, dark_max=90.0,
                       transparent_globs=["assets/sprites/good.png", "assets/sprites/bad.png"],
                       quiet=True)
        report = run_check(opts)
        codes = {i.code for i in report.issues}
        expected = {
            "manifest.missing_product",
            "manifest.extra_product",
            "spec.invalid_png",
            "spec.too_small",
            "spec.aspect",
            "duplicate.near",
            "results.invalid_status",
            "results.checklist_fail",
            "results.missing_file",
            "results.missing_checklist",
            "background.too_bright",
            "transparency.corners",
        }
        missing = expected - codes
        checks.append(f"检测码覆盖 {len(expected) - len(missing)}/{len(expected)}")
        if missing:
            raise AssertionError(f"selftest 未检测到: {sorted(missing)}；实际: {sorted(codes)}")
        pass_a = [a for a in report.assets if a.rel == "art/chars/CHAR-A/hero.png"]
        if not pass_a or pass_a[0].status != "pass":
            raise AssertionError("CHAR-A/hero 应通过")
        checks.append("干净主图判为 pass")
        if not any(a.rel == "assets/sprites/good.png" and a.status == "pass" for a in report.assets):
            raise AssertionError("透明精灵 good.png 应通过")
        if not any(a.rel == "assets/sprites/bad.png" and "corners" in " ".join(a.fail_codes) for a in report.assets):
            raise AssertionError("不透明精灵 bad.png 应判失败")
        checks.append("透明精灵正反例")
        # 输出文件与两栏
        out = root / "reports" / "art-qa" / "selftest.md"
        out.parent.mkdir(parents=True, exist_ok=True)
        text = render_markdown(report)
        out.write_text(text, encoding="utf-8")
        for needle in ("## 需要 Lead 看", "## 程序已判定通过", "缺少产物", "长宽比不符", "checklist 不通过", "暗背景不达标"):
            if needle not in text:
                raise AssertionError(f"报告缺少: {needle}")
        checks.append("报告两栏与关键条目")
        if not report.stats["png_total"] >= 9:
            raise AssertionError("PNG 统计异常")
        checks.append("统计计数")
    print(f"SELFTEST PASS: {len(checks)} 项断言 / {', '.join(checks)}")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def find_root() -> Path:
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "AGENTS.md").is_file() or (p / ".git").exists():
            return p
    return Path.cwd().resolve()


def resolve_out(root: Path, out: str | None, stamp: str) -> Path:
    if out:
        p = Path(out)
        if not p.is_absolute():
            p = root / p
        if p.suffix.lower() == ".md":
            return p
        return p / f"{stamp}.md"
    return root / "reports" / "art-qa" / f"{stamp}.md"


def report_to_json(report: Report) -> dict:
    return {
        "generated_at": report.generated_at,
        "root": str(report.root),
        "art": str(report.art),
        "stats": report.stats,
        "environment": report.environment,
        "issues": [dataclasses.asdict(i) for i in report.issues],
        "assets": [dataclasses.asdict(a) for a in report.assets],
        "duplicates": [dataclasses.asdict(d) for d in report.duplicates],
        "top_pairs": [dataclasses.asdict(d) for d in report.top_pairs],
        "check_findings": [dataclasses.asdict(f) for f in report.check_findings],
        "notes": report.notes,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="美术资产自动检查（只读 art/）")
    parser.add_argument("--root", default=None, help="仓库根目录（默认自动查找）")
    parser.add_argument("--art", default=None, help="art 目录（默认 <root>/art）")
    parser.add_argument("--out", default=None, help="报告文件或目录（默认 reports/art-qa/<时间>.md）")
    parser.add_argument("--json-out", default=None, help="另存结构化 JSON")
    parser.add_argument("--selftest", action="store_true", help="用临时目录假文件自测")
    parser.add_argument("--include-archive", action="store_true", help="把 art/archive/ 也纳入")
    parser.add_argument("--min-bytes", type=int, default=MIN_BYTES_DEFAULT, help="普通美术文件大小下限（字节）")
    parser.add_argument("--sprite-min-bytes", type=int, default=SPRITE_MIN_BYTES_DEFAULT, help="精灵文件大小下限（字节）")
    parser.add_argument("--aspect-tol", type=float, default=ASPECT_TOL_DEFAULT, help="长宽比容差（默认 0.10）")
    parser.add_argument("--dark-max", type=float, default=DARK_MAX_DEFAULT, help="暗背景四角平均亮度上限（默认 90）")
    parser.add_argument("--transparent-glob", action="append", default=[],
                        help="额外要求透明 alpha 的路径 glob（可重复）")
    parser.add_argument("--strict", action="store_true", help="有硬性失败时退出码 1")
    parser.add_argument("--quiet", action="store_true", help="不打印摘要")
    args = parser.parse_args(argv)
    if args.selftest:
        return selftest()
    root = Path(args.root).resolve() if args.root else find_root()
    art = Path(args.art).resolve() if args.art else root / "art"
    opts = Options(
        root=root, art=art, include_archive=args.include_archive,
        min_bytes=args.min_bytes, sprite_min_bytes=args.sprite_min_bytes,
        aspect_tol=args.aspect_tol, dark_max=args.dark_max,
        transparent_globs=args.transparent_glob, quiet=args.quiet,
    )
    report = run_check(opts)
    stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = resolve_out(root, args.out, stamp)
    out.parent.mkdir(parents=True, exist_ok=True)
    text = render_markdown(report)
    out.write_text(text, encoding="utf-8")
    if args.json_out:
        jp = Path(args.json_out)
        if not jp.is_absolute():
            jp = root / jp
        jp.parent.mkdir(parents=True, exist_ok=True)
        jp.write_text(json.dumps(report_to_json(report), ensure_ascii=False, indent=1), encoding="utf-8")
    if not args.quiet:
        lead = len(report.lead_issues)
        review = len(report.review_issues)
        print(f"美术资产检查：{report.stats['png_total']} PNG / {report.stats['prompt_files']} 提示词 / "
              f"{report.stats['result_records']} RESULTS 条")
        print(f"硬性失败 {lead} 项，需人工确认 {review} 项")
        print(f"报告：{out}")
        for i in report.lead_issues[:12]:
            print(f"  [失败] {i.message}")
        if lead > 12:
            print(f"  … 其余 {lead - 12} 项见报告")
    if args.strict and report.lead_issues:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
