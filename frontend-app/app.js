const chains = [
  { short: "HOME", color: "#7cc8ff" },
  { short: "LZ", color: "#ecff82" },
  { short: "REMOTE", color: "#9cff75" },
  { short: "ADAPTER", color: "#ff8ab4" },
  { short: "MORPHO", color: "#9ab0ff" },
];

const nodes = [
  { id: "user", type: "source", title: "User", label: "entry", copy: "Capital starts here.", address: "deposit / mint", x: 6, y: 44 },
  { id: "vault", type: "execution", title: "CrossChainVault", label: "accounting core", copy: "Home vault. Shares are accounted only here.", address: "contracts/crosschain/CrossChainVault.sol", x: 24, y: 44 },
  { id: "allocator", type: "execution", title: "StrategyAllocator", label: "control", copy: "Starts allocate / recall operations.", address: "contracts/crosschain/StrategyAllocator.sol", x: 24, y: 16 },
  { id: "registry", type: "execution", title: "StrategyRegistry", label: "control", copy: "Maps strategy, chain and limits.", address: "contracts/crosschain/StrategyRegistry.sol", x: 24, y: 76 },
  { id: "bridge", type: "router", title: "BridgeAdapter", label: "bridge", copy: "Moves asset + payload cross-chain.", address: "contracts/crosschain/LayerZeroBridgeAdapter.sol", x: 46, y: 44 },
  { id: "settler", type: "execution", title: "ReportSettler", label: "control", copy: "Brings remote state back into vault accounting.", address: "contracts/crosschain/ReportSettler.sol", x: 46, y: 16 },
  { id: "queue", type: "execution", title: "WithdrawalQueue", label: "home liquidity", copy: "Serves delayed withdrawals after recall.", address: "contracts/crosschain/WithdrawalQueue.sol", x: 46, y: 76 },
  { id: "agent", type: "execution", title: "RemoteStrategyAgent", label: "remote agent", copy: "Receives funds and executes strategy commands.", address: "contracts/crosschain/RemoteStrategyAgent.sol", x: 66, y: 44 },
  { id: "provider", type: "provider", title: "MorphoProvider", label: "adapter", copy: "Protocol adapter called by the agent.", address: "contracts/providers/MorphoProvider.sol", x: 84, y: 28 },
  { id: "meta", type: "provider", title: "MetaMorpho", label: "vault layer", copy: "Selected Morpho vault.", address: "IMetaMorpho", x: 84, y: 52 },
  { id: "morpho", type: "provider", title: "Morpho Blue", label: "protocol", copy: "Final market exposure.", address: "IMorpho", x: 84, y: 76 },
];

const scenarios = [
  {
    id: "allocate",
    title: "Allocate",
    subtitle: "Vault -> Bridge -> Agent -> Morpho",
    amount: "$2.8M",
    route: ["user", "vault", "bridge", "agent", "provider", "meta", "morpho"],
  },
  {
    id: "control",
    title: "Control",
    subtitle: "Registry -> Allocator -> Settle",
    amount: "opId",
    route: ["registry", "allocator", "vault", "bridge", "agent", "settler", "vault"],
  },
  {
    id: "recall",
    title: "Recall",
    subtitle: "Morpho -> Bridge -> Vault",
    amount: "$860K",
    route: ["morpho", "meta", "provider", "agent", "bridge", "vault", "queue"],
  },
];

const links = [
  ["user", "vault"],
  ["registry", "allocator"],
  ["allocator", "vault"],
  ["vault", "bridge"],
  ["settler", "vault"],
  ["vault", "queue"],
  ["bridge", "agent"],
  ["agent", "provider"],
  ["provider", "meta"],
  ["meta", "morpho"],
  ["agent", "settler"],
];

const elements = {
  scenarioList: document.getElementById("scenarioList"),
  chainRibbon: document.getElementById("chainRibbon"),
  nodeGroup: document.getElementById("nodeGroup"),
  routeLayer: document.getElementById("routeLayer"),
  scenarioTitle: document.getElementById("scenarioTitle"),
  scenarioAmount: document.getElementById("scenarioAmount"),
  scenarioEta: document.getElementById("scenarioEta"),
  topologyStage: document.getElementById("topologyStage"),
};

let activeScenarioId = scenarios[0].id;

function init() {
  renderChains();
  renderScenarios();
  renderNodes();
  positionNodes();
  renderPaths();
  applyScenario(activeScenarioId);
  window.addEventListener("resize", () => {
    positionNodes();
    renderPaths();
  });
}

function currentScenario() {
  return scenarios.find((item) => item.id === activeScenarioId);
}

function renderChains() {
  elements.chainRibbon.innerHTML = chains
    .map(
      (chain) => `
        <div class="pill">
          <span class="pill-dot" style="background:${chain.color}"></span>
          <span>${chain.short}</span>
        </div>
      `
    )
    .join("");
}

function renderScenarios() {
  elements.scenarioList.innerHTML = scenarios
    .map(
      (scenario) => `
        <article
          class="scenario-card ${scenario.id === activeScenarioId ? "active" : ""}"
          data-scenario-id="${scenario.id}"
          title="${scenario.subtitle}"
        >
          <div class="section-kicker">${scenario.amount}</div>
          <h3>${scenario.title}</h3>
          <footer>
            <span>${scenario.subtitle}</span>
          </footer>
        </article>
      `
    )
    .join("");

  elements.scenarioList.querySelectorAll("[data-scenario-id]").forEach((card) => {
    card.addEventListener("click", () => {
      activeScenarioId = card.dataset.scenarioId;
      renderScenarios();
      applyScenario(activeScenarioId);
    });
  });
}

function renderNodes() {
  elements.nodeGroup.innerHTML = nodes
    .map(
      (node) => `
        <article
          class="topology-node ${node.type}"
          data-node-id="${node.id}"
          data-x="${node.x}"
          data-y="${node.y}"
          title="${node.title}\n${node.copy}\n${node.address}"
        >
          <div class="node-meta">${node.label}</div>
          <div class="node-title">${node.title}</div>
        </article>
      `
    )
    .join("");
}

function positionNodes() {
  const stageWidth = elements.topologyStage.clientWidth;
  const stageHeight = elements.topologyStage.clientHeight;

  elements.nodeGroup.querySelectorAll("[data-node-id]").forEach((nodeElement) => {
    const width = nodeElement.offsetWidth;
    const height = nodeElement.offsetHeight;
    const x = Number(nodeElement.dataset.x);
    const y = Number(nodeElement.dataset.y);
    const left = clamp((stageWidth * x) / 100 - width / 2, 18, stageWidth - width - 18);
    const top = clamp((stageHeight * y) / 100 - height / 2, 18, stageHeight - height - 18);

    nodeElement.style.left = `${left}px`;
    nodeElement.style.top = `${top}px`;
  });
}

function renderPaths() {
  const stageRect = elements.topologyStage.getBoundingClientRect();
  const nodeMap = new Map();

  elements.nodeGroup.querySelectorAll("[data-node-id]").forEach((nodeElement) => {
    const rect = nodeElement.getBoundingClientRect();
    nodeMap.set(nodeElement.dataset.nodeId, {
      x: rect.left - stageRect.left + rect.width / 2,
      y: rect.top - stageRect.top + rect.height / 2,
    });
  });

  elements.routeLayer.innerHTML = `
    <defs>
      <linearGradient id="routeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#8ec5ff"></stop>
        <stop offset="50%" stop-color="#8bffb0"></stop>
        <stop offset="100%" stop-color="#f0ff7a"></stop>
      </linearGradient>
      <filter id="routeGlow">
        <feGaussianBlur stdDeviation="6" result="blur"></feGaussianBlur>
        <feMerge>
          <feMergeNode in="blur"></feMergeNode>
          <feMergeNode in="SourceGraphic"></feMergeNode>
        </feMerge>
      </filter>
    </defs>
    ${links
      .map(([from, to]) => {
        const start = nodeMap.get(from);
        const end = nodeMap.get(to);
        if (!start || !end) return "";
        const dx = Math.abs(end.x - start.x) * 0.42;
        const d = `M ${start.x} ${start.y} C ${start.x + dx} ${start.y}, ${end.x - dx} ${end.y}, ${end.x} ${end.y}`;
        return `<path class="route-path" data-link="${from}:${to}" d="${d}" />`;
      })
      .join("")}
  `;

  highlightActiveRoute();
}

function applyScenario(scenarioId) {
  const scenario = scenarios.find((item) => item.id === scenarioId);
  if (!scenario) return;
  elements.scenarioTitle.textContent = scenario.title;
  elements.scenarioAmount.textContent = scenario.amount;
  elements.scenarioEta.textContent = scenario.subtitle;
  highlightActiveNodes(scenario.route);
  highlightActiveRoute();
}

function highlightActiveNodes(route) {
  const routeSet = new Set(route);
  elements.nodeGroup.querySelectorAll("[data-node-id]").forEach((nodeElement) => {
    nodeElement.classList.toggle("active", routeSet.has(nodeElement.dataset.nodeId));
  });
}

function highlightActiveRoute() {
  const scenario = currentScenario();
  const activePairs = new Set(
    scenario.route.slice(0, -1).map((nodeId, index) => `${nodeId}:${scenario.route[index + 1]}`)
  );
  elements.routeLayer.querySelectorAll("[data-link]").forEach((path) => {
    path.classList.toggle("active", activePairs.has(path.dataset.link));
  });
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

init();
