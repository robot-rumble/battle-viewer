import { Lang } from './constants'
import { SimulationSettings } from '../worker/match.worker'
import { captureException } from '@sentry/browser'
import yaml from 'js-yaml'
import DOMPurify from 'dompurify'
import { marked } from 'marked'

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

export const fetchTutorial = async (url: string): Promise<Tutorial | null> => {
  let tutorial = null
  await fetch(url)
    .then(async (res) => {
      if (res.ok) {
        const text = await res.text()
        try {
          tutorial = yaml.load(text, { json: true }) as Tutorial
          processTutorial(tutorial)
        } catch (e) {
          captureException(e)
        }
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
