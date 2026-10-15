---
name: Executive Liquidity Intelligence
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#44474d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#75777e'
  outline-variant: '#c5c6cd'
  surface-tint: '#515f78'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#0d1c32'
  on-primary-container: '#76849f'
  inverse-primary: '#b9c7e4'
  secondary: '#006c4a'
  on-secondary: '#ffffff'
  secondary-container: '#82f5c1'
  on-secondary-container: '#00714e'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#0d1c2e'
  on-tertiary-container: '#77859a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#b9c7e4'
  on-primary-fixed: '#0d1c32'
  on-primary-fixed-variant: '#39475f'
  secondary-fixed: '#85f8c4'
  secondary-fixed-dim: '#68dba9'
  on-secondary-fixed: '#002114'
  on-secondary-fixed-variant: '#005137'
  tertiary-fixed: '#d5e3fc'
  tertiary-fixed-dim: '#b9c7df'
  on-tertiary-fixed: '#0d1c2e'
  on-tertiary-fixed-variant: '#3a485b'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-hero:
    fontFamily: Plus Jakarta Sans
    fontSize: 56px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.03em
  display-hero-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '600'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.005em
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.05em
  metric-ticker:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 18px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 2.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system serves high-level financial executives, treasury teams, and board-level decision-makers presenting multi-billion dollar positions. The UI balances the steadfast reliability of legacy private wealth institutions with the agility of forward-looking quantitative analytics. 

The aesthetic is Modern Executive Glassmorphic: crystalline data containers over crisp neutral canvases, punctuated by deliberate architectural geometry and institutional contrast. Surfaces feel weightless yet mathematically precise. Information is staged as narrative decks—enabling real-time transitions between analytical monitoring and boardroom slideshow presentations.

## Colors

- **Primary (`#0A192F`)**: Sovereign Navy. Conveys stability, authority, and institutional gravitas. Applied across critical metrics, dominant headings, primary navigation, and high-impact structural anchors.
- **Secondary (`#059669`)**: Emerald Growth. Represents positive alpha, optimal liquidity health, positive variance, and primary presentation actions.
- **Tertiary (`#475569`)**: Slate Accent. Handles structural lines, axis typography, secondary metrics, and contextual meta-indicators.
- **Neutral (`#F8FAFC`)**: Crystalline Canvas. The foundational background tone, providing a calm, glare-free staging ground for high-density tables and glass card structures.

### Functional Palette Rules
- Positive fiscal variance: `#059669` (Secondary Emerald).
- Adverse or risk-elevated variance: `#DC2626` (Crimson Risk).
- Neutral/Unhedged state: `#475569` (Tertiary Slate).
- Glass container base: `rgba(255, 255, 255, 0.72)` with border highlights of `rgba(255, 255, 255, 0.85)` and structural separation borders of `rgba(15, 23, 42, 0.08)`.

## Typography

Typography enforces a strict hierarchy tailored for executive presentation clarity and data legibility across both projection displays and desktop interfaces:

- **Display & Headlines (`Plus Jakarta Sans`)**: Delivers geometric structure and executive refinement. Tighter letter spacing on display-level scales ensures multi-million and multi-billion dollar metrics project authority without sprawling visually.
- **Body & Data (`Inter`)**: Deployed for tabular reports, operational bodies, and narrative slides. High x-height and neutral grotesque contours preserve rapid optical scanning during high-stakes presentations.
- **Numbers & Metrics**: All numerical tables and graph callouts must strictly use `font-variant-numeric: tabular-nums` to maintain horizontal column alignment during real-time data streaming.

## Layout & Spacing

The layout is built around a hybrid 16:9 widescreen presentation canvas anchored within a 12-column fluid grid. Content modules are composed to maintain executive slide pacing:

- **Desktop (1280px and above)**: 12 columns, 1.5rem gutters, 2.5rem canvas margin. The layout prioritizes dual-pane executive dashboards: a primary slide viewport (8 columns) flanked by analytical inspection or secondary treasury metrics (4 columns), with the option to trigger a distraction-free Full-Stage mode.
- **Tablet (768px - 1279px)**: 8 columns, 1.25rem gutters, 1.5rem canvas margin. Analytical sidebars collapse into toggleable drawer views; slides retain their 16:9 proportion with horizontal swipe or dock navigation.
- **Mobile (Below 768px)**: 4 columns, 1rem gutters, 1rem canvas margin. The viewport stacks vertically, rendering slides as sequential card modules. Sticky bottom carousels anchor progress across reports.

## Elevation & Depth

Visual hierarchy uses frosted glassmorphic card containers paired with soft ambient shadows to keep dense financial interfaces clean and modern.

- **Base Canvas**: The clean `#F8FAFC` slate background sets the stage with zero elevation.
- **Glass Container (Level 1 - Cards/Dashboards)**:
  - Surface: `rgba(255, 255, 255, 0.75)`
  - Backdrop Blur: `blur(16px)`
  - Border: 1px solid `rgba(255, 255, 255, 0.9)` inner gradient fading to `rgba(10, 25, 47, 0.06)` outer rim
  - Shadow: `0 4px 20px -2px rgba(10, 25, 47, 0.04), 0 2px 6px -1px rgba(10, 25, 47, 0.02)`
- **Raised Surfaces (Level 2 - Hover/Active Slides)**:
  - Surface: `rgba(255, 255, 255, 0.88)`
  - Backdrop Blur: `blur(20px)`
  - Shadow: `0 12px 32px -4px rgba(10, 25, 47, 0.08), 0 4px 12px -2px rgba(10, 25, 47, 0.03)`
- **Overlay & Presentations (Level 3 - Slide HUD, Floating Carousels, Dropdowns)**:
  - Surface: `rgba(10, 25, 47, 0.92)` for dark HUD or `rgba(255, 255, 255, 0.95)` for light contextual tools
  - Backdrop Blur: `blur(24px)`
  - Shadow: `0 20px 40px -8px rgba(10, 25, 47, 0.16)`

## Shapes

The system implements a balanced `rounded-2` geometry (0.5rem base) to blend sharp institutional precision with modern glass software styling.

- **Standard Cards & Presentation Tiles**: `rounded-lg` (1rem / 16px) establishes clean, modern corners that frame complex graphs without clipping data points.
- **Metric Micro-Chips & HUD Badges**: `rounded-md` (0.5rem / 8px) matches the precision of numerical values.
- **Carousel Controls, Segmented Slide Toggles & Ticker Indicators**: Fully rounded capsules (`pill-shaped` / 9999px) provide instant affordance for active deck progression and interactive presentation tools.

## Components

### Buttons
- **Primary Executive Action**: Deep sovereign navy (`#0A192F`) background with crisp white text, 0.5rem radius, and subtle inset top-border `rgba(255,255,255,0.2)`. Focus states display an emerald (`#059669`) outline ring with 2px offset.
- **Secondary / Ghost Button**: Semi-transparent slate (`rgba(71, 85, 105, 0.08)`) with navy text, transitioning on hover to frosted white with elevated shadow.
- **Slide Stage Navigation**: Pill-shaped translucent glass triggers containing minimal chevron iconography and tooltip slide previews.

### Cards & Presentation Containers
- Built using Level 1 Glassmorphic tokens: `rgba(255, 255, 255, 0.75)` backdrop blur with a sharp hairline border. Header regions feature an integrated baseline divider in `rgba(15, 23, 42, 0.06)` separating narrative context from quantitative charts.

### Slide Indicators & Progress Elements
- **Stage Progress Bar**: Hairline track (2px) in `rgba(10, 25, 47, 0.10)` spanning the top border of the slide, filled by an animated secondary emerald (`#059669`) bar indicating presentation or auto-advance state.
- **Slide Carousel Controls**: Floating docked glass pill at bottom-center featuring current slide index (`03 / 12`), thumbnail previews on hover, previous/next buttons, and auto-play ticker controls.

### Ticker Status & Variance Badges
- **Status Indicator**: Soft tinted emerald (`rgba(5, 150, 105, 0.12)`) chip featuring a solid `#059669` pulse dot and tabular percentage growth values (+12.4% ARR).
- **Adverse Variance Badge**: Soft crimson (`rgba(220, 38, 38, 0.10)`) chip with `#DC2626` text, signaling liquidity warnings or yield dips.

### Financial Graphs & Metric Displays
- **Metric Callouts**: Oversized display numbers (`display-hero` or `headline-xl`) accompanied by a top label in uppercase tracking (`label-sm`).
- **Data Visualizations**: Line charts use emerald strokes (`#059669`, 2.5px) with soft vertical gradients fading down to `rgba(5, 150, 105, 0.0)`. Projection and stress-test lines render as dashed slate (`#475569`).

### Input Fields & Selectors
- Frosted input fields with inset fill `rgba(248, 250, 252, 0.8)`, border `rgba(15, 23, 42, 0.12)`, and active focus transition to `#0A192F` border with secondary emerald accent ring.