import { Elm } from './Main.elm'
import '../css/app.scss'

Elm.Main.init({
  node: document.getElementById('root'),
  windowWidth: window.innerWidth,
})
