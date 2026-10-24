To the web AI: how iOS draws a gem, so the website can match it (traits especially)

The iOS app is the reference for how gems look. Its renderer is favorium/FavorGemView.swift in github.com/davestrand/favorium-ios (tag v1.0). Everything below comes from that file. The website seems to be missing mainly the traits, so they're covered in the most detail, but the base layers matter too.

======================================================================
1. WHAT DECIDES A GEM'S LOOK (all from DNA + transfer_count)
======================================================================

Family (art set): DNA gemFamily, else identity.base_form, else "lightning".
  Asset keys: lightning | celestial | victorian | gothic. "gothic" is shown to people as "Darkheart".
  Matching is case- and whitespace-insensitive. A value that isn't a known asset key falls through to the next source.
  The frame family ALWAYS equals the gem family.

Tier, from transfer_count (each tier also swaps the artwork):
  seed      0–4
  bloom     5–14
  legacy    15–29
  radiance  30+
Assets: gem_<family>_<tier>.png and frame_<family>_<tier>.png (16 gem + 16 frame images).

Gem colour:   hsb(hue = primaryHue/360, sat = saturation, brightness 0.9).
  Fallbacks: primaryHue → identity.primary_color → 45; saturation → identity.saturation → 0.7.
Frame colour: hsb(identity.frame_hue/360, 0.7, 0.85) when frame_hue exists.
  Otherwise use the tier default colour (hue/sat/bri, 0–1):
    seed      0.28 / 0.50 / 0.60
    bloom     0.55 / 0.70 / 0.85
    legacy    0.12 / 0.80 / 0.90
    radiance  0.15 / 0.15 / 1.00

TRAIT, the part that's "unlocked at higher levels":
  DNA "trait" is rolled once at mint and never changes. Values: starlight | rainbow | iridescent | charged | ember.
  RULE: a trait is HIDDEN while the gem is at seed tier (under 5 transfers), even if the DNA already has one.
  From bloom upward (5+ transfers) it is drawn on top of the gem. The gem guide calls bloom
  "passed along enough times to open up and reveal its hidden trait".
  Unknown or empty trait means no trait.
  NOTE: IOS_CONTRACT §6.2 says not to draw traits. iOS draws them anyway, on the user's instruction, so the web should match iOS.

======================================================================
2. LAYER ORDER (bottom → top), all inside a square of side S
======================================================================
1. (optional) background glow: soft radial blooms in the frame colour and gem colour
2. GEM image, built from stacked copies:
   a. shadow: gem image tinted black, 40% opacity, blur 3px, nudged down 2% of S
   b. base: gem image multiplied by the gem colour, brightness -0.15, saturation 1.2
   c. mid: the same, brightness +0.1, saturation 1.1, blend "lighten", 80%
   d. facet highlight: white, blend "screen", 50%, masked by a linear gradient from top-left (white → 30% → clear) to bottom-right
   e. sparkle: white, "screen", 70%, masked by a radial gradient centred at (30%, 25%), radius 0.3·S
   f. prism: multiplied by hsb(gemHue + 0.1, 0.8, 1.0), "screen", 20%, offset (-2px, -2px)
   g. rim glow: gem image multiplied by gem colour, blur 4px, "screen", 60%
3. FRAME image, built the same way:
   - a glow copy at 1.05·S multiplied by the GEM colour, blur 6px, 40%
   - a black shadow copy, 30%, blur 2px
   - the base copy multiplied by the frame colour, brightness -0.1, saturation 1.1
   - a mid copy at brightness +0.15, "lighten", 70%
   - a white "screen" copy at 50%, masked by a top-left linear gradient
   - a white "screen" copy at 60%, masked by a radial gradient at (30%, 20%), radius 0.25·S
4. (optional) shimmer: a diagonal white sweep, blend "overlay", that tracks the tilt
5. TRAIT overlay (bloom tier and up)

"Multiply by colour" means a colour-multiply tint: CSS mix-blend-mode multiply over a solid fill clipped to the image,
or a canvas globalCompositeOperation. A trait masked to the gem means clipped to the gem PNG's alpha:
CSS mask-image: url(gem_<family>_<tier>.png).

Whole gem motion, the "pendulum tilt", which several traits key off:
  rotateY from -15° to +20° and back, ease-in-out, 4.5s per half-swing, repeating forever.
  The axis is mostly vertical (x 0.15, y 1.0), with perspective.
  The drop shadow is black 35%, radius 14, y +6, and its x offset follows sin(tilt)·10.
  CSS: perspective on the parent plus an animated transform: rotate3d(0.15, 1, 0, angle).
  Traits marked "tilt-driven" below need the CURRENT tilt angle each frame, so animate it in JS
  (or read it with a CSS @property) rather than with a pure keyframe you can't see into.

======================================================================
3. THE FIVE TRAITS — exact recipes
======================================================================

RAINBOW: "A full spectrum of color drifts through its heart."
  - A conic (angular) gradient around the centre: 13 stops at full saturation and brightness,
    hue_i = (i mod 12) / 12 at location i/12. The last stop repeats red, so there's no seam.
  - The wheel turns CLOCKWISE continuously: one full revolution every 12s, linear, forever.
    No rocking and no separate hue drift. (Updated 2026-10-24 to match the web's full spin, which the user liked.)
  - Draw it oversized (1.5·S) so its corners never show while it turns.
  - Opacity 50%, blend mode "color" (CSS mix-blend-mode: color), so it recolours the gem but keeps its shading.
  - Masked to the GEM image only, never the frame.
  CSS sketch:
    .rainbow {
      background: conic-gradient(<13 hue stops>);
      mix-blend-mode: color;
      opacity: .5;
      mask-image: url(gem.png);
      animation: spin 12s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg) } }

IRIDESCENT: "Its setting shimmers like a butterfly's wing, shifting with every tilt." (tilt-driven)
  - Applies to the FRAME only.
  - A soft horizontal band 1.5·S wide.
    Stops: hue h1 at 0% opacity (0%), h1 at 60% (30%), h2 at 80% (50%), h3 at 60% with sat .95 (70%), h3 at 0% (100%).
    h1 = base, h2 = base + 0.10, h3 = base + 0.22.
    base drifts 0 → 0.22 and back over 10s, linear, alternating.
  - The band's x offset = ((tilt + 15) / 35 - 0.5) · S, so it slides across as the gem swings.
  - Draw the band with blend "hue" at 50%, which changes the metal's colour but keeps all engraved detail.
  - Plus a thin white specular line (0 → 35% → 0 between 44% and 56% of the band), blend "screen", 40%.
  - Clip to the square and mask with the FRAME image.

STARLIGHT: "Hidden stars glint across its facets as it turns in the light." (tilt-driven)
  - 10 fixed star positions. Offsets from the centre are fractions of S; each has a scale, a trigger angle and a window:
      ( 0.00,-0.28) 0.6  -10 3.5     (-0.05,-0.18) 0.8   16 3.0
      ( 0.09,-0.10) 1.0    5 2.5     (-0.12, 0.02) 1.4  -14 3.0
      ( 0.10, 0.06) 1.1   12 2.5     ( 0.00, 0.12) 1.8    0 4.0  (hero star)
      (-0.08, 0.22) 1.2   19 2.5     ( 0.11, 0.18) 1.0   -5 3.0
      (-0.22, 0.38) 0.9    9 2.5     ( 0.20, 0.44) 0.7  -13 3.0
  - A star's brightness is ZERO unless |tilt - trigger| < window. Inside the window it is cos²((|tilt - trigger| / window) · π/2).
    So each star flashes once as the swing passes its angle, and only one or two are lit at a time.
  - Each star is built from:
    - a soft white radial halo (radius 0.8·b, blur 0.35·b), where b = 0.07·S·scale;
    - a hard white dot (0.3·b, at least 2px);
    - two hair-thin needle arms, horizontal and vertical, each 7·b long and 0.08·b thick (at least 1px),
      with gradient clear → white → clear and blur 0.4px.
  - The whole group uses blend "screen", masked by the gem AND frame images together.

CHARGED: "Crackling arcs of energy dance across its surface."
  - An ambient tint: the gem image multiplied by hsb(0.6, 0.6, 1.0), 18%, blend "color".
  - Three electric arcs. Each is a bar 0.9·S long and max(0.014·S, 2px) tall, gradient
    clear → hsb(0.58, .35, 1) → white → hsb(0.58, .35, 1) → clear, blur 0.8 × its height, blend "plus-lighter".
      arc 0: rotated 20°,  moved up 0.08·S,   phase offset 0
      arc 1: rotated 85°,  centred,           phase offset 1/3
      arc 2: rotated 150°, moved down 0.08·S, phase offset 2/3
  - A shared phase loops 0 → 1 linearly every 1.4s. local = (phase + offset) mod 1.
    Visible only while local < 0.35, with opacity sin(local / 0.35 · π). So the arcs fire in quick staggered bursts.
  - All of it is masked to the GEM image.

EMBER: "A slow inner fire glows deep within, warm as a coal."
  - A warm tint: the gem image multiplied by hsb(0.06, 1, 1), 50%, blend "color".
  - A core fireball: a radial gradient, radius 0.38·S, inside a 0.76·S circle:
    hsb(.08, 1, 1) at glow·0.9 → hsb(.04, 1, .9) at glow·0.5 → clear. Blur 0.06·S, blend "plus-lighter".
  - A rim: a ring 0.72·S across, line width 0.06·S, colour hsb(.06, 1, 1) at glow·0.7, blur 0.04·S, "plus-lighter".
  - glow pulses 0.4 ↔ 1.0, ease-in-out, 2s each way, repeating.
  - All of it is masked to the GEM image.

======================================================================
4. CHECKLIST FOR MATCHING iOS
======================================================================
[ ] The tier comes from transfer_count, and the art changes per tier
[ ] The trait is hidden at seed and shown from bloom (5+ transfers)
[ ] Rainbow, ember and charged are masked to the gem only; iridescent to the frame only; starlight to gem + frame
[ ] The blend modes are as listed: CSS mix-blend-mode supports color, hue, screen, overlay, lighten and plus-lighter
[ ] The pendulum tilt runs (-15° ↔ +20°, 4.5s), and iridescent and starlight read the live tilt angle
[ ] Frame colour from identity.frame_hue, else the tier default
[ ] Respect prefers-reduced-motion: stop the tilt and hold traits at a pleasant static frame

Side by side, a bloom-tier or higher gem with each trait should look the same on iOS and the web. If something can't be matched exactly in CSS, please say which piece, and the user can decide.
