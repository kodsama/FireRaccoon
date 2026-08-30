# Design specification

Visual and interaction reference for FireRaccoon. The Flutter app implements this spec.

**Interactive prototype:** not in the tree any more, because its sample ledger
named real banks and accounts. To click through it, take it out of history:

```sh
git show 0.1.2:fireraccoon-standalone.html > /tmp/fireraccoon-prototype.html
open /tmp/fireraccoon-prototype.html
```

---

## About the design files

The HTML files were a **design reference**: a working, clickable prototype showing the intended look, layout, and behaviour, never production code to copy. The Flutter app recreates those designs with idiomatic widgets, a theming system, and the Firefly III API client.

Both were removed from the tree at 0.1.12. The sample ledger they shipped with
carried real bank and account names, and nothing in the build read them. They
are still in history at the tag above:

- `FireRaccoon.dc.html`, the source prototype (all screens plus logic).
- `fireraccoon-standalone.html`, the same app bundled into one self-contained
  file, which was the visual source of truth.
- `assets/`, the brand fonts (Comfortaa, Roboto Slab) and the app mark, which
  are still in the tree.

## Fidelity

**High-fidelity.** Colours, typography, spacing, radii, and interactions are final.
Recreate the UI pixel-faithfully in Flutter. The data shown is illustrative sample data;
in the real app it all comes from Firefly III.

---

## Product scope

A persistent left sidebar navigates six areas plus a settings screen:

1. **Dashboard** (three switchable layout directions — Insights / Accounts / Focus)
2. **Accounts** (list) → **Account detail**
3. **Transactions** (browse, filter, add/edit)
4. **Budgets** (friendly pacing view)
5. **Expenses** (spending analysis)
6. **Projection** (balance forecast — the differentiator)
7. **Settings** (appearance + connection)

Everything is denominated per-account in its native currency; **totals** are shown in a
user-chosen **display currency** (EUR default) using FX conversion.

---

## Design tokens

### Typography
- **Comfortaa** (rounded geometric sans) — everything: display, headings, body, UI.
  Weights 300/400/500/600/700. Headings 600, set tight (letter-spacing −0.02em).
- **Roboto Slab** (slab serif) — **numbers/figures only** (balances, KPIs, chart values)
  and the highlight accents. Weight 700. Never body copy.
- Scale (px): 11, 12, 12.5, 13, 13.5, 14, 15, 16, 18, 20, 22, 24, 27, 30, 34, 38, 46.
- Line-height: tight 1.1 (headings), 1.45–1.7 (body).

### Colour — neutrals (theme-aware)
Two modes. Values are the exact tokens used.

**Light**
| Token | Value |
|---|---|
| page bg | `#ECF0F0` |
| surface (cards) | `#FFFFFF` |
| surface-2 (inset controls) | `#ECF0F0` |
| sunken (subtle fills) | `#F6F8F8` |
| border | `#DCE3E3` |
| divider | `#ECF0F0` |
| text | `#14201F` |
| text-2 | `#3F4C4B` |
| text-3 (muted) | `#8A9797` |
| header bg | `rgba(246,248,248,0.85)` + blur(8px) |
| card shadow | `0 1px 3px rgba(11,70,80,0.05)` |
| track / track-strong | `#ECF0F0` / `#C2CCCC` |
| overlay (modal scrim) | `rgba(6,20,20,0.5)` + blur(3px) |

**Dark**
| Token | Value |
|---|---|
| page bg | `#0E1516` |
| surface | `#161E1D` |
| surface-2 | `#0B1211` |
| sunken | `#121A19` |
| border | `#2A3432` |
| divider | `#222B29` |
| text | `#EAF1EF` |
| text-2 | `#AEBCB9` |
| text-3 | `#7C8A87` |
| header bg | `rgba(14,21,22,0.82)` + blur(8px) |
| card shadow | `0 1px 3px rgba(0,0,0,0.35)` |
| track / track-strong | `#232D2B` / `#3A4644` |
| overlay | `rgba(0,0,0,0.6)` + blur(3px) |

### Colour — accent (user-selectable, **green is default**)
Each accent supplies: `acc` (primary actions, links, active nav), `strong` (hover),
`deep` (dark hero panels + sidebar background), `hi` (pale highlight chip / logo tile /
CTA on dark), `hiOn` (text on `hi`). `onAcc` is always `#FFFFFF`.

| Accent | acc | strong | deep | hi | hiOn |
|---|---|---|---|---|---|
| **Green** (default) | `#1F8A5B` | `#177049` | `#103A2B` | `#D4F5A6` | `#0B3A26` |
| Teal | `#028A93` | `#037780` | `#0B4650` | `#E7FFC8` | `#0B4650` |
| Blue | `#2A6FDB` | `#2159BD` | `#132C4F` | `#CFE3FF` | `#0B2E63` |
| Orange | `#E07B29` | `#C4661A` | `#3C2A18` | `#FFE1BF` | `#5C3208` |
| Red | `#D64A4A` | `#BB3A3A` | `#3B1E1E` | `#FFD9D9` | `#5C1414` |
| Violet | `#7A5AD6` | `#6547BD` | `#241C42` | `#E4DBFF` | `#2E1D63` |

**Derived colours** (compute at runtime from the active accent, so charts and tints
follow the theme — see “Colour math” below):
- `panel2` = mix(deep, white, 9%); `panelMuted` = mix(acc, white, 60%)
- `sidebarMuted` = mix(acc, white, 55%)
- `iconBg` = light: mix(acc, white, 86%) · dark: acc @ 20% alpha
- `iconFg` = light: acc · dark: mix(acc, white, 32%)
- chart line = light: acc · dark: mix(acc, white, 18%)
- confidence band fill = light: mix(acc, white, 74%) · dark: acc @ 24% alpha
- category ramp (6 donut/legend colours) =
  `[acc, mix(acc,white,30%), mix(acc,white,54%), mix(acc,white,74%), mix(acc,black,30%), mix(acc,black,52%)]`

### Colour — status (fixed, both modes)
- success `#33A76A` · warning `#E0A93B` · danger `#E05656`
- soft backgrounds (light): success `#E7F5EC`, warning `#FBF1DC`, danger `#FCE9E9`
- soft backgrounds (dark): the status hue at 18% alpha
- Income amounts render success-green; expense amounts render `text`; transfers render `text-2`.

### Colour math
```
mix(a, b, t) = per-channel round(a + (b-a)*t)   // t in 0..1, hex in/out
alpha(hex, a) = rgba(r,g,b,a)
```
Precompute the whole theme once per (mode, accent) and expose via `ThemeExtension`
so widgets and the chart painters read the same values.

### Shape & elevation
- Radii: chips/controls 8px; small buttons/pills 10–11px; cards 14–16px; hero panels
  18–20px; modal 20px; icon tiles 11px; pill tags full.
- Icon tiles: 8px padding around a 18px icon.
- Shadows are soft and low; primary button gets `0 2px 10px rgba(0,0,0,0.14)`.

### Spacing
4px base. Common: card padding 18–24px; grid/gap 12–16px; section gaps 16px;
page padding 26px 30px.

### Iconography
**Lucide** outline icons, stroke ≈1.9 at 24px, rounded caps, `currentColor`. In Flutter
use `lucide_icons_flutter`. Icons used: layout-dashboard, wallet,
arrow-left-right, target, pie-chart, sparkles, settings, search, plus, trending-up,
alert-triangle, sliders-horizontal, arrow-left, sun, moon, palette, coins, link,
chevron-down, x, landmark, piggy-bank, shield, credit-card, shopping-cart, utensils,
car, zap, shopping-bag, clapperboard, music, briefcase, home, dumbbell, wifi, circle-dot.

---

## Screens

> Layout baseline: sidebar is a fixed **246px** column; main area is a flexible column
> with a sticky header (padding 16×30) and scrolling content (padding 26×30, bottom 60).
> Cards use `surface` bg + `border` + card radius + card shadow. Hero/“panel” cards use
> the accent `deep` bg with white text.

### Sidebar (persistent)
- Logo tile: 34px, `hi` background, app mark, radius 10. Wordmark “Fire·Raccoon” (the ·
  in accent `hi`), sub “personal finance” in `sidebarMuted`.
- Nav: 6 items, each a full-width button (padding 10×12, radius 11, gap 11). Active =
  `acc` bg + white text + 600 weight. Inactive = transparent + `sidebarMuted`. The
  Projection item has a badge “1” (`hi` bg, `hiOn` text). Account-detail keeps Accounts active.
- Bottom: a **Net worth** mini-card (`panel2` bg, Roboto Slab figure, accent-hi delta), then
  a **profile row button** (avatar in `acc`, name + “Firefly III · connected”, gear icon)
  — this row **opens Settings** (gear turns accent when Settings active).
- Sidebar background = accent `deep`; text white.

### Header (sticky, every screen)
- Left: eyebrow (crumb, `text-3`) + H1 title (24px/600, single line, ellipsis).
- A read-only search affordance (surface pill, 220px min).
- Currency segmented control EUR/USD/GBP (active = `acc` bg/white).
- Primary **Add** button (`acc` bg, white, plus icon) → opens the New-transaction modal.

### 1. Dashboard
A “Layout direction” segmented control (Insights / Accounts / Focus) toggles three
distinct compositions over the same data:

**A — Insights** (default)
- Row of 4 KPI cards: Total balance, Income · July, Spending · July, Saved · July.
  Each: label + icon tile (top), Roboto Slab value, delta line (coloured).
- Cash-flow grouped bar chart (income = `acc`, spending = `track-strong`), 6 months,
  height 190, plus legend.
- “Where money goes” donut (category ramp) + top-4 legend with amounts.
- Recent activity list (6 rows: icon tile, desc + meta, signed amount) with “View all” → Transactions.
- Accent-deep “Looking ahead” panel: projected end-of-month figure, delta, a warning
  callout, and a `hi` CTA → Projection.

**B — Accounts**
- 2-col account tiles (icon, name, Roboto Slab native balance, sub) → account detail.
- Accent “Total balance” card with sparkline.
- “Upcoming bills” list (date chip + name + amount).
- Full-width “Budgets at a glance” — 4 mini progress bars.

**C — Focus**
- Large accent-deep hero: net worth (46px Roboto Slab), delta, big sparkline, two inset
  stat tiles (income/spending).
- Right column: “30-day outlook” projection chart + “Today’s timeline” list.

### 2. Accounts
- 4 summary cards: Cash & current, Investments, Liabilities (danger colour), Net worth
  (accent colour).
- Table: columns Account / Type / Trend (30d sparkline) / Balance (Roboto Slab native +
  converted sub). Rows are buttons → account detail. Negative balances in danger colour.

### 3. Account detail
- Back link → Accounts.
- Left accent-deep card: icon tile (`hi`), name/bank, big Roboto Slab balance, converted +
  type, sparkline (in `hi`), two inset In/Out (30d) tiles.
- Right card: transaction list filtered to this account.

### 4. Transactions
- Filter segmented control: All / Income / Expenses / Transfers.
- “New transaction” outline button → modal.
- List grouped by date; each group has a header (date + signed day total) and rows
  (icon tile, desc + category, account, right-aligned signed amount).

### 5. Budgets
- Left accent-deep card with a **budget-used ring** (progress ring: accent-hi under 85%,
  warning 85–100%, danger over 100%) + “€spent of €budget”.
- Right card “This month’s pacing”: per-category row = icon + name + “spent / budget”,
  a progress bar (category colour; warning when >85%; danger when over), and a status
  line (“On pace — €X left” / “Spending fast — …” / “Over by €X”). Pacing compares spend
  vs. `budget * (dayOfMonth / daysInMonth)`.

### 6. Expenses
- “Spending by category”: large donut + full legend with change % (positive = danger/red,
  negative = success/green) and amount.
- “Monthly trend”: 6-month spending bars (latest month in accent, others `track-strong`),
  value labels above.
- “Top merchants”: 4 tiles (icon, name, payment count, amount).

### 7. Projection (the differentiator)
- Warning banner when an account is forecast to go negative (date + suggested action).
- Main chart: historical **solid** line + projected **dashed** line + shaded
  **confidence band** widening over time; a dotted “today” marker; gridlines with value
  labels; end-point dot + value label. Range segmented control **30d / 60d / 90d**.
- **What-if slider** (0–40%, step 5): “cut discretionary spending by N%” raises the
  projected line and shows “+€X by N days”.
- Right column: **Predicted balances** per account (now → predicted, coloured change) for
  the selected range, and **Upcoming recurring** (date chip + name + amount).

### Settings
- **Appearance** card: Theme segmented (Light/Dark, sun/moon icons) + Accent colour
  swatches (6 dots + labels; selected dot gets a ring in surface + accent).
- **Display currency** card: EUR/USD/GBP segmented.
- **Firefly III connection** card: instance URL, masked token, status (“Connected · synced
  …”, success dot).

### New-transaction modal
- Centred over a blurred scrim (z above everything).
- Type segmented (Expense/Income/Transfer), Amount (Roboto Slab, € prefix), Account + Category
  selectors, Description, Date. Cancel + Save. Save posts to Firefly and returns to Transactions.

---

## Interactions & behaviour
- Sidebar nav and in-content links switch the active screen (client-side routing;
  `go_router`). Account rows and table rows open account detail. Back link returns.
- Segmented controls update state immediately and re-render.
- The what-if slider recomputes the projected series and per-account predictions live.
- Motion: calm — short fades / gentle ease-out slides (120–400ms). **No bounce/overshoot.** Respect reduced-motion.
- Hover (desktop/web): active-nav darkens toward `strong`; cards lift slightly.

## Assets & brand
- Fonts in `assets/fonts/` (Comfortaa TTF 300–700; Roboto Slab variable TTF).
- App mark in `assets/fireraccoon_logo.png`.
- Visual system inspired by the **AlmaScience** brand reference.
