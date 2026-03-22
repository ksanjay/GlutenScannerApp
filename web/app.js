const storageKeys = {
  profile: "gluten-scanner-web-profile",
  sessions: "gluten-scanner-web-sessions"
};

const sampleProfile = {
  likedCuisines: ["Mexican", "Japanese", "Mediterranean"],
  likedIngredients: ["avocado", "lime", "salmon", "rice"],
  dislikedIngredients: ["mushroom"],
  conservativeMode: true
};

const sampleMenuText = `TACOS
Salmon Rice Bowl - avocado, cucumber, tamari, sesame 18
Crispy Fish Taco - cabbage, house sauce, lime 8
Carne Asada Plate - grilled steak, corn tortilla, salsa verde 21

SMALL PLATES
Ceviche - citrus, chili, avocado 16
Fried Calamari - lemon aioli 17
Roasted Cauliflower - tahini, herbs, pistachio 14`;

const state = {
  activeTab: "home",
  currentStep: "home",
  currentDocument: null,
  currentSession: null,
  profile: loadJSON(storageKeys.profile, sampleProfile),
  sessions: loadJSON(storageKeys.sessions, []),
  processing: false,
  analyzing: false,
  processingLabel: "Reading menu...",
  resultsScope: "bestMatches",
  resultsCuisine: "All",
  safestFirst: true,
  cameraStream: null
};

const app = document.getElementById("app");
const titleEl = document.getElementById("screen-title");
const toastEl = document.getElementById("toast");
const photoInput = document.getElementById("photo-input");
const cameraInput = document.getElementById("camera-input");
const documentInput = document.getElementById("document-input");
const cameraModal = document.getElementById("camera-modal");
const cameraVideo = document.getElementById("camera-video");
const captureCanvas = document.getElementById("capture-canvas");

const commonSections = new Set([
  "starters", "appetizers", "mains", "entrees", "desserts", "salads", "tacos", "sushi", "specials", "small plates"
]);

const cuisineKeywords = {
  taco: "Mexican",
  salsa: "Mexican",
  curry: "Indian",
  masala: "Indian",
  sushi: "Japanese",
  ramen: "Japanese",
  mezze: "Mediterranean",
  falafel: "Mediterranean",
  pasta: "Italian",
  risotto: "Italian",
  pho: "Vietnamese",
  kimchi: "Korean"
};

const safeVocabulary = [
  "gluten-free", "corn tortilla", "ceviche", "sashimi", "lettuce wrap", "rice bowl", "tamari", "polenta", "risotto", "grilled", "roasted vegetables"
];

const riskVocabulary = [
  "breaded", "soy sauce", "roux", "flour tortilla", "pasta", "beer batter", "bun", "crouton", "malt", "tempura", "seitan", "fried chicken", "udon"
];

const ambiguityVocabulary = [
  "fried", "crispy", "special sauce", "chef's special", "house sauce", "marinade", "dumpling", "shared fryer", "seasonal"
];

document.getElementById("home-reset").addEventListener("click", () => {
  state.activeTab = "home";
  render();
});

document.querySelectorAll(".tab-button").forEach((button) => {
  button.addEventListener("click", () => {
    state.activeTab = button.dataset.tab;
    render();
  });
});

document.getElementById("close-camera").addEventListener("click", closeCamera);
document.getElementById("camera-fallback").addEventListener("click", () => {
  closeCamera();
  cameraInput.click();
});
document.getElementById("capture-photo").addEventListener("click", capturePhotoFromStream);

photoInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (file) await importImageFile(file, "Menu Photo");
  photoInput.value = "";
});

cameraInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (file) await importImageFile(file, "Live Menu Capture");
  cameraInput.value = "";
});

documentInput.addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  if (file.type === "application/pdf" || file.name.toLowerCase().endsWith(".pdf")) {
    await importPdfFile(file);
  } else {
    await importImageFile(file, file.name);
  }
  documentInput.value = "";
});

render();

function render() {
  updateHeader();
  updateTabs();
  const loading = state.processing || state.analyzing ? renderLoadingOverlay() : "";
  if (state.activeTab === "preferences") {
    app.innerHTML = `${renderPreferences()}${loading}`;
    bindPreferences();
    return;
  }
  if (state.activeTab === "history") {
    app.innerHTML = `${renderHistory()}${loading}`;
    bindHistory();
    return;
  }
  if (state.currentStep === "review" && state.currentDocument) {
    app.innerHTML = `${renderReview()}${loading}`;
    bindReview();
    return;
  }
  if (state.currentStep === "results" && state.currentSession) {
    app.innerHTML = `${renderResults()}${loading}`;
    bindResults();
    return;
  }
  app.innerHTML = `${renderHome()}${loading}`;
  bindHome();
}

function updateHeader() {
  if (state.activeTab === "preferences") {
    titleEl.textContent = "Preferences";
  } else if (state.activeTab === "history") {
    titleEl.textContent = "History";
  } else if (state.currentStep === "review") {
    titleEl.textContent = "Review";
  } else if (state.currentStep === "results" && state.currentSession) {
    titleEl.textContent = state.currentSession.menuDocument.title;
  } else {
    titleEl.textContent = "Gluten-Friendly";
  }
}

function updateTabs() {
  document.querySelectorAll(".tab-button").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.tab === state.activeTab);
  });
}

function renderHome() {
  const highlights = [...state.profile.likedCuisines.slice(0, 2), ...state.profile.likedIngredients.slice(0, 2)];
  const recentCards = state.sessions.length === 0
    ? `<p class="body-copy">Your first analyzed menu will appear here for fast recall.</p>`
    : state.sessions.slice(0, 3).map((session) => `
        <button class="list-button reopen-session" data-session-id="${session.id}">
          <div>
            <strong>${escapeHtml(session.menuDocument.title)}</strong>
            <p class="list-meta">${formatDate(session.createdAt)} · ${session.analyzedItems.length} dishes</p>
          </div>
        </button>
      `).join("");

  const continueCard = state.currentDocument && state.currentStep === "review" ? `
    <button class="card soft fade-up continue-review">
      <div class="section-label">Continue where you left off</div>
      <h3>Continue menu review</h3>
      <p class="body-copy">We kept your extraction in place so you can refine dish text before analysis.</p>
    </button>
  ` : state.currentSession && state.currentStep === "results" ? `
    <button class="card soft fade-up continue-results">
      <div class="section-label">Continue where you left off</div>
      <h3>Open latest results</h3>
      <p class="body-copy">Jump back into your safest matches and preference filters.</p>
    </button>
  ` : "";

  return `
    <section class="screen-stack fade-up">
      <article class="card hero-card">
        <p class="eyebrow">Gluten-aware dining</p>
        <h2 class="hero-title">Find the safest menu picks faster.</h2>
        <p class="body-copy">Scan, upload, review, and rank dishes with a conservative gluten-safety lens before you order.</p>
        <div class="caution"><span class="shield">!</span><span>Probabilistic guidance only. Always confirm ingredients and cross-contamination risk with staff.</span></div>
      </article>

      <article class="card">
        <div class="section-label">Start here</div>
        <h3>Scan a live menu</h3>
        <p class="body-copy">Point your camera at the menu and move straight into review mode with extracted dishes already grouped.</p>
        <div style="height:14px"></div>
        <button class="primary-button" id="scan-menu-button">Scan Menu</button>
      </article>

      <section>
        <div class="section-label">Or import a menu</div>
        <div class="two-up">
          <button class="card compact-action" id="photo-upload-button">
            <span class="compact-icon">🖼️</span>
            <div>
              <strong>Photo Library</strong>
              <p class="body-copy">Import image</p>
            </div>
          </button>
          <button class="card compact-action" id="document-upload-button">
            <span class="compact-icon">📄</span>
            <div>
              <strong>Upload PDF</strong>
              <p class="body-copy">Read document</p>
            </div>
          </button>
        </div>
      </section>

      <article class="card soft">
        <div class="section-label">Your taste snapshot</div>
        <p class="preference-note muted">Preference matches help rank dishes, but they never override gluten-safety scoring.</p>
        <div class="chip-row" style="margin-top:12px;">
          ${(highlights.length ? highlights : ["No preferences yet"]).map((tag) => `<span class="pill">${escapeHtml(tag)}</span>`).join("")}
        </div>
      </article>

      ${continueCard}

      <article class="card">
        <div class="section-label">Recent scans</div>
        <div class="recent-list">${recentCards}</div>
      </article>

      <article class="card soft">
        <div class="section-label">Need a fast demo?</div>
        <h3>Use the preview menu</h3>
        <p class="body-copy">Load the same sample dishes from the native app to test the full review and scoring flow in Safari.</p>
        <div style="height:14px"></div>
        <button class="secondary-button" id="preview-menu-button">Load preview menu</button>
      </article>
    </section>
  `;
}

function bindHome() {
  byId("scan-menu-button")?.addEventListener("click", openCamera);
  byId("photo-upload-button")?.addEventListener("click", () => photoInput.click());
  byId("document-upload-button")?.addEventListener("click", () => documentInput.click());
  byId("preview-menu-button")?.addEventListener("click", () => {
    state.currentDocument = parseMenu(sampleMenuText, "Preview Menu");
    state.currentStep = "review";
    state.activeTab = "home";
    render();
  });
  byId("continue-review")?.addEventListener("click", () => {
    state.currentStep = "review";
    render();
  });
  byId("continue-results")?.addEventListener("click", () => {
    state.currentStep = "results";
    render();
  });
  document.querySelector(".continue-review")?.addEventListener("click", () => {
    state.currentStep = "review";
    render();
  });
  document.querySelector(".continue-results")?.addEventListener("click", () => {
    state.currentStep = "results";
    render();
  });
  document.querySelectorAll(".reopen-session").forEach((button) => {
    button.addEventListener("click", () => {
      const session = state.sessions.find((entry) => entry.id === button.dataset.sessionId);
      if (!session) return;
      state.currentSession = session;
      state.currentDocument = session.menuDocument;
      state.currentStep = "results";
      render();
    });
  });
}

function renderReview() {
  const doc = state.currentDocument;
  return `
    <section class="screen-stack fade-up">
      <article class="card review-header">
        <div class="section-label">Refine the scan</div>
        <h2>Review extracted dishes</h2>
        <p class="body-copy">Tighten OCR mistakes before scoring. Short edits here make the later safety ranking much more trustworthy.</p>
        <div class="inline-actions">
          <span class="status-pill ${doc.extractionConfidence >= 0.7 ? "safe" : doc.extractionConfidence >= 0.55 ? "medium" : "caution"}">
            ${Math.round(doc.extractionConfidence * 100)}% OCR confidence
          </span>
          <button class="primary-button inline" id="analyze-button" ${state.analyzing ? "disabled" : ""}>${state.analyzing ? "Analyzing..." : "Analyze menu"}</button>
        </div>
      </article>
      ${doc.sections.map((section, sectionIndex) => `
        <article class="card review-section">
          <div class="inline-actions">
            <div>
              <h3>${escapeHtml(section.title)}</h3>
              <p class="list-meta">${section.items.length} items</p>
            </div>
          </div>
          ${section.items.map((item, itemIndex) => `
            <section class="editable-item" data-section-index="${sectionIndex}" data-item-index="${itemIndex}">
              <label>
                <span class="field-label">Dish</span>
                <input class="text-input item-name" value="${escapeHtml(item.name)}" data-section-index="${sectionIndex}" data-item-index="${itemIndex}">
              </label>
              <label>
                <span class="field-label">Description</span>
                <textarea class="text-area item-description" data-section-index="${sectionIndex}" data-item-index="${itemIndex}">${escapeHtml(item.description)}</textarea>
              </label>
              <div class="inline-actions">
                <input class="text-input item-price" style="max-width:110px;" placeholder="Price" value="${escapeHtml(item.price || "")}" data-section-index="${sectionIndex}" data-item-index="${itemIndex}">
                <button class="ghost-button duplicate-row" data-section-index="${sectionIndex}" data-item-index="${itemIndex}">Duplicate row</button>
              </div>
              <p class="list-meta">${escapeHtml(item.rawText)}</p>
            </section>
          `).join("")}
        </article>
      `).join("")}
    </section>
  `;
}

function bindReview() {
  byId("analyze-button")?.addEventListener("click", analyzeCurrentDocument);
  document.querySelectorAll(".item-name").forEach((input) => {
    input.addEventListener("input", updateDocumentField("name"));
  });
  document.querySelectorAll(".item-description").forEach((input) => {
    input.addEventListener("input", updateDocumentField("description"));
  });
  document.querySelectorAll(".item-price").forEach((input) => {
    input.addEventListener("input", updateDocumentField("price"));
  });
  document.querySelectorAll(".duplicate-row").forEach((button) => {
    button.addEventListener("click", () => {
      const sectionIndex = Number(button.dataset.sectionIndex);
      const itemIndex = Number(button.dataset.itemIndex);
      const clone = structuredClone(state.currentDocument.sections[sectionIndex].items[itemIndex]);
      clone.id = crypto.randomUUID();
      state.currentDocument.sections[sectionIndex].items.splice(itemIndex + 1, 0, clone);
      render();
    });
  });
}

function renderResults() {
  const session = state.currentSession;
  const cuisines = ["All", ...new Set(session.analyzedItems.flatMap((item) => item.item.cuisineTags))];
  const filteredItems = getFilteredItems(session);

  return `
    <section class="screen-stack fade-up">
      <article class="card results-header">
        <div class="section-label">Ranked recommendations</div>
        <h2>Safer menu picks</h2>
        <p class="body-copy">Use these tiers as a starting point, not a substitute for ingredient confirmation.</p>
        <div class="caution"><span class="shield">?</span><span>If fryer setup, sauces, marinades, or soy-based ingredients are unclear, ask staff before ordering.</span></div>
      </article>

      <article class="card filter-stack">
        <div class="section-label">Tune the list</div>
        <div class="segmented">
          <button class="${state.resultsScope === "bestMatches" ? "is-selected" : ""}" data-scope="bestMatches">Best matches</button>
          <button class="${state.resultsScope === "allSaferOptions" ? "is-selected" : ""}" data-scope="allSaferOptions">All safer options</button>
        </div>
        <div class="chip-row">
          ${cuisines.map((cuisine) => `<button class="chip-button ${state.resultsCuisine === cuisine ? "is-selected" : ""}" data-cuisine="${escapeHtml(cuisine)}">${escapeHtml(cuisine)}</button>`).join("")}
        </div>
        <button class="secondary-button" id="safest-first-toggle">${state.safestFirst ? "Showing safest first" : "Showing preference order"}</button>
      </article>

      ${filteredItems.length === 0 ? `
        <article class="card empty-state">
          <div class="section-label">No matches yet</div>
          <h3>Nothing fits this filter mix.</h3>
          <p class="body-copy">Try widening cuisine filters or switch to all safer options to see the best available picks.</p>
        </article>
      ` : ""}

      ${["definitelyGood", "mediumProbability", "mightBeGood"].map((tier) => renderTierGroup(tier, filteredItems)).join("")}
    </section>
  `;
}

function bindResults() {
  document.querySelectorAll("[data-scope]").forEach((button) => {
    button.addEventListener("click", () => {
      state.resultsScope = button.dataset.scope;
      render();
    });
  });
  document.querySelectorAll("[data-cuisine]").forEach((button) => {
    button.addEventListener("click", () => {
      state.resultsCuisine = button.dataset.cuisine;
      render();
    });
  });
  byId("safest-first-toggle")?.addEventListener("click", () => {
    state.safestFirst = !state.safestFirst;
    render();
  });
}

function renderPreferences() {
  return `
    <section class="screen-stack fade-up">
      <article class="card soft">
        <div class="section-label">Your taste profile</div>
        <h2>Personalize the ranking</h2>
        <p class="body-copy">Cuisine and ingredient preferences help surface dishes you may enjoy, but they never override safety classification.</p>
      </article>
      <section class="prefs-grid">
        ${renderPreferenceBlock("Liked cuisines", "cuisine-input", "Add cuisines you often seek out.", state.profile.likedCuisines)}
        ${renderPreferenceBlock("Liked ingredients", "liked-input", "Examples: avocado, salmon, lime.", state.profile.likedIngredients)}
        ${renderPreferenceBlock("Disliked ingredients", "disliked-input", "Items here will lower match ranking.", state.profile.dislikedIngredients)}
        <article class="card preference-block">
          <div class="section-label">Safety posture</div>
          <div class="toggle-row">
            <div>
              <strong>Conservative mode</strong>
              <p class="body-copy">Keeps ambiguity from climbing into higher-confidence tiers.</p>
            </div>
            <button class="toggle ${state.profile.conservativeMode ? "is-on" : ""}" id="conservative-toggle" aria-label="Toggle conservative mode"></button>
          </div>
        </article>
      </section>
    </section>
  `;
}

function bindPreferences() {
  [
    ["cuisine-input", "likedCuisines"],
    ["liked-input", "likedIngredients"],
    ["disliked-input", "dislikedIngredients"]
  ].forEach(([id, key]) => {
    byId(`${id}-add`)?.addEventListener("click", () => addPreference(id, key));
    byId(id)?.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        addPreference(id, key);
      }
    });
  });
  document.querySelectorAll(".remove-pref").forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.key;
      const value = button.dataset.value;
      state.profile[key] = state.profile[key].filter((entry) => entry !== value);
      persistState();
      if (state.currentDocument) refreshCurrentAnalysis();
      render();
    });
  });
  byId("conservative-toggle")?.addEventListener("click", () => {
    state.profile.conservativeMode = !state.profile.conservativeMode;
    persistState();
    if (state.currentDocument) refreshCurrentAnalysis();
    render();
  });
}

function renderHistory() {
  return `
    <section class="screen-stack fade-up">
      <article class="card soft">
        <div class="section-label">Saved scans</div>
        <h2>Recent menu sessions</h2>
        <p class="body-copy">${state.sessions.length ? "Reopen a previous menu and jump straight back into its ranked results." : "No saved scans yet. Once you analyze a menu, it will appear here for quick recall."}</p>
      </article>
      ${state.sessions.length ? state.sessions.map((session) => `
        <button class="card history-row reopen-session" data-session-id="${session.id}">
          <div>
            <strong>${escapeHtml(session.menuDocument.title)}</strong>
            <p class="list-meta">${formatDate(session.createdAt)} · ${session.analyzedItems.filter((item) => item.confidenceTier === "definitelyGood").length} definitely good</p>
          </div>
        </button>
      `).join("") : ""}
    </section>
  `;
}

function bindHistory() {
  document.querySelectorAll(".reopen-session").forEach((button) => {
    button.addEventListener("click", () => {
      const session = state.sessions.find((entry) => entry.id === button.dataset.sessionId);
      if (!session) return;
      state.currentSession = session;
      state.currentDocument = session.menuDocument;
      state.currentStep = "results";
      state.activeTab = "home";
      render();
    });
  });
}

function renderTierGroup(tier, filteredItems) {
  const group = filteredItems.filter((item) => item.confidenceTier === tier);
  if (!group.length) return "";
  return `
    <section class="result-group fade-up">
      <div class="inline-actions">
        <div>
          <h3>${tierTitle(tier)}</h3>
          <p class="list-meta">${group.length} dishes</p>
        </div>
        <span class="status-pill ${tier === "definitelyGood" ? "safe" : tier === "mediumProbability" ? "medium" : "caution"}">${tierTitle(tier)}</span>
      </div>
      ${group.map((item) => `
        <article class="card result-card">
          <div class="result-topline">
            <div>
              <h4>${escapeHtml(item.item.name)}</h4>
              ${item.item.description ? `<p class="body-copy">${escapeHtml(item.item.description)}</p>` : ""}
            </div>
            <span class="status-pill ${item.confidenceTier === "definitelyGood" ? "safe" : item.confidenceTier === "mediumProbability" ? "medium" : "caution"}">${tierTitle(item.confidenceTier)}</span>
          </div>
          <div class="chip-row">
            ${item.preferenceMatch.isMatch ? `<span class="pill">Matches your profile</span>` : ""}
            ${item.missingInfo ? `<span class="pill">Needs confirmation</span>` : ""}
          </div>
          <p>${escapeHtml(item.explanation)}</p>
          <div class="evidence-row">
            ${item.evidence.slice(0, 4).map((evidence) => `<span class="evidence-chip">${escapeHtml(evidence.label)}</span>`).join("")}
          </div>
          ${item.missingInfo ? `<p class="muted"><strong>Ask staff to confirm preparation details.</strong></p>` : ""}
        </article>
      `).join("")}
    </section>
  `;
}

function renderPreferenceBlock(title, inputId, copy, values) {
  return `
    <article class="card preference-block">
      <div class="section-label">${escapeHtml(title)}</div>
      <p class="body-copy">${escapeHtml(copy)}</p>
      <div class="input-row">
        <input class="text-input" id="${inputId}" placeholder="Add a preference">
        <button class="secondary-button" id="${inputId}-add">Add</button>
      </div>
      <div class="chip-row">
        ${values.length ? values.map((value) => `<button class="chip-button remove-pref" data-key="${mapPreferenceKey(inputId)}" data-value="${escapeHtml(value)}">${escapeHtml(value)} ×</button>`).join("") : `<span class="muted">Nothing added yet.</span>`}
      </div>
    </article>
  `;
}

function renderLoadingOverlay() {
  return `
    <div class="loading-overlay">
      <div class="card loading-card">
        <div class="spinner"></div>
        <h3>${state.analyzing ? "Preparing your safer picks" : "Reading menu"}</h3>
        <p class="body-copy">${escapeHtml(state.processingLabel)}</p>
      </div>
    </div>
  `;
}

function updateDocumentField(field) {
  return (event) => {
    const sectionIndex = Number(event.target.dataset.sectionIndex);
    const itemIndex = Number(event.target.dataset.itemIndex);
    state.currentDocument.sections[sectionIndex].items[itemIndex][field] = event.target.value;
  };
}

async function analyzeCurrentDocument() {
  if (!state.currentDocument || state.analyzing) return;
  state.analyzing = true;
  state.processingLabel = "Checking ingredients and risk signals...";
  render();
  await wait(350);
  state.processingLabel = "Ranking dishes for your profile...";
  render();
  await wait(350);
  const session = analyzeDocument(state.currentDocument, state.profile);
  state.currentSession = session;
  state.currentStep = "results";
  state.resultsScope = "bestMatches";
  state.resultsCuisine = "All";
  state.safestFirst = true;
  state.sessions = [session, ...state.sessions.filter((entry) => entry.id !== session.id)].slice(0, 15);
  persistState();
  state.analyzing = false;
  render();
}

async function importImageFile(file, sourceName) {
  setProcessing(true, "Extracting text from image...");
  try {
    const text = await runOcrFromImage(file);
    state.currentDocument = parseMenu(text, sourceName);
    state.currentStep = "review";
    state.activeTab = "home";
    if (!text.trim()) {
      showToast("OCR came back sparse. You can still edit the extracted text in review.");
    }
  } catch (error) {
    showToast(error.message || "Image import failed.");
  } finally {
    setProcessing(false);
    render();
  }
}

async function importPdfFile(file) {
  setProcessing(true, "Extracting text from PDF...");
  try {
    const text = await extractPdfText(file);
    state.currentDocument = parseMenu(text, file.name);
    state.currentStep = "review";
    state.activeTab = "home";
  } catch (error) {
    showToast(error.message || "PDF import failed.");
  } finally {
    setProcessing(false);
    render();
  }
}

function refreshCurrentAnalysis() {
  if (!state.currentDocument || !state.currentSession) return;
  state.currentSession = analyzeDocument(state.currentDocument, state.profile, state.currentSession.id, state.currentSession.createdAt);
  state.sessions = state.sessions.map((entry) => entry.id === state.currentSession.id ? state.currentSession : entry);
  persistState();
}

function setProcessing(flag, label = "Reading menu...") {
  state.processing = flag;
  state.processingLabel = label;
}

async function openCamera() {
  if (!navigator.mediaDevices?.getUserMedia) {
    showToast("Live camera capture is not supported here. Falling back to photo upload.");
    cameraInput.click();
    return;
  }
  try {
    state.cameraStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: "environment" } },
      audio: false
    });
    cameraVideo.srcObject = state.cameraStream;
    cameraModal.classList.remove("hidden");
    cameraModal.setAttribute("aria-hidden", "false");
  } catch {
    showToast("Camera access was blocked. You can upload a photo instead.");
    cameraInput.click();
  }
}

function closeCamera() {
  if (state.cameraStream) {
    state.cameraStream.getTracks().forEach((track) => track.stop());
    state.cameraStream = null;
  }
  cameraVideo.srcObject = null;
  cameraModal.classList.add("hidden");
  cameraModal.setAttribute("aria-hidden", "true");
}

async function capturePhotoFromStream() {
  if (!state.cameraStream) return;
  const track = state.cameraStream.getVideoTracks()[0];
  const settings = track.getSettings();
  captureCanvas.width = settings.width || 1280;
  captureCanvas.height = settings.height || 1720;
  const context = captureCanvas.getContext("2d");
  context.drawImage(cameraVideo, 0, 0, captureCanvas.width, captureCanvas.height);
  const blob = await new Promise((resolve) => captureCanvas.toBlob(resolve, "image/jpeg", 0.92));
  closeCamera();
  if (blob) {
    await importImageFile(new File([blob], "camera-capture.jpg", { type: "image/jpeg" }), "Live Menu Capture");
  }
}

async function runOcrFromImage(file) {
  if (!window.Tesseract) {
    throw new Error("OCR library failed to load.");
  }
  const result = await window.Tesseract.recognize(file, "eng", {
    logger: (message) => {
      if (message.status) {
        state.processingLabel = `${capitalize(message.status)}...`;
        render();
      }
    }
  });
  return result.data?.text || "";
}

async function extractPdfText(file) {
  const module = await import("https://cdn.jsdelivr.net/npm/pdfjs-dist@4.4.168/build/pdf.min.mjs");
  module.GlobalWorkerOptions.workerSrc = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.4.168/build/pdf.worker.min.mjs";
  const buffer = await file.arrayBuffer();
  const pdf = await module.getDocument({ data: buffer }).promise;
  let text = "";
  for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
    const page = await pdf.getPage(pageNumber);
    const content = await page.getTextContent();
    text += `${content.items.map((item) => item.str).join(" ")}\n`;
  }
  return text;
}

function parseMenu(rawText, sourceName) {
  const normalizedLines = rawText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  let currentSectionTitle = "Chef Picks";
  let currentItems = [];
  let sections = [];

  normalizedLines.forEach((line) => {
    if (isSectionHeader(line)) {
      if (currentItems.length) {
        sections.push({ id: crypto.randomUUID(), title: currentSectionTitle, items: currentItems });
        currentItems = [];
      }
      currentSectionTitle = toTitleCase(line);
      return;
    }
    const item = parseMenuItem(line, currentSectionTitle);
    if (item) currentItems.push(item);
  });

  if (currentItems.length) {
    sections.push({ id: crypto.randomUUID(), title: currentSectionTitle, items: currentItems });
  }

  if (!sections.length) {
    sections = [{
      id: crypto.randomUUID(),
      title: "Menu",
      items: normalizedLines.map((line) => ({
        id: crypto.randomUUID(),
        name: inferredName(line),
        description: inferredDescription(line),
        price: null,
        sectionTitle: "Menu",
        cuisineTags: [],
        rawText: line
      }))
    }];
  }

  const confidence = Math.max(0.35, Math.min(0.94, normalizedLines.length / Math.max(8, rawText.length / 24)));
  return {
    id: crypto.randomUUID(),
    title: inferTitle(sourceName),
    sourceName,
    extractedAt: new Date().toISOString(),
    rawText,
    sections,
    extractionConfidence: confidence
  };
}

function analyzeDocument(document, profile, preservedId = crypto.randomUUID(), createdAt = new Date().toISOString()) {
  const analyzedItems = document.sections
    .flatMap((section) => section.items)
    .map((item) => analyzeItem(item, document.extractionConfidence, profile))
    .sort((left, right) => tierPriority(left.confidenceTier) - tierPriority(right.confidenceTier));
  return {
    id: preservedId,
    createdAt,
    menuDocument: structuredClone(document),
    analyzedItems
  };
}

function analyzeItem(item, documentConfidence, profile) {
  const lowercased = `${item.name} ${item.description} ${item.rawText}`.toLowerCase();
  const evidence = [];

  evidence.push(...matchTokens(lowercased, safeVocabulary, "safeSignal", 0.28));
  evidence.push(...matchTokens(lowercased, riskVocabulary, "riskSignal", -0.4));
  evidence.push(...matchTokens(lowercased, ambiguityVocabulary, "ambiguity", -0.22));

  if (documentConfidence < 0.6) {
    evidence.push(makeEvidence("ambiguity", "Low OCR confidence", -0.24));
  }
  if (item.description.length < 8 && !lowercased.includes("gluten-free")) {
    evidence.push(makeEvidence("ambiguity", "Limited menu detail", -0.18));
  }

  const preferenceMatch = matchPreference(item, profile);
  evidence.push(...preferenceMatch.cuisineHits.map((value) => makeEvidence("preference", `Cuisine match: ${value}`, 0.08)));
  evidence.push(...preferenceMatch.likedIngredientHits.map((value) => makeEvidence("preference", `Likes ${value}`, 0.06)));
  evidence.push(...preferenceMatch.dislikedIngredientHits.map((value) => makeEvidence("preference", `Contains disliked ingredient: ${value}`, -0.25)));

  const recommendation = heuristicRecommendation(item, evidence);
  const tier = determineTier(evidence, lowercased.includes("gluten-free"), profile.conservativeMode);

  return {
    id: crypto.randomUUID(),
    item,
    confidenceTier: tier,
    evidence: evidence.sort((left, right) => right.weight - left.weight),
    explanation: recommendation.summary,
    missingInfo: recommendation.missingInfo,
    preferenceMatch
  };
}

function heuristicRecommendation(item, evidence) {
  const riskCount = evidence.filter((entry) => entry.kind === "riskSignal").length;
  const ambiguityCount = evidence.filter((entry) => entry.kind === "ambiguity").length;
  const safeCount = evidence.filter((entry) => entry.kind === "safeSignal").length;
  let summary = "This item may work, but the available text is too sparse to treat it as clearly gluten-friendly.";
  if (riskCount > 0) {
    summary = "Detected strong gluten-risk signals in the dish wording.";
  } else if (ambiguityCount > 0) {
    summary = "Some ingredients look promising, but the menu leaves important preparation details unclear.";
  } else if (safeCount > 0) {
    summary = "The menu language includes direct or high-confidence gluten-friendly cues.";
  }
  return {
    summary,
    missingInfo: ambiguityCount > 0 || item.description.length < 10
  };
}

function determineTier(evidence, hasExplicitSafeSignal, conservativeMode) {
  const riskCount = evidence.filter((entry) => entry.kind === "riskSignal").length;
  const ambiguityCount = evidence.filter((entry) => entry.kind === "ambiguity").length;
  const safeCount = evidence.filter((entry) => entry.kind === "safeSignal").length;
  const score = evidence.reduce((sum, entry) => sum + entry.weight, 0);

  if (riskCount > 0) return "mightBeGood";
  if (hasExplicitSafeSignal && ambiguityCount === 0) return "definitelyGood";

  if (conservativeMode) {
    if (safeCount > 0 && ambiguityCount === 0 && score >= 0.2) return "definitelyGood";
    if (safeCount > 0 && ambiguityCount <= 2 && score >= -0.05) return "mediumProbability";
    return "mightBeGood";
  }

  if (score >= 0.25) return "definitelyGood";
  if (score >= -0.1) return "mediumProbability";
  return "mightBeGood";
}

function matchPreference(item, profile) {
  const haystack = `${item.sectionTitle || ""} ${item.name} ${item.description} ${item.cuisineTags.join(" ")}`.toLowerCase();
  const normalizedCuisineTags = item.cuisineTags.map((tag) => tag.toLowerCase());
  const cuisineHits = profile.likedCuisines.filter((value) => haystack.includes(value.toLowerCase()) || normalizedCuisineTags.includes(value.toLowerCase()));
  const likedIngredientHits = profile.likedIngredients.filter((value) => haystack.includes(value.toLowerCase()));
  const dislikedIngredientHits = profile.dislikedIngredients.filter((value) => haystack.includes(value.toLowerCase()));
  return {
    cuisineHits,
    likedIngredientHits,
    dislikedIngredientHits,
    score: (cuisineHits.length * 3) + (likedIngredientHits.length * 2) - (dislikedIngredientHits.length * 4),
    get isMatch() {
      return this.score > 0 && this.dislikedIngredientHits.length === 0;
    }
  };
}

function getFilteredItems(session) {
  let items = [...session.analyzedItems];
  if (state.resultsScope === "bestMatches") {
    const matched = items.filter((item) => item.preferenceMatch.isMatch && item.preferenceMatch.dislikedIngredientHits.length === 0);
    items = matched.length ? matched : items;
  }
  if (state.resultsCuisine !== "All") {
    items = items.filter((item) => item.item.cuisineTags.includes(state.resultsCuisine) || item.item.sectionTitle === state.resultsCuisine);
  }
  if (state.safestFirst) {
    items.sort((left, right) => {
      const tierDelta = tierPriority(left.confidenceTier) - tierPriority(right.confidenceTier);
      if (tierDelta !== 0) return tierDelta;
      return right.preferenceMatch.score - left.preferenceMatch.score;
    });
  } else {
    items.sort((left, right) => right.preferenceMatch.score - left.preferenceMatch.score);
  }
  return items;
}

function addPreference(inputId, key) {
  const input = byId(inputId);
  const value = input?.value.trim();
  if (!value) return;
  if (!state.profile[key].includes(value)) state.profile[key].push(value);
  input.value = "";
  persistState();
  if (state.currentDocument) refreshCurrentAnalysis();
  render();
}

function persistState() {
  localStorage.setItem(storageKeys.profile, JSON.stringify(state.profile));
  localStorage.setItem(storageKeys.sessions, JSON.stringify(state.sessions));
}

function showToast(message) {
  toastEl.textContent = message;
  toastEl.classList.remove("hidden");
  clearTimeout(showToast.timeout);
  showToast.timeout = setTimeout(() => toastEl.classList.add("hidden"), 3200);
}

function isSectionHeader(line) {
  const uppercase = line === line.toUpperCase();
  const shortEnough = line.length < 28;
  const noPrice = !line.includes("$");
  const noComma = !line.includes(",");
  return shortEnough && noPrice && noComma && (uppercase || commonSections.has(line.toLowerCase()));
}

function parseMenuItem(line, sectionTitle) {
  const priceMatch = line.match(/\$?\d+(\.\d{2})?/);
  const price = priceMatch ? priceMatch[0] : null;
  const cleaned = line.replace(/\$?\d+(\.\d{2})?/g, "").trim();
  if (!cleaned) return null;
  return {
    id: crypto.randomUUID(),
    name: inferredName(cleaned),
    description: inferredDescription(cleaned),
    price,
    sectionTitle,
    cuisineTags: inferCuisineTags(cleaned, sectionTitle),
    rawText: line
  };
}

function inferredName(line) {
  for (const separator of [":", "-", "•", ","]) {
    if (line.includes(separator)) return toTitleCase(line.split(separator)[0].trim());
  }
  const words = line.split(/\s+/);
  if (words.length > 5) return toTitleCase(words.slice(0, 4).join(" "));
  return toTitleCase(line);
}

function inferredDescription(line) {
  for (const separator of [":", "-", "•"]) {
    if (line.includes(separator)) {
      const parts = line.split(separator);
      if (parts.length > 1) return parts.slice(1).join(separator).trim();
    }
  }
  const words = line.split(/\s+/);
  if (words.length <= 4) return "";
  return words.slice(4).join(" ");
}

function inferCuisineTags(line, sectionTitle) {
  const haystack = `${sectionTitle} ${line}`.toLowerCase();
  return Object.entries(cuisineKeywords).flatMap(([key, value]) => haystack.includes(key) ? [value] : []);
}

function inferTitle(sourceName) {
  return sourceName.replace(/\.pdf$/i, "").replace(/\.jpg$/i, "").replace(/\.png$/i, "");
}

function makeEvidence(kind, label, weight) {
  return { id: crypto.randomUUID(), kind, label, weight };
}

function matchTokens(text, vocabulary, kind, weight) {
  return vocabulary.flatMap((token) => text.includes(token) ? [makeEvidence(kind, toTitleCase(token), weight)] : []);
}

function tierPriority(tier) {
  return { definitelyGood: 0, mediumProbability: 1, mightBeGood: 2 }[tier] ?? 99;
}

function tierTitle(tier) {
  return {
    definitelyGood: "Definitely good",
    mediumProbability: "Medium probability",
    mightBeGood: "Might be good"
  }[tier] || tier;
}

function mapPreferenceKey(inputId) {
  return {
    "cuisine-input": "likedCuisines",
    "liked-input": "likedIngredients",
    "disliked-input": "dislikedIngredients"
  }[inputId];
}

function byId(id) {
  return document.getElementById(id);
}

function loadJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function formatDate(date) {
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(new Date(date));
}

function toTitleCase(value) {
  return value
    .toLowerCase()
    .split(" ")
    .map((word) => word ? word[0].toUpperCase() + word.slice(1) : word)
    .join(" ");
}

function capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
