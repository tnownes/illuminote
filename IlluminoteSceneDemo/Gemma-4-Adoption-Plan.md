# Gemma 4 Adoption Plan

Last updated: April 3, 2026

## Purpose

This plan outlines a low-risk path to evaluate and, if justified, adopt Google's newly released Gemma 4 models inside Illuminote.

The goal is not to replace the current AI stack immediately. The goal is to determine whether Gemma 4 can improve on-device quality, structured reliability, and future multimodal capability without compromising the app's core posture: private, calm, trustworthy, and iPhone-first.

## Current App Reality

Illuminote's existing AI implementation is already strongly opinionated:

- On-device inference runs through MLX and `MLXLMCommon` in [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L107).
- Runtime model selection is hard-coded around Qwen profiles in [Services/DeviceCapabilities.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/DeviceCapabilities.swift#L3).
- The main AI experience today is the critique-first Advisor with tightly budgeted prompts in [PSBuilder/Advisor/AIAdvisorPromptBuilder.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/PSBuilder/Advisor/AIAdvisorPromptBuilder.swift#L92).
- Insights uses optional local AI only as a strict JSON reranker in [Insights/InsightsAnalysisService.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Insights/InsightsAnalysisService.swift#L284).
- Dynamic reflection prompting is still effectively stubbed in [Services/AIPromptService.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/AIPromptService.swift#L59).

This means Gemma 4 should be introduced as a new model family inside the current architecture, not as a broad AI rewrite.

## Recommendation

Adopt Gemma 4 in three stages:

1. Run a validation spike for Gemma 4 E2B as a text-only experimental profile.
2. If the spike succeeds, add Gemma 4 E2B as an optional experimental Advisor and Insights model.
3. Only after text quality and runtime stability are proven, evaluate multimodal audio/image flows.

Do not begin with Gemma 4 as the default model.

## Why Gemma 4 Is Worth Evaluating

Based on Google's April 2, 2026 release materials, Gemma 4 appears relevant for Illuminote because it offers:

- Open weights under Apache 2.0.
- Small edge-oriented models suitable for local deployment.
- Day-one MLX support.
- Native `system` prompt support.
- Structured output and function-calling support.
- Image and audio input on edge-sized models.
- Longer context windows than the current local setup is effectively using.

The strongest near-term benefits for Illuminote are likely better structured output, better instruction following, and a cleaner path toward future multimodal reflection tools.

## Non-Goals

This adoption plan does not recommend:

- Replacing Qwen everywhere immediately.
- Shipping Gemma 4 as the default model in the next release.
- Turning the app into a generic AI assistant.
- Trusting any model for admissions facts, policy, or spiritual direction without app-level safeguards.
- Building multimodal features before text quality and memory behavior are verified.

## Adoption Principles

- Protect privacy first: no regression from current on-device posture.
- Preserve the product's voice: reflective, serious, grounded, non-performative.
- Prefer narrow capability wins over broad AI expansion.
- Keep the primary UX stable for current users while Gemma 4 is experimental.
- Make every phase reversible.

## Phase 0: Validation Spike

### Goal

Confirm that Gemma 4 E2B can actually run inside the current MLX Swift stack and bundle/on-demand delivery model with acceptable quality and memory behavior.

### Scope

Do this as a technical spike only. No user-facing UI yet.

### Work

- Verify the exact `mlx-swift` and `mlx-swift-lm` revisions in [Package.resolved](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved#L22) can load an MLX-converted Gemma 4 E2B checkpoint.
- If not, upgrade MLX dependencies in a contained branch and retest load/generation behavior.
- Obtain an MLX-compatible Gemma 4 E2B quantized model directory with `model.safetensors`, `tokenizer.json`, and `config.json`.
- Test model loading through the existing `MLXLMCommon.loadModel(directory:)` path in [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L176).
- Test plain text generation through the current chat flow in [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L321).
- Measure memory checkpoints and generation speed already exposed by `MLXManager`.

### Success Criteria

- Model loads on a target physical iPhone without runtime architecture errors.
- Advisor-style prompts complete without malformed output in at least 80 percent of test runs.
- Peak memory stays within an acceptable range for supported devices.
- Time-to-first-token and total completion time are acceptable for reflective workflows.
- Output quality is at least competitive with Qwen3.5-2B on a fixed internal prompt set.

### Exit Criteria

Proceed only if Gemma 4 E2B is viable without major MLX framework churn or unacceptable memory pressure.

## Phase 1: Experimental Text-Only Integration

### Goal

Introduce Gemma 4 E2B as an optional experimental model for the two safest current use cases:

- Advisor critique generation
- Insights reranking

### Code Areas

- [Services/DeviceCapabilities.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/DeviceCapabilities.swift#L3)
- [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L107)
- [Services/OnDemandModelManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/OnDemandModelManager.swift#L1)
- [Settings/SettingsView.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Settings/SettingsView.swift)
- [PSBuilder/Advisor/AIAdvisorPanel.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/PSBuilder/Advisor/AIAdvisorPanel.swift#L380)

### Work

- Add a new model profile kind such as `gemma4_e2b`.
- Add delivery metadata, bundle directory names, approximate size, minimum memory threshold, and fallback order.
- Add Gemma-specific prompt budgets rather than copying Qwen budgets blindly.
- Generalize any Qwen-specific error language in `MLXManager`, especially the architecture failure message in [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L473).
- Add a gated settings toggle so Gemma 4 remains explicitly experimental.
- Ensure on-demand download and release behavior works the same way it does for the current experimental 4B model.
- Record the loaded model descriptor so internal testing can confirm which model actually ran.

### Product Behavior

- Gemma 4 should be opt-in.
- Qwen remains the default and fallback.
- If Gemma fails to load, the app falls back silently and safely to the current supported profile.

## Phase 2: Prompt and Output Tuning

### Goal

Tune Gemma 4 for Illuminote's actual product voice rather than assuming the existing Qwen prompts will transfer cleanly.

### Work

- Create a Gemma-specific internal evaluation set for:
  - admissions critique quality
  - reflection sensitivity
  - structured JSON obedience
  - avoidance of generic AI phrasing
- Compare Advisor outputs against the current Qwen baseline on:
  - specificity
  - grounding in draft evidence
  - emotional maturity
  - tendency to overpraise
  - tendency to generate copy-ready rewrites despite constraints
- Adjust sampling separately for Advisor and Insights rather than relying on inherited Qwen defaults.
- Decide whether to keep thinking disabled initially even if Gemma exposes it.

### Why This Matters

The current Advisor prompts are quite strict and critique-shaped in [PSBuilder/Advisor/AIAdvisorPromptBuilder.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/PSBuilder/Advisor/AIAdvisorPromptBuilder.swift#L106). That is helpful, but model families differ in how much they respect negative constraints, quote limits, section formatting, and non-rewrite instructions.

Gemma needs its own tuning pass before the app can trust it in a user-facing flow.

## Phase 3: Safe Expansion Opportunities

Only begin this phase if Phases 0 through 2 succeed.

### Opportunity A: Better Insights Refinement

Gemma 4's structured-output posture may improve the strict JSON rerank flow in [Insights/InsightsAnalysisService.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Insights/InsightsAnalysisService.swift#L327).

This is a strong candidate because:

- the task is bounded
- the output shape is narrow
- the app can fall back to deterministic suggestions
- quality failures are lower risk than in drafting flows

### Opportunity B: Dynamic Reflection Prompts

If Gemma 4 proves more stable than the current stubbed path in [Services/AIPromptService.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/AIPromptService.swift#L77), it could eventually power contextual follow-up prompts during reflection.

This should be handled carefully because:

- reflective prompts shape the emotional tone of the app
- low-quality prompting could make the app feel generic or spiritually shallow
- the current product philosophy prefers guided restraint over endless AI generation

### Opportunity C: Audio Reflection Assistance

Gemma 4 edge models support audio input, but this should be treated as research, not an immediate product feature.

Recommended uses:

- short spoken reflection clips
- post-transcription summarization
- optional extraction of themes from a brief recorded note

Not recommended at first:

- replacing Apple's speech transcription stack
- long-session audio journaling
- always-on audio processing

### Opportunity D: Image or Document Intake

Potential future use:

- parsing handwritten notes
- extracting content from screenshots or exported forms
- helping users turn offline reflection artifacts into journal material

This is promising, but it requires a broader input abstraction because `MLXManager` is currently text-only in [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L321).

## Phase 4: Decision Gate

After the experimental rollout, make an explicit product decision:

### Promote Gemma 4 if

- it clearly improves Advisor quality
- it obeys structured constraints more reliably
- it stays within acceptable memory and latency bounds
- it does not increase generic, overconfident, or spiritually flat responses

### Keep Gemma 4 Experimental if

- quality is mixed
- runtime support remains brittle
- device compatibility is too narrow
- the gains are meaningful only in niche flows

### Stop the Adoption if

- MLX support proves unstable on your target devices
- text quality does not beat the current default enough to justify complexity
- operational overhead around model packaging and testing becomes too high

## Technical Tasks by File

### Likely first implementation slice

- [Services/DeviceCapabilities.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/DeviceCapabilities.swift#L3)
  - Add Gemma profile kinds, memory thresholds, prompt budgets, generation defaults, and fallback order.
- [Services/MLXManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/MLXManager.swift#L107)
  - Make error messages model-family agnostic.
  - Confirm generation works with Gemma chat templates and any required additional context.
- [Services/OnDemandModelManager.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Services/OnDemandModelManager.swift#L1)
  - Add the new tagged on-demand pack if Gemma is not bundled.
- [Settings/SettingsView.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Settings/SettingsView.swift)
  - Surface experimental Gemma selection cleanly and without confusing non-technical users.
- [PSBuilder/Advisor/AIAdvisorPromptBuilder.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/PSBuilder/Advisor/AIAdvisorPromptBuilder.swift#L92)
  - Tune budgets and possibly few-shot examples specifically for Gemma.
- [Insights/InsightsAnalysisService.swift](/Users/tobias/Desktop/Desktop - Tobias’s MacBook Pro/IlluminoteSceneDemo/IlluminoteSceneDemo/Insights/InsightsAnalysisService.swift#L284)
  - Validate structured JSON reliability before enabling Gemma for reranking by default.

## Evaluation Set

Build an internal test set with at least these categories:

- Strong draft with grounded reflection
- Weak draft with generic service language
- Overwritten draft with inflated tone
- Underdeveloped draft with thin evidence
- Faith-forward reflection that needs respectful handling
- Emotionally vulnerable reflection that should not receive glib or performative AI output
- Insights candidate sets where strict JSON output is required

For each case, score:

- instruction adherence
- format obedience
- evidence-grounded critique
- usefulness of revisions
- tonal fit with Illuminote
- latency
- memory footprint

## Risks

### Product Risks

- Generic AI voice that breaks the app's contemplative tone.
- Overconfident critique that feels harsh or false.
- Spiritually flattened or emotionally mismatched reflection support.

### Technical Risks

- Current MLX dependency revisions may not cleanly support Gemma 4.
- Quantized checkpoints may behave differently than Google's reference expectations.
- Multimodal support may require input plumbing that does not exist today.

### Operational Risks

- Larger model packs may complicate TestFlight size and download flows.
- Device eligibility may become harder to explain if Gemma needs a different threshold.
- Supporting multiple model families increases QA burden.

## Safeguards

- Keep Gemma behind an experimental toggle at first.
- Maintain Qwen as the stable default until Gemma earns promotion.
- Add internal QA prompts focused on tone, humility, and emotional appropriateness.
- Avoid enabling thinking mode until chunk parsing and output sanitation are ready.
- Prefer bounded structured tasks before open-ended generation tasks.

## Suggested Rollout Order

1. Gemma 4 E2B validation spike.
2. Experimental Advisor support on physical devices only.
3. Experimental Insights reranking.
4. Prompt tuning and evaluation pass.
5. Decision gate.
6. Optional multimodal R&D.

## Immediate Next Step

The best next move is a short technical spike:

1. Confirm whether the current MLX package revisions can load a Gemma 4 E2B MLX checkpoint.
2. If they can, wire Gemma in as an experimental text-only profile.
3. Run a fixed evaluation set against Advisor and Insights before making any UI or product-level promises.

## External References

- [Google Gemma 4 launch post](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/)
- [Google AI Edge Gemma 4 post](https://developers.googleblog.com/bring-state-of-the-art-agentic-skills-to-the-edge-with-gemma-4/)
- [Gemma 4 E2B model card](https://huggingface.co/google/gemma-4-E2B-it)
- [Gemma 4 E4B model card](https://huggingface.co/google/gemma-4-E4B-it)
