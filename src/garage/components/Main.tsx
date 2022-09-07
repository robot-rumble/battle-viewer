import { Match, onMount, Switch } from 'solid-js'
// @ts-ignore
import { Elm } from '../Main.elm'
import Split from 'split.js'
// @ts-ignore
import { applyTheme } from '../themes'
import { captureMessage } from '@sentry/browser'
import SettingsMenu from './SettingsMenu'
import { CallbackParams, EvalInfo, SimulationSettings } from '../match.worker'
import { SiteInfo, useStore } from '../store'
import Bar from './Bar'
import { Editor } from './Editor'
import { OUR_TEAM } from '../constants'

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
  startEval: Subscription<{
    id: number
    turns: number
    settings: SimulationSettings
    opponentEvalInfo: EvalInfo
  }>
  reportDecodeError: Subscription<string>
  reportApiError: Subscription<string>
}

interface ElmApp {
  ports: ElmAppPorts
}

const Main = () => {
  const [state, _actions] = useStore()
  let battleViewerRef: HTMLDivElement

  onMount(() => {
    init(battleViewerRef)
  })

  return (
    <div class="_root-app-root d-flex">
      <div class="_ui">
        <Switch>
          <Match when={state.viewingSettings}>
            <SettingsMenu />
          </Match>
          <Match when={!state.viewingSettings}>
            <Bar />
            <Editor />
          </Match>
        </Switch>
      </div>
      <div class="gutter" id="main-gutter" />
      <div class="_viewer">
        <div ref={battleViewerRef!} />
      </div>
    </div>
  )
}

export default Main

function init(node: HTMLElement) {
  const [state, actions] = useStore()

  const apiContext = createApiContext(state.siteInfo, state.assetsPath)

  const app = Elm.Main.init({
    node,
    flags: {
      apiContext,
      team: OUR_TEAM,
      unsupported: !state.compatible,
    },
  }) as ElmApp

  if (state.compatible) {
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
    )
  }

  initSplit()

  app.ports.reportDecodeError.subscribe((error) => {
    console.log('Decode Error!', error)
    captureMessage('Garage decode error: ' + error)
  })

  app.ports.reportApiError.subscribe((error) => {
    console.log('Api Error!', error)
    captureMessage('Garage Api error:' + error)
  })

  app.ports.startEval.subscribe(({ turns, settings, opponentEvalInfo }) => {
    actions.startWorker(turns, opponentEvalInfo, settings)
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

export function initSplit() {
  // we need to make sure that the tutorial loaded successfully
  // if (tutorial && document.querySelector('._tutorial')) {
  //   Split(['._tutorial', '._ui'], {
  //     sizes: [25, 40],
  //     minSize: [300, 650],
  //     gutterSize: 5,
  //     gutter: () => document.querySelector('.gutter-1')!,
  //   })
  //
  //   Split(['._ui', '._viewer'], {
  //     sizes: [40, 35],
  //     minSize: [650, 650],
  //     gutterSize: 5,
  //     gutter: () => document.querySelector('.gutter-2')!,
  //   })
  // } else {
  Split(['._ui', '._viewer'], {
    sizes: [60, 40],
    minSize: [650, 650],
    gutterSize: 5,
    gutter: () => document.querySelector('#main-gutter')!,
  })
  // }
}
