import Reveal from "stimulus-reveal-controller";

export default class extends Reveal {
  connect() {
    super.connect()
    console.log('Do what you want here.')
  }

  toggle() {
    super.toggle()

    document.body.classList.toggle('sidebar--opened')
  }
}