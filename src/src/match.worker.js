const logicPromise = import('logic')

// to fix some weird bug, set the `Window` global to the worker global scope class
// it's not exactly like the main-thread Window, but it's close enough
self.Window = self.constructor

self.addEventListener('message', ({ data: { code1, code2, turnNum, lang } }) => {
  logicPromise
    .then((logic) => {
      const startTime = Date.now()

      const turnCallback = (turnState) => {
        self.postMessage({ type: 'getProgress', data: turnState })
      }

      // TODO: use `lang`

      const finalState = logic.run(code1, code2, turnCallback, turnNum)

      console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
      self.postMessage({ type: 'getOutput', data: finalState })
    })
    .catch((e) => self.postMessage({ type: 'error', data: e.message }))
})
