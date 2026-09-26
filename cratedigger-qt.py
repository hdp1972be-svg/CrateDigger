#!/usr/bin/env python3
"""Thin Qt6 wrapper for the CrateDigger CLI.

The original ./shazam program is intentionally left untouched. This wrapper
runs it inside a pseudo-terminal (PTY), so the CLI still sees a real TTY:
ANSI colours, carriage-return progress updates, and the existing /dev/tty
live controls continue to work.

Usage:
    ./cratedigger-qt.py
    ./cratedigger-qt.py --live --input pulse --device shazam_sink.monitor --loop
    ./cratedigger-qt.py 'https://www.youtube.com/watch?v=VIDEO_ID' -t 10:00
"""

from __future__ import annotations

import os
import pty
import signal
import sys
from pathlib import Path

from PyQt6.QtCore import QSocketNotifier, Qt
from PyQt6.QtGui import QColor, QFont, QTextCharFormat, QTextCursor
from PyQt6.QtWidgets import QApplication, QMainWindow, QPlainTextEdit, QToolBar

APP_DIR = Path(__file__).resolve().parent
CLI = APP_DIR / "shazam"

ANSI_COLOURS = {
    30: QColor("#000000"), 31: QColor("#cc5555"), 32: QColor("#55aa55"),
    33: QColor("#bbbb55"), 34: QColor("#5555cc"), 35: QColor("#bb55bb"),
    36: QColor("#55bbbb"), 37: QColor("#dddddd"), 90: QColor("#666666"),
    91: QColor("#ff7777"), 92: QColor("#77dd77"), 93: QColor("#dddd77"),
    94: QColor("#7777ff"), 95: QColor("#dd77dd"), 96: QColor("#77dddd"),
    97: QColor("#ffffff"),
}


class Terminal(QPlainTextEdit):
    """Small terminal-like output widget, not a general terminal emulator."""

    def __init__(self):
        super().__init__()
        self.setReadOnly(True)
        self.setUndoRedoEnabled(False)
        self.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.setFont(QFont("Monospace", 10))
        self.setStyleSheet(
            "QPlainTextEdit { background: #111111; color: #dddddd; "
            "selection-background-color: #444444; border: 0; padding: 8px; }"
        )
        self._fmt = QTextCharFormat()
        self._fmt.setForeground(QColor("#dddddd"))
        self._pending = ""
        self._current_line = ""

    def feed(self, data: bytes):
        self._pending += data.decode("utf-8", errors="replace")
        self._render_pending()

    def _render_pending(self):
        while self._pending:
            esc = self._pending.find("\x1b")
            if esc == -1:
                chunk, self._pending = self._pending, ""
                self._consume_text(chunk)
                break

            if esc:
                self._consume_text(self._pending[:esc])
                self._pending = self._pending[esc:]

            if self._pending.startswith("\x1b["):
                end = next(
                    (i for i in range(2, len(self._pending))
                     if "@" <= self._pending[i] <= "~"),
                    None,
                )
                if end is None:
                    return
                sequence = self._pending[2:end]
                final = self._pending[end]
                self._pending = self._pending[end + 1:]
                if final == "m":
                    self._apply_sgr(sequence)
            else:
                self._pending = self._pending[1:]

    def _consume_text(self, text: str):
        for char in text:
            if char == "\r":
                self._current_line = ""
            elif char == "\n":
                self._write_line(self._current_line)
                self._current_line = ""
            elif char == "\b":
                self._current_line = self._current_line[:-1]
            elif char != "\x00":
                self._current_line += char

        if "\r" in text and "\n" not in text:
            self._replace_current_display_line()

    def _write_line(self, line: str):
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        cursor.insertText(line, self._fmt)
        cursor.insertText("\n", self._fmt)
        self.setTextCursor(cursor)
        self.ensureCursorVisible()

    def _replace_current_display_line(self):
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        if self.toPlainText():
            cursor.movePosition(
                QTextCursor.MoveOperation.StartOfBlock,
                QTextCursor.MoveMode.KeepAnchor,
            )
            cursor.removeSelectedText()
        cursor.insertText(self._current_line, self._fmt)
        self.setTextCursor(cursor)
        self.ensureCursorVisible()

    def _apply_sgr(self, sequence: str):
        try:
            codes = [int(x or "0") for x in sequence.split(";")] if sequence else [0]
        except ValueError:
            return

        for code in codes:
            if code == 0:
                self._fmt = QTextCharFormat()
                self._fmt.setForeground(QColor("#dddddd"))
            elif code == 1:
                fmt = QTextCharFormat(self._fmt)
                fmt.setFontWeight(QFont.Weight.Bold)
                self._fmt = fmt
            elif code == 2:
                fmt = QTextCharFormat(self._fmt)
                fmt.setForeground(QColor("#777777"))
                self._fmt = fmt
            elif code in ANSI_COLOURS:
                fmt = QTextCharFormat(self._fmt)
                fmt.setForeground(ANSI_COLOURS[code])
                self._fmt = fmt


class CrateDiggerWindow(QMainWindow):
    def __init__(self, argv):
        super().__init__()
        self.setWindowTitle("CrateDigger")
        self.resize(1000, 650)

        self.terminal = Terminal()
        self.setCentralWidget(self.terminal)

        toolbar = QToolBar()
        toolbar.setMovable(False)
        toolbar.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextOnly)
        self.addToolBar(toolbar)
        self.status = toolbar.addAction("Starting…")
        toolbar.addSeparator()
        toolbar.addAction("Stop").triggered.connect(self.stop_process)

        self.master_fd, child_pid = pty.fork()

        if child_pid == 0:
            env = os.environ.copy()
            env["TERM"] = "xterm-256color"
            env["FORCE_COLOR"] = "1"
            os.chdir(APP_DIR)
            os.execve(str(CLI), [str(CLI), *argv], env)

        self.child_pid = child_pid
        self.notifier = QSocketNotifier(
            self.master_fd, QSocketNotifier.Type.Read
        )
        self.notifier.activated.connect(self.read_pty)
        self.status.setText("Running")

    def read_pty(self, _fd):
        try:
            data = os.read(self.master_fd, 65536)
        except OSError:
            self.stop_notifier()
            return
        if not data:
            self.stop_notifier()
            return
        self.terminal.feed(data)

    def stop_notifier(self):
        if self.notifier is not None:
            self.notifier.setEnabled(False)
            self.notifier.deleteLater()
            self.notifier = None

    def keyPressEvent(self, event):
        # Forward the existing live controls without changing ./shazam.
        if event.text() in ("p", "n"):
            self.send_key(event.text())
            return
        if (
            event.key() == Qt.Key.Key_C
            and event.modifiers() & Qt.KeyboardModifier.ControlModifier
        ):
            self.stop_process()
            return
        super().keyPressEvent(event)

    def send_key(self, key: str):
        try:
            os.write(self.master_fd, key.encode())
        except OSError:
            pass

    def stop_process(self):
        if getattr(self, "child_pid", None):
            try:
                os.kill(self.child_pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            self.child_pid = None
        self.status.setText("Stopped")

    def closeEvent(self, event):
        self.stop_process()
        self.stop_notifier()
        try:
            os.close(self.master_fd)
        except OSError:
            pass
        event.accept()


def main():
    if not CLI.exists():
        print(f"CrateDigger CLI not found: {CLI}", file=sys.stderr)
        return 1

    app = QApplication(sys.argv)
    window = CrateDiggerWindow(sys.argv[1:])
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
