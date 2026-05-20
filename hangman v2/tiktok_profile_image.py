"""Fetch TikTok profile avatar bytes (best-effort; page HTML parsing)."""
from __future__ import annotations

import re
from typing import Optional

import httpx

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)


def _extract_avatar_url(html: str) -> Optional[str]:
    for key in ("avatarLarger", "avatarMedium", "avatarThumb"):
        m = re.search(rf'"{key}"\s*:\s*"([^"]+)"', html)
        if m:
            url = m.group(1).replace("\\/", "/").replace("\\u002F", "/")
            if url.startswith("http"):
                return url
    m = re.search(
        r"(https://p\d+-sign[^\s\"<>\\]+\.(?:jpe?g|webp)(?:\?[^\s\"<>]*)?)",
        html,
    )
    if m:
        return m.group(1).replace("\\/", "/")
    return None


async def fetch_profile_avatar_bytes(unique_id: str) -> Optional[bytes]:
    if not unique_id:
        return None
    uid = unique_id.strip().lstrip("@")
    page_url = f"https://www.tiktok.com/@{uid}"
    headers = {"User-Agent": UA, "Accept-Language": "en-GB,en;q=0.9"}
    try:
        async with httpx.AsyncClient(timeout=18.0, follow_redirects=True) as client:
            r = await client.get(page_url, headers=headers)
            html = r.text
            pic_url = _extract_avatar_url(html)
            if not pic_url:
                return None
            ir = await client.get(pic_url, headers={**headers, "Referer": page_url})
            if ir.status_code == 200 and ir.content[:4] not in (b"<htm", b"<!DO"):
                return ir.content
    except (httpx.HTTPError, OSError):
        return None
    return None


def fallback_avatar_svg() -> bytes:
    return """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="a" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#c084fc"/><stop offset="100%" style="stop-color:#6b21a8"/>
    </linearGradient>
  </defs>
  <circle cx="64" cy="64" r="64" fill="url(#a)"/>
  <text x="64" y="76" text-anchor="middle" fill="#f3e8ff" font-family="Segoe UI,system-ui,sans-serif"
    font-size="34" font-weight="800">NFG</text>
</svg>""".encode(
        "utf-8"
    )
