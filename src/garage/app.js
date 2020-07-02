import { Elm } from './Main.elm'

import './codemirror'
import { applyTheme } from './themes'

import Split from 'split.js'

window.runCount = 0

function loadSettings() {
  let settings
  try {
    settings = JSON.parse(localStorage.getItem('settings'))
  } catch (e) {
    settings = null
  }
  if (!settings) {
    settings = { theme: 'Light', keyMap: 'Default' }
  }
  return settings
}

function createRoutes(user, robot, robotId, assetsPath) {
  return {
    paths: {
      robot: `/p/${user}/${robot}`,
      publish: `/publish/${robotId}`,
      assets: assetsPath,
    },
    apiPaths: {
      getUserRobots: `/api/get-user-robots`,
      getRobotCode: `/api/get-robot-code`,
      updateRobotCode: `/api/update-robot-code`,
    },
  }
}

if (process.env.NODE_ENV !== 'production' && module.hot) {
  import('./main.scss')

  init(
    document.querySelector('#root'),
    {
      user: 'asdf',
      robot: 'asdf',
      robotId: 0,
      ...createRoutes('asdf', 'asdf', 0),
      code: '',
    },
    'dist/worker.js',
    'Python',
  )

  module.hot.addStatusHandler(initSplit)
}

customElements.define(
  'garage-el',
  class extends HTMLElement {
    connectedCallback() {
      const user = this.getAttribute('user')
      const robot = this.getAttribute('robot')
      const robotId = parseInt(this.getAttribute('robotId'))
      const lang = this.getAttribute('lang')
      const code = this.getAttribute('code')
      const assetsPath = this.getAttribute('assetsPath')
      if (!user || !robot || !robotId || !lang || !code) {
        throw new Error('No user|robot|robotId|lang|code attribute found')
      }
      const routes = createRoutes(user, robot, robotId, assetsPath)

      init(
        this,
        {
          user,
          robot,
          robotId,
          ...routes,
          code,
        },
        routes.paths.assets + '/dist/worker.js',
        lang,
      )
    }
  },
)

function initSplit() {
  Split(['._ui', '._viewer'], {
    sizes: [60, 40],
    minSize: [600, 400],
    gutterSize: 5,
    gutter: () => document.querySelector('.gutter'),
  })
}

function init(node, flags, workerUrl, lang) {
  // set window vars first so CodeMirror has access to them on init
  window.lang = lang

  const settings = loadSettings()
  applyTheme(settings.theme)
  window.settings = settings

  const app = Elm.Main.init({
    node,
    flags: {
      ...flags,
      settings,
      lang,
      code: flags.code,
    },
  })

  initSplit()

  const matchWorker = new Worker(workerUrl)

  let workerRunning = false
  app.ports.startEval.subscribe(({ code, opponentCode, turnNum }) => {
    window.runCount++
    if (!workerRunning) {
      workerRunning = true
      matchWorker.postMessage({
        assetsPath: flags.paths.assets,
        code1: code,
        code2: opponentCode,
        turnNum,
      })
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

  app.ports.saveSettings.subscribe((settings) => {
    window.localStorage.setItem('settings', JSON.stringify(settings))
  })

  window.savedCode = flags.code
  app.ports.savedCode.subscribe((code) => {
    window.savedCode = code
  })

  window.onbeforeunload = () => {
    if (window.code && window.code !== window.savedCode) {
      return "You've made unsaved changes."
    }
  }
}
