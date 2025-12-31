import { Application, Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js";

const application = Application.start();

application.register("chat", class extends Controller {
  static targets = ["footer", "stream"];

  connect() {
    this.setupKeyboardPadding();
    this.scroll();
  }

  scroll() {
    if (this.hasStreamTarget) {
      this.streamTarget.scrollTop = this.streamTarget.scrollHeight;
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
});
