"""Read comment author without using CommentEvent.user (broken ExtendedUser.from_user / nickName)."""
from __future__ import annotations

import re
from typing import Any

from text_normalize import normalize_display_name, normalize_tiktok_user_key

from TikTokLive.events.proto_events import CommentEvent, GiftEvent
from TikTokLive.proto.custom_proto import ExtendedUser

try:
    from TikTokLive.proto.tiktok_proto import BadgeStructBadgeSceneType
except ImportError:
    BadgeStructBadgeSceneType = None  # type: ignore[misc, assignment]

try:
    from TikTokLive.proto.tiktok_proto import (
        PublicAreaMessageCommonUserMetricsUserMetricsType as _PamUserMetricsType,
    )
except ImportError:
    _PamUserMetricsType = None  # type: ignore[misc, assignment]


def effective_tiktok_user_key(uid: str, nick: str) -> str:
    """
    TikTok sometimes omits stable ids; ``uid`` may be empty or the literal ``anon``.

    Using ``anon`` as the runtime key makes unrelated viewers share one player bucket (elimination,
    wagers, gift pending maps). Prefer the display handle when the id is missing or anon.
    """
    u = (uid or "").strip()
    n = (nick or "").strip()
    if not u or u.lower() == "anon":
        return n or "anon"
    return u


def stable_user_key_and_name(ui: Any) -> tuple[str, str]:
    """
    Returns (user_key, display_name). user_key must be stable per viewer so scores don't collide
    when @username is missing (use TikTok id / id_str / sec_uid before falling back to nickname).
    """
    if ui is None:
        return ("anon", "anon")
    nick = normalize_display_name(
        str(getattr(ui, "nick_name", None) or getattr(ui, "nickName", None) or "")
    )
    username = normalize_tiktok_user_key(str(getattr(ui, "username", None) or ""))
    id_str = normalize_tiktok_user_key(str(getattr(ui, "id_str", None) or ""))
    sec_uid = normalize_tiktok_user_key(str(getattr(ui, "sec_uid", None) or ""))
    num_id = getattr(ui, "id", None)

    if username:
        key = username
    elif id_str:
        key = id_str
    elif num_id:
        try:
            key = str(int(num_id))
        except (TypeError, ValueError):
            key = ""
        if not key:
            key = sec_uid or nick or "anon"
    elif sec_uid:
        key = sec_uid
    else:
        key = nick or "anon"

    if not nick:
        nick = username or (key if key != "anon" else "anon")
    return (key, nick)


def extract_comment_author(event: CommentEvent) -> tuple[str, str]:
    """
    Returns (user_key, display_name).
    TikTok's protobuf can expose camelCase in dict conversions; avoid event.user.
    """
    return stable_user_key_and_name(event.user_info)


def extract_gift_sender(event: GiftEvent) -> tuple[str, str]:
    """Returns (user_key, display_name) for a gift sender (uses from_user)."""
    return stable_user_key_and_name(event.from_user)


def _fan_club_room_total_from_fans_club_info_obj(fci: Any) -> int | None:
    if fci is None:
        return None
    for attr in ("fans_count", "fansCount"):
        try:
            v = int(getattr(fci, attr, 0) or 0)
        except (TypeError, ValueError):
            continue
        if 0 < v <= 5_000_000:
            return v
    return None


def fan_club_room_total_from_user(user: Any) -> int | None:
    """
    Best-effort total Heart Me / fan-club members for this LIVE from a TikTok User payload.

    TikTok may expose this on ``UserFansClubInfo`` (snake_case or camelCase field names).
    Values are capped to ignore obvious garbage.
    """
    if user is None:
        return None
    fci = getattr(user, "fans_club_info", None) or getattr(user, "fansClubInfo", None)
    return _fan_club_room_total_from_fans_club_info_obj(fci)


def _user_metric_type_is_fans_club(t: Any) -> bool:
    if t is None:
        return False
    try:
        if _PamUserMetricsType is not None and t == _PamUserMetricsType.USER_METRICS_TYPE_FANS_CLUB:
            return True
    except Exception:
        pass
    try:
        if int(t) == 4:
            return True
    except (TypeError, ValueError):
        pass
    return "FANS_CLUB" in str(t).upper()


def _parse_public_area_metrics_count(raw: Any) -> int | None:
    """Parse ``metrics_value`` (often digits or digit groups with commas) into a capped int."""
    if raw is None:
        return None
    s = str(raw).strip().replace(",", "").replace(" ", "").replace("\u00a0", "")
    if not s:
        return None
    if s.isdigit():
        try:
            v = int(s)
        except ValueError:
            return None
        if 0 < v <= 5_000_000:
            return v
        return None
    # e.g. "12.5K" / "1.2M" (rare for this field)
    if len(s) < 2:
        return None
    suf = s[-1].upper()
    if suf not in ("K", "M"):
        return None
    body = s[:-1].strip()
    try:
        base = float(body)
    except ValueError:
        return None
    mult = 1000.0 if suf == "K" else 1_000_000.0
    v = int(base * mult)
    if 0 < v <= 5_000_000:
        return v
    return None


def _parse_public_area_metrics_count_loose(raw: Any) -> int | None:
    """Like strict parse, then pull integers from mixed text (e.g. labels with the count at the end)."""
    v = _parse_public_area_metrics_count(raw)
    if v is not None:
        return v
    if raw is None:
        return None
    s = str(raw)
    best: int | None = None
    for m in re.finditer(r"\d[\d,\s]*\d|\d+", s):
        t = m.group(0).replace(",", "").replace(" ", "").replace("\u00a0", "")
        if not t.isdigit():
            continue
        try:
            n = int(t)
        except ValueError:
            continue
        if 0 < n <= 5_000_000:
            best = n if best is None else max(best, n)
    return best


def fan_club_room_total_from_public_area(pamc: Any) -> int | None:
    """
    Room-level fan / Heart Me member count from ``PublicAreaMessageCommon`` when TikTok
    attaches ``portrait_info.user_metrics`` with type ``USER_METRICS_TYPE_FANS_CLUB``.
    Often populated when ``UserFansClubInfo.fans_count`` on the user object is zero or missing.
    """
    if pamc is None:
        return None
    portrait = getattr(pamc, "portrait_info", None)
    if portrait is None:
        return None
    metrics = getattr(portrait, "user_metrics", None) or []
    best: int | None = None
    for m in metrics:
        if not _user_metric_type_is_fans_club(getattr(m, "type", None)):
            continue
        raw_mv = getattr(m, "metrics_value", None)
        v = _parse_public_area_metrics_count(raw_mv)
        if v is None:
            v = _parse_public_area_metrics_count_loose(raw_mv)
        if v is not None:
            best = v if best is None else max(best, v)
    tags = getattr(portrait, "portrait_tag", None) or []
    for t in tags:
        tag_id = (getattr(t, "tag_id", None) or "").strip().lower()
        if not tag_id or ("fan" not in tag_id and "club" not in tag_id and "heart" not in tag_id):
            continue
        v = _parse_public_area_metrics_count_loose(getattr(t, "show_value", None))
        if v is not None:
            best = v if best is None else max(best, v)
    return best


def _badge_scene_is_fans(sc: Any) -> bool:
    """True if a BadgeStruct.badge_scene value is the FANS / Heart Me team badge."""
    if sc is None:
        return False
    try:
        if BadgeStructBadgeSceneType is not None and sc == BadgeStructBadgeSceneType.BADGE_SCENE_TYPE_FANS:
            return True
    except Exception:
        pass
    try:
        if int(sc) == 10:
            return True
    except (TypeError, ValueError):
        pass
    name = str(sc).upper()
    return "BADGE_SCENE_TYPE_FANS" in name or name.endswith(".FANS") or name == "FANS"


def _fan_club_is_sleeping(ui: Any) -> bool:
    """TikTok sets UserFansClubInfo.is_sleeping when Heart Me / fan club is inactive (greyed)."""
    fci = getattr(ui, "fans_club_info", None)
    if fci is None:
        return False
    return bool(getattr(fci, "is_sleeping", False))


def _badge_list_fans_all_greyed(ui: Any) -> bool:
    """
    True if badge_list has at least one FANS badge and every one is greyed (greyed_by_client != 0).
    In that case the viewer must not be treated as an active fan, even if ExtendedUser still reports FANS.
    """
    bl = getattr(ui, "badge_list", None) or []
    fans_badges: list[Any] = []
    for b in bl:
        if _badge_scene_is_fans(getattr(b, "badge_scene", None)):
            fans_badges.append(b)
    if not fans_badges:
        return False
    for b in fans_badges:
        if int(getattr(b, "greyed_by_client", 0) or 0) == 0:
            return False
    return True


def _badge_list_includes_fans_team(ui: Any) -> bool:
    """True if User.badge_list has an active (non-greyed) FANS / fan-team badge."""
    bl = getattr(ui, "badge_list", None) or []
    for b in bl:
        if not _badge_scene_is_fans(getattr(b, "badge_scene", None)):
            continue
        if int(getattr(b, "greyed_by_client", 0) or 0) != 0:
            continue
        return True
    return False


def _user_has_fan_club_access(ui: Any) -> bool:
    """
    Detect fan club / Heart Me / team membership from TikTok User payloads.
    Uses ExtendedUser FANS badge (same as TikTokLive docs), fans_club_info, and fans_club blocks.
    Inactive / greyed Heart Me (is_sleeping or only greyed FANS badges) does not count.
    """
    if ui is None:
        return False
    if _fan_club_is_sleeping(ui):
        return False
    if _badge_list_fans_all_greyed(ui):
        return False
    try:
        eu = ui if isinstance(ui, ExtendedUser) else ExtendedUser.from_user(ui)
        if eu.member_level is not None:
            return True
        if eu.has_badge("FANS"):
            return True
        for badge_name, _ in eu.get_all_badges:
            if "FANS" in (badge_name or "").upper():
                return True
    except Exception:
        pass
    if _badge_list_includes_fans_team(ui):
        return True
    try:
        fci = getattr(ui, "fans_club_info", None)
        if fci is not None:
            if int(getattr(fci, "fans_level", 0) or 0) > 0:
                return True
            if int(getattr(fci, "fans_score", 0) or 0) > 0:
                return True
            if (getattr(fci, "fans_club_name", None) or "").strip():
                return True
    except Exception:
        pass
    try:
        fc = getattr(ui, "fans_club", None)
        if fc is None:
            return False
        data = getattr(fc, "data", None)
        if data is not None:
            if int(getattr(data, "level", 0) or 0) > 0:
                return True
            if int(getattr(data, "user_fans_club_status", 0) or 0) != 0:
                return True
        pref = getattr(fc, "prefer_data", None) or {}
        for pdata in pref.values():
            if int(getattr(pdata, "level", 0) or 0) > 0:
                return True
            if int(getattr(pdata, "user_fans_club_status", 0) or 0) != 0:
                return True
    except Exception:
        pass
    return False


def comment_user_is_fan_club_member(event: CommentEvent) -> bool:
    """
    Best-effort: fan club / team (Heart Me) on TikTok LIVE.
    """
    try:
        if getattr(event, "user_is_super_fan", False):
            return True
    except Exception:
        pass
    try:
        ident = getattr(event, "user_identity", None)
        if ident is not None and getattr(ident, "is_subscriber_of_anchor", False):
            return True
    except Exception:
        pass
    ui = getattr(event, "user_info", None)
    return _user_has_fan_club_access(ui)


def gift_user_is_fan_club_member(event: GiftEvent) -> bool:
    """Same fan-team detection for gift senders."""
    try:
        if getattr(event, "user_is_super_fan", False):
            return True
    except Exception:
        pass
    try:
        ident = getattr(event, "user_identity", None)
        if ident is not None and getattr(ident, "is_subscriber_of_anchor", False):
            return True
    except Exception:
        pass
    return _user_has_fan_club_access(getattr(event, "from_user", None))
