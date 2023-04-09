import { Lang } from './constants'
import { SimulationSettings } from '../worker/match.worker'
import { captureException } from '@sentry/browser'
import yaml from 'js-yaml'
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import DEFAULT_TUTORIAL from './tutorial.yaml'

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
  url: string | null,
): Promise<Tutorial | null> => {
  let string
  if (url) {
    string = await fetchTutorialStringFromUrl(url)
    if (!string) return null
  } else {
    string = DEFAULT_TUTORIAL
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
    chapter.body = DOMPurify.sanitize(marked.parse(chapter.body))
  })
}
