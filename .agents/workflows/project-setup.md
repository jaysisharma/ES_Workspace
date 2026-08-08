---
name: project-setup
description: Complete automated end-to-end setup for Flutter & Next.js projects. Installs UI/motion packages, sets up rules, GEMINI.md, .geminiignore, Graphify AST hooks, builds initial UI foundation, and verifies build integrity.
---

# Complete End-to-End Project Setup & Foundation Builder

When `/project-setup` is run on any project directory:

## 1. Automatic Framework Detection
- **Next.js**: If `next.config.*` or `package.json` with `"next"` exists.
- **Flutter**: If `pubspec.yaml` exists.

## 2. Rules & Token Guard
- **Rules**: Create `.agents/rules/nextjs_rules.md` or `flutter_rules.md` and `GEMINI.md`.
- **Token Guard**: Create `.geminiignore` (`.next/`, `node_modules/`, `build/`, `.dart_tool/`, `*.g.dart`).

## 3. Essential UI & Motion Package Installation & Helpers
- **Next.js**: Install `framer-motion`, `lucide-react`, `clsx`, `tailwind-merge`. Create `src/lib/utils.ts` class merger.
- **Flutter**: Ensure `flutter_riverpod`, `google_fonts`, `cupertino_icons` in `pubspec.yaml`.

## 4. Graphify AST Knowledge Graph & Git Hooks
- Run `graphify antigravity install` and `graphify hook install`.

## 5. UI Foundation & Build Verification
- Build an initial responsive UI foundation.
- Verify build compilation (`npm run build` or `flutter analyze`).
