import { Elm } from './Main.elm'
import './css/app.scss'

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

    const robot = new URL(window.location.href).pathname.slice(1)

    const app = Elm.Main.init({
      node: this,
      flags: {
        totalTurns: window.turnNum,
        updatePath: robot ? window.jsRoutes.controllers.RobotController.postCreate(robot).url : null,
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
      } else if (data.type in app.ports) {
        // we pass all other data, including other errors, to the elm app
        console.log(data)
        app.ports[data.type].send(data.data)
      } else {
        throw new Error(`Unknown message type ${data.type}`)
      }
    }

    app.ports.reportDecodeError.subscribe((error) => {
      console.log('Decode Error!')
      console.error(error)
    })
  }
})
