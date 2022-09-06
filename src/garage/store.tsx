import { createContext, ParentProps, useContext } from 'solid-js'
import { createStore, SetStoreFunction } from 'solid-js/store'
import { WorkerWrapper } from './workerWrapper'
import { Lang } from './types'
import { CallbackParams, EvalInfo, SimulationSettings } from './match.worker'
import { KeyMap, loadSettings, saveSettings, Settings, Theme } from './settings'
import { applyTheme } from './themes'
import { checkCompatibility } from './checkCompatibility'
import defaultCode from './defaultCode'

export type Id = number

export interface SiteInfo {
  user: string
  userId: Id
  robot: string
  robotId: Id
}

interface State {
  workerWrapper: WorkerWrapper | null
  code: string
  savedCode: string
  lang: Lang
  settings: Settings
  viewingSettings: boolean
  tutorial: boolean
  siteInfo: SiteInfo | null
  assetsPath: string
  workerUrl: string
  compatible: boolean
}

interface ProviderProps {
  assetsPath: string
  workerUrl: string
  code: string
  lang: Lang
  siteInfo: SiteInfo | null
}

const initialState = ({
  code,
  lang,
  assetsPath,
  siteInfo,
  workerUrl,
}: ProviderProps): State => {
  const [compatible, incompatibilityWarning] = checkCompatibility(lang)

  if (incompatibilityWarning) {
    code = incompatibilityWarning + code
  }

  const settings = loadSettings()
  applyTheme(settings.theme)

  return {
    assetsPath,
    workerUrl,
    workerWrapper: null,
    lang,
    code,
    savedCode: code,
    settings,
    viewingSettings: false,
    tutorial: false,
    siteInfo,
    compatible,
  }
}

export const ROUTES = {
  // GET
  docs: 'https://rr-docs.readthedocs.io/en/latest/',
  publish: '/boards',
  viewRobot: (robotId: Id) => '/api/view-robot-by-id/' + robotId,
  viewUser: (userId: Id) => userId,
  getUserRobots: (userId: Id) => '/api/get-user-robots/' + userId,
  getDevCode: (robotId: Id) => '/api/get-dev-code/' + robotId,
  getPublishedCode: (robotId: Id) => '/api/get-published-code/' + robotId,

  // POST
  updateRobotCode: (robotId: Id) => '/api/update-robot-code/' + robotId,
}

const createActions = (state: State, setState: SetStoreFunction<State>) => ({
  synchronizeCode(code: string) {
    setState({ code })
  },
  async saveRobotCode() {
    if (!state.siteInfo) {
      throw new Error('Missing siteInfo')
    }

    await fetch(ROUTES.updateRobotCode(state.siteInfo.robotId), {
      method: 'POST',
      body: JSON.stringify({ code: state.code }),
    })
    setState({ savedCode: state.code })
  },
  toggleSettingsMenu() {
    setState({ viewingSettings: !state.viewingSettings })
  },
  setKeyMap(keyMap: KeyMap) {
    setState('settings', { keyMap })
    saveSettings(state.settings)
  },
  setTheme(theme: Theme) {
    setState('settings', { theme })
    saveSettings(state.settings)
    applyTheme(theme)
  },

  initWorker(
    finishedDownloadingCb: () => void,
    finishedLoadingCb: () => void,
    timedOutCb: () => void,
    workerCb: (params: CallbackParams) => void,
  ) {
    const workerWrapper = new WorkerWrapper(
      finishedDownloadingCb,
      finishedLoadingCb,
      timedOutCb,
      workerCb,
      state.lang,
      state.assetsPath,
      state.workerUrl,
    )
    setState({ workerWrapper })
  },

  selectLang(lang: Lang) {
    const confirmResult = confirm(
      'Are you sure that you want to switch the robot language? This will clear your code.',
    )
    if (!confirmResult) return
    if (state.workerWrapper) {
      state.workerWrapper.changeLang(lang, state.assetsPath, state.workerUrl)
    }
    setState({ lang, code: defaultCode[lang] })
  },

  startWorker(
    turnNum: number,
    opponentEvalInfo: EvalInfo,
    settings: SimulationSettings | null,
  ) {
    if (!state.workerWrapper) {
      throw new Error('Worker not initialized')
    }
    const selfEvalInfo = { code: state.code, lang: state.lang }
    if (!opponentEvalInfo.code && !opponentEvalInfo.lang) {
      // This is the shortcut I'm using to signify that the opponent is the robot itself
      // TODO: improve this
      opponentEvalInfo = selfEvalInfo
    }
    state.workerWrapper.start({
      evalInfo1: selfEvalInfo,
      evalInfo2: opponentEvalInfo,
      turnNum,
      settings,
      assetsPath: state.assetsPath,
    })
  },
})

const Context = createContext<[State, ReturnType<typeof createActions>]>()

export const Provider = (props: ParentProps<ProviderProps>) => {
  const [state, setState] = createStore<State>(initialState(props))

  window.onbeforeunload = () => {
    if (state.code && state.code !== state.savedCode) {
      return "You've made unsaved changes."
    }
    return undefined
  }

  return (
    <Context.Provider value={[state, createActions(state, setState)]}>
      {props.children}
    </Context.Provider>
  )
}

export function useStore() {
  return useContext(Context)!
}
