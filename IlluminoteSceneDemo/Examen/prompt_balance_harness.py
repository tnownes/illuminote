#!/usr/bin/env python3
"""
Prompt balance harness for Illuminote.

Purpose:
- Reproduce current PromptSelector behavior.
- Run Monte Carlo simulations across scenarios.
- Quantify prompt concentration by phase (top share, entropy, coverage).

Usage:
  python3 Examen/prompt_balance_harness.py
  python3 Examen/prompt_balance_harness.py --iterations 10000 --top-n 8
  python3 Examen/prompt_balance_harness.py --json-output /tmp/prompt-balance.json
"""

from __future__ import annotations

import argparse
import json
import math
import random
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Set, Tuple


# Mirrors Examen/PromptSelector.swift constants.
PHASES = [0, 1, 2, 3, 4]
CROSSOVER_TAGS: Set[str] = {
    "vocation",
    "clinical",
    "service",
    "shadowing",
    "leadership",
    "research",
    "work",
    "dailylife",
    "compassion",
    "discernment",
}
DAILY_CONTEXT_TAGS: Set[str] = {"other", "daily", "dailylife"}
DAILY_PROMPT_TAGS: Set[str] = {
    "dailylife",
    "daily",
    "prayer",
    "gratitude",
    "presence",
    "reflection",
    "compassion",
    "closing",
}
MODE_TAGS: Dict[str, Set[str]] = {
    "quick": set(),
    "deep": set(),
    "vocation": {
        "vocation",
        "pre-professional",
        "clinical",
        "ethics",
        "growth",
        "experience-specific",
    },
    "spiritual": {"spiritual", "presence", "compassion", "reflection", "hope"},
}


@dataclass(frozen=True)
class Scenario:
    name: str
    mode: str
    experience_context_tags: Tuple[str, ...]
    profession_tags: Tuple[str, ...]


@dataclass(frozen=True)
class Prompt:
    id: str
    text: str
    phase: int
    stage: str
    depth: str
    step_index: int
    experience_types: Tuple[str, ...]
    profession_tags: Tuple[str, ...]
    tags: Tuple[str, ...]

    @staticmethod
    def from_json(obj: dict) -> "Prompt":
        return Prompt(
            id=str(obj.get("id", "")),
            text=str(obj.get("text", "")),
            phase=int(obj.get("phase", 0)),
            stage=str(obj.get("stage", "")),
            depth=str(obj.get("depth", "")),
            step_index=int(obj.get("stepIndex", 0)),
            experience_types=tuple(obj.get("experienceTypes") or []),
            profession_tags=tuple(obj.get("professionTags") or []),
            tags=tuple(obj.get("tags") or []),
        )

    @property
    def tags_lower(self) -> Set[str]:
        return {t.lower() for t in self.tags}

    @property
    def experience_lower(self) -> Set[str]:
        return {t.lower() for t in self.experience_types}

    @property
    def profession_lower(self) -> Set[str]:
        return {t.lower() for t in self.profession_tags}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze prompt selection balance.")
    parser.add_argument(
        "--prompts-file",
        default="Examen/prompts.json",
        help="Path to prompts.json (default: Examen/prompts.json)",
    )
    parser.add_argument(
        "--iterations",
        type=int,
        default=5000,
        help="Simulation runs per scenario (default: 5000)",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=6,
        help="Top prompts to print per phase (default: 6)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducible runs (default: 42)",
    )
    parser.add_argument(
        "--json-output",
        default="",
        help="Optional path to emit full JSON report",
    )
    parser.add_argument(
        "--simulate-recent-window",
        type=int,
        default=0,
        help=(
            "Optional recency rotation simulation window size. "
            "0 means current app behavior (no update to recentPromptIDs)."
        ),
    )
    return parser.parse_args()


def load_prompts(path: Path) -> List[Prompt]:
    raw = json.loads(path.read_text())
    prompts = [Prompt.from_json(obj) for obj in raw.get("prompts", [])]
    return prompts


def is_daily_context(exp_lower: Set[str]) -> bool:
    return not DAILY_CONTEXT_TAGS.isdisjoint(exp_lower)


def phase_cap(mode: str, phase: int) -> int:
    if mode == "quick":
        return 1
    return 3 if phase == 0 else 4


def passes_base_guards(prompt: Prompt, include_deep: bool, allow_spiritual_prompts: bool) -> bool:
    depth_lower = prompt.depth.lower()
    if depth_lower == "deep" and not include_deep:
        return False

    prompt_tags_lower = prompt.tags_lower
    if not allow_spiritual_prompts and "spiritual" in prompt_tags_lower:
        if prompt_tags_lower.isdisjoint(CROSSOVER_TAGS):
            return False
    return True


def passes_context_filters(
    prompt: Prompt,
    exp_lower: Set[str],
    prof_lower: Set[str],
    enforce_profession: bool,
    enforce_experience: bool,
) -> bool:
    if enforce_profession and prof_lower and prompt.profession_tags:
        if prompt.profession_lower.isdisjoint(prof_lower):
            return False

    if enforce_experience and exp_lower:
        if is_daily_context(exp_lower):
            prompt_exp_lower = prompt.experience_lower
            prompt_tag_lower = prompt.tags_lower

            if not prompt_exp_lower.isdisjoint(exp_lower):
                return True
            if len(prompt_exp_lower) >= 5:
                return True
            if not prompt_tag_lower.isdisjoint(DAILY_PROMPT_TAGS):
                return True

        if prompt.experience_types:
            if prompt.experience_lower.isdisjoint(exp_lower):
                return False
        elif prompt.tags:
            if prompt.tags_lower.isdisjoint(exp_lower):
                return False

    return True


def score_prompt(
    prompt: Prompt,
    mode: str,
    include_deep: bool,
    mode_tags_lower: Set[str],
    exp_lower: Set[str],
    recent_prompt_ids: Set[str],
) -> int:
    prompt_tags_lower = prompt.tags_lower
    prompt_exp_lower = prompt.experience_lower

    score = len(prompt_tags_lower.intersection(mode_tags_lower)) * 10

    if include_deep and prompt.depth.lower() == "deep":
        score += 5
    if prompt.depth.lower() == "standard" and prompt.phase == 0:
        score += 5
    if mode in ("vocation", "deep") and prompt.stage.lower() == "first-principle" and prompt.phase == 0:
        score += 15
    if prompt.phase == 3:
        if len(prompt_exp_lower) <= 2 and prompt_exp_lower and not exp_lower.isdisjoint(prompt_exp_lower):
            score += 20

    if is_daily_context(exp_lower):
        if not prompt_tags_lower.isdisjoint(DAILY_PROMPT_TAGS):
            score += 18
        if "spiritual" in prompt_tags_lower:
            score += 12
        if not prompt_exp_lower.isdisjoint(DAILY_CONTEXT_TAGS):
            score += 24
        elif len(prompt_exp_lower) >= 5:
            score += 6
        if len(prompt_exp_lower) <= 2 and prompt_exp_lower.isdisjoint(DAILY_CONTEXT_TAGS):
            score -= 20

    if prompt.id in recent_prompt_ids:
        score -= 100

    return score


def select_prompts(
    all_prompts: Sequence[Prompt],
    mode: str,
    experience_context_tags: Sequence[str],
    profession_tags: Sequence[str],
    recent_prompt_ids: Set[str],
) -> List[Prompt]:
    include_deep = mode != "quick"
    mode_tags_lower = MODE_TAGS.get(mode, set())
    exp_lower = {t.lower() for t in experience_context_tags}
    prof_lower = {t.lower() for t in profession_tags}
    allow_spiritual_prompts = (mode == "spiritual") or is_daily_context(exp_lower)

    result: List[Prompt] = []

    for phase in PHASES:
        cap = phase_cap(mode, phase)
        if cap <= 0:
            continue

        phase_pool = [
            p
            for p in all_prompts
            if p.phase == phase and passes_base_guards(p, include_deep, allow_spiritual_prompts)
        ]

        strict_candidates = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=True,
                enforce_experience=True,
            )
        ]
        relax_profession_candidates = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=False,
                enforce_experience=True,
            )
        ]
        general_phase_candidates = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=False,
                enforce_experience=False,
            )
        ]

        candidates: List[Prompt] = []
        seen_ids: Set[str] = set()

        def append_unique(prompts: Iterable[Prompt]) -> None:
            for prompt in prompts:
                if prompt.id in seen_ids:
                    continue
                seen_ids.add(prompt.id)
                candidates.append(prompt)

        append_unique(strict_candidates)
        if len(candidates) < cap:
            append_unique(relax_profession_candidates)
        if len(candidates) < cap:
            append_unique(general_phase_candidates)

        if not candidates:
            continue

        scored_prompts = [
            (
                prompt,
                score_prompt(
                    prompt=prompt,
                    mode=mode,
                    include_deep=include_deep,
                    mode_tags_lower=mode_tags_lower,
                    exp_lower=exp_lower,
                    recent_prompt_ids=recent_prompt_ids,
                ),
            )
            for prompt in candidates
        ]

        random.shuffle(scored_prompts)
        scored_prompts.sort(key=lambda t: t[1], reverse=True)
        selected = [prompt for prompt, _ in scored_prompts[:cap]]
        result.extend(selected)

    return result


def normalized_entropy(counts: Sequence[int]) -> float:
    total = sum(counts)
    if total <= 0 or len(counts) <= 1:
        return 0.0
    h = 0.0
    for c in counts:
        if c <= 0:
            continue
        p = c / total
        h -= p * math.log2(p)
    return h / math.log2(len(counts))


def default_scenarios() -> List[Scenario]:
    return [
        Scenario("Deep + Shadowing + PreMedicine", "deep", ("shadowing",), ("premedicine",)),
        Scenario("Deep + Daily + PreMedicine", "deep", ("other", "daily", "dailylife"), ("premedicine",)),
        Scenario("Vocational + Shadowing + PreMedicine", "vocation", ("shadowing",), ("premedicine",)),
        Scenario("Spiritual + Daily + PreMedicine", "spiritual", ("other", "daily", "dailylife"), ("premedicine",)),
    ]


def analyze_scenario(
    prompts: Sequence[Prompt],
    scenario: Scenario,
    iterations: int,
    top_n: int,
    recent_window: int,
) -> dict:
    # Baseline candidate pool by phase for coverage context.
    baseline_recent: Set[str] = set()
    baseline_selected = select_prompts(
        all_prompts=prompts,
        mode=scenario.mode,
        experience_context_tags=scenario.experience_context_tags,
        profession_tags=scenario.profession_tags,
        recent_prompt_ids=baseline_recent,
    )
    baseline_by_phase: Dict[int, Set[str]] = defaultdict(set)
    for p in baseline_selected:
        baseline_by_phase[p.phase].add(p.id)

    # We also inspect phase pools independent of top-N selection.
    include_deep = scenario.mode != "quick"
    exp_lower = {t.lower() for t in scenario.experience_context_tags}
    prof_lower = {t.lower() for t in scenario.profession_tags}
    allow_spiritual_prompts = (scenario.mode == "spiritual") or is_daily_context(exp_lower)

    candidate_counts: Dict[int, int] = {}
    for phase in PHASES:
        phase_pool = [
            p
            for p in prompts
            if p.phase == phase and passes_base_guards(p, include_deep, allow_spiritual_prompts)
        ]
        strict = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=True,
                enforce_experience=True,
            )
        ]
        relax = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=False,
                enforce_experience=True,
            )
        ]
        general = [
            p
            for p in phase_pool
            if passes_context_filters(
                p,
                exp_lower=exp_lower,
                prof_lower=prof_lower,
                enforce_profession=False,
                enforce_experience=False,
            )
        ]
        dedup = []
        seen: Set[str] = set()
        for arr in (strict, relax, general):
            for p in arr:
                if p.id in seen:
                    continue
                seen.add(p.id)
                dedup.append(p)
        candidate_counts[phase] = len(dedup)

    per_phase_counts: Dict[int, Counter] = defaultdict(Counter)
    rolling_recent: List[str] = []

    for _ in range(iterations):
        recent_ids = set(rolling_recent) if recent_window > 0 else set()
        selected = select_prompts(
            all_prompts=prompts,
            mode=scenario.mode,
            experience_context_tags=scenario.experience_context_tags,
            profession_tags=scenario.profession_tags,
            recent_prompt_ids=recent_ids,
        )

        for p in selected:
            per_phase_counts[p.phase][p.id] += 1

        if recent_window > 0:
            # Track in selection order for recency penalty simulation.
            rolling_recent.extend([p.id for p in selected])
            if len(rolling_recent) > recent_window:
                rolling_recent = rolling_recent[-recent_window:]

    prompt_by_id = {p.id: p for p in prompts}
    phase_reports = []

    for phase in PHASES:
        cap = phase_cap(scenario.mode, phase)
        counts = per_phase_counts.get(phase, Counter())
        total_selected = sum(counts.values())
        unique_selected = len(counts)
        top = counts.most_common(top_n)
        top_share = (top[0][1] / iterations) if top else 0.0

        entropy = normalized_entropy(list(counts.values()))
        candidate_count = candidate_counts.get(phase, 0)
        even_share = (cap / candidate_count) if candidate_count > 0 else 0.0
        concentration_ratio = (top_share / even_share) if even_share > 0 else 0.0

        notes: List[str] = []
        if candidate_count <= cap:
            notes.append("Deterministic by design: candidate pool <= phase cap.")
        if top_share >= 0.95 and candidate_count > cap:
            notes.append("Very high concentration (>95%) despite candidate headroom.")
        if entropy < 0.35 and candidate_count > cap:
            notes.append("Low entropy (narrow rotation).")
        if unique_selected <= cap and candidate_count > cap:
            notes.append("Effective rotation is near-fixed for this phase.")

        phase_reports.append(
            {
                "phase": phase,
                "cap": cap,
                "candidate_count": candidate_count,
                "unique_selected_over_runs": unique_selected,
                "top_prompt_share": round(top_share, 4),
                "normalized_entropy": round(entropy, 4),
                "concentration_ratio_vs_even": round(concentration_ratio, 3),
                "notes": notes,
                "top_prompts": [
                    {
                        "id": pid,
                        "share": round(count / iterations, 4),
                        "count": count,
                        "stage": prompt_by_id[pid].stage if pid in prompt_by_id else "",
                        "text": (prompt_by_id[pid].text if pid in prompt_by_id else "")[:140],
                    }
                    for pid, count in top
                ],
            }
        )

    return {
        "scenario": scenario.name,
        "mode": scenario.mode,
        "experience_context_tags": list(scenario.experience_context_tags),
        "profession_tags": list(scenario.profession_tags),
        "iterations": iterations,
        "recent_window": recent_window,
        "phase_reports": phase_reports,
    }


def print_report(report: dict) -> None:
    print(f"\n=== {report['scenario']} ===")
    print(
        "mode={mode} experience={exp} profession={prof} iterations={n} recent_window={rw}".format(
            mode=report["mode"],
            exp=report["experience_context_tags"],
            prof=report["profession_tags"],
            n=report["iterations"],
            rw=report["recent_window"],
        )
    )

    for p in report["phase_reports"]:
        print(
            "phase {phase}: cap={cap}, candidates={cand}, unique={uniq}, top_share={top:.1%}, entropy={ent:.2f}, concentration={cr:.2f}".format(
                phase=p["phase"],
                cap=p["cap"],
                cand=p["candidate_count"],
                uniq=p["unique_selected_over_runs"],
                top=p["top_prompt_share"],
                ent=p["normalized_entropy"],
                cr=p["concentration_ratio_vs_even"],
            )
        )
        for note in p["notes"]:
            print(f"  - {note}")
        for top in p["top_prompts"][:3]:
            print(
                "  - {share:.1%} [{stage}] {id} :: {text}".format(
                    share=top["share"],
                    stage=top["stage"],
                    id=top["id"][:8],
                    text=top["text"],
                )
            )


def main() -> None:
    args = parse_args()
    random.seed(args.seed)

    prompt_file = Path(args.prompts_file)
    if not prompt_file.exists():
        raise SystemExit(f"Prompts file not found: {prompt_file}")

    prompts = load_prompts(prompt_file)
    if not prompts:
        raise SystemExit("No prompts loaded.")

    scenarios = default_scenarios()
    reports = [
        analyze_scenario(
            prompts=prompts,
            scenario=scenario,
            iterations=args.iterations,
            top_n=args.top_n,
            recent_window=max(args.simulate_recent_window, 0),
        )
        for scenario in scenarios
    ]

    print("Prompt Balance Harness")
    print(f"prompts_file={prompt_file} total_prompts={len(prompts)}")
    for report in reports:
        print_report(report)

    if args.json_output:
        output = {
            "prompts_file": str(prompt_file),
            "total_prompts": len(prompts),
            "iterations": args.iterations,
            "seed": args.seed,
            "recent_window": max(args.simulate_recent_window, 0),
            "scenarios": reports,
        }
        out_path = Path(args.json_output)
        out_path.write_text(json.dumps(output, indent=2))
        print(f"\nWrote JSON report: {out_path}")


if __name__ == "__main__":
    main()
