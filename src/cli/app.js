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
    const eventSource = new EventSource(url.href)
    eventSource.addEventListener('message', ({ data }) => {
      const event = JSON.parse(data)
      if (event.type === 'getOutput') eventSource.close()
      app.ports[event.type].send(event.data)
    })
  })
}

