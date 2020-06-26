const makerRunnerPromise = import('make-runner')
const logicPromise = import('logic')

self.addEventListener('message', ({ data: { code1, code2, turnNum } }) => {
  Promise.all([makerRunnerPromise, logicPromise])
    .then(async ([makeRunner, logic]) => {
      const startTime = Date.now()

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
