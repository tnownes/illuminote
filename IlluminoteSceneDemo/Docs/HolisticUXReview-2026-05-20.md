# Illuminote Holistic UX Review

Date: May 20, 2026  
Scope: current SwiftUI codebase, the attached Antigravity report at `/Users/tobias/Desktop/holistic_ux_review_report.md`, Apple HIG research, UX complexity research, and comparison with adjacent best-in-class apps.

## Executive Verdict

Illuminote has not failed because it has the wrong features. It is becoming hard to use because the same small-screen app asks the user to move between three different roles too quickly:

1. A contemplative reflector using the Examen.
2. An evidence archivist preparing application-ready records.
3. A writing strategist drafting under admissions requirements.

That is a real product tension, but it is fixable. The strongest path is not to remove Application Records, Insights, or Writing. The strongest path is to make the product feel like one progressive spine:

**Reflect -> Journal -> Notice Patterns -> Write**

Application Records should remain available, but they should behave like a later preparation layer, not a cognitive demand at the moment of reflection.

## Method

I reviewed the app primarily through code because I did not run a simulator session in this pass. The key files inspected were:

- `ContentView.swift`
- `LandingView.swift`
- `Onboarding/OnboardingSteps.swift`
- `Examen/ExamenFlowView.swift`
- `Examen/ExamenDetailsView.swift`
- `Examen/ExperienceTypeSelectionView.swift`
- `Journal/JournalView.swift`
- `Insights/InsightsView.swift`
- `Insights/InsightsModels.swift`
- `ExperienceLog/ExperienceLogView.swift`
- `ExperienceLog/ApplicationExperienceDetailView.swift`
- `PSBuilder/StatementListView.swift`
- `PSBuilder/PSRichTextEditorView.swift`
- `PSBuilder/Advisor/AIAdvisorPanel.swift`
- `Resources/writing_targets.json`
- `Resources/experience_requirements.json`

I also checked prior project context in memory, because this app has already had a core-flow simplification pass and the current state should not be judged against stale assumptions.

## Assessment of the Attached Antigravity Report

The attached report is directionally useful, but it overstates several current-code facts.

What it gets right:

- It correctly identifies a core risk: Illuminote can feel split between sanctuary, ledger, and writing workshop.
- It correctly focuses attention on the post-Examen handoff.
- It correctly warns that mobile writing can become too much like a desktop writing environment.

What is stale or overstated:

- `ExperienceLogView` is not currently a main tab. The main tabs are Home, Journal, Insights, Writing, and Settings.
- The Application Record path is already opt-in in `ExamenDetailsView`, not fully forced.
- The mobile writing editor does not appear to be a permanent sidebar-heavy layout in the current code; it uses a formatting toolbar plus a SwiftUI inspector for Advisor. That is still dense, but the critique should be framed accurately.
- Some of the cited sources in the attached report are not precise or appear invented, especially the Apple HIG "mental health and journaling" citation.

My conclusion: use that report as a warning signal, not as an authoritative diagnosis.

## Research Synthesis

### Apple HIG Implications

Apple's current design guidance consistently points toward:

- Familiar iOS patterns and ergonomics for people using iPhone on the go.
- Simple, consistent interactions for cognitive accessibility.
- Minimum 44x44 pt touch targets.
- Sufficient contrast, Dynamic Type support, and alternatives to gesture-only behavior.
- Disclosure controls that hide details until they are relevant.
- One or two prominent actions per view, because too many prominent actions increase decision effort.
- Clear labels and concise writing on small screens.

Relevant Apple sources:

- [Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls)
- [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)
- [Writing](https://developer.apple.com/design/human-interface-guidelines/writing)

The practical implication for Illuminote: the app can remain deep, but each screen must make the next action obvious and defer secondary detail until it is truly needed.

### Complexity and Cognitive Load

NN/g's progressive disclosure guidance is directly relevant: show the most important options first, then reveal specialized options only when users ask for them. NN/g also emphasizes recognition over recall and aesthetic minimalism: every extra unit of interface competes with the relevant units of information.

Cognitive load theory and working-memory research reinforce this. Sweller's cognitive-load work distinguishes the load of the task itself from avoidable interface load. Cowan's working-memory research suggests that short-term capacity is closer to three to five chunks than the older "seven plus or minus two" rule.

Relevant sources:

- [NN/g: Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
- [NN/g: 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [Cowan 2001, working memory capacity](https://pubmed.ncbi.nlm.nih.gov/11515286/)
- [Sweller 1988, cognitive load during problem solving](https://doi.org/10.1207/s15516709cog1202_4)
- [Baymard on mobile form constraints](https://baymard.com/blog/mobile-ecommerce-checkout-forms)

The practical implication for Illuminote: reflection itself is already cognitively and emotionally demanding. The interface should not add avoidable form complexity at the same moment.

### Mental Health and Reflection Apps

Digital mental health engagement research shows that engagement is fragile, and that users with higher distress or cognitive burden may need simpler tasks and lower interaction demands. A Nature Digital Medicine review also reports low real-world retention in mental health apps, which makes the first-repeat habit loop especially important.

Relevant sources:

- [Borghouts et al. 2021, barriers and facilitators of digital mental health engagement](https://pubmed.ncbi.nlm.nih.gov/33759801/)
- [Baumel et al. 2019/2021, engagement in depression and anxiety apps](https://www.nature.com/articles/s41746-021-00386-8)

The practical implication for Illuminote: preserve emotional trust by making reflection completion feel like completion, not the start of an administrative chore.

### Best-of-Breed Comparisons

| App | Relevant lesson for Illuminote |
| --- | --- |
| Apple Journal | Simple text capture comes first; richer media and suggestions support the entry without making setup heavy. Apple's Journal also emphasizes on-device suggestions and privacy. Source: [Apple Journal newsroom](https://www.apple.com/newsroom/2023/12/apple-launches-journal-app-a-new-app-for-reflecting-on-everyday-moments/) |
| Day One | Power sits underneath capture: automatic metadata, reminders, templates, search, tags, export, and rich media. The lesson is "type less, preserve more." Source: [Day One App Store](https://apps.apple.com/us/app/day-one-daily-journal-diary/id1044867788) |
| Headspace | Apple highlights Headspace's move from many category tabs toward a Today surface with one-tap access, while depth remains under Explore. This is the closest benchmark for Illuminote's "simple surface, deep archive" problem. Source: [Apple Behind the Design: Headspace](https://developer.apple.com/news/?id=fkfnhq8u) |
| Stoic | Offers many mental-health and reflection tools, but positions them around daily rhythms and guided prompts. Voice/photo alternatives reduce typing burden. Source: [Stoic App Store](https://apps.apple.com/gb/app/journal-habit-tracker-stoic/id1312926037) |
| Ulysses and Bear | Focused writing apps keep the writing surface primary and move organization, export, and advanced tools around it. Source: [Ulysses](https://www.ulysses.app/), [Bear App Store](https://apps.apple.com/us/app/bear-markdown-notes/id1016366447) |

The best competitor pattern is not "fewer features." It is **fewer simultaneous decisions**.

## Current UX Findings

### 1. The Main IA Is Mostly Right, But The Mental Model Is Still Heavy

`ContentView.swift` defines five top-level tabs:

- Home
- Journal
- Insights
- Writing
- Settings

Five tabs is within Apple-style tab-bar expectations, and the ordering is much better than an overloaded dashboard. The issue is conceptual, not numeric: the user must learn that "Journal," "Insights," "Writing," and "Application Records" are different layers of the same reflective material.

Recommendation: keep the five tabs, but make the app's language repeatedly reinforce the spine:

**Home starts reflection. Journal preserves it. Insights notices patterns. Writing shapes it. Application Records prepare facts when needed.**

### 2. Home Is Calmer Than Earlier Reviews Claimed, But It Still Hints At Too Many Jobs

`LandingView.swift` is already restrained: the main actions are "Start Examen" and "Capture a Quick Note." That is good. However, Home also includes summary panels for writing, focus, recent reflections, and hours/application-record tools.

This is not a disaster. It is a prioritization issue.

Recommendation: make Home's default visible hierarchy:

1. Start Examen
2. Capture Quick Note
3. Continue one recent thing
4. Quiet summary

Move application-record management one level deeper under Journal or Writing unless there is an urgent readiness alert.

### 3. The Examen Start Still Creates A Decision Wall

`ExperienceTypeSelectionView.swift` asks "What kind of experience are you reflecting on?" and renders all active `ExperienceType.allCases`, currently eight choices:

- Shadowing
- Clinical
- Leadership
- Research
- Work
- Service / Volunteer
- Discernment
- Daily

That is too much before the user has entered the contemplative act. It also frames the Examen first as categorization rather than reflection.

Recommendation: make "Start Examen" begin with a default general Examen, then offer a compact optional focus:

- Daily review
- Clinical or service
- Discernment
- Other

Only reveal the full eight-type list when the user chooses "More specific focus."

Impact: fewer first-step decisions, more spiritual/emotional continuity, and less premature application framing.

### 4. The Post-Examen Screen Is The Highest-Leverage Simplification

`ExamenDetailsView.swift` already protects the Application Record path behind a toggle, which is good. But the screen still opens as a details form with:

- Reflection Notes
- Optional Details
- Hours
- experience-specific fields
- Private Notes
- Tags
- Application Record toggle
- optional category/date/hour/contact fields after opting in

The problem is not that those fields exist. The problem is timing.

After a guided Examen, the user should land in a "save and breathe" moment. The current screen still asks them to parse metadata and future application implications.

Recommendation: replace the default post-Examen screen with a soft-landing save screen:

- Title: "Save this reflection"
- One editable reflection body
- Optional one-line title
- Primary action: "Save to Journal"
- Secondary action: "Add details"

After save, show completion actions:

- View in Journal
- Open in Insights
- Add application details
- Return Home

Application Record creation can still exist, but it should be reached after the reflection is safely saved.

Impact: this would remove the most emotionally jarring context switch without deleting the application-support feature.

### 5. Application Records Are Valuable, But They Should Feel Like Preparation, Not Reflection

`ExperienceLogView.swift` and `ApplicationExperienceDetailView.swift` are appropriately structured for facts: categories, dates, hours, contacts, permission, descriptions, service readiness, linked notes, export. This is useful for application work.

The risk is brand contamination: if Application Records appear too soon or too often, Illuminote can start to feel like an admissions spreadsheet wearing contemplative clothing.

Recommendation: preserve Application Records, but position them as "Prepare application details" and "Application Records" in writing/evidence contexts only. Do not place record creation in the emotional center of reflection.

Impact: keeps the professional utility while protecting the Sacred Void from administrative pressure.

### 6. Journal Has Good Tools, But Too Many Entry Points To The Same Actions

`JournalView.swift` supports search, filters, favorites, multi-select, quick note, bulk tagging, export, add to Writing, open in Insights, edit details, edit text, context menus, leading swipe actions, and trailing swipe actions.

That is powerful, but a first-time or stressed user may not know whether Journal is for reading, organizing, exporting, tagging, drafting, or analyzing.

Recommendation:

- Default Journal mode should be read/revisit.
- Keep search visible or easily available.
- Keep filters collapsed unless active.
- Move export/tag/bulk operations behind Select mode only.
- Reduce duplicate swipe/context actions.
- Consider moving "Capture Quick Note" primarily to Home, with Journal plus as a secondary convenience.

Impact: Journal becomes a quiet memory surface first and a power surface only when the user asks for power.

### 7. Insights Is Conceptually Rich Enough To Need A Guided Default

`InsightsView.swift` presents four lenses: Themes, Experiences, Values, Why. The studio then asks users to choose source notes, understand scope, review suggested patterns, save nodes, brainstorm, publish, and move material into Writing.

This is the most intellectually ambitious part of Illuminote. It is also the place most likely to feel abstract.

Recommendation:

- Make the landing page choose one recommended next action, not four equal choices.
- Rename or explain lens names in plain language:
  - Themes -> Patterns
  - Experiences -> Experience Evidence
  - Values -> Values
  - Why -> Calling or Motivation
- When possible, auto-scope to recent reflections and show "Change source notes" as secondary.
- Hide theme scope controls until the user is inside Themes/Patterns and has enough notes.

Impact: Insights becomes a guided interpretive bridge instead of a conceptual dashboard.

### 8. Writing Is The Most Feature-Dense Mobile Surface

`StatementListView.swift` is trying to support:

- core statements
- supplemental essays
- school-specific essays
- application entries
- draft assignment
- Journal import
- Insights import
- requirement catalogs
- knowledge-base tools
- wide iPad sidebar navigation

`PSRichTextEditorView.swift` then adds:

- essay target context
- character counts and limits
- review state
- rich text toolbar
- Save
- Share/export
- snapshot
- rename
- target assignment
- Advisor
- sync conflict handling

That is legitimate writing power, but it should not be the default mobile feeling.

Recommendation:

- On iPhone, make the editor's first visual priority the draft text.
- Collapse essay context into a compact header.
- Hide rich formatting until selection or "Format" is tapped.
- Move Advisor into a deliberate "Review Draft" action rather than a persistent writing companion.
- Keep requirements as a separate checklist panel, not always-present context.

Impact: Writing starts to feel like a place to write, not a place to manage writing infrastructure.

### 9. Onboarding Is Doing Too Much Teaching, But It Is Pointed In The Right Direction

`Onboarding/OnboardingSteps.swift` currently explains the app map and then collects profile defaults. The copy is calm and aligned with the app's identity, but the app map introduces five places before the user has felt the value of one.

Recommendation:

- Keep onboarding short.
- Teach the spine, not the map.
- Defer most profile/application settings until they become relevant.

Suggested onboarding spine:

1. Begin with an Examen.
2. Save what surfaces.
3. Return later to notice patterns or write.

Impact: less memorization, more immediate emotional value.

## Cognitive Load Checklist

| Area | Failed checklist items | Load level |
| --- | ---: | --- |
| Home | 2 | Moderate |
| Examen start | 3 | Moderate |
| Post-Examen details | 5 | High |
| Journal | 3 | Moderate |
| Insights Studio | 5 | High |
| Writing editor on iPhone | 5 | High |
| Application Record detail | 4 | High, but acceptable if framed as later admin work |

The main issue is not raw feature count. The issue is that the app sometimes exposes advanced work at the wrong emotional moment.

## Heuristic Score

| # | Heuristic | Score | Key issue |
| --- | --- | ---: | --- |
| 1 | Visibility of System Status | 3 | Save, sync, conflict, and selection feedback exist, but the post-reflection state could be clearer. |
| 2 | Match System / Real World | 3 | "Application Record" is better than raw model terms, but Insights terms remain abstract. |
| 3 | User Control and Freedom | 3 | Cancel/back/save paths exist; some flows still feel modal-heavy. |
| 4 | Consistency and Standards | 2 | Similar actions appear via toolbar, swipe, menu, bottom bar, and sheet depending on screen. |
| 5 | Error Prevention | 3 | Good constraints and readiness checks, especially in application records. |
| 6 | Recognition Rather Than Recall | 2 | Users must learn the distinction between Journal, Insights, Writing, and Application Records. |
| 7 | Flexibility and Efficiency | 2 | Power features exist, but they increase visible complexity for non-power users. |
| 8 | Aesthetic and Minimalist Design | 2 | Reflection screens are stronger than organizational screens; several surfaces show too much at once. |
| 9 | Error Recovery | 3 | Persistence and sync conflict recovery are stronger than average. |
| 10 | Help and Documentation | 2 | Onboarding and coach panels help, but contextual help is thin at the hardest decision points. |
| Total |  | 25/40 | Acceptable foundation; significant simplification needed before TestFlight confidence. |

## Anti-Pattern Verdict

Illuminote does not read as generic AI slop. Its vocabulary, Sacred Void atmosphere, and Ignatian-rooted intent are distinctive.

The risk is different: **mission drift through accumulated utility.** The app can begin to feel like an admissions workflow tool that contains a spiritual reflection feature, rather than a reflection app that can later support application writing.

## Persona Red Flags

### Thoughtful Busy Pre-Health Student

Likely behavior: opens the app after a draining clinical or service day, wants to capture meaning before it fades.

Red flags:

- Eight experience choices before reflection may feel like filing, not beginning.
- Post-Examen details can convert a reflective moment into task cleanup.
- Application service language may trigger performance anxiety too early.

### Spiritually Engaged Returning User

Likely behavior: returns because the Examen felt grounding.

Red flags:

- If Home increasingly emphasizes hours, records, and drafts, the user may feel the app is asking them to produce rather than notice.
- "Why Studio" and "Experience Evidence" concepts may need gentler language to remain discernment-oriented.

### Distracted iPhone User

Likely behavior: one-handed, interrupted, low patience for forms.

Red flags:

- Long forms after reflection.
- Horizontal toolbars and top toolbar actions in Writing.
- Journal has multiple hidden action surfaces, increasing recall burden.

### First-Time User

Likely behavior: wants to understand what Illuminote is for.

Red flags:

- Onboarding explains five app places before the first completed value loop.
- Insights is conceptually rich but may not reveal "what should I do now?" fast enough.

## Recommended Revisions

### P1: Make The Core Spine Explicit Everywhere

Adopt this user-facing mental model:

**Reflect. Save. Notice. Write. Prepare records only when needed.**

Where to apply:

- Home subtitles and coach panels.
- Onboarding.
- Insights empty states.
- Writing support cards.
- Application Record entry points.

Why: the app currently has strong parts, but the user needs one story that explains why those parts belong together.

### P1: Simplify Examen Entry

Current: choose one of eight experience types before beginning.

Recommended:

- Default "Start Examen" begins immediately or starts with a compact focus picker.
- Show four focus options at most.
- Move the full category list to "More specific focus."

Why: the first Examen action should feel like beginning reflection, not classifying an experience.

### P1: Replace The Post-Examen Details Form With A Save Landing

Current: a details form is shown after the reflective prompts.

Recommended:

- Primary surface: save reflection to Journal.
- Secondary: add optional details.
- Tertiary after save: connect/create Application Record.

Why: saving the reflection should be emotionally complete. Administrative enrichment can happen later.

### P1: Create A Gentle "Application Detail Suggestions" Layer

Current: Application Record creation can happen at Examen details time or through Experience Log suggestions.

Recommended:

- After save, quietly suggest "This may belong with Mercy Hospital ER Shadowing" or "Add 3 hours later."
- Put those suggestions in Journal or Home only after the reflection is safely saved.
- Let users dismiss suggestions permanently for a note.

Why: this keeps the useful professional bridge while respecting the contemplative moment.

### P2: Make Journal Read-First, Manage-Second

Recommended:

- Keep browse/search/read as default.
- Put batch actions behind Select.
- Reduce duplicated swipe/context-menu actions.
- Use "Open in Insights" and "Use in Writing" as contextual next steps after opening a note, not as equally visible actions everywhere.

Why: Journal should feel like a memory surface before it feels like a data-management tool.

### P2: Reframe Insights As A Guided Bridge

Recommended:

- One recommended starting card based on recent notes.
- Plain-language lens names.
- Auto-source recent notes when appropriate.
- Show advanced scope controls only after the user chooses a lens.

Why: Insights is valuable but abstract. It needs a guide rail, not just a menu of lenses.

### P2: Make Writing Mobile-First Again

Recommended:

- Text editor first.
- Essay context collapsed by default.
- Formatting toolbar hidden until requested or text is selected.
- Advisor as a deliberate review mode.
- Requirements checklist as a separate panel.

Why: the user came to write. The app should not make the writing infrastructure louder than the draft.

### P3: Preserve Sacred Void By Using It More Selectively

Recommended:

- Keep Sacred Void strongest in Examen, completion, reflective review, and AI-assisted writing moments.
- Use clearer system-like surfaces for Application Records, Settings, and dense Writing management.

Why: Sacred Void is the soul of the app, but if every admin surface is atmospheric, the atmosphere stops signaling sacred attention.

## What I Would Not Remove

- Do not remove Application Records. They are strategically valuable.
- Do not remove Insights. It is a differentiator, especially if made more guided.
- Do not remove the on-device Advisor. Make it optional and deliberately invoked.
- Do not flatten the app into generic minimalism. The contemplative identity is the reason the product is interesting.

## Suggested Implementation Sequence

### Phase 1: Save The Reflection Loop

Goal: make first use and repeat reflection feel calm.

Work:

- Simplify Examen entry.
- Rework `ExamenDetailsView` into a save-first landing.
- Move Application Record creation behind a post-save action.
- Adjust completion actions and copy.

Expected impact: biggest reduction in emotional whiplash and abandonment risk.

### Phase 2: Clarify The Middle

Goal: make Journal and Insights feel like a natural bridge.

Work:

- Simplify Journal default actions.
- Add note-level next-step guidance.
- Reframe Insights landing around one recommended action.
- Rename or clarify Insights lenses.

Expected impact: fewer "where am I supposed to go next?" moments.

### Phase 3: Focus The Writing Surface

Goal: make mobile drafting feel like writing.

Work:

- Collapse writing context.
- Hide formatting until needed.
- Move Advisor into review mode.
- Make requirements available but not visually dominant.

Expected impact: less writing anxiety and better mobile ergonomics.

### Phase 4: Test With A Small Script

Run 5 to 7 target-user sessions with these tasks:

- Start and save a first Examen.
- Capture a quick note.
- Reopen a reflection in Journal.
- Notice one pattern in Insights.
- Create or continue one draft.
- Add application details later.

Track:

- Where they hesitate.
- What terms they repeat back.
- Whether they understand the Reflect -> Journal -> Insights -> Writing spine.
- Whether Application Records feel helpful or stressful.

## Open Questions For The Next Decision

1. Should v1 be unmistakably reflection-first, with application support secondary, or should it continue to present reflection and application preparation as equal pillars?
2. Should Application Records appear on Home at all, or only after Journal/Writing interactions make them relevant?
3. Should non-medical tracks remain visible in onboarding for v1, or should they be moved behind an advanced "other track" path until the pre-med journey is fully calm?

My recommendation: reflection-first, Application Records secondary, pre-med/pre-health defaults visible but deep track breadth deferred.

## Bottom Line

Illuminote is too complex in the experience layer, not necessarily in the underlying product strategy. The code already contains many of the right separations: Journal versus Application Record, Insights versus Writing, optional record linking, draft naming, and completion routing. The next design move should be to reduce simultaneous decisions, especially at the beginning and end of the Examen.

The app should not become smaller in spirit. It should become gentler in sequence.
