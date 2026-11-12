#!/usr/bin/env python3
# 发布前清除 QML 注释：删除纯注释行、截断行尾注释，并清理因此留下的空行
# Strip QML comments for releases: drop comment-only lines, truncate trailing comments, tidy the gaps
#
# 用法 / Usage:
#   python3 strip_qml_comments.py FILE.qml [...]
#   python3 strip_qml_comments.py --check FILE.qml [...]
#
# --check 只校验不写入：文件中不得再有引号外的 //，且再清除一次不应产生任何变化
# --check verifies without writing: no // outside string literals may remain and stripping must be a no-op
#
# 只处理 QML：contents/config/main.xml 的 xmlns / schemaLocation 含 //，绝不能交给本脚本
# QML only: contents/config/main.xml contains // in xmlns / schemaLocation and must never be passed here

from __future__ import annotations

import sys
from pathlib import Path

QUOTES = ("'", '"', "`")


def scan_line(line: str) -> tuple[str, str, int]:
    """返回 (引号外 // 之前的代码, 行末仍未闭合的引号, 注释起点) / (code, open quote, comment index)"""
    quote = ""
    escaped = False
    for index, char in enumerate(line):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char in QUOTES:
            quote = char
        elif char == "/" and line.startswith("//", index):
            return line[:index], "", index
    return line, quote, -1


def strip_text(text: str) -> str:
    """清除注释后的全文 / Full text with comments removed"""
    kept: list[str] = []
    removed_before = False
    for line in text.splitlines():
        code, quote, comment_index = scan_line(line)
        if quote:
            raise ValueError("存在未闭合的字符串字面量 / unterminated string literal")
        if comment_index >= 0:
            code = code.rstrip()
            if not code:
                removed_before = True
                continue
        if not code.strip() and removed_before and kept and kept[-1] == "":
            removed_before = False
            continue
        kept.append(code)
        removed_before = False
    if not kept:
        return ""
    body = "\n".join(kept)
    return body + "\n" if text.endswith("\n") else body


def check_file(path: Path) -> list[str]:
    """校验文件已无注释且不可再被清除 / Verify the file carries no comments and cannot be stripped further"""
    text = path.read_text(encoding="utf-8")
    problems: list[str] = []
    if strip_text(text) != text:
        problems.append("仍有可清除的注释 / comments can still be stripped")
    for number, line in enumerate(text.splitlines(), 1):
        _, _, comment_index = scan_line(line)
        if comment_index >= 0:
            problems.append(f"第 {number} 行仍有注释 / comment left: {line.strip()}")
    return problems


def main(argv: list[str]) -> int:
    args = argv[1:]
    check_only = bool(args) and args[0] == "--check"
    if check_only:
        args = args[1:]
    if not args:
        print("用法 / usage: strip_qml_comments.py [--check] FILE.qml [...]", file=sys.stderr)
        return 2

    failed = 0
    for name in args:
        path = Path(name)
        try:
            if check_only:
                problems = check_file(path)
                for problem in problems:
                    print(f"{path}: {problem}", file=sys.stderr)
                failed += 1 if problems else 0
            else:
                text = path.read_text(encoding="utf-8")
                stripped = strip_text(text)
                if stripped != text:
                    path.write_text(stripped, encoding="utf-8")
                    removed = len(text.splitlines()) - len(stripped.splitlines())
                    print(f"{path}: 删除 {removed} 行 / removed {removed} lines")
        except (OSError, ValueError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
