import { Elm } from './Main.elm'

import defaultJsRobot from './robots/default.raw.js'
import defaultPyRobot from './robots/default.raw.py'

import './codemirror'
import { applyTheme } from './themes'

import Split from 'split.js'

const defaultRobots = {
  JAVASCRIPT: defaultJsRobot,
  PYTHON: defaultPyRobot,
}

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
    apiPaths: {
      getUserRobots: '',
      getRobotCode: '',
    },
    code: '',
    settings: loadSettings(),
  }, 'dist/worker.js', 'PYTHON')

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
    const lang = this.getAttribute('lang')
    if (!user || !robot || !lang) {
      throw new Error('No user|robot|lang attribute found')
    }
    const code = this.getAttribute('code')

    init(
      this,
      {
        paths: {
          robot: window.jsRoutes.controllers.RobotController.view(user, robot).url,
          update: window.jsRoutes.controllers.RobotController.update(user, robot).url,
          publish: window.jsRoutes.controllers.RobotController.publish(user, robot).url,
          asset: window.jsRoutes.controllers.Assets.at('').url,
        },
        apiPaths: {
          getUserRobots: window.jsRoutes.controllers.RobotController.getUserRobots('').url.slice(0, -1),
          getRobotCode: window.jsRoutes.controllers.RobotController.getRobotCode('').url.slice(0, -1),
        },
        user,
        robot,
        code,
        settings: loadSettings(),
      },
      window.jsRoutes.controllers.Assets.at('dist/worker.js').url,
      lang,
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

function init (node, flags, workerUrl, lang) {
  // do this first so CodeMirror has access to it on init
  window.lang = lang

  const app = Elm.Main.init({
    node, flags: { ...flags, code: flags.code || defaultRobots[lang] },
  })

  initSplit()

  const matchWorker = new Worker(workerUrl)

  let workerRunning = false
  app.ports.startEval.subscribe(({ code, opponentCode, turnNum }) => {
    window.runCount++
    if (!workerRunning) {
      workerRunning = true
      matchWorker.postMessage({ code1: code, code2: opponentCode, turnNum, lang: flags.lang })
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
