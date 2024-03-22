import { Controller } from "@hotwired/stimulus";

export default class NavbarController extends Controller {
  static targets = ["menu"];

  static values = { open: Boolean };

  connect() {
    this.toggleClass = this.data.get("class") || "hidden";
  }

  disconnect() {
    this.hide();
  }

  toggle() {
    this.openValue = !this.openValue;
  }

  openValueChanged() {
    if (this.openValue) {
      this.show();
    } else {
      this.hide();
    }
  }

  show() {
    this.element.classList.add("overflow-hidden", "md:overflow-auto");
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove(this.toggleClass);
    }
  }

  hide() {
    this.element.classList.remove("overflow-hidden", "md:overflow-auto");
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add(this.toggleClass);
    }
  }
}
