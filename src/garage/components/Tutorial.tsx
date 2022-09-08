import { useStore } from '../store'
import { Match, Switch } from 'solid-js'
import { Chapter } from '../utils/tutorial'

const Tutorial = () => {
  const [{ tutorialState }] = useStore()

  if (!tutorialState) {
    return <></>
  }

  return (
    <Switch>
      <Match when={tutorialState.loadingErrored}>
        <p>Loading the tutorial failed</p>
      </Match>
      <Match when={!tutorialState.tutorial}>
        <p>Loading...</p>
      </Match>
      <Match when={tutorialState.tutorial}>
        <Chapter />
      </Match>
    </Switch>
  )
}

const Chapter = () => {
  const [{ tutorialState }, actions] = useStore()

  if (!tutorialState?.tutorial) {
    throw Error('tutorial is null')
  }

  const chapter = () =>
    tutorialState.tutorial!.chapters[tutorialState.currentChapter]

  return (
    <div>
      <h3 class="mb-3">{chapter().title}</h3>
      {/* eslint-disable-next-line solid/no-innerhtml */}
      <div class="mb-4" innerHTML={chapter().body} />
      <div class="d-flex">
        <button
          class="button me-2"
          onClick={actions.previousTutorialChapter}
          disabled={tutorialState.currentChapter === 0}
        >
          Previous
        </button>
        <button
          class="button"
          onClick={actions.nextTutorialChapter}
          disabled={
            tutorialState.currentChapter ===
            tutorialState.tutorial.chapters.length - 1
          }
        >
          Next
        </button>
      </div>
    </div>
  )
}

export default Tutorial
