# SpeachText1.0

![SpeachText1.0 — private speech transformed into text](Branding/SpeachText1.0-Release-Hero.png)

**SpeachText1.0** is a local-first macOS dictation application. It turns speech into text in any application, supports multiple on-device speech engines, offers optional local AI cleanup, and includes an explicitly controlled Command Mode for Mac automation.

> The project name intentionally uses the spelling **SpeachText1.0**.

## Core features

| Area | Included capability |
|---|---|
| Dictation | Global push-to-talk, live preview, direct typing through macOS Accessibility APIs, microphone selection, and per-app configuration |
| Speech engines | Apple Speech, Whisper, Parakeet, Nemotron, and other models supported by the inherited FluidAudio pipeline |
| Local enhancement | Open on-device text cleanup using an MLX-optimized Qwen model on Apple Silicon; cloud providers remain optional |
| Command Mode | Voice-driven Mac actions and terminal commands with confirmation for destructive or high-impact operations |
| Editing | Dictate, write, rewrite, custom vocabulary, pronunciation training, and transcript/audio history controls |
| Privacy Lock | Configurable sensitive applications automatically force local-only processing and suppress risky features |
| Voice Macros | Deterministic spoken shortcuts for text snippets, app launching, URLs, and Apple Shortcuts without an LLM |
| Recovery Vault | A local ring buffer of recent text insertions with instant undo and restore |

## Privacy

SpeachText1.0 contains **no product analytics or telemetry**. Dictation and enhancement stay on the Mac when a local speech model and local enhancement are selected. Choosing OpenAI, Anthropic, Groq, Gemini, OpenRouter, or another remote provider sends the relevant text to that provider under its terms. API keys are stored in the macOS Keychain.

Privacy Lock is enabled by default for common password managers, banking applications, and private-browsing contexts. Users can edit the list in Settings.

## Command Mode safety

Command Mode is available and enabled by default, but it is never silent. Destructive actions, privilege changes, application automation, outbound messages, file deletion, package installation, and commands outside the user’s home directory require confirmation. The feature can be disabled at any time.

## Requirements

- macOS 15.0 or later
- Apple Silicon for the MLX local enhancement model and most high-performance speech models
- Intel Macs can use Apple Speech and supported Whisper paths
- Microphone permission for capture
- Accessibility permission for system-wide typing
- Optional Automation permission for Apple Shortcuts and application control

## Build from source

```bash
git clone <your-repository-url>
cd SpeachText1.0
open SpeachText1.0.xcodeproj
```

Choose a development team in Xcode, then build the **SpeachText1.0** scheme. Dependencies are resolved with Swift Package Manager.

For an unsigned local build:

```bash
./build.sh unsigned
```

For a signed development build:

```bash
SPEACHTEXT_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./build.sh
```

## Distribution

The repository includes a macOS release workflow that builds, tests, archives, packages, hashes, and publishes downloadable ZIP and DMG files. A valid Apple Developer ID and notarization secrets are optional; without them, recipients must approve the unsigned build in macOS Privacy & Security.

## License and upstream attribution

SpeachText1.0 is licensed under **GNU GPLv3** because it is a derivative of the public FluidVoice codebase. The original FluidVoice project is maintained by ALTIC and available at [altic-dev/FluidVoice](https://github.com/altic-dev/FluidVoice). The proprietary Fluid Intelligence runtime is **not** included or copied. SpeachText1.0 implements its own open local enhancement path.

See [UPSTREAM.md](UPSTREAM.md) for provenance and [LICENSE](LICENSE) for full terms.

## References

1. [FluidVoice public repository](https://github.com/altic-dev/FluidVoice)
2. [Apple MLX overview](https://mlx-framework.org/)
3. [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)
4. [Qwen3-1.7B MLX model card](https://huggingface.co/Qwen/Qwen3-1.7B-MLX-4bit)
