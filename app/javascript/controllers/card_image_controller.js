import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "input", "file", "remove", "error"]
  static values = { savedUrl: String }

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete) {
      this.imageTarget.naturalWidth > 0 ? this.loaded() : this.failed()
    }
  }

  disconnect() {
    this.releasePreview()
  }

  loaded() {
    this.element.classList.add("has-card-image")
  }

  failed() {
    this.element.classList.remove("has-card-image")
  }

  releasePreview() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }

  preview() {
    this.failed()
    this.releasePreview()
    if (this.hasErrorTarget) this.errorTarget.hidden = true
    const file = this.hasFileTarget ? this.fileTarget.files[0] : null
    if (this.hasFileTarget) this.fileTarget.setCustomValidity("")
    if (file) {
      if (!["image/png", "image/jpeg", "image/webp"].includes(file.type) || file.size > 5 * 1024 * 1024) {
        const message = "Bitte PNG, JPG oder WebP mit maximal 5 MB auswählen."
        this.fileTarget.setCustomValidity(message)
        this.errorTarget.textContent = message
        this.errorTarget.hidden = false
        this.imageTarget.removeAttribute("src")
        return
      }
      this.objectUrl = URL.createObjectURL(file)
      this.imageTarget.src = this.objectUrl
      return
    }
    if (this.savedUrlValue && !(this.hasRemoveTarget && this.removeTarget.checked)) {
      this.imageTarget.src = this.savedUrlValue
      return
    }
    const value = this.inputTarget.value.trim()
    try {
      const url = new URL(value)
      if (url.protocol !== "https:" || url.username || url.password) throw new Error("Invalid image URL")
      this.imageTarget.src = url.href
      if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) this.loaded()
    } catch {
      this.imageTarget.removeAttribute("src")
    }
  }
}
