import Bowser from 'bowser'
import { Lang } from './types'

const supportedBrowsers = {
  Chrome: 85,
  'Microsoft Edge': 85,
  Firefox: 78,
  Opera: 71,
} as const

type Browser = keyof typeof supportedBrowsers

export function checkCompatibility(lang: Lang): [boolean, string | null] {
  const browser = Bowser.getParser(window.navigator.userAgent).getBrowser()
  let compatible = false
  if (
    browser.version &&
    browser.name !== undefined &&
    browser.name in supportedBrowsers
  ) {
    const version = parseInt(browser.version.split('.')[0])
    compatible = version >= supportedBrowsers[browser.name as Browser]
  }
  if (!compatible) {
    return [false, generateIncompatibilityWarning(browser, lang)]
  }
  return [true, null]
}

function generateIncompatibilityWarning(
  browser: Bowser.Parser.Details,
  lang: Lang,
): string {
  const supportString = Object.entries(supportedBrowsers)
    .map(([name, version]) => `${name} ${version}+`)
    .join(', ')
  let warning = `
Unsupported browser type!
The Garage officially supports ${supportString}
The Garage DOES NOT support Safari
Your browser is: ${browser.name} ${browser.version}

If you cannot switch to a different browser, consider downloading Rumblebot, our command line tool
https://rr-docs.readthedocs.io/en/latest/rumblebot.html
`
  const comment = {
    Python: '#',
    Javascript: '//',
  }[lang]
  warning = warning
    .split('\n')
    .map((line) => `${comment} ${line}`)
    .join('\n')
  return warning + '\n\n'
}
