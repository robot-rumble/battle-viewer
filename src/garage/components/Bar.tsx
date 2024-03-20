import { For, Match, Switch, Show, createSignal } from 'solid-js'
import { ROUTES, useStore } from '../store'
import { LANGS } from '../utils/constants'

const Bar = () => {
  const [state, actions] = useStore()
  const [saveAnimation, setSaveAnimation] = createSignal('');
  const [hasSaveError, setHasSaveError] = createSignal(false);

  const shared = (
    <div class="d-flex align-items-center">
      <a class="me-4" href={ROUTES.docs} target="_blank">
        docs
      </a>
      <div class="_img-settings" onClick={actions.toggleSettingsMenu} />
    </div>
  )

  const save = async () => {
    try {
      await actions.saveRobotCode()
      if (saveAnimation() === 'disappearing-one') {
        setSaveAnimation('disappearing-two')
      } else {
        setSaveAnimation('disappearing-one')
      }
    } catch (e) {
      setHasSaveError(true)
    }
  }

  const barForUser = () => (
    <>
      <div class="d-flex align-items-center">
        <div class="d-flex">
          <p class="me-3">The Garage -- editing</p>
          <a href={ROUTES.viewRobot(3)} target="_blank">
            r2
          </a>
        </div>
        <button class="button ms-4" onClick={save}>
          save
        </button>
        <Switch>
          <Match when={saveAnimation() !== ''}>
            <p class={"mx-3 " + saveAnimation()}>
              saved
            </p>
          </Match>
          <Match when={hasSaveError()}>
            <p class="mx-3 internal-error">
              error (check console)
            </p>
          </Match>
        </Switch>
      </div>
      <div class="d-flex align-items-center">
        <a class="me-4" href="/builtin" target="_blank">
          your robots
        </a>
        <a class="me-4" href="/boards/" target="_blank">
          publish to a board
        </a>
        {shared}
      </div>
    </>
  )

  const barForDemo = () => (
    <>
      <div class="d-flex align-items-center">
        <a class="me-3" href="/">
          Robot Rumble
        </a>
        <Show
          when={state.tutorialState == null}
          fallback={<p>{state.tutorialState?.tutorial?.title}</p>}
        >
          <p class="me-3">Choose lang: </p>
          <div class="d-flex">
            <For each={LANGS}>
              {(lang) => (
                <button
                  class="me-3 no-bold"
                  id={`select-${lang}`}
                  onClick={() => actions.selectLang(lang)}
                >
                  {lang}
                </button>
              )}
            </For>
          </div>
        </Show>
      </div>

      <div class="d-flex align-items-center">{shared}</div>
    </>
  )

  return (
    <div class="_bar d-flex justify-content-between align-items-center">
      <Switch>
        <Match when={state.siteInfo !== null}>{barForUser()}</Match>
        <Match when={state.siteInfo === null}>{barForDemo()}</Match>
      </Switch>
    </div>
  )
}

export default Bar
