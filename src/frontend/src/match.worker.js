import stdlib from './stdlib.raw.py'
import { main as runLogic } from 'logic'
import _ from 'lodash'

const rpPromise = import('rustpython_wasm')

// to fix some weird bug
self.Window = self.constructor

const errorToObj = (e, num) => {
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
    num,
    errorLoc,
  }
}

self.addEventListener('message', ({data: {code1, code2, turnNum}}) => {
  rpPromise
    .then((rp) => {
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
        _.zip(codes, vms).forEach(([code, vm]) => {
          vm.exec(code)
        })
      } catch (e) {
        self.postMessage({
          type: 'getOutput',
          data: errorToObj(e, 0),
        })
        return
      }

      try {
        vms.forEach((vm) => {
          vm.exec(stdlib)
        })
      } catch (e) {
        self.postMessage({
          type: 'getOutput',
          data: errorToObj(e, 1),
        })
        return
      }

      const [run1, run2] = vms.map((vm) => {
        const main = (args) => vm.eval('main')([args, Math.random])
        return (args) => {
          args = JSON.parse(args)
          try {
            return JSON.stringify(main(args, {}))
          } catch (e) {
            self.postMessage({
              type: 'getOutput',
              data: errorToObj(e, 2),
            })
          }
        }
      })
      const turnCallback = (turn) => self.postMessage({type: 'getProgress', data: turn})

      runLogic({run1, run2, turnNum: turnNum, turnCallback}, (output) => {
        console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
        self.postMessage({type: 'getOutput', data: JSON.parse(output)})
      })
    })
    .catch((e) => {
      let data
      if (e.message) {
        // JS error
        data = errorToObj(e, 3)
      } else {
        // OCAML error
        data = e
      }
      self.postMessage({type: 'error', data})
    })
})
