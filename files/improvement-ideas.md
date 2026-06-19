# PUBG Site Improvement Ideas & New Page Concepts

> Written June 2026. Based on: full code review of all five pages, knowledge of what the
> telemetry data contains, and research into what PUBG players actually care about
> (PUBGLookup, OP.GG, community trackers, pro-team meta guides).
> 
> Every suggestion includes an exact implementation plan. Estimated difficulty uses the
> same vanilla JS + Canvas + Chart.js stack already in use — no build tools, no npm.

---

## Bugs Fixed In This Commit

These were silent errors found during the review — already patched and pushed.

| File | Bug | Fix |
|------|-----|-----|
| `index.html` | Map Analysis page was absent from nav menu AND no card on landing page | Added nav link + card with description |
| `pubg.html` | Map Analysis absent from nav menu | Added nav link |

---

## 1. Stats Page (`stats.html`)

### ~~1.1 — Placement Distribution Histogram~~ ✅ IMPLEMENTED

Side-by-side bar chart showing placement buckets (Win, #2-5, #6-10, #11-20, #21-50, #51+) for both players. Updates on every filter change.

---

### ~~1.2 — Rolling K/D and Win-Rate Trend Line~~ ✅ IMPLEMENTED

Rolling 10-game K/D line chart for both players, chronological order. Updates on every filter change.

---

### ~~1.3 — Performance by Map Table~~ ✅ IMPLEMENTED

Table showing per-map: Games, Win%, Avg Kills, Avg Placement for each player. Sorted by games desc. Win% colored green/red vs overall average.

---

### ~~1.4 — Duo Synergy Panel~~ ✅ IMPLEMENTED

"Duo Chemistry" panel with: kill distribution (both/only D282/only S821/neither), top-10 survival split, and avg kill delta.

---

### 1.5 — Time-of-Day Performance Heatmap

**Why it matters:** PUBG performance degrades late at night. Even just seeing "we always play poorly after 23:00" is actionable.

**Exact plan:**
- Parse `m.created_at` hour (`new Date(m.created_at).getHours()`).
- Build a 24-column bar chart or a 7×24 calendar heatmap (days × hours).
- Color-code by avg placement (green = good). Use `.setHours()` with local time.
- If date range is short and hours sparse, fall back to just a bar chart by hour-of-day.
- The implementation is pure JS, no new data needed.

---

### ~~1.6 — Session "PB Badges" — Personal Bests~~ ✅ IMPLEMENTED (as Lifetime Records Card)

"Lifetime Records" panel showing: most kills in one game (D282), most kills in one game (S821), highest win streak, most games in one day. Each with player, value, and date.

---

### ~~1.7 — Win Condition Analysis~~ ✅ IMPLEMENTED

"Win Condition Analysis" panel comparing: avg combined kills, avg combined damage, avg survival time for wins vs losses. Higher value highlighted in amber.

---

## 2. Match Analysis (`match.html`)

### 2.1 — Match Playback Mode (Auto-Play)

**Why it matters:** The #1 feature request in PUBG replay tools. Watching a match "live" is much more intuitive than scrubbing manually. Equivalent to a mini-killcam replay.

**Exact plan:**
- Add a play/pause button (▶ / ⏸) and speed selector (0.5×, 1×, 2×, 5×, 10×) next to the time slider.
- Use `setInterval` (cleared on pause) calling `jumpTime(speedMultiplier * 0.5)` every 500ms.
  - Speed 1× = real time (steps 0.5s every 500ms)
  - Speed 10× = 5s every 500ms = finishes 30-min match in 3 min
- Auto-pause at match end or when user drags the slider.
- Loop option: restart from t=0.
- Implementation: ~40 lines of JS. Two new `<button>` elements in `.tl-hdr`.

```js
let playInterval = null;
function togglePlay() {
  if (playInterval) { clearInterval(playInterval); playInterval = null; updatePlayBtn(); return; }
  const speed = +document.getElementById('playSpeed').value || 1;
  playInterval = setInterval(() => {
    if (state.time >= (MD.duration_s||1800)) { togglePlay(); return; }
    jumpTime(speed * 0.5);
  }, 500);
  updatePlayBtn();
}
```

---

### 2.2 — Key Moments Jump List

**Why it matters:** Matches are 20–30 minutes. Nobody wants to scrub through the entire thing to find when they got knocked. Auto-generate a "highlight reel" of significant events.

**Exact plan:**
- After loading match data, compute `keyMoments`:
  - All kills (label: "D282 killed [target]")
  - All deaths/knocks
  - Any revive
  - Blue zone damage spikes (> 30 damage in one tick, if tracked)
  - Airdrop lands (`crate_land` events)
- Render as a vertical scrollable list in the sidebar, below the Engagements panel.
- Each row: icon + label + timestamp. Clicking sets `state.time` and scrolls map to event.
- Sort chronologically. Group nearby events (within 5s) into "combat burst" labels.

```js
function buildKeyMoments(md) {
  const SIGNIFICANT = new Set(['kill','knockdown','knocked','death','revive','blue_chip_revive','crate_land']);
  return md.events
    .filter(ev => SIGNIFICANT.has(ev.type) && ['D282','S821'].includes(ev.player))
    .sort((a,b) => a.t - b.t)
    .map(ev => ({ t: ev.t, label: fmtEvent(ev), type: ev.type, player: ev.player }));
}
```

---

### 2.3 — Export Map Snapshot

**Why it matters:** Players love sharing "look at this insane play" screenshots. One click to get the current map view as a PNG.

**Exact plan:**
- Add a camera icon button to `.map-controls`.
- On click: `canvas.toDataURL('image/png')` → create `<a download="match-snapshot.png" href=...>` → `.click()` → remove.
- Optionally overlay timestamp watermark using `ctx.fillText(mmss(state.time), ...)` before export.
- **Caution:** canvas must be same-origin for `toDataURL` to work. The map image from `image_url` (local `map-images/`) is same-origin on GitHub Pages — this works. The `cdn_url` fallback from `raw.githubusercontent.com` would be cross-origin and block `toDataURL`. Ensure local images are used first (they already are).

---

### 2.4 — Circle Position Score Timeline

**Why it matters:** "Were we inside the circle?" is the most important survival question. Players know they take blue damage but don't easily see *how inside* or *outside* they were over time.

**Exact plan:**
- Compute per-timestep: for each player, `dist_to_center / safe_r` (0 = at center, 1 = on edge, >1 = outside).
- Add a new mini-chart panel below the HP chart: "Zone Position" — two lines (D282, S821), red zone above 1.0.
- Use the existing Chart.js chart rendering pattern already used for HP/proximity charts.
- Data computed entirely from `MD.positions` + `MD.circles` already loaded.

```js
function buildZoneScoreData(player) {
  return (MD.positions[player]||[]).map(p => {
    const c = MD.circles.filter(ci => ci.t <= p.t).slice(-1)[0];
    if (!c || !c.safe_r) return { x: p.t, y: null };
    const dx = p.x - c.safe_x, dy = p.y - c.safe_y;
    const dist = Math.sqrt(dx*dx + dy*dy);
    return { x: p.t, y: +(dist / c.safe_r).toFixed(3) };
  });
}
```

---

### ~~2.5 — Damage Dealt Breakdown by Weapon~~ ✅ IMPLEMENTED

"Weapon Damage" sidebar panel showing top-5 weapons per player as horizontal bars with damage totals. Added in sidebar after engagements panel.

---

### 2.6 — Blue Zone Damage Indicator on Timeline

**Status:** Implemented with fallback logic. Checks for `dmg_taken` events with attacker containing 'blue'/'zone'. If none found, uses `positions[player].blue` flag bands. If neither source yields data, nothing is drawn (data quality varies per match).

---

### ~~2.7 — Enemy Encounter Table (enriched)~~ ✅ IMPLEMENTED

Extended `buildEngagementSummary()` to track `killed` boolean per enemy. Each enemy row now shows "✓ Killed" (green) or "escaped" (muted) status.

---

## 3. Map Analysis (`mapanalysis.html`)

### 3.1 — Wins-Only Filter Toggle

**Why it matters:** The most important question in self-coaching: "What do we do differently when we win?" A single toggle that restricts all layers to winning games only reveals drop patterns, rotation habits, and engagement locations that correlate with victory.

**Exact plan:**
- Add a "Wins Only" toggle button to the filter row (styled same as the player/phase buttons).
- `state.winsOnly = false` by default.
- In `filteredMatches()`, add: `&& (!state.winsOnly || m.players['D282']?.placement===1)`.
- Triggers full `loadAndRender()` on toggle (same as date change).
- Heatmaps, drops, deaths, kills, engagements — everything instantly reflects winning patterns.
- 3 lines of state + filter change + one button in HTML.

---

### 3.2 — Final Circle Center Scatter / Heatmap

**Why it matters:** Experienced PUBG players know that circles are NOT random — they have terrain and map-center biases. Seeing where your circles have actually ended lets you develop better "circle read" intuition backed by personal data.

**Exact plan:**
- New layer toggle: "Final Circle Centers" (color: `#ff88ff`).
- In `aggregateLayers()`, extract the phase-8 (or last available phase) circle center from each match's `circlePhases`.
- Store as `LAYER.finalCircles = [{cx, cy, matchId, date}, ...]`.
- Draw as small magenta `×` markers with a subtle glow on the canvas.
- Also offer a density heatmap version (use `buildHeatmapCanvas()` with these points).
- In the sidebar stats, show the most common map quadrant (divide map into 3×3 grid, count which cell appears most often as final circle).

```js
// In aggregateLayers():
LAYER.finalCircles = matches.flatMap(m => {
  const c = MATCH_CACHE.get(m.match_id);
  if (!c?.circlePhases?.length) return [];
  const last = c.circlePhases[c.circlePhases.length - 1];
  return [{ cx: last.cx, cy: last.cy, matchId: m.match_id, date: c.date }];
});
```

---

### ~~3.3 — Landing Zone Outcome Scoring~~ ✅ IMPLEMENTED

Drop dots now colored by match placement: gold=#1, green=top5, blue=top10, orange=top20, red=worse. Hover shows placement. At zoom>2, placement number drawn next to dot.

---

### 3.4 — Engagement Outcome Choropleth

**Why it matters:** A heatmap of "where do we win fights vs lose fights" is more useful than individual dots. This is the kind of insight pro coaches use — "we always lose fights in the south-east quadrant, let's avoid it".

**Exact plan:**
- New layer toggle: "Combat Zones" (distinct from Engagements layer).
- Divide the map into a 16×16 grid (45px cells at CSZ=720).
- For each cell, compute: avg engagement score of all clusters whose `cx/cy` falls in that cell.
- Color each cell from dark-red (avg < -100) → transparent (few engagements) → dark-green (avg > 100).
- Render as a semi-transparent overlay (`ctx.globalAlpha = 0.45`).
- Only show cells with ≥ 3 engagements (suppress noise).
- This layer uses the already-computed `LAYER.engClusters`.

```js
function drawCombatZones() {
  const GRID = 16, CELL = CSZ / GRID;
  const cells = {};
  for (const cl of LAYER.engClusters.filter(c => inPhase(c.t))) {
    const gx = Math.floor(cl.cx / CELL), gy = Math.floor(cl.cy / CELL);
    const k = `${gx},${gy}`;
    if (!cells[k]) cells[k] = { sum:0, n:0 };
    cells[k].sum += cl.score; cells[k].n++;
  }
  ctx.globalAlpha = 0.42;
  for (const [k, v] of Object.entries(cells)) {
    if (v.n < 3) continue;
    const [gx, gy] = k.split(',').map(Number);
    const avg = v.sum / v.n;
    const t = Math.max(-1, Math.min(1, avg / 200));
    const col = t > 0 ? `rgba(26,170,68,${t})` : `rgba(204,17,17,${-t})`;
    ctx.fillStyle = col;
    ctx.fillRect(gx * CELL, gy * CELL, CELL, CELL);
  }
  ctx.globalAlpha = 1;
}
```

---

### 3.5 — Route Direction Arrows (Rotation Tendency)

**Why it matters:** Rotation patterns are one of the highest-value strategic insights. "We always rotate west" becomes visible as a cluster of arrows, revealing whether the duo has predictable (exploitable) or varied rotation habits.

**Exact plan:**
- Process path data: for each path segment between consecutive positions that are > 50px apart, compute the direction vector.
- Bin into 8 directions (N/NE/E/SE/S/SW/W/NW) per 3×3 map grid cell.
- Draw an arrow in each cell pointing in the dominant direction. Arrow length scales with frequency. Color by player (amber D282, blue S821).
- New layer toggle: "Rotation Arrows".
- Implementation uses existing `LAYER.paths` data — no new fetch.

---

### ~~3.6 — Map Sector Survivability Grid (Late Game Positions Layer)~~ ✅ IMPLEMENTED

New "Late Game Positions" layer (purple, default off) showing a heatmap of positions at t>1200s. Added to LAYER_DEFS, aggregated in aggregateLayers(), drawn with screen blend mode.

---

### 3.7 — Per-Match Replay Scrubber (Mini Mode)

**Why it matters:** Sometimes you want to understand one specific match's movement directly in the map analysis view, without switching to match.html. A single-match overlay mode with a time slider would let you review a specific game while keeping the aggregate context.

**Exact plan:**
- Add a "Single Match" toggle in the filter row. When active, a match selector dropdown appears (showing matches for the current map/date range).
- Selecting a match loads just that match's full JSON (from MATCH_CACHE or fetch).
- Display a time slider (same as match.html) below the map.
- Render: movement paths up to slider time, player position dots, circle at current time.
- Layers still controllable via the sidebar.
- Essentially embeds a simplified version of match.html's canvas logic into mapanalysis.html.

---

## 4. Loadout Planner (`pubg.html`)

### ~~4.1 — Saved Presets (localStorage)~~ ✅ IMPLEMENTED

"Presets" panel above Capacity with Select/Load/Save/Delete. Saves `{backpack, vest, counts}` to localStorage under `pubg_preset_*` keys.

---

### ~~4.2 — Shareable URL~~ ✅ IMPLEMENTED

"Copy Link" button in Capacity panel. `encodeLoadout()` / `decodeLoadout()` using item indices. On page load, decodes URL params if present.

---

### ~~4.3 — Capacity Breakdown Donut Chart~~ ✅ IMPLEMENTED

Chart.js doughnut chart in Capacity panel showing used capacity by category. Center text shows used/total. Color-coded legend below chart. Updates on every render().

---

### ~~4.4 — Ammo Smart Suggestion~~ ✅ IMPLEMENTED

Static `AMMO_SUGGEST` table for 6 ammo types. Shows "Suggest: N — fill" hint below each ammo item when current count < suggestion.

---

### 4.5 — Map-Specific Starter Presets

**Why it matters:** Loadout meta varies significantly by map. Karakin (tiny map) = more grenades, less ammo. Erangel = healing heavy. Having official starter presets teaches new players and saves regulars time.

**Exact plan:**
- Add 4 preset buttons at the top: "Erangel", "Miramar", "Sanhok", "Karakin".
- Each encodes a reasonable community-consensus loadout (based on actual meta guides):
  - **Erangel** (8×8, slow): 4× FAK, 6× boost, 120× 5.56, 90× 7.62, 3× smoke, 2× frag, 2× stun
  - **Miramar** (8×8, open): similar but +1 long-range ammo, fewer smokes
  - **Sanhok** (4×4, fast): 6× bandage, 3× FAK, 4× boost, 90× 5.56, 3× smoke, 3× frag
  - **Karakin** (2×2, tiny): 6× FAK, 8× boost, 60× 5.56, 60× 7.62, 4× smoke, 3× C4, 4× frag
- Clicking loads the preset into state (same logic as §4.1 but hardcoded). Doesn't overwrite saved presets.

---

### ~~4.6 — Item Search / Filter~~ ✅ IMPLEMENTED

Search input above category tabs. Filters across all categories by name match. Clear button (×) restores category view. Tab row hidden during search.

---

## 5. New Page Ideas

### 5.1 — Circle Predictor (`circles.html`) ⭐ Highest Value

**Concept:** "Where will the circle end up?" — Show a heat map of historical final circle positions for each map, built from actual match data. This answers the question pro players obsess over: "should I hold center or play edge?"

**Unique value:** No other personal tracker does this with YOUR own match history. OP.GG and PUBGLookup show community-wide data; this shows what happened in your specific 50+ games.

**Implementation plan:**
- Data already exists: every match in `MATCH_CACHE` has `circlePhases` with 8 circles per match.
- Load all match JSONs (same as mapanalysis.html does, using MATCH_CACHE).
- For each phase 1–8, extract the circle center `{cx, cy}` and radius `r`.
- Render 8 tabbed views (phase selector).
- Each view shows:
  1. **Historical scatter** — small dots for each match's circle center at that phase.
  2. **Density heatmap** — using the same `buildHeatmapCanvas()` function already written.
  3. **Average circle** — dashed circle showing the mean center ± 1 standard deviation.
- Filter by date (reuse the date slider component).
- Stats sidebar: most common map quadrant, average radius, how often circle starts central vs edge.

```js
// Core data extraction — runs once per map selection
function extractPhaseCircles(matches, phaseIdx) {
  // phaseIdx: 0-7
  return matches.flatMap(m => {
    const c = MATCH_CACHE.get(m.match_id);
    if (!c?.circlePhases?.[phaseIdx]) return [];
    return [{ cx: c.circlePhases[phaseIdx].cx, cy: c.circlePhases[phaseIdx].cy }];
  });
}
```

**Pages needed:** 1 new HTML file, ~400 lines. Reuses map image, heatmap canvas, date slider from mapanalysis.html (copy or extract shared components).

---

### 5.2 — Weapon Kill Log (`weapons.html`) ⭐ High Value

**Concept:** A searchable, filterable table of every kill across all matches, with weapon and context. Answers: "What's our best weapon?", "Do we headshot more with snipers?", "What weapons are enemies using when they kill us?"

**Unique value:** This is personal kill-feed data, not aggregate community stats. The weapon breakdown is already in telemetry `events` with `type:'kill'` and `weapon` field.

**Implementation plan:**
- Load all match JSONs (parallel fetch with MATCH_CACHE, same as mapanalysis.html).
- Extract all `{type:'kill', player, weapon, target, t, x, y, matchId, date}` events.
- Build a weapon stats table:

| Weapon | Kills | Deaths | K/D | Headshot% | Avg distance | Matches used |
|--------|-------|--------|-----|-----------|--------------|--------------|

- Filters: player (D282/S821/both), date range, map, weapon category (AR/SR/SMG/SG/Pistol).
- Secondary panel: "Killed by" — same table but from `type:'death'` events (if killer weapon is tracked).
- Chart: top-10 weapons by kills as a horizontal bar chart. Chart.js.
- Clicking a weapon row filters the match list to show which matches it was used in.

**Weapon distance heatmap:** For each weapon, scatter its kill locations on the map canvas — reveals whether snipers die close-range or ARs are being used at long range.

---

### 5.3 — Duo Chemistry Dashboard (`duo.html`)

**Concept:** A page entirely dedicated to D282+S821 as a unit. Every stat is about the partnership, not the individuals.

**Why it's different:** PUBGLookup and OP.GG only show individual stats. The combination insight — "how well do these two play together?" — is completely absent from public tools.

**Implementation plan:**
- All data from `matches.json` + match JSON files (using MATCH_CACHE).
- **Section 1: Joint Performance**
  - Win rate together (already computed).
  - Games where both got kills vs one-sided.
  - Avg combined kills per game trend.
- **Section 2: Proximity Stats** — requires loading individual match JSONs
  - Average proximity throughout matches (already computed in match.html as "Proximity" chart).
  - **Correlation: proximity vs outcome**. For each match, compute avg proximity and final placement. Scatter plot. Does playing close together correlate with better results?
  - Time spent within 100m vs >100m vs >300m (split into phases).
- **Section 3: Support Stats**
  - Who revives who more (count `type:'revive'` events per player).
  - Who takes more blue zone damage.
  - How often one player is knocked when the other is still up.
- **Section 4: Carry Analysis**
  - Delta: (D282 kills - S821 kills) per game. Histogram. Shows balance of contribution.
  - Games where one player carried (got 3+ kills, other got 0).

**Data sources:** `matches.json` for placement/kills summary, match JSON files for position proximity, revive events, damage events.

---

### 5.4 — Personal Records Trophy Room (`records.html`)

**Concept:** Lifetime bests displayed as a visual "trophy case". Motivating and easy to skim.

**Implementation plan:**
- Load `matches.json` + all match JSONs for detailed records.
- Categories:
  - **Most kills in a game** (and link to that match)
  - **Highest damage in a game** (if in data)
  - **Best placement streak** (consecutive top-3 finishes)
  - **Longest win streak**
  - **Most kills in one session** (across all games on a day)
  - **Earliest kill in a match** (smallest `t` for a kill event)
  - **Latest kill before winning** (last kill event in a win)
  - **Most heals used in one game** (count heal events)
  - **Closest clutch win** (won with <1 circle phase remaining, e.g., final circle)
  - **Longest in-blue survival** (time spent outside safe zone)
- Each record: trophy icon + value + player + date + "View Match →" link.
- Sparkline charts showing the record stat over time (Chart.js `line` with hidden axes).
- Reset button to recalculate (since new matches may break old records).

---

### 5.5 — Session Goal Tracker (`goal.html`)

**Concept:** Before a play session, set a goal ("win 1 game", "get 5 kills each", "top-5 every game"). The page tracks live progress as new matches are added. Uses localStorage for persistence.

**Why it's interesting technically:** The site already has a data pipeline that could be extended to pull the latest matches and detect new ones since last visit.

**Implementation plan:**
- Goal types: Win X games, K/D ≥ X, Avg placement ≤ X, Play Y games.
- Progress bar per goal.
- localStorage: `{ goal, startDate, startMatchCount }` — on load, filter matches after `startDate` to measure progress.
- "Start Session" button sets the baseline. "End Session" shows summary.
- Simple motivational UI: big progress rings (CSS `conic-gradient`), green when achieved.
- No new data — uses `matches.json` entirely.

---

### 5.6 — Landing Zone Analyzer (`landings.html`)

**Concept:** Answer definitively: "Which drop locations give D282+S821 the best results?" Every landing zone is scored by outcome across all historical matches.

**Why it's high value:** This is the strategic question every PUBG duo discusses before queuing. Moving from opinion ("I feel like Pochinki is unlucky") to data ("we win 12% of Pochinki games vs 24% from Georgopol") is genuinely useful.

**Implementation plan:**
- Load all match JSONs, extract drop locations + match outcomes (placement).
- Cluster drop locations spatially (DBSCAN with ~80px radius — the same union-find algorithm already written in mapanalysis.html for engagements).
- Each cluster = a named zone (name by proximity to known POI grid coordinates, or just show grid reference like "C4").
- Render on map canvas:
  - Each cluster as a large circle, radius scales with visit count.
  - Color by avg outcome: green = good results, red = bad results.
  - Hover: "Visited X times. Avg placement: #Y. Win rate: Z%. Avg combined kills: K."
- Filter by map (same map tabs as mapanalysis.html).
- Sidebar: ranked list of all landing zones by win rate (min 3 visits to qualify).

**POI name lookup:** A static lookup table of known POI positions per map (can source from pubg wiki coordinates and convert to canvas coordinates using world_size).

---

### 5.7 — Head-to-Head Rivals (`rivals.html`)

**Concept:** Track recurring enemy names from kill/death events. Have you fought the same squad multiple times? How did those rematches go?

**Why it's fun:** The PUBG community loves the concept of "nemesis" players. This surfaces yours automatically from telemetry.

**Implementation plan:**
- Extract from all match JSONs:
  - `{type:'kill', target}` — enemies the duo killed.
  - `{type:'death', killer}` — enemies who killed the duo (if killer name is in event data).
- Build frequency table: enemy name → { encounters, killed_by_us, killed_us, dates }.
- Show players encountered ≥ 2 times in a table.
- Sort by: most recent | most encountered | biggest nemesis (killed us more than we killed them).
- "Rivals" badge: players you've both killed AND been killed by.
- Note: PUBG telemetry target names may be truncated or anonymized — verify data quality before building this.

---

## 6. Cross-Cutting Technical Improvements

### 6.1 — Shared Component Library

**Problem:** The nav menu, date slider, and filter-row styles are copy-pasted across 5 files. Any change requires editing all of them.

**Solution:** Extract a `shared.js` and `shared.css` (or inline into a `<template>` element):
- `initSiteNav(currentPage)` — renders the nav, marks current page active.
- `initDateSlider(dates, onchange)` — reusable dual-range slider.
- CSS variables already shared via `:root` — extract to a `shared.css` include.
- **Priority:** Low (cosmetic). **Risk:** Breaking changes across pages if done wrong. Do it carefully, one file at a time.

### 6.2 — Offline / PWA Support

**Problem:** The site requires network for every visit (map images, match data).

**Solution:** Add a `service-worker.js` that caches:
- All map images (they never change).
- `matches.json` (cache for 5 minutes, update on next visit).
- Individual match JSONs (cache forever — they never change once written).
- Add `manifest.json` for "Add to Home Screen" on mobile.
- **Impact:** Map Analysis loads instantly on repeat visits. Huge UX improvement for mobile.

### 6.3 — Match Data Update Script

**Problem:** The data pipeline (how `matches.json` and individual match JSONs are written) is external to this site. If there's a script to update it, it should support incremental updates (only fetch new matches).

**Suggestion:** Ensure the data pipeline:
- Never overwrites existing match JSONs (they're immutable).
- Appends new matches to `matches.json` sorted newest-first.
- Writes a `last_updated` timestamp to `matches.json`.
- Supports a dry-run mode to preview what would be fetched.

### 6.4 — Mobile Touch for Match.html

**Problem:** `match.html` has no pinch-to-zoom or touch pan. You added it to `mapanalysis.html` in an earlier session — the same touch code can be ported directly.

**Solution:** Copy the pinch-zoom touch handler block from `mapanalysis.html` into `match.html`. The canvas/view model is identical (`view.scale`, `view.offsetX/Y`, `applyZoom`, `clampView`). Estimated: 30 minutes, 60 lines.

### 6.5 — Consistent Error States

**Problem:** When match files fail to load (network error), the map just shows "Loading…" forever.

**Solution:**
- In `match.html`: catch individual match fetch failures, show "Failed to load [matchId]" with a retry button.
- In `mapanalysis.html`: already handles individual match failures with `console.warn`. Add a visible "X matches failed to load" badge in the match count display.

---

## 7. Priority Matrix

### Implemented (this sprint)

| # | Item | Status |
|---|------|--------|
| 1.1 | Placement histogram | ✅ Done |
| 1.2 | Rolling K/D trend | ✅ Done |
| 1.3 | Per-map stats table | ✅ Done |
| 1.4 | Duo Synergy Panel | ✅ Done |
| 1.6 | Lifetime Records / PB Badges | ✅ Done |
| 1.7 | Win Condition Analysis | ✅ Done |
| 2.5 | Weapon Damage Breakdown | ✅ Done |
| 2.6 | Blue Zone Indicator | ✅ Done (fallback logic) |
| 2.7 | Enemy Encounter Table (killed badge) | ✅ Done |
| 3.3 | Landing zone outcome scoring | ✅ Done |
| 3.6 | Late Game Positions layer | ✅ Done |
| 4.1 | Saved presets | ✅ Done |
| 4.2 | Shareable URL | ✅ Done |
| 4.3 | Capacity donut chart | ✅ Done |
| 4.4 | Ammo smart suggestions | ✅ Done |
| 4.6 | Item search / filter | ✅ Done |
| 5.4 | Personal Records page (records.html) | ✅ Done |

### Next Sprint

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 5.1 | Circle Predictor page | ★★★★★ | Medium |
| 5.2 | Weapon Kill Log | ★★★★★ | Medium |
| 2.1 | Match playback | ★★★★★ | Low |
| 3.1 | Wins-only filter | ★★★★★ | Very Low |
| 2.2 | Key moments list | ★★★★☆ | Low |
| 3.4 | Combat choropleth | ★★★★☆ | Low |
| 3.2 | Final circle scatter | ★★★★☆ | Low |
| 6.4 | Mobile touch match.html | ★★★★☆ | Very Low |

### Later

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 5.3 | Duo Chemistry page | ★★★★☆ | Medium |
| 5.6 | Landing Zone Analyzer | ★★★★☆ | Medium |
| 1.5 | Time-of-day heatmap | ★★★☆☆ | Low |
| 3.5 | Rotation arrows | ★★★☆☆ | Medium |
| 2.3 | Export map snapshot | ★★★★☆ | Low |
| 2.4 | Zone position timeline | ★★★☆☆ | Low |
| 5.5 | Session Goal Tracker | ★★★☆☆ | Medium |
| 3.7 | Per-match mini replay (DO NOT IMPLEMENT — too complex) | — | Very High |
| 5.7 | Rivals tracker (DO NOT IMPLEMENT — verify data first) | — | Medium |
| 6.1 | Shared components | ★★☆☆☆ | Medium |

---

*All suggestions assume the same constraints: static GitHub Pages hosting, vanilla JS, no npm, no build step, Chart.js via CDN for charts, Canvas 2D for map rendering.*
