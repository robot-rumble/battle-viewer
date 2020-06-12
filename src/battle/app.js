import { Elm } from './Main.elm'

customElements.define(
  'battle-el',
  class extends HTMLElement {
    connectedCallback() {
      const data = this.getAttribute('data')
      if (!data) {
        throw new Error('No data found')
      }

      window.data = data

      Elm.Main.init({
        node: this,
        flags: { data: JSON.parse(data) },
      })
    }
  },
)
