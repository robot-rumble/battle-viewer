import { useStore } from '../store'
import { Match, Switch, createEffect, onCleanup, onMount } from 'solid-js'
import { Chapter } from '../utils/tutorial'

const Tutorial = () => {
  const [{ tutorialState }, actions] = useStore()

  if (!tutorialState) {
    return <></>
  }

  const readChapter = () => {
    const queryParams = new URLSearchParams(window.location.search);
    const chapter = parseInt(queryParams.get('chapter') || '');
    if (!isNaN(chapter)) {
      actions.setTutorialChapter(chapter, false)
    }
  }

  createEffect(() => {
    window.addEventListener('popstate', readChapter);
    onCleanup(() => window.removeEventListener('popstate', readChapter))
  })

  onMount(readChapter)

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
    <div class="_chapter">
      <h3>{chapter().title}</h3>
      {/* eslint-disable-next-line solid/no-innerhtml */}
      <div class="_body" innerHTML={chapter().body} />
      <div class="d-flex _buttons">
        <button
          class="button me-2"
          onClick={() => actions.setTutorialChapter(tutorialState.currentChapter - 1, true)}
          disabled={tutorialState.currentChapter === 0}
        >
          Previous
        </button>
        <button
          class="button"
          onClick={() => actions.setTutorialChapter(tutorialState.currentChapter + 1, true)}
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
