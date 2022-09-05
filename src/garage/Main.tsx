import { onMount } from 'solid-js'
// @ts-ignore
import { Elm } from './Main.elm'
import Split from 'split.js'
import * as Comlink from 'comlink'
// @ts-ignore
import { applyTheme } from './themes'
import { captureMessage } from '@sentry/browser'
import { checkCompatibility } from './checkCompatibility'
import { Lang } from './types'

export const THEMES = ['light', 'dark'] as const
export type Theme = typeof THEMES[number]

export const KEYMAPS = ['default', 'sublime', 'emacs', 'vim'] as const
export type Keymap = typeof KEYMAPS[number]

export interface Settings {
  theme: Theme
  keyMap: Keymap
}

type Id = number

export interface SiteInfo {
  user: string
  userId: Id
  robot: string
  robotId: Id
}

interface MainProps {
  code: string
  lang: Lang
  siteInfo: SiteInfo | null
  assetsPath: string
  workerUrl: string
}

interface Command<T> {
  send: (params: T) => void
}

interface Subscription<T> {
  subscribe: (cb: (params: T) => void) => void
}

interface EvalInfo {
  code: string
  lang: Lang
}

interface SimulationSettings {
  initialUnitNum: number
  recurrentUnitNumber: number
  spawnEvery: number
}

interface ElmAppPorts {
  getOutput: Command<any>
  getProgress: Command<any>
  getInternalError: Command<null>
  finishedDownloading: Command<null>
  finishedLoading: Command<null>
  getTooLong: Command<null>
  confirmSelectLang: Command<string>
  startEval: Subscription<{
    evalInfo: EvalInfo
    opponentEvalInfo: EvalInfo
    turnNum: number
    settings: SimulationSettings | null
  }>
  reportDecodeError: Subscription<string>
  reportApiError: Subscription<string>
  savedCode: Subscription<string>
  saveSettings: Subscription<Settings>
  selectLang: Subscription<Lang>
}

interface ElmApp {
  ports: ElmAppPorts
}

interface RunParams {
  assetsPath: string
  evalInfo1: any
  evalInfo2: any
  turnNum: number
  settings: SimulationSettings | null
}

interface MatchWorker {
  init: (assetsPath: string, lang: Lang, finishDownloadCb: () => void) => any

  run: (
    { assetsPath, evalInfo1, evalInfo2, turnNum, settings }: RunParams,
    cb: (data: any) => void,
  ) => any
}

const Main = (props: MainProps) => {
  let battleViewerRef: HTMLDivElement

  onMount(() => {
    init(
      battleViewerRef,
      props.code,
      props.lang,
      props.siteInfo,
      props.assetsPath,
      props.workerUrl,
    )
  })

  return <div ref={battleViewerRef!} />
}

declare global {
  interface Window {
    savedCode: string
    code: string
  }
}

function init(
  node: HTMLElement,
  code: string,
  lang: Lang,
  siteInfo: SiteInfo | null,
  assetsPath: string,
  workerUrl: string,
) {
  const settings = loadSettings()
  applyTheme(settings.theme)

  const apiContext = createApiContext(siteInfo, assetsPath)

  const [compatible, incompatibilityWarning] = checkCompatibility(lang)

  if (incompatibilityWarning) {
    code = incompatibilityWarning + code
  }

  const app = Elm.Main.init({
    node,
    flags: {
      code,
      lang,
      apiContext,
      settings,
      team: 'Blue',
      unsupported: !compatible,
      tutorial: null,
    },
  }) as ElmApp

  if (compatible) {
    initWorker(workerUrl, app, apiContext.paths.assets, lang).then()
  }

  initSplit(false)

  app.ports.saveSettings.subscribe((settings) => {
    window.localStorage.setItem('settings', JSON.stringify(settings))
  })

  window.savedCode = code
  app.ports.savedCode.subscribe((code) => {
    window.savedCode = code
  })

  app.ports.reportDecodeError.subscribe((error) => {
    console.log('Decode Error!', error)
    captureMessage('Garage decode error: ' + error)
  })

  app.ports.reportApiError.subscribe((error) => {
    console.log('Api Error!', error)
    captureMessage('Garage Api error:' + error)
  })

  window.onbeforeunload = () => {
    if (window.code && window.code !== window.savedCode) {
      return "You've made unsaved changes."
    }
    return undefined
  }
}

function createApiContext(siteInfo: SiteInfo | null, assetsPath: string) {
  return {
    siteInfo,
    paths: {
      getUserRobots: '/api/get-user-robots',
      getDevCode: '/api/get-dev-code',
      getPublishedCode: '/api/get-published-code',
      updateRobotCode: '/api/update-robot-code',
      viewRobot: '/api/view-robot-by-id',
      viewUser: '',
      editRobot: '/api/edit-robot-by-id',
      publish: '/boards',
      assets: assetsPath,
    },
  }
}

const DEFAULT_SETTINGS = {
  theme: 'Light',
  keyMap: 'Default',
}

function loadSettings() {
  let settings = DEFAULT_SETTINGS
  const storedSettings = localStorage.getItem('settings')
  if (storedSettings) {
    try {
      settings = JSON.parse(storedSettings) as Settings
    } catch (_e) {}
  }
  return settings
}

export function initSplit(tutorial: boolean) {
  // we need to make sure that the tutorial loaded successfully
  if (tutorial && document.querySelector('._tutorial')) {
    Split(['._tutorial', '._ui'], {
      sizes: [25, 40],
      minSize: [300, 650],
      gutterSize: 5,
      gutter: () => document.querySelector('.gutter-1')!,
    })

    Split(['._ui', '._viewer'], {
      sizes: [40, 35],
      minSize: [650, 650],
      gutterSize: 5,
      gutter: () => document.querySelector('.gutter-2')!,
    })
  } else {
    Split(['._ui', '._viewer'], {
      sizes: [60, 40],
      minSize: [650, 650],
      gutterSize: 5,
      gutter: () => document.querySelector('.gutter-2')!,
    })
  }
}

async function initWorker(
  workerUrl: string,
  app: ElmApp,
  assetsPath: string,
  lang: Lang,
) {
  let workerRunning = false
  let done = false

  const checkTime = (stage: string) => {
    const startTime = Date.now()
    const checkEvery = 1000
    const tooLong = 15 * checkEvery
    done = false

    // tell elm when a process is taking a while
    // keeps track of whether a task is done with done
    const cb = () => {
      console.log(`Loading for: ${(Date.now() - startTime) / 1000} seconds`)
      if (!done) {
        if (Date.now() - startTime > tooLong) {
          captureMessage(`Taking too long at stage: ${stage}`)
          app.ports.getTooLong.send(null)
        } else {
          setTimeout(cb, checkEvery)
        }
      }
    }

    setTimeout(cb, checkEvery)
  }

  const createWorker = async (lang: Lang): Promise<[Worker, MatchWorker]> => {
    // ---- start time check ----
    checkTime('compilation')

    const rawWorker = new Worker(workerUrl)
    const MatchWorker = Comlink.wrap(rawWorker)
    // @ts-ignore
    const worker = (await new MatchWorker()) as MatchWorker

    await worker.init(
      assetsPath,
      lang,
      Comlink.proxy(() => {
        app.ports.finishedDownloading.send(null)
      }),
    )
    app.ports.finishedLoading.send(null)

    // ---- end time check ----
    done = true

    return [rawWorker, worker]
  }

  let [rawWorker, worker] = await createWorker(lang)

  app.ports.startEval.subscribe(
    ({ evalInfo, opponentEvalInfo, turnNum, settings }) => {
      if (!workerRunning) {
        workerRunning = true

        // ---- start time check ----
        checkTime('initialization')

        worker.run(
          {
            assetsPath,
            evalInfo1: evalInfo, // blue
            evalInfo2: opponentEvalInfo, // red
            turnNum,
            settings,
          },
          Comlink.proxy(runCallback),
        )
      }
    },
  )

  const runCallback = (data: any) => {
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
      // @ts-ignore
      app.ports[data.type].send(data.data)
    } else {
      throw new Error(`Unknown message type ${data.type}`)
    }
  }

  // in the demo, you can select the lang
  app.ports.selectLang.subscribe(async (lang) => {
    if (
      confirm(
        'Are you sure that you want to switch the robot language? This will clear your code.',
      )
    ) {
      app.ports.confirmSelectLang.send(lang)

      rawWorker.terminate()
      const res = await createWorker(lang)
      rawWorker = res[0]
      worker = res[1]
    }
  })
}

export default Main
