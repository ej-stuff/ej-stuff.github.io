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

### 1.1 — Placement Distribution Histogram

**Why it matters:** K/D alone is misleading. PUBG rewards survival more than kills (2× the ranking weight). A histogram of placement finishes instantly reveals whether the duo are consistent survivors or aggressive early-exitters.

**Exact plan:**
- Add a Chart.js bar chart below the existing overview KPI cards.
- Buckets: `#1 (Win)`, `#2–5`, `#6–10`, `#11–20`, `#21–50`, `#51+`
- Data source: `filteredMatches()` → `m.players[p].placement` already in `matches.json`
- Two datasets (D282 amber, S821 blue) grouped side by side.
- Show count AND percentage on each bar (Chart.js `datalabels` plugin or manual rendering).
- Update on every filter change — hook into existing `renderStats()`.
- `<canvas id="placementChart">` inside a new `.panel` between the KPI row and the Sessions panel.

```js
// Core logic — runs inside renderStats()
function buildPlacementBuckets(matches, player) {
  const b = [0,0,0,0,0,0]; // win, 2-5, 6-10, 11-20, 21-50, 51+
  for (const m of matches) {
    const pl = m.players[player]?.placement;
    if (!pl) continue;
    if (pl === 1) b[0]++;
    else if (pl <= 5) b[1]++;
    else if (pl <= 10) b[2]++;
    else if (pl <= 20) b[3]++;
    else if (pl <= 50) b[4]++;
    else b[5]++;
  }
  return b;
}
```

---

### 1.2 — Rolling K/D and Win-Rate Trend Line

**Why it matters:** The most-requested stat in every PUBG tracker community. Is the duo improving? Slumping? A rolling 10-game window smooths noise while capturing real trends.

**Exact plan:**
- Add two line charts (or one combined dual-axis chart) in the Charts tab of the existing Daily Sessions panel.
- X-axis = match date (chronological). Y-axis = rolling 10-game K/D / win-rate.
- Rolling window: iterate through `filteredMatches()` sorted by date, compute a trailing slice of 10.
- Both players on same chart, D282 amber / S821 blue.
- If fewer than 10 games exist, use whatever is available.

```js
function rollingKD(matches, player, window=10) {
  const sorted = [...matches].sort((a,b) => a.created_at.localeCompare(b.created_at));
  return sorted.map((_, i) => {
    const slice = sorted.slice(Math.max(0, i-window+1), i+1);
    const kills  = slice.reduce((s,m) => s + (m.players[player]?.kills||0), 0);
    const deaths = slice.filter(m => m.players[player]?.placement > 1).length;
    return { x: sorted[i].created_at.slice(0,10), y: deaths ? kills/deaths : kills };
  });
}
```

---

### 1.3 — Performance by Map Table

**Why it matters:** D282 and S821 probably have very different win rates on Erangel vs Miramar. This is instant actionable feedback ("stop queueing Miramar on weeknights").

**Exact plan:**
- Add a compact stats table inside the existing Stats panel (or new panel).
- Columns: Map | Games | Win% | Avg Kills | Avg Placement | Avg Damage (if available)
- Data entirely from `matches.json` — no individual match files needed.
- Sort by Games descending.
- Color-code Win% column green/red based on overall average.

```js
function buildMapStats(matches, player) {
  const maps = {};
  for (const m of matches) {
    if (!maps[m.map]) maps[m.map] = { n:0, wins:0, kills:0, plSum:0 };
    const s = maps[m.map], pd = m.players[player];
    if (!pd) continue;
    s.n++; s.kills += pd.kills||0; s.plSum += pd.placement||99;
    if (pd.placement===1) s.wins++;
  }
  return Object.entries(maps)
    .map(([map,s]) => ({ map, n:s.n, winPct: s.wins/s.n*100,
                         avgKills: s.kills/s.n, avgPl: s.plSum/s.n }))
    .sort((a,b) => b.n - a.n);
}
```

---

### 1.4 — Duo Synergy Panel

**Why it matters:** The unique selling point of this site is that it tracks two players together. No public tracker shows this. Questions answered: who carries more? Do they play similarly? Who survives when the other dies?

**Exact plan:**
- New panel: "Duo Chemistry"
- Metrics computed from `filteredMatches()`:
  - **Both got kills** vs **Only D282** vs **Only S821** vs **Neither** — donut chart
  - **Both died** vs **One survived** — survival style breakdown
  - **Kill delta** — D282 kills minus S821 kills per game; histogram of this delta (who dominates fights)
  - **Games where they placed top-3 together** (both alive) vs one survived
- All purely from `matches.json` summary fields — no telemetry fetch needed.

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

### 1.6 — Session "PB Badges" — Personal Bests

**Why it matters:** Positive reinforcement. Shows when a session was the duo's best ever at something. Great for motivation.

**Exact plan:**
- Compute lifetime bests once per `filteredMatches()` call:
  - Most kills in one game (per player)
  - Most kills in one session
  - Best avg placement session
  - Longest top-3 streak
  - Highest win streak
- In the Sessions table, add small badge icons (`👑`, `⭐`, `🔥`) on the rows that are personal bests.
- Show a "Lifetime Records" card at the top of the Stats panel with current holder of each record.

---

### 1.7 — Win Condition Analysis

**Why it matters:** Pro teams study "what are we doing differently when we win vs lose?" This does that automatically.

**Exact plan:**
- Split `filteredMatches()` into wins (placement=1) and non-wins.
- Compute avg kills, avg damage (if available), avg survival time for each group.
- Show as a side-by-side stat panel: "When we win" | "When we lose"
- Highlight the biggest differences in amber.
- The data is entirely in `matches.json`. No telemetry fetch needed.

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

### 2.5 — Damage Dealt Breakdown by Weapon

**Why it matters:** "Did my AKM or M416 do more work this match?" Players constantly ask this. It validates attachment and ammo choices.

**Exact plan:**
- Aggregate `md.events.filter(ev => ev.type==='dmg_dealt')` by `ev.weapon`.
- Show as a small horizontal bar chart in the sidebar, per player.
- Each bar: weapon name + total damage value + count of hits.
- Sort by total damage descending, top 5 weapons.
- Uses data already in match JSON (no new processing needed).
- Could also show headshot vs body breakdown if `ev.damage` distinguishes it.

---

### 2.6 — Blue Zone Damage Indicator on Timeline

**Why it matters:** Blue zone damage is invisible in the current timeline. Players can correlate "we were getting wrecked in blue" with their HP drop on the chart.

**Exact plan:**
- On the HP-over-time chart, add a shaded red background region for any period where `dmg_taken` events (from `source='bluezone'` if that field exists) are occurring.
- Alternatively: scan position data for `p.blue === true` (which is already tracked in positions) and shade those time ranges on the chart.
- Uses `_dist282` and `_dist821` already computed. No new data needed.
- Add a thin `rgba(74, 158, 221, 0.15)` band on the HP chart during blue periods.

---

### 2.7 — Enemy Encounter Table (enriched)

**Why it matters:** The current engagement list shows enemy names but no summary stats. Players want to know "how much damage did we deal to each enemy team?"

**Exact plan:**
- Extend existing `buildEngagementSummary()`:
  - Per enemy player encountered: total `dmg_dealt` to them, number of shots, whether we killed them.
  - Sort by total damage dealt descending.
  - Show: enemy name | damage in | damage out | outcome (killed/knocked/survived)
- Group by inferred enemy team (players with same `ev.target_team_id` if available, or cluster by time).
- Data source: `md.events` filtered to `dmg_dealt` + cross-reference with kill/knockdown events.

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

### 3.3 — Landing Zone Outcome Scoring

**Why it matters:** "Is Pochinki worth it for us?" — This overlays our actual performance stats on top of the landing zone dots. Every drop location gets a color showing whether games from that area tend to end well.

**Exact plan:**
- For each drop location, look up the match result (`filteredMatches().find(m => m.match_id === drop.matchId)`).
- Score = `(1 - placement/totalPlayers) * 100` to normalize across squad sizes.
- Color the drop dot on a green→red gradient based on avg outcome score at that location cluster.
- Show in hover: "Landed here X times, avg placement #Y, win rate Z%".
- Data entirely from `MATCH_CACHE` (drops) + `DATA.matches` (placement). No new fetch needed.

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

### 3.6 — Map Sector Survivability Grid

**Why it matters:** "Where do we die?" vs "Where do we survive late game?" shows which map areas are dangerous for this duo specifically — not just "popular drop" data, but their personal survival stats.

**Exact plan:**
- Two new computed layers that leverage existing data:
  - **Death density**: heatmap built from `LAYER.events.deaths` positions (different color scheme — red, already planned but shown via existing Deaths layer; this would be a blended heatmap version).
  - **Late-game presence**: heatmap built from positions filtered to `t > 1200` (late game phase). Shows where the duo tends to be when they make it to late game.
- Toggle both together as a "Survival Zones" layer.
- The contrast between the two maps reveals: "we're in the north-east late game when we survive, but we die in the south when we push early."

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

### 4.1 — Saved Presets (localStorage)

**Why it matters:** The most-requested feature in any planner tool. Being able to save "my standard Erangel loadout" and load it with one click saves time and enables comparison.

**Exact plan:**
- Add a "Presets" panel above the bag panel.
- "Save" button: prompt for name, `localStorage.setItem('preset_' + name, JSON.stringify(state.counts))`.
- "Load" dropdown: `Object.keys(localStorage).filter(k => k.startsWith('preset_'))` → renders as options.
- "Delete" button per preset.
- Max 10 presets (soft limit), warn if exceeded.
- No external dependencies — pure localStorage.

```js
function savePreset() {
  const name = prompt('Preset name:');
  if (!name?.trim()) return;
  localStorage.setItem('pubg_preset_' + name.trim(), JSON.stringify(state.counts));
  renderPresets();
}
function loadPreset(name) {
  const saved = localStorage.getItem('pubg_preset_' + name);
  if (saved) { state.counts = JSON.parse(saved); render(); }
}
```

---

### 4.2 — Shareable URL

**Why it matters:** "Check out the loadout I'm running" is a common duo conversation. Encoding the loadout in the URL means sharing = copy URL and paste.

**Exact plan:**
- On any state change (if share mode is on), update `history.replaceState` with query params:
  `?bp=3&vest=1&c=Bandage:5,FirstAidKit:2,556mm:120,...` (abbreviated item names).
- On page load, parse `URLSearchParams` and populate `state.counts`.
- Add a "Copy Link" button that calls `navigator.clipboard.writeText(location.href)`.
- URL-safe: use item index in `ITEMS` array as the key (shorter than full names).

```js
function encodeLoadout() {
  const parts = [];
  parts.push(`bp=${state.backpack}`, `vest=${state.vest?1:0}`);
  for (let i=0; i<ITEMS.length; i++) {
    const n = state.counts[ITEMS[i].name]||0;
    if (n) parts.push(`i${i}=${n}`);
  }
  return parts.join('&');
}
function decodeLoadout(qs) {
  const p = new URLSearchParams(qs);
  state.backpack = +(p.get('bp') ?? 3);
  state.vest     = p.get('vest') !== '0';
  for (let i=0; i<ITEMS.length; i++) {
    const n = p.get(`i${i}`);
    if (n) state.counts[ITEMS[i].name] = +n;
  }
}
```

---

### 4.3 — Capacity Breakdown Donut Chart

**Why it matters:** "Where is my capacity going?" A visual donut/pie by category (Healing / Ammo / Throwables / Attachments) makes over-packing in one category instantly obvious.

**Exact plan:**
- Add a small Chart.js doughnut chart inside the Capacity panel, replacing or sitting beside the text breakdown.
- Segments: one per category (Healing, Throwables, Ammo, Attachments, Tactical).
- Colors: healing=green, ammo=amber, throwables=red, attachments=blue, tactical=purple.
- Center label shows total used / total capacity.
- Updates on every `render()` call.
- ~30 lines of Chart.js config.

---

### 4.4 — Ammo Smart Suggestion

**Why it matters:** "How much ammo should I carry?" is a constantly-asked question. The answer depends on weapon choice and how aggressive you play. This automates the math.

**Exact plan:**
- Detect current weapon choice from the Slot-only section: if user has added any rifle entries that use 5.56 / 7.62 etc., surface an ammo suggestion banner.
- Rule-based formula: `suggested_rounds = base_mag_count * mag_size * safety_factor`
  - Example: M416 (5.56) → default 3 mags = 90 rounds + 60 spare → suggest 150× 5.56
  - AKM (7.62) → 120× 7.62
- Show as a dim suggestion line under each ammo row: "Suggested: 150 for 1× AR" — clicking auto-fills the count.
- This is static data tied to the ammo categories already in ITEMS. No API needed.

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

### 4.6 — Item Search / Filter

**Why it matters:** The item list has 60+ entries. Scrolling categories works but a search bar is faster when you know what you want.

**Exact plan:**
- Add a `<input type="text" placeholder="Search items…">` above the category tabs.
- On input: filter `ITEMS` by `name.toLowerCase().includes(query)` across ALL categories.
- Show results in a flat list (bypassing category filter). Highlighting matching chars is optional.
- Clear button (×) restores the category view.
- ~20 lines of JS.

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

| # | Item | Impact | Effort | Do First? |
|---|------|--------|--------|-----------|
| 1.1 | Placement histogram | ★★★★★ | Low | ✅ Yes |
| 1.2 | Rolling K/D trend | ★★★★★ | Low | ✅ Yes |
| 1.3 | Per-map stats table | ★★★★☆ | Low | ✅ Yes |
| 2.1 | Match playback | ★★★★★ | Low | ✅ Yes |
| 2.3 | Export snapshot | ★★★★☆ | Low | ✅ Yes |
| 3.1 | Wins-only filter | ★★★★★ | Very Low | ✅ Yes |
| 3.2 | Final circle scatter | ★★★★☆ | Low | ✅ Yes |
| 4.1 | Saved presets | ★★★★☆ | Low | ✅ Yes |
| 4.2 | Shareable URL | ★★★☆☆ | Low | ✅ Yes |
| 5.1 | Circle Predictor page | ★★★★★ | Medium | Next sprint |
| 5.2 | Weapon Kill Log | ★★★★★ | Medium | Next sprint |
| 5.3 | Duo Chemistry | ★★★★☆ | Medium | Next sprint |
| 3.3 | Landing zone scoring | ★★★★☆ | Medium | Next sprint |
| 3.4 | Combat choropleth | ★★★★☆ | Low | Next sprint |
| 2.2 | Key moments list | ★★★★☆ | Low | Next sprint |
| 5.6 | Landing Zone Analyzer | ★★★★☆ | Medium | Later |
| 5.4 | Trophy Room | ★★★☆☆ | Medium | Later |
| 4.3 | Capacity donut | ★★★☆☆ | Low | Later |
| 6.4 | Mobile touch match.html | ★★★★☆ | Very Low | Later |
| 5.5 | Session Goal Tracker | ★★★☆☆ | Medium | Later |
| 5.7 | Rivals tracker | ★★☆☆☆ | Medium | Verify data first |
| 6.1 | Shared components | ★★☆☆☆ | Medium | Maintenance |

---

*All suggestions assume the same constraints: static GitHub Pages hosting, vanilla JS, no npm, no build step, Chart.js via CDN for charts, Canvas 2D for map rendering.*
