import { Application, Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js";

const application = Application.start();

application.register("chat", class extends Controller {
  static targets = ["footer", "stream", "indicator"];
  static values = { pollUrl: String, sseUrl: String, correlationId: String };

  connect() {
    this.lastEventId = null;
    this.pollInterval = 3000;
    this.backoffSteps = [3000, 5000, 10000];
    this.backoffIndex = 0;
    this.pollTimer = null;
    this.eventsSeen = new Set();

    this.setupKeyboardPadding();
    this.scroll();
    this.observeStream();
    this.startSse();
    this.startPolling();
  }

  disconnect() {
    this.stopPolling();
    if (this.eventSource) {
      this.eventSource.close();
    }
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
    }
  }

  startPolling() {
    this.stopPolling();
    if (!this.pollUrlValue) return;
    this.poll();
    this.pollTimer = setInterval(() => this.poll(), this.pollInterval);
    this.updateIndicator(`Polling every ${this.pollInterval / 1000}s...`);
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  async poll() {
    if (!this.pollUrlValue) return;
    const url = new URL(this.pollUrlValue, window.location.origin);
    if (this.lastEventId) url.searchParams.set("last_event_id", this.lastEventId);

    const started = performance.now();
    try {
      const response = await fetch(url.toString(), { headers: { "Accept": "application/json" } });
      const latency = Math.round(performance.now() - started);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const data = await response.json();
      this.handleEvents(data.events || []);
      this.resetBackoff();
      this.updateIndicator(`Polling every ${this.pollInterval / 1000}s... (${latency}ms)`);
    } catch (error) {
      this.backoff();
      this.updateIndicator(`Retrying in ${this.pollInterval / 1000}s... (${error.message})`, true);
      this.appendErrorBubble(error.message);
    }
  }

  startSse() {
    if (!this.sseUrlValue) return;
    try {
      this.eventSource = new EventSource(this.sseUrlValue);
      this.eventSource.addEventListener("sap_run", (event) => {
        try {
          const payload = JSON.parse(event.data);
          this.handleEvents([payload]);
        } catch (e) {
          console.error("sap_run sse parse error", e);
        }
      });
      this.eventSource.onerror = () => {
        this.eventSource.close();
        this.eventSource = null;
      };
    } catch (e) {
      console.warn("SSE unavailable, fallback to polling", e);
    }
  }

  handleEvents(events) {
    if (!this.hasStreamTarget) return;

    events.forEach((event) => {
      if (!event || !event.id || this.eventsSeen.has(event.id)) return;
      this.eventsSeen.add(event.id);
      this.lastEventId = event.id;
      if (event.html) {
        this.streamTarget.insertAdjacentHTML("beforeend", event.html);
      } else if (event.body) {
        const bubble = document.createElement("div");
        bubble.className = "chat-bubble";
        bubble.textContent = event.body;
        this.streamTarget.appendChild(bubble);
      }
    });

    if (events.length > 0) {
      this.scroll();
    }
  }

  backoff() {
    this.backoffIndex = Math.min(this.backoffIndex + 1, this.backoffSteps.length - 1);
    this.pollInterval = this.backoffSteps[this.backoffIndex];
    this.startPolling();
  }

  resetBackoff() {
    if (this.backoffIndex === 0 && this.pollInterval === this.backoffSteps[0]) return;
    this.backoffIndex = 0;
    this.pollInterval = this.backoffSteps[0];
    this.startPolling();
  }

  updateIndicator(text, isError = false) {
    if (!this.hasIndicatorTarget) return;
    this.indicatorTarget.textContent = text;
    this.indicatorTarget.classList.toggle("alert-error", isError);
    this.indicatorTarget.classList.toggle("alert-info", !isError);
  }

  scroll() {
    if (this.hasStreamTarget) {
      // With flex-col-reverse, scrollTop = 0 shows the visual "bottom" (newest content)
      this.streamTarget.scrollTop = 0;
    }
  }

  setupKeyboardPadding() {
    if (!this.hasFooterTarget) return;
    const updatePadding = () => {
      const footerHeight = this.footerTarget.offsetHeight || 0;
      document.documentElement.style.setProperty("--chat-footer-height", `${footerHeight + 24}px`);
    };
    updatePadding();
    window.addEventListener("resize", updatePadding);
    window.addEventListener("focus", updatePadding, true);
  }

  observeStream() {
    if (!this.hasStreamTarget) return;
    this.mutationObserver = new MutationObserver((mutations) => {
      if (mutations.some((m) => m.addedNodes.length > 0)) {
        this.scroll();
      }
    });
    this.mutationObserver.observe(this.streamTarget, { childList: true });
  }

  appendErrorBubble(message) {
    if (!this.hasStreamTarget) return;
    const wrapper = document.createElement("div");
    wrapper.className = "chat chat-start";
    const bubble = document.createElement("div");
    bubble.className = "chat-bubble chat-bubble-error whitespace-pre-wrap";
    bubble.textContent = `Error (corr: ${this.correlationIdValue || "unknown"}): ${message}. You can retry or switch model.`;
    wrapper.appendChild(bubble);
    this.streamTarget.appendChild(wrapper);
    this.scroll();
  }
});
