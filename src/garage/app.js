import * as Comlink from 'comlink'
import Split from 'split.js'

import './codemirror'
import { applyTheme } from './themes'
import { Elm } from './Main.elm'
import { captureMessage } from '../sentry'

function createApiContext(siteInfo, assetsPath) {
  return {
    siteInfo,
    paths: {
      getUserRobots: '/api/get-user-robots',
      getRobotCode: '/api/get-robot-code',
      updateRobotCode: '/api/update-robot-code',
      viewRobot: '/api/view-robot-by-id',
      editRobot: '/api/edit-robot-by-id',
      publish: '/boards',
      assets: assetsPath,
    },
  }
}

function loadSettings() {
  let settings
  try {
    settings = JSON.parse(localStorage.getItem('settings'))
  } catch (e) {
    settings = null
  }
  if (!settings) {
    settings = {
      theme: 'Light',
      keyMap: 'Default',
    }
  }
  return settings
}

if (process.env.NODE_ENV !== 'production' && module.hot) {
  import('./main.scss')

  if (!process.env.BOT_LANG) {
    throw new Error('You must specify the robot language through the "BOT_LANG" env var.')
  }

  init(
    document.querySelector('#root'),
    '',
    'Python',
    createApiContext(null, ''),
    'dist/worker.js',
  )

  module.hot.addStatusHandler(initSplit)
}

customElements.define(
  'garage-el',
  class extends HTMLElement {
    connectedCallback() {
      const user = this.getAttribute('user')
      const userId = parseInt(this.getAttribute('userId'))
      const robot = this.getAttribute('robot')
      const robotId = parseInt(this.getAttribute('robotId'))

      let siteInfo = null
      if (user && userId && robot && robotId) {
        // we're in the normal garage
        siteInfo = {
          user,
          userId,
          robot,
          robotId,
        }
      } else if (user || userId || robot || robotId) {
        throw new Error('Missing some but not all of user|userId|robot|robotId attributes')
      } else {
        // we're in demo mode
      }

      const lang = this.getAttribute('lang') || 'Python'
      const code = this.getAttribute('code') || ''

      const assetsPath = this.getAttribute('assetsPath')
      if (!assetsPath) {
        throw new Error('No assetsPath attribute found')
      }

      init(
        this,
        code,
        lang,
        createApiContext(siteInfo, assetsPath),
        // get around the same-origin rule for loading workers through a cloudflare proxy worker
        // that rewrites robotrumble.org/assets to cloudfront
        // this is not necessary anywhere else because normal assets don't have this security rule
        process.env.NODE_ENV === 'production'
          ? 'https://robotrumble.org/assets/worker-assets/worker.js'
          : assetsPath + '/dist/worker.js',
      )
    }
  },
)

function init(node, code, lang, apiContext, workerUrl) {
  const settings = loadSettings()
  applyTheme(settings.theme)

  const app = Elm.Main.init({
    node,
    flags: {
      code,
      lang,
      apiContext,
      settings,
      team: 'Blue',
    },
  })

  initSplit()
  initWorker(workerUrl, app, apiContext.paths.assets, lang).then()

  app.ports.saveSettings.subscribe((settings) => {
    window.localStorage.setItem('settings', JSON.stringify(settings))
  })

  window.savedCode = code
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
  let workerRunning = false
  let done = false

  const checkTime = (stage) => {
    const startTime = Date.now()
    const checkEvery = 1000
    const tooLong = 10 * checkEvery
    done = false

    // tell elm when a process is taking a while
    // keeps track of whether a task is done with done
    const cb = () => {
      console.log(`Loading for: ${(Date.now() - startTime) / 1000} seconds`)
      if (!done) {
        if (Date.now() - startTime > tooLong) {
          captureMessage(`Taking too long at stage: ${stage}`, '')
          app.ports.getTooLong.send(null)
        } else {
          setTimeout(cb, checkEvery)
        }
      }
    }

    setTimeout(cb, checkEvery)
  }

  const createWorker = async (lang) => {
    // ---- start time check ----
    checkTime('compilation')

    const rawWorker = new Worker(workerUrl)
    const MatchWorker = Comlink.wrap(rawWorker)
    const worker = await new MatchWorker()

    await worker.init(assetsPath, lang, Comlink.proxy(() => {
      app.ports.finishedDownloading.send(null)
    }))
    app.ports.finishedLoading.send(null)

    // ---- end time check ----
    done = true

    return [rawWorker, worker]
  }

  let [rawWorker, worker] = await createWorker(lang)

  app.ports.startEval.subscribe(({
    code,
    opponentCode,
    turnNum,
  }) => {
    if (!workerRunning) {
      workerRunning = true

      // ---- start time check ----
      checkTime('initialization')

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
      // ---- end time check ----
      done = true
      workerRunning = false

      app.ports.getInternalError.send(null)
      console.log('Worker Error!')
      captureMessage('Garage worker error', data.data)
    } else if (data.type in app.ports) {
      // ---- end time check ----
      done = true
      if (data.type === 'getOutput') workerRunning = false

      // we pass all other data, including other errors, to the elm app
      console.log(data)
      app.ports[data.type].send(data.data)
    } else {
      throw new Error(`Unknown message type ${data.type}`)
    }
  }

  // in the demo, you can select the lang
  app.ports.selectLang.subscribe(async (lang) => {
    rawWorker.terminate()
    const res = await createWorker(lang)
    rawWorker = res[0]
    worker = res[1]
  })

  app.ports.reportDecodeError.subscribe((error) => {
    console.log('Decode Error!')
    captureMessage('Garage decode error', error)
  })

  app.ports.reportApiError.subscribe((error) => {
    console.log('Api Error!')
    captureMessage('Garage Api error', error)
  })
}
