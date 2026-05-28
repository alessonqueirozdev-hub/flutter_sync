# Security Policy

## Supported versions

FlutterSync is in early-stage development (v0.1.x). The latest minor version receives all fixes.

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |
| < 0.1.0 | No        |

## Reporting a vulnerability

**Please do not open public GitHub issues for security reports.**

Use one of the private channels below:

1. **Preferred** — open a private vulnerability report via GitHub's "Security" tab:
   https://github.com/alessonqueirozdev-hub/flutter_sync/security/advisories/new
2. **Alternative** — email the maintainer at `alessonqueiroz.dev@gmail.com` with the subject `FlutterSync security` and a clear description.

Please include:

- A description of the issue and the affected component (HLC, outbox, an adapter, encryption, etc.).
- Steps to reproduce, ideally with a minimal repro case.
- The version (or commit SHA) you observed it on.
- The impact you believe a real exploit would have.

## Response timeline

This is a community project staffed by volunteers, so timelines are best-effort:

| Step | Target |
|------|--------|
| Acknowledgement of receipt | within 5 business days |
| Initial severity assessment | within 10 business days |
| Fix or mitigation timeline | communicated after assessment |
| Public disclosure | coordinated with reporter |

Reporters are credited in the release notes unless they request otherwise.

## Cryptography note

FlutterSync ships AES-256-GCM at rest with Argon2id key derivation (default parameters `memory = 64 MiB`, `iterations = 3`, `parallelism = 4`). The implementations live under `lib/src/encryption/`.

**Important caveat:** the cryptographic code has not yet undergone third-party security review. Until it does, treat encryption as defense-in-depth, not as a sole control for highly sensitive data. If you can fund or perform a review, we would love to coordinate — open a Discussion or contact the maintainer.

## Out of scope

The following are not currently considered FlutterSync security issues:

- Vulnerabilities in third-party packages (`drift`, `cryptography`, `supabase_flutter`, etc.) — report those upstream first; we will pick up the relevant version bumps.
- Misconfigured server-side RLS / auth policies in the user's own backend.
- Information disclosure that requires a compromised device with full disk access.

Thank you for helping keep FlutterSync safe.
