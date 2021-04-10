import { Elm } from './Main.elm'
import { captureMessage } from '../sentry'

customElements.define(
  'battle-el',
  class extends HTMLElement {
    connectedCallback() {
      const data = this.getAttribute('data')
      const team = this.getAttribute('team') || null
      if (!data) {
        throw new Error('No data attribute found')
      }

      const app = Elm.Main.init({
        node: this,
        flags: { data: JSON.parse(data), team },
      })

      app.ports.reportDecodeError.subscribe((error) => {
        console.log('Decode Error!')
        // don't do console.log or else Sentry will pick that up as a breadcrumb
        captureMessage('Battle viewer decode error', error)
      })
    }
  },
)
