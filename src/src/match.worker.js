import RawWasiWorker from './wasi.worker.js';
import { lowerI64Imports } from '@wasmer/wasm-transformer'
import * as Comlink from "comlink";

const logicPromise = import('logic')

const runnerCache = Object.create(null)

const fetchRunner = (name) => {
  if (name in runnerCache) return runnerCache[name];
  const ret = runnerCache[name] = WebAssembly.compileStreaming(fetch(`/assets/dist/${name}.wasm`))
    // .then(r => r.arrayBuffer())
    // .then(lowerI64Imports)
    // .then(WebAssembly.compileStreaming);
  return ret
}

// to fix some weird bug, set the `Window` global to the worker global scope class
// it's not exactly like the main-thread Window, but it's close enough
self.Window = self.constructor

self.addEventListener('message', ({ data: { code1, code2, turnNum, lang } }) => {
  logicPromise
    .then(async (logic) => {
      const startTime = Date.now()

      const langRunner = await fetchRunner({
        PYTHON: "pyrunner",
        JAVASCRIPT: "jsrunner",
      }[lang]);
      const makeRunner = async (code) => {
        const WasiRunner = Comlink.wrap(new RawWasiWorker());
        const sourcePath = "/sourcecode";
        const runner = await new WasiRunner()
        await runner.setup(lang, { [sourcePath]: code })
        await runner.init(new TextEncoder().encode(sourcePath));
        return runner;
      }

      const turnCallback = (turnState) => {
        self.postMessage({ type: 'getProgress', data: turnState })
      }

      const [runner1, runner2] = await Promise.all([makeRunner(code1), makeRunner(code2)]);

      const finalState = await logic.run(runner1, runner2, turnCallback, turnNum)

      console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
      self.postMessage({ type: 'getOutput', data: finalState })
    })
    .catch((e) => {
      console.error("error in logic", e, e && e.stack)
      self.postMessage({ type: 'error', data: e.message })
    })
})
