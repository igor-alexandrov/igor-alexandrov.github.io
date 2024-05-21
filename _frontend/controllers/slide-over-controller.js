// import Reveal from "stimulus-reveal-controller";

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  initialize() {
    this.opened = false
  }

  toggle() {
    if (this.opened) {
      this.#close()
    } else {
      this.#open()
    }
  }

  #open() {
    document.body.classList.add('sidebar-opened')
    document.addEventListener("keydown", (e) => {
      if (e.key == "Escape") {
        this.#close()
      }
    }, { once: true });

    this.opened = true
  }

  #close() {
    document.body.classList.remove('sidebar-opened')
    this.opened = false
  }
}