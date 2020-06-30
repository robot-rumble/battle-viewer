import { Elm } from './Main.elm'

import './main.scss'

fetch('/getflags')
  .then(r => r.json())
  .then(init)

function init(flags) {
  const app = Elm.Main.init({
    node: document.getElementById('root'),
    flags,
  })

  app.ports.startEval.subscribe((params) => {
    const url = new URL('/run', document.location)
    for (const key in params) url.searchParams.set(key, params[key])
    const evsrc = new EventSource(url.href)
    evsrc.addEventListener('message', ({ data }) => {
      const ev = JSON.parse(data)
      if (ev.type == 'getOutput') evsrc.close()
      app.ports[ev.type].send(ev.data)
    })
  })
}

