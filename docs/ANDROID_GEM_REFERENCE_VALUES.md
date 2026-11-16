# iOS gem reference values, for the Android port

These are test vectors. Android should produce the same numbers from the same inputs.
Every value below came from running the real iOS code (`CrystalEngine.swift`), or a
line-for-line copy of `InteriorScene.init` from `GemInteriorView.swift`, on 2026-10-24
at commit c46c1e5. Decimals are printed to 10 places. Compare with a tolerance of about 1e-9.

## 0. What decides what (read this first)

**The phone never turns a seed into a gem.** The backend's `mint_coin` writes the DNA:
family, hue, saturation and trait. iOS only reads that DNA and draws it. So:

- **Family, colours and trait come from the DNA**, not from the seed. Section 2 tests that mapping.
- **The seed only drives the inside-a-gem view** (shard layout, sparkles, charged arcs)
  through `CrystalRng`. Sections 1 and 3 test that.
- Seeds are coin UUID strings in practice, e.g. `3f2a9c4e-8b1d-4e6f-a2c7-5d9e0b1f7a34`.
- `CrystalEngine.derive(...)` (colour relationships, orbitals) exists in the iOS source,
  but **no screen calls it**. Don't port it for v1. Section 1c lists its seed fallbacks anyway,
  in case it's wired up later.

## 1. CrystalRng (xmur3 → mulberry32)

The input to xmur3 is `"<seed>::<salt>"`, hashed over its **UTF-16 code units**, not bytes
and not code points. Kotlin's `String` is UTF-16 already, so iterate `str[i].code`. The
`café 🌟` case checks this: `é` is one unit, and the emoji is a surrogate pair, so two units.
`next()` returns `uint32 / 4294967296.0`.

### 1a. First 8 `next()` values

```
seed="3f2a9c4e-8b1d-4e6f-a2c7-5d9e0b1f7a34" salt="interior"
  0.9976908178, 0.8511770528, 0.0519081324, 0.1393918106, 0.4233252550, 0.2923847414, 0.5453783565, 0.9790889905
seed="3f2a9c4e-8b1d-4e6f-a2c7-5d9e0b1f7a34" salt="frame-hue"
  0.9805787196, 0.0344912491, 0.6017680762, 0.9800403479, 0.9469654243, 0.7528668877, 0.6606214077, 0.6851619363
seed="b71e0d52-6c3a-4f98-9e14-a0c2d8f63b19" salt="interior"
  0.7776214189, 0.1141871470, 0.3464608677, 0.6296958427, 0.6182202941, 0.6281643703, 0.0258317476, 0.0889611347
seed="favorium" salt="color-relationship"
  0.9381849871, 0.7515801447, 0.8456168713, 0.4707892628, 0.2335472750, 0.9302562480, 0.8564225370, 0.9165240421
seed="café 🌟" salt="interior"
  0.5801291349, 0.9599587556, 0.5605666451, 0.8572954442, 0.2882427117, 0.4489456799, 0.5279918802, 0.3315133618
seed="" salt=""
  0.9439983615, 0.6564009679, 0.1096631072, 0.3809673751, 0.1916742725, 0.8597397930, 0.0735696838, 0.3126454647
```

### 1b. Helper draws on one stream (seed `favorium`, salt `helpers`, called in this order)

```
range(0,360) = 227.8673671000
int(4)       = 2
pick(9 rels) = analogous
chance(0.5)  = false
sign()       = 1
```

What the helpers do:

- `range(lo, hi)` is `lo + next()·(hi − lo)`.
- `int(n)` is `floor(n · next())`.
- `pick(a)` is `a[int(a.size)]`.
- `chance(p)` is `next() < p`.
- `sign()` is `next() < 0.5 ? -1 : 1`.

`pick` above used the 9 colour relationships in this order: complementary, analogous, split,
core-and-shell, refracted, veined, spectral, gradient, asymmetric.

### 1c. Seed fallbacks in CrystalEngine (not used by any screen today)

```
3f2a9c4e-8b1d-4e6f-a2c7-5d9e0b1f7a34: frame_hue=353.0 color_relationship=veined secondary_influence=0.4557
b71e0d52-6c3a-4f98-9e14-a0c2d8f63b19: frame_hue=333.6 color_relationship=spectral secondary_influence=0.2477
e05c4b8a-1f27-4d3e-b6a9-72c1f0e8d456: frame_hue=1.8 color_relationship=gradient secondary_influence=0.6476
```

Here `frame_hue = round(range(0,360)·10)/10` with salt `frame-hue`, and
`secondary_influence = round4(range(0.22,0.88))` with salt `color-influence`.

## 2. DNA → the drawn gem (FavorGemView + GemInterior)

The rules are in `GEM_RENDERING_SPEC.md`. Hex values are plain sRGB from HSB, **before** the
brightness/saturation tweaks the layer stack applies.

| Case | DNA (relevant keys) | transfers | Family | Tier | Trait shown | Gem colour | Frame colour | Interior mirrors |
|---|---|---|---|---|---|---|---|---|
| A | `gemFamily:"celestial", primaryHue:210, saturation:0.8, trait:"starlight", identity.frame_hue:45` | 7 | celestial | bloom | starlight | hsb(210,0.8,0.9) = `#2E8AE6` | hsb(45,0.7,0.85) = `#D9B341` | 8 |
| B | `gemFamily:""` (or missing), `primaryHue:0, saturation:0`, `identity:{primary_color:120, saturation:0.6, base_form:" Victorian "}`, no trait | 0 | victorian (trimmed, lowercased) | seed | none | hsb(120,0.6,0.9) = `#5CE65C` | seed default hsb(0.28,0.5,0.6) = `#65994D` | 12 |
| C | `gemFamily:"darkheart", identity.base_form:"gothic", primaryHue:0, saturation:0.9, trait:"ember"` | 30 | gothic ("darkheart" isn't an asset key, so it falls through to base_form) | radiance | ember | hsb(0,0.9,0.9) = `#E61717` (hue 0 is kept because gemFamily is non-empty) | radiance default hsb(0.15,0.15,1.0) = `#FFFBD9` | 10 |
| D | DNA is null | 3 | lightning | seed | none | tier default `#65994D` | tier default `#65994D` | 6 |
| E | `gemFamily:"lightning", primaryHue:300, saturation:0.2, trait:"rainbow"` | 4 | lightning | seed | **hidden** (seed tier) | hsb(300,0.2,0.9) = `#E6B8E5` | seed default `#65994D` | 6 |

Interior palette (`GemInterior`). These rules differ from the card:

- Saturation is clamped to 0.35–1. Case E becomes hsb(300,0.35,0.95) = `#F29DF2`.
- A missing frame_hue becomes `(gemHue + 180) mod 360`, **not** the tier default.
  Case B gives 300 → `#E645E5`. Case C gives 180 → `#45E6E6`.
- A null DNA uses hue 45, sat 0.7 (`#F2C849`). The seed becomes the gem's *name*.
- Case A's full palette:

  | Role | HSB | Hex |
  |---|---|---|
  | gem | hsb(210,0.8,0.95) | `#3091F2` |
  | complement | hsb(30,0.68,0.9) | `#E69749` |
  | frame | hsb(45,0.7,0.9) | `#E6BD45` |
  | frame complement | hsb(225,0.6,0.85) | `#5777D9` |
  | depth | hsb(210,1.0,0.22) | `#001C38` |

- The interior hides the trait at seed tier, the same as the card.

## 3. Interior scene layout (salt `interior`)

Draw order, all from one stream:

1. **Shards.** For each shard, in order: `x = 0.5 + range(-spread, spread)`,
   `y = 0.5 + range(-spread, spread)·0.6`, `size = range(lo, hi)`, `spin = range(-0.25, 0.25)`,
   `orbit = range(0.02, 0.12)`, `phase = range(0, 2π)`, `colorIndex = int(4)`.
2. **Groups, in order:**

   | Group | Count | Size range | Spread |
   |---|---|---|---|
   | facet | 22 + extra | 0.14–0.4 | 0.42 |
   | frame | 4 | 0.5–0.85 | 0.3 |
   | gem | 8 + extra/4 | 0.2–0.45 | 0.32 |

   `extra` is seed 0, bloom 4, legacy 8, radiance 12. `extra/4` is integer division.
3. **Sparkles.** Then 18 sparkles (60 if the trait is starlight *and* shown), each `(next(), next(), range(0, 2π))`.

### 3a. seed=3f2a9c4e-8b1d-4e6f-a2c7-5d9e0b1f7a34 tier=seed starlight=false: 34 shards, 18 sparkles

| # | kind | x | y | size | spin | orbit | phase | colorIndex |
|---|---|---|---|---|---|---|---|---|
| 0 | facet | 0.9180602870 | 0.6769932346 | 0.1534961144 | -0.1803040947 | 0.0623325255 | 1.8371075110 | 2 |
| 1 | facet | 0.9024347520 | 0.5110820807 | 0.2228453157 | -0.1290067348 | 0.0354111222 | 1.7863619725 | 2 |
| 2 | facet | 0.4024149107 | 0.4709049758 | 0.2397786238 | -0.2051310830 | 0.0439549145 | 4.0599918971 | 3 |
| 3 | facet | 0.3953730675 | 0.4779173577 | 0.2373162468 | -0.2253934081 | 0.0925027716 | 0.7279934876 | 0 |
| 4 | facet | 0.1782107141 | 0.2503058614 | 0.3368896030 | 0.1830339301 | 0.0575484283 | 1.7056732293 | 0 |
| 5 | facet | 0.1977172513 | 0.4660974577 | 0.3375952245 | 0.1569564734 | 0.0708439002 | 5.5185195281 | 0 |
| 6 | facet | 0.5129211028 | 0.6934987485 | 0.2543707129 | -0.0257375520 | 0.0441233177 | 4.0585001786 | 3 |
| 7 | facet | 0.8770160552 | 0.6327174859 | 0.1712990031 | -0.2480057923 | 0.0705529593 | 0.4334094147 | 0 |
| 8 | facet | 0.7066727274 | 0.3348417398 | 0.2942523670 | 0.0372655413 | 0.0538034950 | 3.3017546804 | 0 |
| 9 | facet | 0.2813224932 | 0.4492627807 | 0.3456840724 | 0.0190657733 | 0.1025141702 | 5.6154751553 | 0 |
| 10 | facet | 0.2715616437 | 0.7501645960 | 0.3179792314 | -0.1918863973 | 0.1056906975 | 1.6212346613 | 2 |
| 11 | facet | 0.4484434019 | 0.4326714857 | 0.2924803479 | -0.1459040613 | 0.1028473830 | 2.9770376988 | 3 |
| 12 | facet | 0.6634703448 | 0.6488903706 | 0.3769658899 | 0.1202939651 | 0.0748647004 | 6.0092209578 | 2 |
| 13 | facet | 0.6911389192 | 0.6017317659 | 0.3980918251 | 0.2105679170 | 0.1002918242 | 3.2625439979 | 1 |
| 14 | facet | 0.2743393365 | 0.2530416129 | 0.3934667106 | 0.0575856166 | 0.0692430890 | 2.8597335951 | 3 |
| 15 | facet | 0.8398015485 | 0.5884529927 | 0.1403714314 | 0.1927909552 | 0.0891439101 | 4.7264411643 | 3 |
| 16 | facet | 0.3110198252 | 0.5323438141 | 0.3790741068 | -0.0728319841 | 0.1130785960 | 2.1196669122 | 2 |
| 17 | facet | 0.2322946531 | 0.6605446067 | 0.3418405360 | 0.0157249086 | 0.1131407676 | 5.9381841443 | 2 |
| 18 | facet | 0.3689175618 | 0.5257458751 | 0.3035912747 | 0.1534138285 | 0.0303742818 | 2.2756875145 | 0 |
| 19 | facet | 0.2786076731 | 0.4205826006 | 0.3723503712 | -0.0511066358 | 0.0245096492 | 2.7059571852 | 1 |
| 20 | facet | 0.3935617430 | 0.2655935397 | 0.2161922938 | 0.2130917272 | 0.0849280002 | 1.9730550515 | 2 |
| 21 | facet | 0.4565193231 | 0.5959863293 | 0.3359032541 | 0.2482447502 | 0.1169493710 | 1.5702594637 | 1 |
| 22 | frame | 0.4966985083 | 0.4434549820 | 0.7527459200 | 0.1024032013 | 0.0581998683 | 0.8491340414 | 3 |
| 23 | frame | 0.5987129244 | 0.5681191071 | 0.8107413990 | 0.1176549367 | 0.0751216078 | 5.5265566318 | 1 |
| 24 | frame | 0.2733742192 | 0.4641528760 | 0.6668074956 | 0.0491757607 | 0.0874894679 | 2.3882001022 | 0 |
| 25 | frame | 0.4001704750 | 0.5201308363 | 0.6532508315 | 0.1580398519 | 0.0435054178 | 6.0756788567 | 2 |
| 26 | gem | 0.4284440093 | 0.5044952410 | 0.3417483379 | -0.1566060446 | 0.0418721286 | 1.0612136630 | 2 |
| 27 | gem | 0.3777207795 | 0.4183821864 | 0.4277862548 | -0.1908799645 | 0.0441663316 | 5.9450093388 | 1 |
| 28 | gem | 0.6468434472 | 0.3641786787 | 0.3136304065 | -0.1171887463 | 0.0478166942 | 2.4976478604 | 3 |
| 29 | gem | 0.4325981128 | 0.4025165489 | 0.4066510829 | 0.1829457190 | 0.0261657439 | 2.9180634963 | 2 |
| 30 | gem | 0.4627937879 | 0.4387429228 | 0.2412483258 | -0.0185936711 | 0.0559443678 | 5.3911122971 | 0 |
| 31 | gem | 0.5473790991 | 0.6045463424 | 0.2292529875 | -0.1571788186 | 0.0247017811 | 5.6422733802 | 2 |
| 32 | gem | 0.4547882451 | 0.5527715938 | 0.2154972780 | 0.2009788516 | 0.0306214783 | 0.1135956796 | 0 |
| 33 | gem | 0.6935775365 | 0.4639024190 | 0.3319041069 | -0.0387015073 | 0.0380403053 | 4.6772824692 | 1 |
first 3 sparkles (x, y, phase): (0.9083866228, 0.7422360617, 5.4417580411), (0.5104567760, 0.3616582954, 2.1243055885), (0.2640780255, 0.7544811566, 0.4325167436)
last sparkle: (0.7401261323, 0.7821006135, 5.0628965596)

### 3b. seed=b71e0d52-6c3a-4f98-9e14-a0c2d8f63b19 tier=bloom starlight=true: 39 shards, 60 sparkles

| # | kind | x | y | size | spin | orbit | phase | colorIndex |
|---|---|---|---|---|---|---|---|---|
| 0 | facet | 0.7332019919 | 0.3055503221 | 0.2300798256 | 0.0648479214 | 0.0818220294 | 3.9468731420 | 0 |
| 1 | facet | 0.1547273531 | 0.4328469247 | 0.3064344135 | -0.0802242294 | 0.0492661489 | 1.7382496924 | 0 |
| 2 | facet | 0.4455982707 | 0.3771683004 | 0.3603896857 | 0.1702144708 | 0.0591358644 | 4.1569847834 | 0 |
| 3 | facet | 0.7744549163 | 0.4573431970 | 0.2290726745 | -0.0669525934 | 0.0617762961 | 2.2235006126 | 3 |
| 4 | facet | 0.8192874560 | 0.3921502913 | 0.3367942542 | -0.2198666544 | 0.0733858513 | 4.3009836969 | 0 |
| 5 | facet | 0.5382632898 | 0.7250321945 | 0.3997337718 | -0.0147161102 | 0.1193445034 | 4.2378042398 | 2 |
| 6 | facet | 0.6550065827 | 0.4150527538 | 0.1966940691 | -0.0812426629 | 0.0610099932 | 5.6548661190 | 2 |
| 7 | facet | 0.3334222095 | 0.6160696618 | 0.2973604174 | 0.0036136252 | 0.0285205466 | 5.9566619539 | 2 |
| 8 | facet | 0.4655323191 | 0.5170645910 | 0.2653487212 | 0.1740066727 | 0.0808480350 | 1.7166021446 | 0 |
| 9 | facet | 0.4116792102 | 0.6582306432 | 0.2440294481 | 0.0650494572 | 0.0533844689 | 6.2007989470 | 0 |
| 10 | facet | 0.4539136417 | 0.6138674755 | 0.2092607850 | 0.1719714353 | 0.0619487711 | 2.4575210606 | 1 |
| 11 | facet | 0.7534230436 | 0.4677231481 | 0.1600954949 | -0.1140775034 | 0.0707588499 | 3.4584130769 | 3 |
| 12 | facet | 0.2259352783 | 0.4329440112 | 0.2578817309 | -0.1647026885 | 0.0651335619 | 2.0640532871 | 1 |
| 13 | facet | 0.1431659893 | 0.6850942135 | 0.2777664570 | 0.0577270227 | 0.0900801786 | 5.9198075408 | 1 |
| 14 | facet | 0.5852620001 | 0.4980710137 | 0.3262817261 | 0.0004287980 | 0.0327721069 | 0.1591039143 | 3 |
| 15 | facet | 0.7451551171 | 0.5502318601 | 0.3695287149 | 0.0593387792 | 0.0525766941 | 6.1450414643 | 3 |
| 16 | facet | 0.5252043379 | 0.5634801567 | 0.1908363802 | 0.1608310764 | 0.0611380250 | 1.4222193911 | 0 |
| 17 | facet | 0.6167679684 | 0.5949395140 | 0.2195737601 | -0.0175792034 | 0.0986952524 | 0.5473167894 | 1 |
| 18 | facet | 0.2408892956 | 0.7269203063 | 0.2740816259 | 0.0092493414 | 0.0287817468 | 2.7998279731 | 1 |
| 19 | facet | 0.2755169866 | 0.5155184365 | 0.3345843605 | -0.0886893052 | 0.0553870426 | 3.0254626689 | 0 |
| 20 | facet | 0.3440409695 | 0.7336603040 | 0.3049476790 | 0.2163292299 | 0.0833850939 | 5.6859806194 | 2 |
| 21 | facet | 0.6763614731 | 0.6996370167 | 0.3484217957 | 0.0642299852 | 0.0464514560 | 0.5034431550 | 0 |
| 22 | facet | 0.2063907599 | 0.3796510845 | 0.3835773491 | -0.0914346371 | 0.1004438431 | 4.5424911445 | 1 |
| 23 | facet | 0.9059174827 | 0.6154275113 | 0.1826063199 | -0.2215348424 | 0.1143522549 | 2.3263330787 | 1 |
| 24 | facet | 0.2976394999 | 0.3525743218 | 0.2776504921 | -0.1597376820 | 0.0620777157 | 0.9205831769 | 0 |
| 25 | facet | 0.1698599686 | 0.3227197291 | 0.3331747754 | 0.0875238334 | 0.0331226641 | 1.1264908686 | 3 |
| 26 | frame | 0.3056728097 | 0.6265965453 | 0.7038791058 | -0.2081706692 | 0.0928538358 | 4.0959764254 | 3 |
| 27 | frame | 0.5694978899 | 0.5745340725 | 0.5775772658 | 0.0777193932 | 0.0438778839 | 2.9409586485 | 0 |
| 28 | frame | 0.5530908688 | 0.5235355775 | 0.5631611753 | 0.0501984132 | 0.0815239253 | 0.3151505755 | 2 |
| 29 | frame | 0.5489971140 | 0.3721517688 | 0.7045499832 | -0.1674706357 | 0.0202647325 | 4.9402101872 | 3 |
| 30 | gem | 0.3992672232 | 0.3570465898 | 0.3582010275 | -0.0679343010 | 0.0999493115 | 3.2008706676 | 3 |
| 31 | gem | 0.3912499155 | 0.6518104291 | 0.2069361425 | 0.1421380024 | 0.1188299915 | 1.2988725067 | 0 |
| 32 | gem | 0.6465498021 | 0.3654693862 | 0.2698111448 | 0.0115664410 | 0.0580294054 | 0.7488178632 | 0 |
| 33 | gem | 0.5398924018 | 0.6725901387 | 0.2652993346 | 0.0332940276 | 0.0266825519 | 4.5386582743 | 1 |
| 34 | gem | 0.6894689950 | 0.3639260737 | 0.3123271087 | 0.1875350495 | 0.1160188951 | 4.7544566249 | 0 |
| 35 | gem | 0.6448244250 | 0.6522505112 | 0.3036348701 | -0.1311628304 | 0.0915341897 | 4.3796782165 | 2 |
| 36 | gem | 0.5778816929 | 0.3200141275 | 0.3221217129 | 0.0227226435 | 0.0693237502 | 4.2819767469 | 1 |
| 37 | gem | 0.5781060076 | 0.4894294466 | 0.2651476210 | -0.2329459486 | 0.0437522323 | 3.5497091583 | 0 |
| 38 | gem | 0.4506251682 | 0.3237433462 | 0.2084821404 | 0.1338186922 | 0.0316997602 | 0.0827495150 | 2 |
first 3 sparkles (x, y, phase): (0.1961136763, 0.8865319372, 4.8743049699), (0.2547447348, 0.2084352423, 1.6545893383), (0.2602826026, 0.1787673065, 1.1687264107)
last sparkle: (0.0832142325, 0.4704462797, 3.1137222823)

### 3c. Charged arc

The charged trait reseeds every half second with salt `arc-<Int(t·2)>`. These are the first
14 draws for seed `b71e0d52-6c3a-4f98-9e14-a0c2d8f63b19`, salt `arc-1` (t in [0.5, 1.0)),
as x,y fractions of the view: move to the first point, then draw lines to the next six.

```
0.4938920669, 0.8812336393, 0.2574860109, 0.2464085610, 0.0774955312, 0.7425671888, 0.1537230038, 0.9220533357, 0.3096040983, 0.9144992894, 0.6436444353, 0.7575963498, 0.0971306514, 0.8159642112
```
