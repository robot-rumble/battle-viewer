import { createContext, ParentProps, useContext } from 'solid-js'
import { createStore, SetStoreFunction } from 'solid-js/store'
import { captureException } from '@sentry/browser'
import { WorkerWrapper } from './worker/workerWrapper'
import { Lang, OUR_TEAM } from './utils/constants'
import { CallbackParams, EvalInfo, SimulationSettings } from './worker/match.worker'
import {
  KeyMap,
  loadSettings,
  saveSettings,
  Settings,
  Theme,
  TurnTimeoutEnabled,
} from './utils/settings'
import { applyTheme } from './utils/themes'
import { checkCompatibility } from './utils/checkCompatibility'
import defaultCode from './utils/defaultCode'
import { fetchTutorial, Tutorial } from './utils/tutorial'

export type Id = number

export interface SiteInfo {
  user: string
  userId: Id
  robot: string
  robotId: Id
}

// [line, char]
export type TextLoc = [number, number | null]

export interface ErrorLoc {
  start: TextLoc
  end: TextLoc | null
}

export interface TutorialState {
  url: string | null
  tutorial: Tutorial | null
  loadingErrored: boolean
  currentChapter: number
}

interface State {
  workerWrapper: WorkerWrapper | null
  workerErrorLoc: ErrorLoc | null
  code: string
  savedCode: string
  lang: Lang
  settings: Settings
  viewingSettings: boolean
  siteInfo: SiteInfo | null
  assetsPath: string
  workerUrl: string
  tutorialState: TutorialState | null
  compatible: boolean
}

interface ProviderProps {
  assetsPath: string
  workerUrl: string
  code: string | null
  lang: Lang
  siteInfo: SiteInfo | null
  tutorial: boolean
  tutorialUrl: string | null
}

const initialState = ({
  code,
  lang,
  assetsPath,
  siteInfo,
  workerUrl,
  tutorial,
  tutorialUrl,
}: ProviderProps): State => {
  const [compatible, incompatibilityWarning] = checkCompatibility(lang)

  code = code || defaultCode[lang]

  if (incompatibilityWarning) {
    code = incompatibilityWarning + code
  }

  const settings = loadSettings()
  applyTheme(settings.theme)

  let tutorialState: TutorialState | null = null
  if (tutorial) {
    tutorialState = {
      url: tutorialUrl,
      tutorial: null,
      currentChapter: 0,
      loadingErrored: false,
    }
  }

  return {
    assetsPath,
    workerUrl,
    workerWrapper: null,
    workerErrorLoc: null,
    lang,
    code,
    savedCode: code,
    settings,
    viewingSettings: false,
    siteInfo,
    compatible,
    tutorialState,
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

const TUTORIAL_CODE_KEY = 'localCode'

const createActions = (state: State, setState: SetStoreFunction<State>) => ({
  synchronizeCode(code: string) {
    setState({ code })
    if (state.tutorialState) {
      localStorage.setItem(TUTORIAL_CODE_KEY, code)
    }
  },
  async saveRobotCode() {
    if (!state.siteInfo) {
      throw new Error('Missing siteInfo')
    }

    try {
      await fetch(ROUTES.updateRobotCode(state.siteInfo.robotId), {
        method: 'POST',
        body: JSON.stringify({ code: state.code }),
        headers: {
          "Content-Type": "application/json",
        },
      })
      setState({ savedCode: state.code })
    } catch (e) {
      captureException(e)
      throw e
    }
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
  setTimeoutEnabled(timeoutEnabled: TurnTimeoutEnabled) {
    setState('settings', { timeoutEnabled })
    saveSettings(state.settings)
  },
  initWorker(
    finishedDownloadingCb: () => void,
    finishedLoadingCb: () => void,
    timedOutCb: () => void,
    workerCb: (params: CallbackParams) => void,
  ) {
    const modifiedWorkerCb = (params: CallbackParams) => {
      if (params.type === 'getOutput') {
        const errorType = params.data?.errors?.[OUR_TEAM]
        const error = errorType?.InitError || errorType?.RuntimeError
        if (error && error.loc != null) {
          setState({ workerErrorLoc: error.loc })
        }
      }
      workerCb(params)
    }
    const workerWrapper = new WorkerWrapper(
      finishedDownloadingCb,
      finishedLoadingCb,
      timedOutCb,
      modifiedWorkerCb,
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

  startWorker(turnNum: number, opponentEvalInfo: EvalInfo) {
    if (!state.workerWrapper) {
      throw new Error('Worker not initialized')
    }
    const selfEvalInfo = { code: state.code, lang: state.lang }

    if (!opponentEvalInfo.code && !opponentEvalInfo.lang) {
      // This is the shortcut I'm using to signify that the opponent is the robot itself
      // TODO: improve this
      if (state.tutorialState) {
        const { opponentCode, opponentLang } =
          state.tutorialState.tutorial!.chapters[
          state.tutorialState.currentChapter
          ]
        opponentEvalInfo = {
          code: opponentCode,
          lang: opponentLang,
        }
      } else {
        opponentEvalInfo = selfEvalInfo
      }
    }
    let settings = null
    if (state.tutorialState) {
      settings =
        state.tutorialState.tutorial!.chapters[
          state.tutorialState.currentChapter
        ]?.simulationSettings || null
    }

    state.workerWrapper.start({
      evalInfo1: selfEvalInfo,
      evalInfo2: opponentEvalInfo,
      turnNum,
      assetsPath: state.assetsPath,
      // This converts the Proxy object into a regular Javascript object,
      // which is necessary to be able to pass it through Comlink's Proxy
      settings: JSON.parse(JSON.stringify(settings)),
      timeoutEnabled: state.settings.timeoutEnabled === 'turn timeout enabled'
    })
  },

  setTutorialChapter(chapter: number, updateUrl: boolean) {
    setState('tutorialState', 'currentChapter', chapter)
    if (updateUrl) {
      updateTutorialQueryParam(chapter)
    }
  }
})

function updateTutorialQueryParam(newChapter: number) {
  const urlObj = new URL(window.location.href);
  urlObj.searchParams.set('chapter', newChapter.toString());
  window.history.pushState('', '', urlObj.toString());
}

const Context = createContext<[State, ReturnType<typeof createActions>]>()

export const Provider = (props: ParentProps<ProviderProps>) => {
  const [state, setState] = createStore<State>(initialState(props))

  window.onbeforeunload = () => {
    if (state.code && state.code !== state.savedCode) {
      return "You've made unsaved changes."
    }
    return undefined
  }

  if (state.tutorialState) {
    fetchTutorial(state.tutorialState.url).then((tutorial) => {
      if (tutorial) {
        const startingCode = localStorage.getItem(TUTORIAL_CODE_KEY) || tutorial.startingCode

        if (startingCode != null) {
          setState('code', startingCode)
          setState('savedCode', startingCode)
        }
        setState('tutorialState', { tutorial })
      } else {
        setState('tutorialState', 'loadingErrored', true)
      }
    })
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
