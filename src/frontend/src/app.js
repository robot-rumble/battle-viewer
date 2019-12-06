import { Elm } from './Main.elm'
import './css/app.scss'

import './codemirror'

window.turnNum = 10
window.language = 'python'
window.runCount = 0

window.onload = () => {
  const app = Elm.Main.init({
    node: document.getElementById('root'),
    flags: {
      totalTurns: window.turnNum,
    },
  })

  const matchWorker = new window.Worker('/assets/dist/worker.js')

  app.ports.startEval.subscribe((code1) => {
    window.runCount++
    matchWorker.postMessage({ code1, code2: code1, turnNum: 20 })
  })

  matchWorker.onmessage = ({ data }) => {
    if (data.type === 'error') {
      console.log('Worker Error!')
      console.error(data.data)
      app.ports.getError.send(null)
    } else {
      if (data.type === 'getOutput') console.log(data.data)
      app.ports[data.type].send(data.data)
    }
  }

  app.ports.reportDecodeError.subscribe((error) => {
    console.log('Decode Error!')
    console.error(error)
  })
}
