// import Reveal from "stimulus-reveal-controller";

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    super.connect()
  }

  toggle() {
    document.body.classList.toggle('sidebar--opened')
  }
}