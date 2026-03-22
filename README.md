# GlutenScannerApp

GlutenScannerApp includes both:

- a native SwiftUI iPhone app
- a mobile-first web app that preserves the same customer flow, visual language, and conservative ranking model for iPhone browsers

Both versions help people review restaurant menus through a conservative gluten-safety lens before they order.

The app lets users scan a live menu, upload a menu image or PDF, review extracted menu items, and sort dishes into three confidence tiers:

- `Definitely good`
- `Medium probability`
- `Might be good`

It also supports saved food preferences so users can surface dishes they are more likely to enjoy without letting preference override safety.

## Screenshots

| Home | App Icon |
| --- | --- |
| ![Home screen](docs/screenshots/home.png) | ![App icon on simulator home screen](docs/screenshots/launcher.png) |

## What It Does

- Scans live menus with camera capture
- Imports menu photos and PDFs
- Extracts menu text with OCR and parses likely sections and dishes
- Applies a conservative gluten-risk rules engine
- Adds structured reasoning and confidence labels for each dish
- Lets users review and correct extracted items before analysis
- Saves recent sessions locally for quick recall
- Filters and ranks results based on cuisine and ingredient preferences

## Product Flow

1. Home
2. Scan or upload a menu
3. Review extracted dishes and correct OCR issues
4. See ranked gluten-friendlier options with preference-aware filtering

## Tech Stack

- Native iPhone app: SwiftUI, Vision / VisionKit, PDFKit, Swift Package Manager
- Mobile web app: HTML, CSS, vanilla JavaScript, Tesseract.js, PDF.js, browser localStorage
- Shared product logic mirrored across both versions: menu parsing, conservative gluten scoring, preference-aware ranking

## Project Structure

```text
GlutenFreeScannerApp/   SwiftUI app, screens, design system, services
Sources/GlutenFreeCore/ Shared parsing, scoring, models, matching logic
Tests/GlutenFreeCoreTests/ Core analysis and parsing tests
web/                   Mobile-first browser version for iPhone Safari
```

## Running Locally

### Web app

Serve the `web/` directory from any static file server:

```bash
python3 -m http.server 4173 --directory web
```

Then open:

```text
http://localhost:4173
```

Notes:

- The web app is optimized for a narrow mobile viewport and works well in iPhone Safari.
- OCR and PDF parsing run in the browser using CDN-hosted libraries.
- Camera capture may require HTTPS on some devices outside localhost.

### Deploy on Render

This repo now includes a Render blueprint at `render.yaml` for the mobile web app.

Fastest path:

1. Push this repo to GitHub.
2. In Render, choose `New +` -> `Blueprint`.
3. Connect the GitHub repo.
4. Render will detect `render.yaml` and create a static web service named `glutenscanner-web`.
5. Deploy.

What Render will use:

- Service type: static site
- Publish directory: `web`
- No build command required

If you prefer creating it manually instead of using the blueprint:

- Environment: `Static Site`
- Build Command: leave blank
- Publish Directory: `web`

The web app is already structured for static hosting, so Render only needs to serve the files in `web/`.

### Native iPhone app

#### Requirements

- Xcode 26+
- iOS Simulator target for iPhone

#### Open and run

1. Open `GlutenFreeScanner.xcodeproj` in Xcode.
2. Select the `GlutenFreeScanner` scheme.
3. Choose an iPhone simulator.
4. Build and run.

#### Command line build

```bash
xcodebuild -project GlutenFreeScanner.xcodeproj -scheme GlutenFreeScanner -destination 'generic/platform=iOS Simulator' build
```

#### Core tests

```bash
swift test --scratch-path .build
```

## Safety Note

This app provides probabilistic guidance, not medical advice. Menu descriptions can be incomplete, OCR can be imperfect, and cross-contamination risk often cannot be confirmed from a menu alone.

Users should still verify ingredients and preparation details with restaurant staff.

## Status

This is an MVP-quality prototype focused on a clear end-to-end iPhone experience across native and browser surfaces:

- modern SwiftUI interface
- matching mobile web interface
- conservative gluten-oriented scoring
- local-first storage
- simulator-tested build path

## Repository

- GitHub: [ksanjay/GlutenScannerApp](https://github.com/ksanjay/GlutenScannerApp)
