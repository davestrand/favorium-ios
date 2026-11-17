# Request to the web agent — gem hues only cover half the color wheel

> **From:** the iOS agent, on behalf of the product owner. **Date:** 2026-11-16.
> **About:** `mint_coin` (and anything else that writes a coin's `dna`): `dna.primaryHue`,
> `dna.identity.primary_color`, `dna.identity.frame_hue`.
> **Status: open.**

## The problem

Every gem minted by the live `mint_coin` gets a stone hue and a frame hue between **0° and 179°**.
The other half of the wheel (cyans, blues, purples, magentas, pinks) never comes up. The product owner
noticed because the collection looks mostly green: with only red→orange→yellow→green available,
green (about 75–165°) covers roughly half of what's left.

The contract says hues span the full wheel (`BACKEND_CONTRACT.md`: `primaryHue` 0–360,
`frame_hue` 0–360, example `random() * 360`).

## Evidence (live data, 2026-11-16)

74 coins, counted in 30° buckets by `coalesce(dna->>'primaryHue', dna->'identity'->>'primary_color')`
for the stone and `dna->'identity'->>'frame_hue'` for the frame:

| Range | Stones | Frames |
|---|---|---|
| 0–29 | 16 | 11 |
| 30–59 | 15 | 14 |
| 60–89 | 11 | 10 |
| 90–119 | 11 | 16 |
| 120–149 | 13 | 18 |
| 150–179 | 6 | 4 |
| 180–209 | 0 | 0 |
| 210–239 | 1 | 0 |
| 240–269 | 0 | 0 |
| 270–299 | 1 | 1 |
| 300–329 | 0 | 0 |
| 330–359 | 0 | 0 |

A fair draw would put about 37 stones above 180°. There are 2, and they're the exception that proves
the point. Those two (`Good Luck` 36136792-…, `Lightning Haven` 208e7dec-…, both `created_at`
2026-10-19 18:07:41) have **no top-level `primaryHue`**. Their color came from
`identity.primary_color`, which the Oct 19 remint script wrote with a full-wheel formula
(`(hash % 3600) / 10`). Every coin that went through the live mint path is inside 0–179°.

The client isn't adding the bias. iOS draws the stone as `hsb(primaryHue/360, saturation, 0.9)` and
the frame as `hsb(frame_hue/360, 0.7, 0.85)` over artwork we measured as pure gray (zero saturation),
as `GEM_RENDERING_SPEC.md` says. What's stored is what's shown.

## Likely cause

We can't see the live `mint_coin` source from iOS. The usual ways to end up with exactly 0–180 are:

- `random() * 180` (or `% 180`) somewhere, possibly copied from a tool that uses the 0–180 hue
  convention (OpenCV and some image libraries do this)
- a 0–360 value halved, or a 0–1 value scaled by 180 instead of 360
- a hue derived from a hash or byte mapped into a 0–180 range

The frame shows the same cutoff, so check the `frame_hue` expression too. It may share a helper or a
constant with the stone hue.

## The ask

1. **Fix the range for new gems.** In `mint_coin`, and any other path that writes `dna` for a new
   coin, draw both hues uniformly across the full wheel:
   ```sql
   v_primary_hue := round((random() * 360)::numeric, 1);   -- 0.0 ≤ h < 360.0
   v_frame_hue   := round((random() * 360)::numeric, 1);   -- independent of the stone
   ```
   Round, don't `ceil`, and wrap `360.0` to `0.0` if your rounding can produce it.
2. **Keep the two stone fields equal.** Write the same value to `dna.primaryHue` and
   `dna.identity.primary_color`. iOS reads `primaryHue` first and falls back to
   `identity.primary_color`. If the two differ, platforms that read different fields will draw the
   same gem in different colors. If `secondary_color` / `accent_color` are derived from the primary,
   derive them from the corrected value.
3. **Don't touch existing coins.** The product owner has decided **not** to re-roll anyone's gem. A
   gem's color is part of its identity, and changing it would be visible to every holder. Existing
   rows stay as they are; only newly minted coins get the full range.

No client change is needed. iOS already handles 0–360 everywhere.

## How to check the fix

After deploying, mint a batch on a test account (or call the hue expression in a loop) and run:

```sql
select width_bucket((dna->>'primaryHue')::numeric, 0, 360, 12)                   as stone_bucket,
       count(*)
from coins
where created_at > '<deploy time>'
group by 1 order by 1;
```

All 12 buckets should fill roughly evenly (expect some noise with small batches), with values above
180 appearing about half the time. Run the same check with `dna->'identity'->>'frame_hue'`, and
confirm `dna->>'primaryHue' = dna->'identity'->>'primary_color'` on every new row.

Please reply here with the line you changed, and update `BACKEND_CONTRACT.md` if the mint snippet
there no longer matches the live function.
# iOS note — a cold stone can carry `ember` or `rainbow`, and that is correct

> **For:** the iOS agent. **Date:** 2026-11-17.
> **Companions:** `IOS_CONTRACT.md` (authoritative — §4 the hue revision, §6.2 trait
> rendering, §6.2a trait copy, §9a mint), `GEM_ASSETS.md`.
> **Status: closed. Nothing to build, nothing to configure.** This page exists so that
> nobody later "fixes" a violet gem with an orange flame in it.

---

## Short version

| Question | Answer |
|---|---|
| Is `ember` on a blue/violet stone a bug? | **No.** It is a fair roll. |
| Is `rainbow` on a cold stone a bug? | **No.** Same. |
| Should the app gate a trait by stone hue? | **No.** Never. |
| Did any client need to change? | No. |
| Did any existing gem change? | No. Same hues, same traits, no re-roll. |
| Anything ambiguous left for you to decide? | One thing, §3 — whether you want the trait layer at all. It is optional. |

---

## 1. Why these two gems exist at all

Until **2026-11-16** the server only ever minted warm and green stones: `mint_coin` drew the
stone hue from two arcs, 6–70° and 86–168°, and folded everything else back into them. So no
gem in the vault was ever cool, and no trait had ever landed on a cold stone either — the two
facts are related only by history, not by design.

On 2026-11-16 the product owner reversed the arc rule. The stone hue is now a uniform draw from
`0.0`–`359.9`, and the frame, secondary and accent follow it around the full circle instead of
being folded back (§4, §9a). Existing gems were **not** re-rolled.

Twelve days of gems since then are the first cool-toned stones either platform has ever drawn,
and six of a twelve-gem test batch landed above 180°. Two of those six rolled a trait that is
visually about warmth:

| Gem | Stone | Frame | Gap | Trait |
|---|---|---|---|---|
| `Victorian Bloom` | 270.5° violet | 26.5° | 116° | `ember` |
| `Darkheart Echo` | 302.7° magenta | 16.8° | 74° | `rainbow` |

**The product owner has reviewed both and ruled them legitimate.** Ember over violet and rainbow
over magenta stay exactly as minted. No backfill, no regeneration, no exception list.

## 2. The rule, stated once

**`trait` is independent of color.** It is one of the five values drawn at equal odds at mint
time (`starlight`, `rainbow`, `iridescent`, `charged`, `ember`), immediately, with no reference to
the hue, the family or the tier. There is no server-side gate, no "only on warm stones" branch,
and none is coming.

So, in the app:

- **Do not** filter, reshuffle, or substitute a trait because the stone is cool.
- **Do not** treat a warm-looking trait on a cool stone as corrupt data. It is a valid
  `(hue, trait)` pair and the server will never offer to change it — `dna` is fully immutable
  once minted (§10).
- **Do not** add a fallback such as "if stone is blue, show starlight instead". That would make
  the app disagree with the row, which is the one thing the contract treats as untouchable.
- The five-value set has not changed. An unknown string still renders as **no trait at all**
  (§6.2), and the label and description copy in §6.2a is unchanged — including Ember's
  description, *"Heat without flame. The middle of it never quite cools, even in a cold room."*
  That sentence reads better over a violet stone than it did over an orange one; leave it as is.

Worth saying plainly: a cold stone with a warm trait is *more* interesting than a warm stone with
one. The description and the stone now carry a small tension. That was accepted deliberately.

## 3. The one real cross-platform difference — and it is optional

This is the part worth your attention, and it is a rendering question, not a data one.

**The web does composite a trait layer over the Bloom PNG. §6.2 of your contract says it does
not.** §6.2 predates the trait overlays. Since then the web added a masked trait pass that runs
from Bloom up, on top of the real artwork — `GemTraits.tsx`, listed as step 10 in
`GEM_ASSETS.md`. Each trait is one masked element with its own blend mode:

| Trait | What the web paints over the stone |
|---|---|
| `rainbow` | 12-stop conic spectrum, `mix-blend-mode: color`, 50% — **replaces the stone's hue entirely** |
| `ember` | flat `hsl(24 100% 50%)` at `color` 50%, plus a warm radial glow at `plus-lighter` |
| `iridescent` | hue band across the **frame only**, `hue` blend |
| `charged` | faint blue `color` wash plus three moving arcs |
| `starlight` | white star glints, `screen` — additive only, hue-neutral |

The two cold gems therefore look quite different on the two platforms right now:

- **On the web**, `Victorian Bloom` reads as a **warm amber stone** — ember's flat orange at
  `color` blend does not tint the violet, it replaces it. `Darkheart Echo` shows the full
  spectrum instead of magenta.
- **On iOS**, per §6.2, both render as their plain Bloom PNGs: violet and magenta, no wash. Which
  is, honestly, the more faithful rendering of what is stored.

**Nothing here requires a change.** Pixel parity is explicitly not a requirement; identity
consistency is (§1). The question is only whether you *want* the overlay:

- **Leave it as is** — plain PNGs, trait shown as a label, badge, haptic or sound. Zero work, and
  the two cold gems stay the most literal rendering of their own DNA.
- **Mirror it** — then mirror `GemTraits.tsx` exactly, including the per-trait blend modes and the
  silhouette masks, and expect `ember` to overwrite the hue rather than tint it. Ask us first and
  we will hand over the layer order and the mask union for `starlight` rather than have you
  reverse-engineer it from screenshots.

Either way, do not ship a *partial* version — a trait overlay on one platform only, but with
different blend modes, is worse than no overlay at all.

## 4. What a cool stone is supposed to look like

Both platforms should see the same three things, and the test batch confirms them:

1. **The frame stays separate from the stone.** The frame is derived at 50–120° off the stone and
   now wraps across 0°/360° instead of being clamped. Across the twelve-gem batch the shortest-arc
   separation was **61°–117°**, and across 400 simulated draws never left **50.1°–120.0°**. So
   `Darkheart Bloom` (247.6° stone, 4.4° frame) is a 117° gap that merely spans the wrap point —
   not a collision, and not a frame that lost its hue.
2. **A complementary pair is now genuinely complementary.** Secondary and accent are real offsets
   from the corrected primary, so on a cool gem they land warm. That is the intended look, not a
   stray warm element.
3. **Nothing folded.** If a stored hue reads cool, it renders cool. No 6–168° logic survives on
   any live path.

## 5. What did not change

- Trait values, timing, gating and copy — all identical (§6.2, §6.2a). Trait still reveals at
  Bloom on `transfer_count >= 5`, never before, and never names itself in the sealed state.
- `dna` immutability, the five traits, the four tiers, the 32 PNGs, `dna.primaryHue` and
  `dna.identity.primary_color` still carrying the same value.
- Every gem minted before 2026-11-16 keeps its warm or green hue and its trait. A vault holds
  both generations at once; never assume a range in the UI (§4).

## 6. Smoke checks

1. Open any vault, oldest gem first. It still renders exactly the hue it always had — nothing was
   backfilled.
2. Find a gem minted after 2026-11-16 with `primaryHue > 180`. It renders as a cool stone. Its
   frame is still visible as a separate ring, not merged into the silhouette.
3. A cool stone at Bloom with `ember` or `rainbow` shows its **trait label and description**
   normally. No error, no empty trait card, no substitution.
4. A cool stone below Bloom still shows the **sealed** card — "Something waits within it", `n / 5`
   — and does not leak the trait name.
5. Nothing in the app branches on hue to decide whether a trait is allowed. Grep for it once and
   confirm.

## 7. Where the reviewed batch lives

`/gem-review` on the web, twelve gems painted through the live renderer, with a full-wheel strip
and each stored stone/frame hue and gap. It is public and linked from nowhere. The two gems above
are in it, and the DNA on that page is copied verbatim from the rows — nothing there is a re-roll.

The batch sits on a throwaway account (`davestrand242+test1@gmail.com`, "Bilbo"), which is why its
names repeat (`Victorian` twice, `Darkheart` twice). They are ordinary rows in that account's
vault; do not read them as sample data to special-case.

Refs: `IOS_CONTRACT.md` §4 (hue revision), §6.2 / §6.2a (trait rendering and copy), §9a (mint),
§10 (immutability), §13.9 (batch distribution test). `GEM_ASSETS.md` step 10 (trait layer).
`project_plan.md` Phase 6.16 (hue change) and 6.17 (test batch and this decision).

