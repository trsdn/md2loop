# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Regression tests for clipboard content detection, Markdown/HTML roundtrips, nested lists, and RTF conversion.
- RTF fallback for converting rich text clipboard content to Markdown when HTML is not available.

### Fixed

- Detect single-signal Markdown content such as simple bullet lists, ordered lists, inline code, and bold text.
- Preserve nested list structure when converting HTML to Markdown.
- Preserve whitespace inside HTML code blocks during Markdown conversion.

## [1.0.0] - 2026-02-27

### Added

- Markdown → Loop conversion (HTML/RTF clipboard)
- Loop → Markdown conversion (HTML parsing)
- Auto-detection of clipboard content type
- Support for headings, bold, italic, strikethrough, lists, ordered lists, task lists, tables, code blocks, inline code, links, images, blockquotes, horizontal rules
- macOS native SwiftUI app
- Keyboard shortcut ⌘⏎ for conversion
- Unicode checkbox support for task lists (☑/☐)
- Multi-format clipboard output (HTML + RTF + plain text)
