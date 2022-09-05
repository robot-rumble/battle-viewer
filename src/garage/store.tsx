import { createContext, ParentProps, useContext } from 'solid-js'
import { createStore, SetStoreFunction } from 'solid-js/store'
import { WorkerWrapper } from './workerWrapper'
import { Lang } from './types'
import { CallbackParams, EvalInfo, SimulationSettings } from './match.worker'

interface State {
  workerWrapper: WorkerWrapper | null
  lang: Lang
  assetsPath: string
}

const initialState = (assetsPath: string): State => ({
  assetsPath,
  workerWrapper: null,
  lang: 'Python',
})

const createActions = (state: State, setState: SetStoreFunction<State>) => ({
  initWorker(
    finishedDownloadingCb: () => void,
    finishedLoadingCb: () => void,
    timedOutCb: () => void,
    workerCb: (params: CallbackParams) => void,
    workerUrl: string,
  ) {
    const workerWrapper = new WorkerWrapper(
      finishedDownloadingCb,
      finishedLoadingCb,
      timedOutCb,
      workerCb,
      state.lang,
      workerUrl,
      state.assetsPath,
    )
    setState({ workerWrapper })
  },

  changeLang(lang: Lang) {
    if (state.workerWrapper) {
      state.workerWrapper.changeLang(lang, state.assetsPath)
    }
    setState({ lang })
  },

  startWorker(
    evalInfo1: EvalInfo,
    evalInfo2: EvalInfo,
    turnNum: number,
    settings: SimulationSettings | null,
  ) {
    if (!state.workerWrapper) {
      throw new Error('Worker not initialized')
    }
    state.workerWrapper.start({
      evalInfo1,
      evalInfo2,
      turnNum,
      settings,
      assetsPath: state.assetsPath,
    })
  },
})

const Context = createContext<[State, ReturnType<typeof createActions>]>()

interface ProviderProps {
  assetsPath: string
}

export const Provider = (props: ParentProps<ProviderProps>) => {
  const [state, setState] = createStore<State>(initialState(props.assetsPath))

  return (
    <Context.Provider value={[state, createActions(state, setState)]}>
      {props.children}
    </Context.Provider>
  )
}

export function useStore() {
  return useContext(Context)!
}
