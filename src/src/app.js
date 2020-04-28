import { Elm } from './Main.elm'

import sampleRobot from './robots/sample.raw.py'
import './codemirror'
import { applyTheme } from './themes'

import Split from 'split.js'

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

if (process.env.NODE_ENV !== 'production' && module.hot) {
  import('./css/webapp.scss')

  init(document.querySelector('#root'), {
    user: 'asdf',
    robot: 'asdf',
    paths: {
      robot: '',
      update: '',
      publish: '',
      asset: '/',
    },
    settings: loadSettings(),
    code: sampleRobot,
  }, 'dist/worker.js')

  module.hot.addStatusHandler(initSplit)
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
    const paths = {
      robot: window.jsRoutes.controllers.RobotController.view(user, robot).url,
      update: window.jsRoutes.controllers.RobotController.update(user, robot).url,
      publish: window.jsRoutes.controllers.RobotController.publish(user, robot).url,
      asset: window.jsRoutes.controllers.Assets.at('').url,
    }
    const code = this.getAttribute('code') || sampleRobot

    init(
      this,
      {
        robot,
        paths,
        code,
        settings: loadSettings(),
      },
      window.jsRoutes.controllers.Assets.at('dist/worker.js').url,
    )
  }
})

function initSplit () {
  Split(['._ui', '._viewer'], {
    sizes: [60, 40],
    minSize: [600, 400],
    gutterSize: 5,
    gutter: () => document.querySelector('.gutter'),
  })
}

function init (node, flags, workerUrl) {
  const app = Elm.Main.init({
    node, flags,
  })

  initSplit()

  const matchWorker = new Worker(workerUrl)

  let workerRunning = false
  app.ports.startEval.subscribe(({ code, turnNum }) => {
    window.runCount++
    if (!workerRunning) {
      workerRunning = true
      matchWorker.postMessage({ code1: code, code2: code, turnNum })
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
