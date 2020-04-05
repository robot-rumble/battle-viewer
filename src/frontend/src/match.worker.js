import stdlib from './stdlib.raw.py'
import zip from 'lodash/zip'

const rpPromise = import('rustpython_wasm')
const logicPromise = import('logic')

const errorToObj = (e, errorType) => {
  // elm expects a null value for missing field
  let errorLoc = null
  if (e.row && e.col && e.endrow && e.endcol) {
    errorLoc = {
      line: e.row,
      ch: e.col,
      endline: e.endrow,
      endch: e.endcol,
    }
  }
  return {
    message: e.message,
    errorLoc,
    // errorType is purely for debugging
    errorType,
  }
}

self.addEventListener('message', ({ data: { code1, code2, turnNum } }) => {
  Promise.all([rpPromise, logicPromise])
    .then(([rp, logic]) => {
      const startTime = Date.now()

      const vms = ['robot1', 'robot2'].map((name) => {
        rp.vmStore.destroy(name)
        return rp.vmStore.init(name, false)
      })

      vms.forEach((vm) => {
        vm.addToScope('print', (val) => console.log(val))
      })

      const codes = [code1, code2]

      try {
        zip(codes, vms).forEach(([code, vm]) => {
          vm.exec(code)
        })
      } catch (e) {
        self.postMessage({
          type: 'getError',
          data: errorToObj(e, 'Python syntax error'),
        })
        return
      }

      try {
        vms.forEach((vm) => {
          vm.exec(stdlib)
        })
      } catch (e) {
        self.postMessage({
          type: 'getError',
          data: errorToObj(e, 'Python execution error'),
        })
        return
      }

      const codeRunners = zip(
        ['Red', 'Blue'],
        vms.map((vm) => (args) => vm.eval('main')([args, Math.random])),
      )

      const runTeam = (team, robotInput) => {
        try {
          if (team in codeRunners) {
            return codeRunners[team](robotInput, {})
          } else {
            throw new Error('Team not found')
          }
        } catch (e) {
          self.postMessage({
            type: 'getError',
            data: errorToObj(e, 'Logic execution error'),
          })
        }
      }

      const turnCallback = (turnState) => {
        self.postMessage({ type: 'getProgress', data: turnState })
      }

      const finalCallback = (finalState) => {
        console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
        self.postMessage({ type: 'getOutput', data: finalState })
      }

      logic.main(runTeam, turnCallback, finalCallback, turnNum)
    })
    .catch((e) => self.postMessage({ type: 'error', data: errorToObj(e, 'Worker execution error') }))
})
