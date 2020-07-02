import RawWasiWorker from './wasi.worker.js'
import * as Comlink from 'comlink'

import fetchRunner from './fetchRunner'

const logicPromise = import('logic')

class MatchWorker {
  async init(assetsPath, lang, finishDownloadCb) {
    return fetchRunner(assetsPath, lang, finishDownloadCb)
  }

  async run({ assetsPath, code1, code2, turnNum }, cb) {
    try {
      const logic = await logicPromise
      const startTime = Date.now()

      const makeRunner = async ({ code, lang }) => {
        const langRunner = await fetchRunner(assetsPath, lang, () => {})
        const rawWorker = new RawWasiWorker()
        const WasiWorker = Comlink.wrap(rawWorker)
        const runner = await new WasiWorker(langRunner)
        await runner.setup()
        await runner.init(new TextEncoder().encode(code))
        return [runner, rawWorker]
      }

      const turnCallback = (turnState) => {
        cb({ type: 'getProgress', data: turnState })
      }

      const [[runner1, worker1], [runner2, worker2]] = await Promise.all([
        makeRunner(code1),
        makeRunner(code2),
      ])

      const finalState = await logic.run(
        runner1,
        runner2,
        turnCallback,
        turnNum,
      )

      worker1.terminate()
      worker2.terminate()

      console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
      cb({ type: 'getOutput', data: finalState })
    } catch (e) {
      console.error('Error in worker', e, e && e.stack)
      cb({ type: 'error', data: e.message })
    }
  }
}

Comlink.expose(MatchWorker)
