"""Backend tests for y666suf.com - leaderboard endpoints"""
import os
import pytest
import requests

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', 'https://game-hub-3d-7.preview.emergentagent.com').rstrip('/')
API = f"{BASE_URL}/api"


@pytest.fixture(scope="module")
def session():
    s = requests.Session()
    s.headers.update({"Content-Type": "application/json"})
    return s


# --- Root ---
def test_root_ok(session):
    r = session.get(f"{API}/")
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "ok"


# --- Leaderboard GET ---
def test_leaderboard_get_sorted_desc(session):
    r = session.get(f"{API}/leaderboard", params={"game": "nfg_crash"})
    assert r.status_code == 200
    items = r.json()
    assert isinstance(items, list)
    assert len(items) >= 10, f"Expected seeded data, got {len(items)}"
    scores = [it["score"] for it in items]
    assert scores == sorted(scores, reverse=True), "Scores not sorted desc"
    # ensure all from nfg_crash
    for it in items:
        assert it["game"] == "nfg_crash"
        assert "id" in it
        assert "player_name" in it


def test_leaderboard_limit_capped(session):
    r = session.get(f"{API}/leaderboard", params={"game": "nfg_crash", "limit": 500})
    assert r.status_code == 200
    assert len(r.json()) <= 100


# --- Seed idempotency ---
def test_seed_idempotent(session):
    r1 = session.post(f"{API}/leaderboard/seed")
    assert r1.status_code == 200
    d1 = r1.json()
    # Already seeded (>=10) -> seeded: false
    if d1.get("seeded") is True:
        # call again
        r2 = session.post(f"{API}/leaderboard/seed")
        assert r2.status_code == 200
        assert r2.json().get("seeded") is False
    else:
        assert d1.get("seeded") is False
        assert d1.get("count", 0) >= 10


# --- POST score persistence ---
def test_submit_score_persists(session):
    payload = {"player_name": "TEST_PLAYER_A", "score": 12345, "multiplier": 3.5, "game": "nfg_crash"}
    r = session.post(f"{API}/leaderboard/score", json=payload)
    assert r.status_code == 200, r.text
    created = r.json()
    assert created["player_name"] == "TEST_PLAYER_A"
    assert created["score"] == 12345
    assert created["multiplier"] == 3.5
    assert created["game"] == "nfg_crash"
    new_id = created["id"]
    assert isinstance(new_id, str) and len(new_id) > 0

    # verify by GET (use high limit)
    g = session.get(f"{API}/leaderboard", params={"game": "nfg_crash", "limit": 100})
    assert g.status_code == 200
    ids = [it["id"] for it in g.json()]
    assert new_id in ids, "Created entry not retrieved via GET"

    # cleanup
    d = session.delete(f"{API}/leaderboard/{new_id}")
    assert d.status_code == 200


# --- Validation ---
def test_negative_score_rejected(session):
    r = session.post(f"{API}/leaderboard/score", json={"player_name": "TEST_NEG", "score": -10})
    assert r.status_code == 422, f"Expected 422 for negative score, got {r.status_code}"


def test_empty_player_name_rejected(session):
    r = session.post(f"{API}/leaderboard/score", json={"player_name": "", "score": 10})
    assert r.status_code == 422, f"Expected 422 for empty name, got {r.status_code}"


# --- DELETE ---
def test_delete_invalid_returns_404(session):
    r = session.delete(f"{API}/leaderboard/non-existent-id-xyz-999")
    assert r.status_code == 404


def test_delete_valid_entry(session):
    create = session.post(f"{API}/leaderboard/score", json={"player_name": "TEST_DEL", "score": 1})
    assert create.status_code == 200
    eid = create.json()["id"]
    d = session.delete(f"{API}/leaderboard/{eid}")
    assert d.status_code == 200
    assert d.json().get("deleted") is True
    # second delete -> 404
    d2 = session.delete(f"{API}/leaderboard/{eid}")
    assert d2.status_code == 404
