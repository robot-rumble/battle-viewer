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
      code: '',
      team: 'Blue',
      apiContext: {
        paths: {
          getRobotCode: '/getrobotcode',
          getUserRobots: '/getrobots',

          // we don't use this, so w/e
          assets: '',
          updateRobotCode: '',
          viewRobot: '',
          viewUser: '',
          editRobot: '',
          publish: '',
        },
        siteInfo: {
          user: flags.user,
          userId: 0,
          robot: flags.robot,
          robotId: 0,
        },
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

