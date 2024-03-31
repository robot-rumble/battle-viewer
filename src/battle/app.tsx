// @ts-ignore
import { Elm } from './Main.elm'
// @ts-ignore
import { captureMessage } from '../sentry'

import { Buffer } from 'buffer'
import decompress from 'brotli/decompress'

customElements.define(
  'battle-el',
  class extends HTMLElement {
    connectedCallback() {
      const rawData = this.getAttribute('data')
      const team = this.getAttribute('team') || null
      const userOwnsOpponent = this.getAttribute('user-owns-opponent')
      const gameMode = this.getAttribute('game-mode')
      if (!rawData || !userOwnsOpponent || !gameMode) {
        throw new Error('No data|userOwnsOpponent|gameMode data attribute found')
      }

      const data = JSON.parse(
        Buffer.from(decompress(Buffer.from(rawData, 'base64'))).toString(
          'utf8',
        ),
      )

      const app = Elm.Main.init({
        node: this,
        flags: {
          data,
          team,
          userOwnsOpponent: userOwnsOpponent === 'true',
          gameMode
        },
      })

      app.ports.reportDecodeError.subscribe((error: string) => {
        console.log('Decode Error!')
        // don't do console.log or else Sentry will pick that up as a breadcrumb
        captureMessage('Battle viewer decode error: ' + error)
      })
    }
  },
)
