#!/usr/bin/env python3
import json
import uuid
import sys
import os

# Config
PROMPTS_CANDIDATES = [
    "Examen/prompts.json",
    "IlluminoteSceneDemo/Examen/prompts.json",
    "prompts.json",
    "IlluminoteSceneDemo/prompts.json",
]
MIN_PER_PHASE = 4

# Template text for missing prompts
TEMPLATES = {
    "opening": "Reflect on your first impressions of the experience today.",
    "presence": "Describe a moment where you found yourself fully present.",
    "disquiet": "What challenged you most emotionally or intellectually?",
    "assumptions": "Which assumption of yours was tested today?",
    "empathy": "Describe a moment where you felt empathy for another person.",
    "discernment": "What question about your purpose or vocation arose during the experience?",
    "affirmation": "Which moment today affirmed your values or goals?",
    "commitment": "What intention do you want to carry forward from this experience?"
}

def new_prompt_id():
    return str(uuid.uuid4())

def generate_prompt(stage, phase):
    return {
        "id": new_prompt_id(),
        "phase": phase,
        "text": TEMPLATES.get(stage, f"Reflect further on {stage}."),
        "stepIndex": phase,
        "stage": stage,
        "depth": "standard",
        "experienceTypes": ["shadowing"],
        "professionTags": ["preMedicine"],
        "tags": [stage],
        "intent": None
    }

def resolve_prompts_file():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    search_roots = [os.getcwd(), script_dir]
    checked = []

    for root in search_roots:
        for rel_path in PROMPTS_CANDIDATES:
            candidate = os.path.normpath(os.path.join(root, rel_path))
            checked.append(candidate)
            if os.path.exists(candidate):
                return candidate, checked

    return None, checked

def main():
    prompts_file, checked = resolve_prompts_file()
    if prompts_file is None:
        print("❌ Failed to find prompts.json in any expected location.")
        for path in checked:
            print(f"   - {path}")
        return

    try:
        with open(prompts_file, "r") as f:
            data = json.load(f)
            prompts = data.get("prompts", [])
    except Exception as e:
        print(f"❌ Failed to load {prompts_file}: {e}")
        return

    by_phase = {}
    for p in prompts:
        ph = p.get("phase", 0)
        by_phase.setdefault(ph, []).append(p)

    additions = []
    # Check phases 0-4 (standard Examen phases)
    for phase in range(5):
        items = by_phase.get(phase, [])
        if len(items) < MIN_PER_PHASE:
            # Determine stage name based on phase if no items exist
            stage_name = "reflection" # default
            if items:
                 stage_name = items[0].get("stage", "reflection")
            else:
                # Fallback mapping if phase is completely empty
                if phase == 0: stage_name = "opening"
                elif phase == 1: stage_name = "presence"
                elif phase == 2: stage_name = "disquiet"
                elif phase == 3: stage_name = "reflection"
                elif phase == 4: stage_name = "commitment"
            
            needed = MIN_PER_PHASE - len(items)
            print(f"⚠️ Phase {phase} ({stage_name}) has {len(items)} prompts. Generating {needed} more.")
            
            for i in range(needed):
                new_p = generate_prompt(stage_name, phase)
                additions.append(new_p)

    if additions:
        print(f"➕ Adding {len(additions)} generated prompts to {prompts_file}")
        data["prompts"].extend(additions)
        with open(prompts_file, "w") as f:
            json.dump(data, f, indent=2)
    else:
        print("✔ All phases already have enough prompts")

if __name__ == "__main__":
    main()
