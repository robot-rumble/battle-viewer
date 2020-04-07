import { Elm } from './Main.elm'
import './css/app.scss'

import sampleRobot from './robots/sample.raw.py'
import './codemirror'

window.turnNum = 10
window.language = 'python'
window.runCount = 0

customElements.define('robot-arena', class extends HTMLElement {
  connectedCallback () {
    // https://www.playframework.com/documentation/2.5.x/ScalaJavascriptRouting#Javascript-Routing
    if (!window.jsRoutes) {
      throw new Error('No Play JS router found.')
    }

    const user = this.getAttribute('user')
    const robot = this.getAttribute('robot')
    const updatePath = user && robot && window.jsRoutes.controllers.RobotController.update(user, robot).url

    window.a = this.getAttribute('code')
    // to fix the serialization that happens when we pass a string as an attribute
    const code = this.getAttribute('code') ? JSON.parse(this.getAttribute('code')) : sampleRobot

    const app = Elm.Main.init({
      node: this,
      flags: {
        totalTurns: window.turnNum,
        updatePath,
        code,
      },
    })

    const matchWorker = new Worker('/assets/dist/worker.js')

    app.ports.startEval.subscribe((code1) => {
      window.runCount++
      matchWorker.postMessage({ code1, code2: code1, turnNum: 20 })
    })

    matchWorker.onmessage = ({ data }) => {
      if (data.type === 'error') {
        console.log('Worker Error!')
        console.error(data.data)
        app.ports.getInternalError.send(null)
      } else {
        // we pass all other data, including other errors, to the elm app
        console.log(data)
        app.ports[data.type].send(data.data)
      }
    }

    app.ports.reportDecodeError.subscribe((error) => {
      console.log('Decode Error!')
      console.error(error)
    })
  }
})
