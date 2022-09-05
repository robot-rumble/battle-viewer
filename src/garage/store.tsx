import { createContext, ParentProps, useContext } from 'solid-js'
import { createStore, SetStoreFunction } from 'solid-js/store'
import { WorkerWrapper } from './workerWrapper'
import { Lang } from './types'
import { CallbackParams, RunParams } from './match.worker'

interface State {
  workerWrapper: WorkerWrapper | null
  lang: Lang
}

const initialState: State = {
  workerWrapper: null,
  lang: 'Python',
}

const createActions = (
  state: State,
  setState: SetStoreFunction<State>,
  assetsPath: string,
) => ({
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
      assetsPath,
    )
    setState({ workerWrapper })
  },

  changeLang(lang: Lang) {
    if (state.workerWrapper) {
      state.workerWrapper.changeLang(lang, assetsPath)
    }
    setState({ lang })
  },

  startWorker(params: RunParams) {
    if (!state.workerWrapper) {
      throw new Error('Worker not initialized')
    }
    state.workerWrapper.start(params)
  },
})

const Context = createContext<[State, ReturnType<typeof createActions>]>()

interface ProviderProps {
  assetsPath: string
}

export const Provider = (props: ParentProps<ProviderProps>) => {
  const [state, setState] = createStore<State>(initialState)

  return (
    <Context.Provider
      value={[state, createActions(state, setState, props.assetsPath)]}
    >
      {props.children}
    </Context.Provider>
  )
}

export function useStore() {
  return useContext(Context)!
}
