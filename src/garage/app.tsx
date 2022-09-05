import './codemirror'
// @ts-ignore
import defaultCode from './defaultCode'

import { render } from 'solid-js/web'
import Main, { initSplit, SiteInfo } from './Main'
import { Lang } from './types'
import { Provider } from './store'

if (process.env['NODE_ENV'] !== 'production' && module.hot) {
  // @ts-ignore
  import('./main.scss')

  if (!process.env['BOT_LANG']) {
    throw new Error(
      'You must specify the robot language through the "BOT_LANG" env var.',
    )
  }

  initSolid(
    document.querySelector('#root')!,
    '',
    'Python',
    null,
    '',
    'dist/worker.js',
  )

  module.hot.addStatusHandler(() => initSplit(false))
}

customElements.define(
  'garage-el',
  class extends HTMLElement {
    async connectedCallback() {
      const user = this.getAttribute('user')
      const userId = parseInt(this.getAttribute('userId')!)
      const robot = this.getAttribute('robot')
      const robotId = parseInt(this.getAttribute('robotId')!)

      let siteInfo = null
      if (user && userId && robot && robotId) {
        // we're in the normal garage
        siteInfo = {
          user,
          userId,
          robot,
          robotId,
        }
      } else if (user || userId || robot || robotId) {
        throw new Error(
          'Missing some but not all of user|userId|robot|robotId attributes',
        )
      } else {
        // we're in demo or tutorial mode
      }

      const lang = this.getAttribute('lang') || 'Python'
      if (!(lang in defaultCode)) {
        throw new Error('Unknown lang value: ' + lang)
      }

      const code = this.getAttribute('code') || defaultCode[lang]

      const assetsPath = this.getAttribute('assetsPath')
      if (!assetsPath) {
        throw new Error('No assetsPath attribute found')
      }

      // let tutorial = null
      // if (this.getAttribute('tutorial')) {
      //   const urlSearchParams = new URLSearchParams(window.location.search)
      //   const uri = urlSearchParams.get('source')
      //   if (uri) {
      //     await fetch(uri)
      //       .then(async (res) => {
      //         if (res.ok) {
      //           const text = await res.text()
      //           try {
      //             tutorial = yaml.load(text, { json: true })
      //           } catch (e) {
      //             code = 'Error! Check the console.'
      //             console.error(e)
      //           }
      //         } else {
      //           code = 'Error! Check the console.'
      //           console.error(`Tutorial load failed at uri "${uri}"`)
      //         }
      //       })
      //       .catch(() => {
      //         code = 'Error! Check the console.'
      //         console.error(`Tutorial load failed at uri "${uri}"`)
      //       })
      //   } else {
      //     code = 'Error! Check the console.'
      //     console.error(
      //       'No tutorial URL specified (no "source" query parameter found)',
      //     )
      //   }
      // }

      initSolid(
        this,
        code,
        lang as Lang,
        siteInfo as SiteInfo,
        assetsPath,
        // get around the same-origin rule for loading workers through a cloudflare proxy worker
        // that rewrites robotrumble.org/assets to cloudfront
        // this is not necessary anywhere else because normal assets don't have this security rule
        process.env['NODE_ENV'] === 'production'
          ? 'https://robotrumble.org/assets/worker-assets/worker.js'
          : assetsPath + '/dist/worker.js',
      )
    }
  },
)

function initSolid(
  node: HTMLElement,
  code: string,
  lang: Lang,
  siteInfo: SiteInfo | null,
  assetsPath: string,
  workerUrl: string,
) {
  render(
    () => (
      <Provider assetsPath={assetsPath}>
        <Main
          code={code}
          lang={lang}
          siteInfo={siteInfo}
          assetsPath={assetsPath}
          workerUrl={workerUrl}
        />
      </Provider>
    ),
    node,
  )
}
