# PUBG Site Improvement Ideas & New Page Concepts

> Last updated: 2026-06-26 (after session 9).
> Every suggestion is grounded in what the current code actually has. Estimated difficulty uses
> the same vanilla JS + Canvas + Chart.js stack already in use — no build tools, no npm.

---

## 1. Stats Page (`stats.html`)

### ~~1.1 — Placement Distribution Histogram~~ ✅ Done
### ~~1.2 — Rolling K/D and Win-Rate Trend Line~~ ✅ Done
### ~~1.3 — Performance by Map Table~~ ✅ Done
### ~~1.4 — Duo Synergy Panel~~ ✅ Done
### ~~1.6 — Lifetime Records Card~~ ✅ Done
### ~~1.7 — Win Condition Analysis Panel~~ ✅ Done

---

### 1.5 — Time-of-Day Performance Heatmap

Parse `m.created_at` hour. Build a 24-column bar chart showing avg placement and avg kills by
hour of day (local time). Even "we play badly after 23:00" is actionable.
Pure JS — no new data needed, just `new Date(m.created_at).getHours()`.

---

### 1.8 — Kill Distribution Histogram

How often do we finish with 0 kills? 1? 5+? A frequency chart (bar per kill count) for each
player side-by-side reveals consistency vs boom-or-bust patterns. Computed entirely from
`matches.json` `players[p].kills`.

---

### 1.9 — Damage vs Placement Scatter Plot

For each match: X = D282 damage dealt, Y = placement (inverted so higher = better). Does
dealing more damage actually correlate with better finish? One dot per match, color by player,
trend line overlay. Uses `Chart.js` scatter type. Damage needs match JSON files but is worth the
fetch — or use the `kills` proxy if damage isn't in `matches.json` summary.

---

### 1.10 — "Hot Hand" Form Badge

Compare last-5-game averages to overall averages for each player. Show a colored badge
(🔥 Hot / ❄ Cold / — Neutral) next to each player name in the summary panel.
Threshold: last-5 placement avg is ≥15% better than career avg = Hot.
Zero new data — pure filter on already-loaded `matches.json`.

---

### 1.11 — Damage Dealt per Kill (Efficiency Metric)

`damage_dealt / kills` per game, averaged. Low = clean efficient kills. High = lots of damage
but enemies survive (traded shots poorly). Show as a stat row in the Summary panel alongside
K/D. Needs per-match damage data — check if `matches.json` has it or fallback to match JSONs.

---

### 1.12 — Weapon Category Breakdown (Kills by Type)

Across all filtered matches, what % of kills come from AR / SR / SMG / SG / Pistol / Melee?
Chart.js doughnut in a new "Weapon Mix" panel. Data from `events[type==='kill']` in match JSONs
(uses MATCH_CACHE already loaded by mapanalysis). If loading match JSONs is too heavy, add
weapon category summary to `matches.json` during export.

---

### 1.13 — Session Grouping in Match History

The stats page currently shows all matches in a flat table. Add an optional "Group by day" toggle
that inserts day-header rows with a mini session summary (games played, wins, avg placement).
`getDailySessions()` is already written — just adapt the match history render.

---

### 1.14 — Score Trend vs Moving Average Dual Line

The trend chart currently shows rolling-10 score. Add a second line: simple 20-game moving
average, always visible as a thin dashed line. Shows both short-term swings and long-term
trajectory simultaneously. One extra dataset in the existing Chart.js config.

---

## 2. Match Analysis (`match.html`)

### ~~2.1 — Match Playback Mode (Auto-Play)~~ ✅ Done
(`playToggle`, `startPlayback`, `pausePlayback`, `playTick`, `setPlaybackSpeed` all implemented.)

### ~~2.5 — Weapon Damage Breakdown Panel~~ ✅ Done
### ~~2.6 — Blue Zone Damage Indicator~~ ✅ Done (fallback logic)
### ~~2.7 — Enemy Encounter Table (enriched)~~ ✅ Done

---

### 2.2 — Key Moments Jump List

After loading match data, build a chronological list of significant events: kills, knocks, deaths,
revives, vehicle entries, blue zone entry. Render as a scrollable sidebar panel. Each row: icon +
label + timestamp. Clicking jumps `state.time` to that moment.

```js
function buildKeyMoments(md) {
  const SIG = new Set(['kill','knockdown','knocked','death','revive','vehicle_in']);
  return (md.events||[])
    .filter(ev => SIG.has(ev.type) && ['D282','S821'].includes(ev.player))
    .sort((a,b) => a.t - b.t);
}
```

Estimated: ~60 lines. High impact for match review.

---

### 2.3 — Export Map Snapshot

Camera icon button in map controls. `canvas.toDataURL('image/png')` → auto-download as
`match-YYYYMMDD-t{time}.png`. Optionally draw `mmss(state.time)` watermark before export.
Local `map-images/` are same-origin so `toDataURL` works fine. The CDN fallback would block it —
already handled by preferring local images first.

---

### 2.4 — Zone Position Timeline Chart

New mini-chart panel alongside HP/proximity: "Zone Position" — per player, compute
`dist_to_safe_center / safe_r` at each timestep (0 = center, 1 = edge, >1 = outside/dead).
Red reference line at 1.0. Shows whether they were rotating correctly.

```js
function buildZoneScoreData(player) {
  return (MD.positions[player]||[]).map(p => {
    const c = MD.circles.filter(ci => ci.t <= p.t).slice(-1)[0];
    if (!c?.safe_r) return { x: p.t, y: null };
    const dx = p.x - c.safe_x, dy = p.y - c.safe_y;
    return { x: p.t, y: +(Math.sqrt(dx*dx+dy*dy)/c.safe_r).toFixed(3) };
  });
}
```

---

### 2.8 — "Follow Mode" During Playback

During auto-play, auto-pan the map canvas to keep the selected player's current position
centered. Toggle button next to the play controls: "Follow D282 / Follow S821 / Off".
When active, after each `jumpTime()` call: compute player's `cx/cy` via `getPositionAt()`,
then set `view.offsetX = CSZ/2 - px * view.scale` (same formula as a manual pan-to-point).
Zero new data. Makes the playback feel like a live spectator cam.

---

### 2.9 — Loot Acquisition Timeline (Inventory Layer)

`MD.inventory` is already loaded (added session 7). Add a "Loot" layer toggle that renders
item pick-up events as small icons on the map at the time they happened. Group by 10s buckets
to avoid icon clutter. In the sidebar, show a per-phase item category breakdown:
"Early: 2× FAK, 1× vest. Mid: 3× 7.62. Late: 1× adrenaline."

---

### 2.10 — Throwable Throw-Location Markers

`LogPlayerUseThrowable` events are already tracked in `MD.events` with `type:'throwable'`.
Add a new Throwables layer (currently they appear in the timeline but not on the map).
Draw grenade icon at throw location. Sub-type by throwable type (frag = red, smoke = grey,
stun = yellow, molotov = orange). Hover: weapon name, timestamp.

---

### 2.11 — Damage Phase Breakdown Bar

In the Match Summary sidebar panel: a horizontal stacked bar showing total damage dealt in
Early / Mid / Late phases. Same split as the mapanalysis phase filter.
`dmgDealt` events have `t` — filter by PHASE_RANGES thresholds. One bar per player.
Shows: "D282 dealt 400 early, 120 mid, 0 late" — reveals at-a-glance when most combat happened.

---

### 2.12 — Match Notes (localStorage)

A small textarea in the sidebar (below Match Summary) that saves free-text notes per match
to `localStorage`. Key: `match_note_{match_id}`. Pre-fill with empty string. Auto-save on blur.
Shows a "📝" icon in the match history table for matches that have notes.
Zero backend — purely client-side. Useful for "remember this match, crazy final circle".

---

### 2.13 — Enemy Approach Direction Indicator

For each `dmg_taken` event cluster (the engagements): compute the compass direction of the
enemy relative to the player at time of damage. Render as a small directional arc overlay on
the map near the engagement dot: "took damage mostly from the east". Uses `dmgTaken`
`{x,y}` vs player position at same `t`. Approximate — but useful for "we always get flanked from behind".

---

### 2.14 — Pinch-to-Zoom Touch Support

`mapanalysis.html` already has a full pinch-zoom + touch-pan implementation (touchstart,
touchmove, touchend, pinchDist, pinchMidRaw, applyZoom). The canvas/view model in `match.html`
is identical. Direct port: copy the touch handler block (~60 lines) and the `lastPinchDist` /
`lastPinchMidRaw` vars. Estimated: 30 minutes. Fixes mobile completely.

---

## 3. Map Analysis (`mapanalysis.html`)

### ~~3.3 — Landing Zone Outcome Coloring~~ ✅ Done
### ~~3.6 — Late Game Positions Layer~~ ✅ Done
### ~~Session 9: Grid Overlay (⊞ button, A1–H8 labels)~~ ✅ Done
### ~~Session 9: Landing Zone Pie Charts (shared group-distance slider)~~ ✅ Done
### ~~Session 9: Duo Drop Midpoint (one marker per match)~~ ✅ Done
### ~~Session 9: Engagement Hover Score Table + Weapon Breakdown~~ ✅ Done
### ~~Session 9: Dmg Dealt / Taken in Engagement Hover + Color Coding~~ ✅ Done
### ~~Removed: Position Heatmap + Loot Heatmap layers~~ ✅ Done

---

### 3.1 — Wins-Only Filter Toggle ⭐ Very Low Effort

Add a "Wins Only" toggle button in the filter row. `state.winsOnly = false` default.
In `filteredMatches()`, add `&& (!state.winsOnly || m.players['D282']?.placement===1)`.
Triggers full `loadAndRender()` on toggle. Heatmaps, drops, deaths, kills, engagements —
everything instantly shows only winning-game patterns. 3 lines of state + 1 button.

---

### 3.2 — Final Circle Centers Scatter

New layer: "Final Circles" (magenta). In `aggregateLayers()`, extract phase-8 (or last available)
circle center from each match's `circlePhases`. Store as `LAYER.finalCircles`. Draw as small `×`
markers. Shows where final circles tend to land — valuable for "should we rotate center or edge?"
Also add to sidebar: which map quadrant (3×3 grid) the final circle lands in most often.

---

### 3.4 — Combat Zone Choropleth (Win/Loss Areas)

New layer: "Combat Zones". Divide map into 16×16 grid. For each cell, compute avg engagement
score across all clusters in that cell. Color cells green (avg > 100) → transparent (sparse) →
red (avg < -100). Only draw cells with ≥3 engagements. Semi-transparent overlay (alpha 0.42).
Reveals: "we always lose fights in the south-east quadrant". Uses existing `LAYER.engClusters`.

```js
function drawCombatZones() {
  const CELL = CSZ / 16;
  const cells = {};
  for (const cl of LAYER.engClusters.filter(c => inPhase(c.t))) {
    const k = `${Math.floor(cl.cx/CELL)},${Math.floor(cl.cy/CELL)}`;
    if (!cells[k]) cells[k] = { sum:0, n:0 };
    cells[k].sum += cl.score; cells[k].n++;
  }
  ctx.save(); ctx.globalAlpha = 0.42;
  for (const [k,v] of Object.entries(cells)) {
    if (v.n < 3) continue;
    const [gx,gy] = k.split(',').map(Number);
    const t = Math.max(-1, Math.min(1, v.sum/v.n/200));
    ctx.fillStyle = t>0 ? `rgba(26,170,68,${t})` : `rgba(204,17,17,${-t})`;
    ctx.fillRect(gx*CELL, gy*CELL, CELL, CELL);
  }
  ctx.restore();
}
```

---

### 3.5 — Rotation Arrows Layer

Process `LAYER.paths`: for each path segment > 50px, compute compass direction. Bin into 8
directions per 3×3 grid cell. Draw an arrow in each cell pointing dominant direction, length
scales with frequency. Color by player (amber D282, blue S821). New layer toggle: "Rotation Arrows".
No new data fetch — uses existing path data.

---

### 3.8 — "Danger Zones" Death Density Layer

New layer: "Danger Zones". For each death in `LAYER.events.deaths`, accumulate a 2D density
grid (same 16×16 as combat zones). Draw cells with ≥2 deaths as semi-transparent red circles
or squares. Reveals: the map areas where you most often die — avoid or prepare better.
Filtered by player and phase like all other layers.

---

### 3.9 — Vehicle Usage Layer

New layer: "Vehicle Routes". Draw path segments that are tagged `tr:'vehicle'` in a distinct
colour (teal). Add entry/exit dot markers. Shows: where the duo drives and how far.
Data already exists in `pathData[player]` — positions tagged with `tr` field. Just filter by
`p.tr === 'vehicle'` when drawing paths and colour them differently.

---

### 3.10 — Drop Zone Win Rate % on Grouped Pies

When the group slider is active and pies are drawn, add a text label inside larger pies (radius
> 16px screen) showing win rate: `Math.round(outcomes.win/n*100)+'%'`. Renders above the count
label. Tiny addition to `drawDropPies()` — makes grouped pies instantly tell you the win rate
at a glance without hovering.

---

### 3.11 — Map Quadrant Survival Grid

Overlay a 3×3 or 4×4 grid where each cell is colored by avg placement of all deaths occurring
in that cell. Darker red = die early and often here. Different from combat zones (which track
engagement outcome) — this tracks *where you end up dying*, regardless of fight quality.
New layer toggle. Uses `LAYER.events.deaths` positions.

---

### 3.12 — Export Current Map View as PNG

Camera button in canvas toolbar. `canvas.toDataURL('image/png')` → auto-download as
`mapanalysis-{map}-{date}.png`. Map images are local same-origin → `toDataURL` works.
Exact same approach as suggestion 2.3 for match.html.

---

### 3.13 — Wins-Only Mode on Landing Zone Pies

When "Wins Only" filter (3.1) is active and landing zones are grouped, show the pie slices
where `outcomes.win > 0` much more prominently — or recolor the whole pie green if win rate
is above 50%. Small visual reinforcement of the filter's purpose.

---

### 3.14 — Blue Zone Deaths Layer

New layer: "Blue Zone Deaths". Many deaths happen outside the safe zone. Filter
`LAYER.events.deaths` by matching events where corresponding `dmgTaken` right before death
is tagged as blue zone. Draw as a distinct "B" icon. Helps identify: "we're dying to blue, not
to players — rotate faster". Data quality depends on how blue zone damage is tagged in export.

---

## 4. Loadout Planner (`pubg.html`)

### ~~4.1 — Saved Presets~~ ✅ Done
### ~~4.2 — Shareable URL~~ ✅ Done
### ~~4.3 — Capacity Breakdown Donut~~ ✅ Done
### ~~4.4 — Ammo Smart Suggestions~~ ✅ Done
### ~~4.6 — Item Search / Filter~~ ✅ Done

---

### 4.5 — Map-Specific Starter Presets

4 buttons (Erangel / Miramar / Sanhok / Karakin) that load community-consensus starter
loadouts. Different maps → different healing/ammo ratios. Karakin needs more grenades,
Sanhok needs faster tempo (less ammo, more heals). Clicking loads as current loadout without
overwriting saved presets.

---

### 4.7 — Loadout Comparison Mode

Split the capacity panel into two columns: "Current" vs "Compare". Load any saved preset into
the Compare slot. Shows side-by-side capacity bars and difference indicators (delta values in
green/red). Useful for "is this preset actually better than what I usually run?"

---

### 4.8 — Throwable Fuse / Effect Timer Panel

Small reference panel below the items list: for each throwable type, show fuse time, effect
duration, and throw range. Static lookup table — no data needed. Frag: 3s fuse, 5m lethal.
Smoke: 1s fuse, 14s duration. Molotov: immediate, 10s burn. Useful while planning.

---

### 4.9 — "Match Your Partner" Suggestion

Enter a partner loadout (or load their saved preset), and the planner highlights which item
categories the partner is already covering. "Partner has medkits covered → you should take
more smokes." Color-code complementary vs redundant items. Requires two simultaneous loadouts
in state — a logical extension of the comparison mode in 4.7.

---

## 5. Records Page (`records.html`)

### ~~5.4 — Personal Records Trophy Room~~ ✅ Done

---

### 5a — Additional Record Categories to Add

The current `computeRecords()` function is easy to extend. Suggested additions:

- **Most damage dealt in a game** — needs `damage_dealt` in match events or per-player summary
- **Fastest win** — minimum survival time across winning matches (`duration_s` field on match JSON)
- **Longest survival without winning** — maximum `t` of death event across non-winning matches
- **Most revives given** — count `type:'revive'` events where `player` is D282 or S821
- **Most throwables used** — count `type:'throwable'` per match, find the max
- **Highest performance score in one game** — `computeExactScore()` already exists, just find the max
- **Most kills duo total** — combined D282+S821 kills in one match
- **Solo clutch** — win where partner died before final circle (death event exists + placement=1)
- **Comeback win** — win where both players were knocked at some point during the match

---

## 6. New Pages

### 5.1 — Circle Predictor (`circles.html`) ⭐⭐⭐ Highest Value

Show historical final circle positions per map as a density scatter. Phase selector (1–8).
Average circle drawn as dashed ring. Reveals terrain biases. Data already in MATCH_CACHE.
~400 lines, reuses map image + heatmap canvas from mapanalysis.

---

### 5.2 — Weapon Kill Log (`weapons.html`) ⭐⭐⭐ High Value

Searchable table of every kill across all matches: weapon, target, distance (approx), HS.
Summary: weapons ranked by kill count, K/D, headshot %. Filter by player, date, map, category.
Answers: "What is actually our best weapon?" beyond gut feel.

---

### 5.3 — Duo Chemistry Dashboard (`duo.html`) ⭐⭐ Medium Value

Proximity vs placement scatter (does playing close together correlate with winning?), who
carries more per session, revive exchange stats, how often one is knocked while other is alive.
Requires loading match JSONs for position data (same as mapanalysis).

---

### 5.5 — Session Goal Tracker (`goal.html`)

Before queuing: set a goal (win 1 game / K/D ≥ 2 / top-5 every game). Track progress across
matches added since goal was set. `localStorage` for persistence. Progress rings (CSS
`conic-gradient`). Zero new data — uses `matches.json` only.

---

### 5.6 — Landing Zone Analyzer (`landings.html`) ⭐⭐ Medium Value

Every drop location clustered by proximity, scored by historical win rate and avg placement.
Map canvas with circles scaled by visit count, colored by outcome. Sidebar: ranked zone list
(min 3 visits). Answers definitively: "Where should we land?" Builds on the duo drop midpoint
already implemented in mapanalysis.

---

### 5.7 — Rivals / Nemesis Tracker (`rivals.html`)

Track recurring enemy names from kill/death events. Table: enemy name → encounters, killed
by us, killed us, dates. "Rivals" badge for mutually traded kills. Data quality dependent on
whether killer name is in death events — verify before building.

---

### 5.8 — Match Comparison (`compare.html`) ⭐ New

Two match selectors → render both matches' paths on the same map canvas with opacity 0.5 each.
Toggle between "overlay" and "split" (canvas divided down the middle). Useful for "what did we
do differently in our win vs the loss the same day?"

---

### 5.9 — Zone Control (`zones.html`) ⭐ New

Pure quadrant analysis. 4×4 grid on each map. Per cell: visit count, death count, kill count,
avg time spent, win rate of matches where we visited this cell. Color by metric (selectable).
Table view + map canvas view toggle. Answers: "Which zones lead to wins when we go there?"

---

### 5.10 — Career Timeline (`career.html`) ⭐ New

Full chronological strip: one row per match, scrollable from session 1 to now.
Columns: date, map icon, placement badge, kills, score sparkline.
Grouped by day with session separator lines. Clicking a row opens `match.html` for that match.
No new data — entirely from `matches.json`. Replaces the flat table in stats.html for this use case.

---

## 7. Cross-Cutting Technical

### 6.1 — Shared Component Library
Nav menu, date slider, filter-row styles are copy-pasted across 5 files. Extract `shared.js` +
`shared.css`. Low priority — risk of breaking changes across pages.

### 6.2 — Service Worker / Offline Cache
Cache all map images (never change) + `matches.json` (5 min TTL) + match JSONs (forever).
Makes repeat visits to Map Analysis instant. Add `manifest.json` for mobile "Add to Home Screen".

### 6.3 — Mobile Touch for `match.html` ⭐ Very Low Effort
Copy pinch-zoom touch handler (~60 lines) from `mapanalysis.html` directly into `match.html`.
Canvas/view model is identical. 30 minutes of work, fixes mobile completely.

### 6.4 — Consistent Error States
`match.html` shows "Loading…" forever on fetch failure. Add visible "X matches failed" badge
in mapanalysis count display. Show retry button on match.html load failure.

### 6.5 — `last_updated` Timestamp in `matches.json`
Write timestamp in export.py. Display on stats.html: "Last updated: June 25 at 14:32".
Helps diagnose whether the pipeline has been run recently.

---

## 8. Priority Matrix

### Completed

| # | Item |
|---|------|
| 1.1–1.4, 1.6–1.7 | Stats panels |
| 2.1 | Match playback |
| 2.5–2.7 | Weapon damage, blue zone, enemy table |
| 3.3, 3.6 | Landing zone colors, late game layer |
| 3.x (session 9) | Grid overlay, duo drop midpoints, landing zone pies, engagement hover table |
| 4.1–4.4, 4.6 | Loadout presets, URL, donut, ammo suggest, search |
| 5.4 | Records page |

### Next Sprint (High Impact / Low Effort)

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 3.1 | Wins-only filter | ★★★★★ | ≈30 min |
| 2.14 | Touch pinch-zoom (match.html) | ★★★★☆ | ≈30 min |
| 3.10 | Win % label on drop pies | ★★★☆☆ | ≈15 min |
| 2.2 | Key moments jump list | ★★★★☆ | ≈1 hr |
| 3.2 | Final circle scatter layer | ★★★★☆ | ≈1 hr |
| 3.4 | Combat zone choropleth | ★★★★☆ | ≈1 hr |
| 2.8 | Follow mode during playback | ★★★★☆ | ≈45 min |
| 2.12 | Match notes (localStorage) | ★★★☆☆ | ≈45 min |
| 3.12 | Export map PNG | ★★★☆☆ | ≈20 min |
| 5a | Additional records categories | ★★★☆☆ | ≈1 hr |
| 1.8 | Kill distribution histogram | ★★★☆☆ | ≈45 min |

### Medium Effort / High Value

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 5.1 | Circle Predictor page | ★★★★★ | ~half day |
| 5.2 | Weapon Kill Log page | ★★★★★ | ~half day |
| 5.10 | Career Timeline page | ★★★★☆ | ~2–3 hrs |
| 2.4 | Zone position timeline chart | ★★★☆☆ | ~2 hrs |
| 3.8 | Danger zones death layer | ★★★★☆ | ~1 hr |
| 3.9 | Vehicle routes layer | ★★★☆☆ | ~1 hr |
| 1.5 | Time-of-day heatmap | ★★★☆☆ | ~1 hr |
| 2.9 | Loot acquisition overlay | ★★★☆☆ | ~1.5 hrs |
| 5.8 | Match comparison page | ★★★★☆ | ~half day |
| 5.9 | Zone control page | ★★★★☆ | ~half day |

### Later / Lower Priority

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 5.3 | Duo Chemistry Dashboard | ★★★★☆ | Medium |
| 5.6 | Landing Zone Analyzer page | ★★★★☆ | Medium |
| 4.7 | Loadout comparison mode | ★★★☆☆ | Medium |
| 1.9 | Damage vs placement scatter | ★★★☆☆ | Medium |
| 3.5 | Rotation arrows | ★★★☆☆ | Medium |
| 2.3 | Export match snapshot | ★★★☆☆ | Low |
| 2.10 | Throwable throw-location layer | ★★☆☆☆ | Low |
| 5.5 | Session Goal Tracker | ★★★☆☆ | Medium |
| 6.2 | Service worker / offline cache | ★★★☆☆ | Medium |
| 3.14 | Blue zone deaths layer | ★★☆☆☆ | Low |
| 5.7 | Rivals tracker | ★★☆☆☆ | Medium (verify data first) |
| 6.1 | Shared component library | ★★☆☆☆ | Medium (risk of breakage) |
| 3.7 | Per-match mini replay in mapanalysis | ★★☆☆☆ | Very High (skip) |

---

*Stack: static GitHub Pages, vanilla HTML/CSS/JS, Chart.js 4.4.1 CDN, Canvas 2D for maps.*
