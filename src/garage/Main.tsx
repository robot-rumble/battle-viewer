import { onMount } from 'solid-js'
// @ts-ignore
import { Elm } from './Main.elm'
import Split from 'split.js'
// @ts-ignore
import { applyTheme } from './themes'
import { captureMessage } from '@sentry/browser'
import { checkCompatibility } from './checkCompatibility'
import { Lang } from './types'
import { CallbackParams, EvalInfo, SimulationSettings } from './match.worker'
import { useStore } from './store'

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

export default Main

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
  const [, actions] = useStore()

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
    const workerCb = (params: CallbackParams) => {
      if (params.type === 'error') {
        app.ports.getInternalError.send(null)
        console.log('Worker Error!')
        captureMessage('Garage worker error' + params.data)
      } else {
        app.ports[params.type].send(params.data)
      }
    }

    actions.initWorker(
      () => app.ports.finishedDownloading.send(null),
      () => app.ports.finishedLoading.send(null),
      () => app.ports.getTooLong.send(null),
      workerCb,
      workerUrl,
    )
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

  app.ports.startEval.subscribe(
    ({ evalInfo, opponentEvalInfo, turnNum, settings }) => {
      actions.startWorker({
        assetsPath,
        evalInfo1: evalInfo, // blue
        evalInfo2: opponentEvalInfo, // red
        turnNum,
        settings,
      })
    },
  )

  app.ports.selectLang.subscribe(async (lang) => {
    if (
      confirm(
        'Are you sure that you want to switch the robot language? This will clear your code.',
      )
    ) {
      app.ports.confirmSelectLang.send(lang)
      actions.changeLang(lang)
    }
  })
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
