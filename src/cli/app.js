import { Elm } from './Main.elm'
import { captureMessage } from '../sentry'

import './main.scss'

fetch('/getflags')
  .then(r => r.json())
  .then(init)

function init(flags) {
  const app = Elm.Main.init({
    node: document.getElementById('root'),
    flags: {
      ...flags,
      team: 'Blue',
      // todo: set dynamically
      userId: 0,
      paths: {
        getRobotCode: '/getrobotcode',
        getUserRobots: '/getrobots',
        // we don't use this, so w/e
        updateRobotCode: '',
        viewRobot: '',
        editRobot: '',
      },
    },
  })

  app.ports.startEval.subscribe((params) => {
    const url = new URL('/run', document.location)
    for (const key in params) url.searchParams.set(key, params[key])
    const eventSource = new EventSource(url.href)
    eventSource.addEventListener('message', ({ data }) => {
      const event = JSON.parse(data)
      if (event.type === 'getOutput') eventSource.close()
      app.ports[event.type].send(event.data)
    })
  })

  app.ports.reportDecodeError.subscribe((error) => {
    console.log('Decode Error!')
    captureMessage('Rumblebot web decode error', error)
  })
}

