import { Elm } from './Main.elm'

import './codemirror'
import { applyTheme } from './themes'
import * as Comlink from 'comlink'

import Split from 'split.js'

import * as Sentry from '@sentry/browser'
import { Integrations } from '@sentry/tracing'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  integrations: [new Integrations.BrowserTracing()],

  // Set tracesSampleRate to 1.0 to capture 100%
  // of transactions for performance monitoring.
  // We recommend adjusting this value in production
  tracesSampleRate: 1.0,
})

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
      robot: `/${user}/${robot}`,
      boards: '/boards',
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

  if (!process.env.BOT_LANG) {
    throw new Error('You must specify the robot language through the "BOT_LANG" env var.')
  }

  init(
    document.querySelector('#root'),
    {
      user: 'asdf',
      robot: 'asdf',
      robotId: 0,
      ...createRoutes('asdf', 'asdf', 0, ''),
      code: '',
    },
    'dist/worker.js',
    process.env.BOT_LANG,
    '',
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
      init(
        this,
        {
          user,
          robot,
          robotId,
          ...createRoutes(user, robot, robotId, assetsPath),
          code,
        },
        // get around the same-origin rule for loading workers through a cloudflare proxy worker
        // that rewrites robotrumble.org/assets to cloudfront
        // this is not necessary anywhere else because normal assets don't have this security rule
        process.env.NODE_ENV === 'production'
          ? 'https://robotrumble.org/assets/worker-assets/worker.js'
          : assetsPath + '/dist/worker.js',
        lang,
        assetsPath,
      )
    }
  },
)

function init(node, flags, workerUrl, lang, assetsPath) {
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
      team: 'Blue',
    },
  })

  initSplit()
  initWorker(workerUrl, app, assetsPath, lang)

  app.ports.saveSettings.subscribe((settings) => {
    window.localStorage.setItem('settings', JSON.stringify(settings))
  })

  window.savedCode = flags.code
  app.ports.savedCode.subscribe((code) => {
    window.savedCode = code
  })

  window.onbeforeunload = () => {
    if (window.code && window.code !== window.savedCode) {
      return 'You\'ve made unsaved changes.'
    }
  }
}

function initSplit() {
  Split(['._ui', '._viewer'], {
    sizes: [60, 40],
    minSize: [600, 400],
    gutterSize: 5,
    gutter: () => document.querySelector('.gutter'),
  })
}

async function initWorker(workerUrl, app, assetsPath, lang) {
  const MatchWorker = Comlink.wrap(new Worker(workerUrl))
  const worker = await new MatchWorker()
  await worker.init(assetsPath, lang, Comlink.proxy(() => {
    app.ports.finishedDownloading.send(null)
  }))
  app.ports.finishedLoading.send(null)

  let workerRunning = false
  app.ports.startEval.subscribe(({ code, opponentCode, turnNum }) => {
    if (!workerRunning) {
      workerRunning = true
      worker.run({
        assetsPath,
        code1: code, // blue
        code2: opponentCode, // red
        turnNum,
      }, Comlink.proxy(runCallback))
    }
  })

  const runCallback = (data) => {
    if (data.type === 'error') {
      const error = JSON.parse(data.data)
      console.log('Worker Error!')
      console.error(error)
      Sentry.captureMessage(error)
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
    Sentry.captureMessage(error)
  })
}

