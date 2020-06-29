import RawWasiWorker from './wasi.worker.js'
import * as Comlink from 'comlink'
import { bigInt } from 'wasm-feature-detect'

const logicPromise = import('logic')

const lowerPromise = (async () => {
  if (await bigInt()) {
    return null
  } else {
    const mod = await import('@wasmer/wasm-transformer/lib/wasm-pack/bundler')
    return mod.lowerI64Imports
  }
})()

const runnerCache = Object.create(null)

const fetchRunner = async (name) => {
  if (name in runnerCache) return runnerCache[name]
  const prom = (async () => {
    const res = await fetch(`/assets/dist/${name}.wasm`)
    let wasm = await res.arrayBuffer()
    const lowerI64Imports = await lowerPromise
    if (lowerI64Imports) {
      wasm = lowerI64Imports(new Uint8Array(wasm))
    }
    return WebAssembly.compile(wasm)
  })()
  runnerCache[name] = prom
  return prom
}

// to fix some weird bug, set the `Window` global to the worker global scope class
// it's not exactly like the main-thread Window, but it's close enough
// self.Window = self.constructor

self.addEventListener('message', ({ data: { code1, code2, turnNum } }) => {
  logicPromise
    .then(async (logic) => {
      const startTime = Date.now()

      const runnerMap = {
        Python: 'pyrunner',
        Javascript: 'jsrunner',
      }
      const makeRunner = async ({ code, lang }) => {
        const langRunner = await fetchRunner(runnerMap[lang])
        const rawWorker = new RawWasiWorker()
        const WasiRunner = Comlink.wrap(rawWorker)
        const runner = await new WasiRunner(langRunner)
        await runner.setup()
        await runner.init(new TextEncoder().encode(code))
        return [runner, rawWorker]
      }

      const turnCallback = (turnState) => {
        self.postMessage({ type: 'getProgress', data: turnState })
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
      self.postMessage({ type: 'getOutput', data: finalState })
    })
    .catch((e) => {
      console.error('error in logic', e, e && e.stack)
      self.postMessage({ type: 'error', data: e.message })
    })
})
