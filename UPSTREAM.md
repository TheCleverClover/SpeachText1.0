# Upstream provenance

SpeachText1.0 began from the public **FluidVoice v1.6.8** source release:

- Upstream repository: https://github.com/altic-dev/FluidVoice
- Upstream tag: `v1.6.8`
- Upstream commit: `a76736eb398576e340f222a8c1347a6a9d6b3574`
- Import date: 2026-08-12
- License at import: GNU General Public License v3.0

ALTIC and the FluidVoice contributors are not responsible for this derivative. FluidVoice and Fluid Intelligence names belong to their respective owners. The closed-source Fluid Intelligence runtime is not part of the imported public source and is not redistributed by SpeachText1.0.

All SpeachText1.0 modifications remain available under GPLv3. Third-party dependencies and downloadable models retain their own licenses; the default Qwen3 model is offered under Apache License 2.0.

## FluidAudio compatibility fork

SpeachText1.0 uses [TheCleverClover/FluidAudio-SpeachText](https://github.com/TheCleverClover/FluidAudio-SpeachText) at commit `2c7755ba2e0866c0e0db41d686e228270eab8fa0`. It is based on ALTIC's public FluidAudio revision `543395149d02100321966fd3312ea55333d6fc2f` from the `B/cohere-coreml-asr` branch.

The fork preserves macOS 15 compatibility by declaring the two Granite Core ML model-container value types as `@unchecked Sendable`. The model containers are loaded into, and subsequently owned by, their respective actors; the patch addresses Swift 6's compile-time transfer check without changing speech-model behavior or data handling.

The fork retains the upstream license and source history. Its use does not imply endorsement by ALTIC or FluidAudio contributors.
