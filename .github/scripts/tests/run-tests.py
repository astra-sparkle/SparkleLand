#!/usr/bin/env python3
"""Unit tests for the applet's JavaScript helpers.

The helpers are plain JavaScript modules, so QuickJS runs them without a Plasma
session. Behavioral checks for the QML calendar object live next to this script in
calendar-shim-check.qml and need the Qt runtime instead.

Usage / 用法:
    python3 .github/scripts/tests/run-tests.py
"""

import json
import pathlib
import sys
import traceback

try:
    import quickjs
except ImportError:  # pragma: no cover - the CI workflow installs it
    print("需要 quickjs：python3 -m pip install quickjs", file=sys.stderr)
    sys.exit(2)

REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[3]


class QmlModule:
    """A QML JavaScript module evaluated in its own QuickJS context.

    一个在独立 QuickJS 上下文中求值的 QML JavaScript 模块。
    """

    def __init__(self, relative_path):
        self.path = REPOSITORY_ROOT / relative_path
        self.context = quickjs.Context()
        self.context.eval(self.path.read_text(encoding="utf-8"))

    def call(self, name, *arguments):
        # Arguments and results cross the boundary as JSON, which keeps QML objects
        # (plain maps and arrays) intact in both directions
        # 参数与返回值以 JSON 跨语言传递，使 QML 的普通对象与数组在两个方向都保持原样
        encoded = ", ".join(json.dumps(argument) for argument in arguments)
        result = self.context.eval(f"JSON.stringify(({name})({encoded}))")
        if result is None:
            return None
        return json.loads(result)

    def evaluate(self, expression):
        return self.context.eval(expression)


SPLAYER = QmlModule("contents/ui/Providers/SPlayer_Next.js")
LYRICS = QmlModule("contents/ui/Providers/LyricText.js")


# ---------------------------------------------------------------------------
# SPlayer-Next protocol, lyric timeline and request policy
# SPlayer-Next 协议、歌词时间轴与请求策略
#
# The policy tests cover the two behaviours that must stay bounded: a failed lyric
# fetch has to remain retryable, and the socket is attempted once per playback session.
# 策略测试覆盖两处必须有界的行为：歌词请求失败后仍可重试，
# 套接字在每次播放会话中只尝试一次。
# ---------------------------------------------------------------------------


def test_parse_message_accepts_events():
    message = SPLAYER.call("parseMessage", '{"kind":"event","type":"status","data":{"state":"playing"}}')
    assert message["kind"] == "event"
    assert message["type"] == "status"
    assert message["data"]["state"] == "playing"


def test_parse_message_fills_missing_event_data():
    message = SPLAYER.call("parseMessage", '{"kind":"event","type":"ended"}')
    assert message["data"] == {}


def test_parse_message_rejects_broken_or_unknown_frames():
    assert SPLAYER.call("parseMessage", "not json") is None
    assert SPLAYER.call("parseMessage", '{"kind":"mystery"}') is None
    assert SPLAYER.call("parseMessage", "") is None


def test_command_message_merges_payload():
    payload = json.loads(SPLAYER.call("commandMessage", "seek", {"positionMs": 1500}))
    assert payload == {"op": "seek", "positionMs": 1500}


def test_command_message_without_payload():
    assert json.loads(SPLAYER.call("commandMessage", "play")) == {"op": "play"}


def test_track_state_builds_stable_cache_key():
    track = {
        "id": "42",
        "source": "local",
        "title": "Song",
        "artists": [{"name": "A"}, {"name": "B"}],
        "album": {"name": "Album", "cover": "cover.png"},
        "duration": -5,
    }
    state = SPLAYER.call("trackState", track)
    assert state["key"] == "local:42"
    assert state["artist"] == "A / B"
    assert state["album"] == "Album"
    assert state["cover"] == "cover.png"
    assert state["duration"] == 0


def test_track_state_returns_null_without_track():
    assert SPLAYER.call("trackState", None) is None
    assert SPLAYER.call("trackState", {})["title"] == ""


def test_normalize_lines_sorts_and_fills_end_times():
    lines = SPLAYER.call("normalizeLines", [
        {"startTime": 2000, "endTime": 0, "words": [{"word": "second"}]},
        {"startTime": 1000, "endTime": 900, "words": [{"word": "first"}]},
        {"startTime": 3000, "words": []},
    ])
    assert [line["text"] for line in lines] == ["first", "second"]
    assert lines[0]["endTime"] == 2000
    assert lines[1]["endTime"] > lines[1]["startTime"]


def test_normalize_lines_keeps_translation_and_romanisation():
    lines = SPLAYER.call("normalizeLines", [
        {"startTime": 0, "words": [{"word": "a"}], "translatedLyric": "乙", "romanLyric": "b"},
    ])
    assert lines[0]["translation"] == "乙"
    assert lines[0]["roman"] == "b"


def test_index_at_finds_the_active_line():
    lines = [
        {"startTime": 1000, "endTime": 2000},
        {"startTime": 2000, "endTime": 3000},
        {"startTime": 5000, "endTime": 6000},
    ]
    assert SPLAYER.call("indexAt", lines, 0) == -1
    assert SPLAYER.call("indexAt", lines, 1000) == 0
    assert SPLAYER.call("indexAt", lines, 2500) == 1
    assert SPLAYER.call("indexAt", lines, 4999) == 1
    assert SPLAYER.call("indexAt", lines, 5000) == 2
    assert SPLAYER.call("indexAt", [], 1000) == -1


def test_line_cache_evicts_the_least_recently_used_entry():
    result = SPLAYER.evaluate(
        "(function () {"
        "  const cache = createLineCache(2);"
        "  cache.put('a', [1]);"
        "  cache.put('b', [2]);"
        "  cache.get('a');"
        "  cache.put('c', [3]);"
        "  return JSON.stringify([cache.size(), cache.get('a'), cache.get('b'), cache.get('c')]);"
        "})()"
    )
    assert json.loads(result) == [2, [1], None, [3]]


def test_failed_lyric_fetch_stays_retryable_until_the_limit():
    state = {"trackKey": "local:1", "appliedKey": "", "requestKey": "", "retries": 0, "limit": 3}
    assert SPLAYER.call("shouldRequestLyrics", state) is True

    state["requestKey"] = "local:1"
    assert SPLAYER.call("shouldRequestLyrics", state) is False

    # The read failed and released the in-flight marker, so a retry is allowed
    # 读取失败并释放了在途标记，因此允许重试
    state["requestKey"] = ""
    state["retries"] = 1
    assert SPLAYER.call("shouldRequestLyrics", state) is True

    state["retries"] = 3
    assert SPLAYER.call("shouldRequestLyrics", state) is False

    state["retries"] = 0
    state["appliedKey"] = "local:1"
    assert SPLAYER.call("shouldRequestLyrics", state) is False


def test_lyrics_are_not_requested_without_a_track():
    state = {"trackKey": "", "appliedKey": "", "requestKey": "", "retries": 0, "limit": 3}
    assert SPLAYER.call("shouldRequestLyrics", state) is False


def test_connection_attempts_once_per_playback_session():
    state = {"attempted": False, "connected": False, "connecting": False, "targetPlaying": True}
    assert SPLAYER.call("shouldAttemptConnection", state) is True

    # A failed attempt keeps the session closed until the MPRIS target disappears
    # 失败的尝试会保持会话关闭，直到 MPRIS 目标消失
    state["attempted"] = True
    state["targetPlaying"] = False
    assert SPLAYER.call("shouldAttemptConnection", state) is False

    state["targetPlaying"] = True
    assert SPLAYER.call("shouldAttemptConnection", state) is False

    # The registry resets the session when the target is lost
    # 目标消失后由注册中心重置会话
    state["attempted"] = False
    assert SPLAYER.call("shouldAttemptConnection", state) is True


def test_connection_skips_players_that_are_not_splayer():
    state = {"attempted": False, "connected": False, "connecting": False, "targetPlaying": False}
    assert SPLAYER.call("shouldAttemptConnection", state) is False

    state["connected"] = True
    state["targetPlaying"] = True
    assert SPLAYER.call("shouldAttemptConnection", state) is False

    state["connected"] = False
    state["connecting"] = True
    assert SPLAYER.call("shouldAttemptConnection", state) is False


# ---------------------------------------------------------------------------
# Lyric text splitting: a row holds 31 half-width units, and a break mark may use
# one extra unit that the layout reserves for it
# 歌词文本切分：一行容纳 31 个半角单位，断句标点可使用布局为它额外预留的一个单位
# ---------------------------------------------------------------------------


def test_short_line_is_kept_whole():
    parts = LYRICS.call("splitLine", "短句")
    assert parts == {"head": "短句", "tail": ""}


def test_full_width_line_splits_within_the_row():
    text = "一二三四五六七八九十一二三四五六七八九十"
    parts = LYRICS.call("splitLine", text)
    assert parts["head"] != ""
    assert parts["tail"] != ""
    assert LYRICS.call("textUnits", parts["head"]) <= 31
    assert parts["head"] + parts["tail"] == text


def test_half_width_text_uses_the_full_budget():
    # 31 half-width units fill the row exactly
    # 31 个半角单位正好填满一行
    text = "a" * 31 + " bbbb"
    parts = LYRICS.call("splitLine", text)
    assert parts == {"head": "a" * 31, "tail": "bbbb"}


def test_odd_budget_keeps_one_extra_half_width_unit():
    # 15 full-width labels plus one half-width unit still fit
    # 15 个全角字符再加一个半角单位仍能放进一行
    text = "一二三四五六七八九十一二三四五a"
    parts = LYRICS.call("splitLine", text)
    assert parts == {"head": text, "tail": ""}


def test_early_punctuation_ends_the_row():
    # The comma fits inside the extra unit, so the row ends right after it
    # 逗号落在额外预留的一个单位内，因此本行止于该逗号之后
    text = "一二三四五六七八九十甲乙丙丁戊，己庚辛壬癸子丑寅卯辰"
    parts = LYRICS.call("splitLine", text)
    assert parts["head"].endswith("，")
    assert LYRICS.call("textUnits", parts["head"]) == 32
    assert parts["head"] + parts["tail"] == text


def test_punctuation_after_the_row_is_ignored():
    # The comma comes after the budget, so the row falls back to the default cut
    # 逗号已超出可容纳宽度，因此按默认位置切分
    text = "一二三四五六七八九十一二三四五六七八九十一二，短"
    parts = LYRICS.call("splitLine", text)
    assert "，" not in parts["head"]
    assert LYRICS.call("textUnits", parts["head"]) <= 31
    assert parts["head"] + parts["tail"] == text


def test_period_outweighs_comma():
    # Both marks fit, but the sentence end is the stronger break
    # 两个标点都放得下，但句号是更强的断句
    text = "一二三。四五，六七八九十一二三四五六七八九十一二三四五"
    parts = LYRICS.call("splitLine", text)
    assert parts["head"] == "一二三。"
    assert "，" not in parts["head"]
    assert parts["head"] + parts["tail"] == text


def test_punctuation_outweighs_space():
    # The space comes first, but the comma carries a heavier weight
    # 空格先出现，但逗号的权重更高
    text = "abc defghijklmnopqrstuvwxyz,尾巴尾巴"
    parts = LYRICS.call("splitLine", text)
    assert parts["head"].endswith(",")
    assert parts["head"] + parts["tail"] == text


def test_empty_line_is_safe():
    parts = LYRICS.call("splitLine", "")
    assert parts == {"head": "", "tail": ""}
    assert LYRICS.call("splitLine", None) == {"head": "", "tail": ""}


def main():
    tests = []
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            tests.append((name, value))

    failed = 0
    for name, test in tests:
        try:
            test()
        except Exception:
            failed += 1
            print(f"FAIL {name}")
            traceback.print_exc()
        else:
            print(f"ok   {name}")

    print(f"\n{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
