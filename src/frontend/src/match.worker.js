import stdlib from './stdlib.raw.py'
import zip from 'lodash/zip'
import fromPairs from 'lodash/fromPairs'

const logicPromise = import('logic')

// to fix some weird bug, set the `Window` global to the worker global scope class
// it's not exactly like the main-thread Window, but it's close enough
self.Window = self.constructor

const errorToObj = (e, errorType) => {
  // elm expects a null value for missing field
  let errorLoc = null
  let message = e.message
  let traceback = null
  console.log(e)
  if (e.row != null && e.col != null) {
    errorLoc = {
      line: e.row,
      ch: e.col,
      endline: e.endrow == null ? -1 : e.endrow,
      endch: e.endcol == null ? -1 : e.endcol,
    }
  }
  if (e.constructor.name == "PyError") {
    // TODO: extract more info from this, display it nicely maybe
    message = e.toString()
    for (const tb of e.traceback) {
      if (tb.filename == "<robot>") {
        errorLoc = {
          line: tb.lineno,
          ch: 0,
          endline: -1,
          endch: -1,
        }
        break
      }
    }
  }
  return {
    message,
    errorLoc,
    // errorType is purely for debugging
    errorType,
    stack: e.stack,
  }
}

self.addEventListener('message', ({ data: { code1, code2, turnNum } }) => {
  logicPromise
    .then((logic) => {
      const startTime = Date.now()

      const turnCallback = (turnState) => {
        self.postMessage({ type: 'getProgress', data: turnState })
      }

      const finalState = logic.run_rustpython(code1, code2, turnCallback, turnNum)

      console.log(`Time taken: ${(Date.now() - startTime) / 1000}s`)
      self.postMessage({ type: 'getOutput', data: finalState })
    })
    .catch((e) => self.postMessage({ type: 'getError', data: errorToObj(e, 'logic/python') }))
})
