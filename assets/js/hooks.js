let Hooks = {}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

// Keeps a container scrolled to the bottom when new children appear
Hooks.AutoScroller = {
    mounted() {
        this._raf = null
        this._jumpToEnd = () => {
            cancelAnimationFrame(this._raf)
            this._raf = requestAnimationFrame(() => {
                this.el.scrollTo({ top: this.el.scrollHeight, behavior: "smooth" })
            })
        }
        this._watcher = new MutationObserver(this._jumpToEnd)
        this._watcher.observe(this.el, { childList: true, subtree: true })
        this._jumpToEnd()
    },
    updated() { this._jumpToEnd() },
    destroyed() {
        this._watcher.disconnect()
        cancelAnimationFrame(this._raf)
    }
}

// Manages the copilot text input: auto-resize, Enter-to-send, @-mention detection
Hooks.InputAssistant = {
    mounted() {
        this._input = this.el.querySelector("textarea")
        if (!this._input) return

        // Auto-grow the textarea as user types
        const autoGrow = () => {
            this._input.style.height = "0"
            const next = Math.min(this._input.scrollHeight, 140)
            this._input.style.height = next + "px"
        }

        // Check for @mention pattern while typing
        const checkForMention = () => {
            const pos = this._input.selectionStart
            const preceding = this._input.value.slice(0, pos)
            const mentionMatch = preceding.match(/@(\w{2,})$/)
            if (mentionMatch) {
                this.pushEvent("mention_lookup", { q: mentionMatch[1] })
            } else {
                this.pushEvent("dismiss_mentions", {})
            }
        }

        this._input.addEventListener("input", () => { autoGrow(); checkForMention() })

        // Enter sends, Shift+Enter inserts newline
        this._input.addEventListener("keydown", (evt) => {
            if (evt.key === "Enter" && !evt.shiftKey) {
                evt.preventDefault()
                this._dispatch()
            }
        })

        // Button-triggered send via custom DOM event
        this.el.addEventListener("dispatch-question", () => this._dispatch())

        // "Add context" inserts @ into textarea and triggers mention lookup
        this.el.addEventListener("insert-at-symbol", () => {
            const pos = this._input.selectionStart || this._input.value.length
            const before = this._input.value.slice(0, pos)
            const after = this._input.value.slice(pos)
            this._input.value = before + "@" + after
            this._input.selectionStart = pos + 1
            this._input.selectionEnd = pos + 1
            this._input.focus()
            autoGrow()
        })

        // When server pins a contact, splice name into textarea
        this.handleEvent("contact_pinned", ({ label }) => {
            const val = this._input.value
            const caret = this._input.selectionStart
            const head = val.slice(0, caret).replace(/@\w*$/, `@${label} `)
            const tail = val.slice(caret)
            this._input.value = head + tail
            this._input.selectionStart = head.length
            this._input.selectionEnd = head.length
            this._input.focus()
            autoGrow()
        })

        autoGrow()
    },

    _dispatch() {
        const text = (this._input.value || "").trim()
        if (text.length === 0) return
        this.pushEvent("submit_question", { question: text })
        this._input.value = ""
        this._input.style.height = "auto"
        this.pushEvent("dismiss_mentions", {})
    }
}

export default Hooks
