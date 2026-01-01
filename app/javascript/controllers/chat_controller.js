import { Controller } from "@hotwired/stimulus"

// Keeps the chat pinned to the newest message.
// - Scrolls on connect
// - Scrolls on Turbo-stream updates (append/replace)
// - Clears the textarea after successful submit
export default class extends Controller {
  static targets = ["stream", "input"]

  connect() {
    this.debugEnabled = new URLSearchParams(window.location.search).get("debug") === "1"
    this.debug("connected", {
      turboDefined: typeof window.Turbo !== "undefined",
      cableStreamSourceDefined: typeof customElements !== "undefined" && !!customElements.get("turbo-cable-stream-source"),
      actionCableUrlMeta: document.querySelector("meta[name='action-cable-url']")?.content
    })

    this.scrollToBottom()

    // Track whether the user is "following" the bottom of the chat.
    // IMPORTANT: during streaming we replace the last bubble repeatedly.
    // If we compute "near bottom" *after* a replace, the user will suddenly
    // be considered "not near bottom" because the content grew.
    // So we persist this intent based on scroll position *before* updates.
    this.userNearBottom = true

    this.onScroll = this.onScroll.bind(this)
    if (this.hasStreamTarget) this.streamTarget.addEventListener("scroll", this.onScroll)

    this.onTurboStream = (event) => {
      // Fires for each incoming turbo-stream before it is rendered.
      const streamElement = event.target

      const wasNearBottom = this.userNearBottom

      // Ensure we keep the view pinned while the user is following the bottom,
      // even when the last message is being replaced repeatedly.
      if (wasNearBottom && event.detail?.render) {
        const originalRender = event.detail.render
        event.detail.render = (...args) => {
          originalRender(...args)
          this.scrollToBottom()
        }
      }

      this.debug("turbo:before-stream-render", {
        action: streamElement.getAttribute?.("action"),
        target: streamElement.getAttribute?.("target")
      })
    }
    document.addEventListener("turbo:before-stream-render", this.onTurboStream)

    if (this.hasStreamTarget) {
      this.observer = new MutationObserver(() => {
        // Only auto-scroll if the user is already near the bottom.
        if (this.isNearBottom()) this.scrollToBottom()
      })
      this.observer.observe(this.streamTarget, { childList: true, subtree: true })
    }
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.hasStreamTarget && this.onScroll) this.streamTarget.removeEventListener("scroll", this.onScroll)
    if (this.onTurboStream) document.removeEventListener("turbo:before-stream-render", this.onTurboStream)
  }

  afterSubmit(event) {
    if (!event.detail.success) return
    if (this.hasInputTarget) this.inputTarget.value = ""
    this.scrollToBottom()

    this.debug("turbo:submit-end", {
      success: event.detail.success,
      fetchResponseStatus: event.detail.fetchResponse?.response?.status
    })
  }

  // Submit on Enter, but allow newline with Shift+Enter.
  maybeSubmit(event) {
    if (event.key !== "Enter") return
    if (event.shiftKey) return

    event.preventDefault()

    const form = this.element.querySelector("form")
    if (form) form.requestSubmit()
  }

  scrollToBottom() {
    if (!this.hasStreamTarget) return

    // Pin the scroll container to the bottom.
    // Using `scrollIntoView` can cause a slow “creep” during frequent updates.
    this.streamTarget.scrollTop = this.streamTarget.scrollHeight
  }

  onScroll() {
    this.userNearBottom = this.isNearBottom()
  }

  isNearBottom() {
    if (!this.hasStreamTarget) return true
    const threshold = 120
    const { scrollTop, clientHeight, scrollHeight } = this.streamTarget
    return scrollHeight - (scrollTop + clientHeight) < threshold
  }

  debug(message, payload = {}) {
    if (!this.debugEnabled) return
    // eslint-disable-next-line no-console
    console.log("[chat_controller]", message, payload)
  }
}
