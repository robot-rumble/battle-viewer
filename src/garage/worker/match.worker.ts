import * as Comlink from 'comlink'

import fetchRunner from './fetchRunner'
import { Lang } from '../utils/constants'
import { convertObjectKeysToSnakeCase } from '../utils/snakeCase'

// @ts-ignore
const logicPromise = import('logic')

export interface EvalInfo {
  code: string
  lang: Lang
}

interface SpawnSettings {
  initialUnitNum: number
  recurrentUnitNum: number
  spawnEvery: number
}

type Team = 'Red' | 'Blue'
type TerrainType = 'Wall'
type UnitType = 'Soldier'

interface BasicObj {
  id: number
  coords: [number, number]
}

interface Terrain {
  objType: 'Terrain'
  type: TerrainType
}

interface Unit {
  objType: 'Unit'
  type: UnitType
  team: Team
  health: number
}

type ObjDetails = Terrain | Unit

interface Obj {
  BasicObj: BasicObj
  ObjDetails: ObjDetails
}

export interface SimulationSettings {
  gridInit: Obj[]
  spawnSettings?: SpawnSettings
}

export interface RunParams {
  assetsPath: string
  evalInfo1: EvalInfo
  evalInfo2: EvalInfo
  turnNum: number
  settings: SimulationSettings | null
}

export interface CallbackParams {
  type: 'getProgress' | 'getOutput' | 'error'
  data: any
}

export class MatchWorker {
  async init(assetsPath: string, lang: Lang, finishDownloadCb: () => void) {
    return fetchRunner(assetsPath, lang, finishDownloadCb)
  }

  async run(
    { assetsPath, evalInfo1, evalInfo2, turnNum, settings }: RunParams,
    cb: (params: CallbackParams) => void,
  ) {
    try {
      const logic = await logicPromise
      const startTime = Date.now()

      console.log('Starting battle...')

      const makeRunner = async ({ code, lang }: EvalInfo) => {
        const langRunner = await fetchRunner(assetsPath, lang, () => {})
        const rawWorker = new Worker(
          new URL('./wasi.worker.js', import.meta.url),
        )
        const WasiWorker = Comlink.wrap(rawWorker)
        // @ts-ignore
        const runner = await new WasiWorker(langRunner)
        await runner.setup()
        await runner.init(new TextEncoder().encode(code))
        return [runner, rawWorker]
      }

      const turnCallback = (turnState: any) => {
        cb({
          type: 'getProgress',
          data: turnState,
        })
      }

      const [[runner1, worker1], [runner2, worker2]] = await Promise.all([
        makeRunner(evalInfo1),
        makeRunner(evalInfo2),
      ])

      // const logicSettings = settings
      //   ? new logic.Settings(
      //       settings.initialUnitNum,
      //       settings.recurrentUnitNum,
      //       settings.spawnEvery,
      //     )
      //   : null

      const snakeCaseSettings =
        settings && JSON.stringify(convertObjectKeysToSnakeCase(settings))
      console.log(snakeCaseSettings)

      const finalState = await logic.run(
        runner1,
        runner2,
        turnCallback,
        turnNum,
        snakeCaseSettings,
      )
      console.log('done')

      worker1.terminate()
      worker2.terminate()

      console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
      cb({
        type: 'getOutput',
        data: finalState,
      })
    } catch (e: any) {
      console.error('Error in worker', e, e && e.stack)
      // can't pass error object directly because of:
      // DataCloneError: The object could not be cloned.
      // so we stringify the error object, but there's a nuance to doing this
      // https://stackoverflow.com/a/50738205
      cb({
        type: 'error',
        data: JSON.stringify(e, Object.getOwnPropertyNames(e)),
      })
    }
  }
}

Comlink.expose(MatchWorker)
