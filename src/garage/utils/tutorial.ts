import { Lang } from './constants'
import { SimulationSettings } from '../worker/match.worker'
import { captureException } from '@sentry/browser'
import yaml from 'js-yaml'
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import DEFAULT_TUTORIAL_1 from './tutorial1.yaml'
import DEFAULT_TUTORIAL_2 from './tutorial2.yaml'
import { TutorialSource } from '../store'

export interface Chapter {
  title: string
  body: string
  opponentCode: string
  opponentLang: Lang
  simulationSettings: SimulationSettings
}

export interface Tutorial {
  title: string
  chapters: Chapter[]
  startingCode: string | null
}

export const fetchTutorial = async (
  source: TutorialSource
): Promise<Tutorial | null> => {
  let string
  if (source.type === "url") {
    string = await fetchTutorialStringFromUrl(source.value)
    if (!string) return null
  } else {
    if (source.value === "1") {
      string = DEFAULT_TUTORIAL_1
    } else {
      string = DEFAULT_TUTORIAL_2
    }
  }

  let tutorial = null
  try {
    tutorial = yaml.load(string, { json: true }) as Tutorial
    processTutorial(tutorial)
  } catch (e) {
    captureException(e)
  }
  return tutorial
}

const fetchTutorialStringFromUrl = async (
  url: string,
): Promise<string | null> => {
  let tutorial = null
  await fetch(url)
    .then(async (res) => {
      if (res.ok) {
        tutorial = await res.text()
      }
    })
    .catch((e) => {
      captureException(e)
    })
  return tutorial
}

const processTutorial = (tutorial: Tutorial) => {
  tutorial.chapters.forEach((chapter) => {
    // When a configuration option is set, marked.parse will return a promise
    // https://marked.js.org/using_advanced
    chapter.body = DOMPurify.sanitize(marked.parse(chapter.body) as string)
  })
}
