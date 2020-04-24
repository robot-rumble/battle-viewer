import { Elm } from './Main.elm'

import sampleRobot from './robots/sample.raw.py'
import './codemirror'
import { applyTheme } from './themes'

import Split from 'split.js'

window.turnNum = 20
window.language = 'python'
window.runCount = 0

function loadSettings () {
  let settings
  try {
    settings = JSON.parse(localStorage.getItem('settings'))
  } catch (e) {
    settings = null
  }
  if (!settings) {
    settings = { theme: 'Light', keyMap: 'Default' }
  }
  applyTheme(settings.theme)
  window.settings = settings
  return settings
}

if (process.env.NODE_ENV !== 'production' && process.env.HOT === '1') {
  import('./css/webapp.scss')

  init(document.querySelector('#root'), {
    totalTurns: window.turnNum,
    robot: 'asdf',
    robotPath: '',
    updatePath: '',
    publishPath: '',
    assetPath: '/',
    settings: loadSettings(),
    code: sampleRobot,
  }, 'worker.js')
}

customElements.define('robot-arena', class extends HTMLElement {
  connectedCallback () {
    // https://www.playframework.com/documentation/2.5.x/ScalaJavascriptRouting#Javascript-Routing
    if (!window.jsRoutes) {
      throw new Error('No Play JS router found')
    }

    const user = this.getAttribute('user')
    const robot = this.getAttribute('robot')
    if (!user || !robot) {
      throw new Error('No user/robot attribute found')
    }

    const robotPath = window.jsRoutes.controllers.RobotController.view(user, robot).url
    const updatePath = window.jsRoutes.controllers.RobotController.update(user, robot).url
    const publishPath = window.jsRoutes.controllers.RobotController.publish(user, robot).url
    const assetPath = window.jsRoutes.controllers.Assets.at('').url

    const code = this.getAttribute('code') || sampleRobot

    init(
      this,
      {
        totalTurns: window.turnNum,
        robot,
        robotPath,
        updatePath,
        publishPath,
        assetPath,
        code,
        settings: loadSettings(),
      },
      window.jsRoutes.controllers.Assets.at('dist/worker.js').url,
    )
  }
})

function init (node, flags, workerUrl) {
  const app = Elm.Main.init({
    node, flags,
  })

  Split(['._ui', '._viewer'], {
    sizes: [60, 40],
    minSize: [600, 400],
    gutterSize: 5,
    gutter: () => document.querySelector('.gutter'),
  })

  const matchWorker = new Worker(workerUrl)

  let workerRunning = false
  app.ports.startEval.subscribe((code1) => {
    window.runCount++
    if (!workerRunning) {
      workerRunning = true
      matchWorker.postMessage({ code1, code2: code1, turnNum: 20 })
    }
  })

  matchWorker.onmessage = ({ data }) => {
    if (data.type === 'error') {
      console.log('Worker Error!')
      console.error(data.data)
      app.ports.getInternalError.send(null)
    } else if (data.type in app.ports) {
      if (data.type === 'getOutput') workerRunning = false

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

  app.ports.saveSettings.subscribe(settings => {
    window.localStorage.setItem('settings', JSON.stringify(settings))
    applyTheme(settings.theme)
  })

  window.savedCode = flags.code
  app.ports.savedCode.subscribe(code => {
    window.savedCode = code
  })

  window.onbeforeunload = () => {
    if (window.code && window.code !== window.savedCode) {
      return 'You\'ve made unsaved changes.'
    }
  }
}
