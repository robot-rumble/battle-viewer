import { Elm } from './Main.elm'

customElements.define(
  'battle-el',
  class extends HTMLElement {
    connectedCallback() {
      const data = this.getAttribute('data')
      const team = this.getAttribute('team') || null
      if (!data) {
        throw new Error('No data attribute found')
      }
      console.log(data)

      Elm.Main.init({
        node: this,
        flags: { data: JSON.parse(data), team },
      })
    }
  },
)
