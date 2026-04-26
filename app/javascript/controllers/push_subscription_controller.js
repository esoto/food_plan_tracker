import { Controller } from "@hotwired/stimulus"

// Wires up the "Enable reminders" button on /settings.
//
// The flow:
//   1. Ask the browser for Notification permission (must be a user gesture).
//   2. Register the service worker if it isn't already.
//   3. Subscribe with the server's VAPID public key.
//   4. POST the subscription JSON to the Rails app.
//   5. Flip the UI to a "Disable" state.
//
// The VAPID public key arrives via a data attribute the view embeds. We
// don't ship the key in JS source so it can rotate without a deploy.
export default class extends Controller {
  static values = { vapidPublicKey: String, enabled: Boolean }
  static targets = [ "status", "toggleButton" ]

  connect() {
    this.refreshFromBrowser().catch((err) => {
      this.setStatus(`Couldn't read subscription state: ${err.message}`)
    })
  }

  async enable() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.setStatus("Push isn't supported in this browser. Add the app to your home screen on iOS 16.4+.")
      return
    }

    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      this.setStatus("Notifications denied. Re-enable in your browser settings to subscribe.")
      return
    }

    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const res = await fetch("/push_subscriptions", {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrf || ""
        },
        body: JSON.stringify(sub.toJSON())
      })

      if (!res.ok) throw new Error(`server returned ${res.status}`)

      this.enabledValue = true
      this.setStatus("Reminders enabled on this device.")
    } catch (err) {
      this.setStatus(`Subscription failed: ${err.message}`)
    }
  }

  async disable() {
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        const endpoint = sub.endpoint
        await sub.unsubscribe()

        const csrf = document.querySelector('meta[name="csrf-token"]')?.content
        await fetch("/push_subscriptions", {
          method: "DELETE",
          credentials: "same-origin",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrf || ""
          },
          body: JSON.stringify({ endpoint })
        })
      }

      this.enabledValue = false
      this.setStatus("Reminders disabled on this device.")
    } catch (err) {
      this.setStatus(`Unsubscribe failed: ${err.message}`)
    }
  }

  async refreshFromBrowser() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.setStatus("Push isn't supported in this browser.")
      return
    }
    const reg = await navigator.serviceWorker.ready
    const sub = await reg.pushManager.getSubscription()
    this.enabledValue = !!sub
  }

  enabledValueChanged() {
    if (!this.hasToggleButtonTarget) return
    if (this.enabledValue) {
      this.toggleButtonTarget.textContent = "Disable reminders"
      this.toggleButtonTarget.dataset.action = "click->push-subscription#disable"
    } else {
      this.toggleButtonTarget.textContent = "Enable reminders"
      this.toggleButtonTarget.dataset.action = "click->push-subscription#enable"
    }
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  // VAPID public keys are URL-safe base64. The Push API expects a Uint8Array.
  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = atob(base64)
    const out = new Uint8Array(raw.length)
    for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i)
    return out
  }
}
