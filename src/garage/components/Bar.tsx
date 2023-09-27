import { For, Match, Switch } from 'solid-js'
import { ROUTES, useStore } from '../store'
import { LANGS } from '../utils/constants'

const Bar = () => {
  const [state, actions] = useStore()

  const shared = (
    <div class="d-flex align-items-center">
      <a class="me-4" href={ROUTES.docs} target="_blank">
        docs
      </a>
      <div class="_img-settings" onClick={actions.toggleSettingsMenu} />
    </div>
  )

  const barForUser = () => (
    <>
      <div class="d-flex align-items-center">
        <div class="d-flex">
          <p class="me-3">The Garage -- editing</p>
          <a href={ROUTES.viewRobot(3)} target="_blank">
            r2
          </a>
        </div>
        <button class="button ms-4" onClick={actions.saveRobotCode}>
          save
        </button>
        <p class="mx-3 disappearing-" style="visibility: hidden;">
          saved
        </p>
      </div>
      <div class="d-flex align-items-center">
        <a class="me-4" href="/builtin" target="_blank">
          your robots
        </a>
        <a class="me-4" href="/boards/" target="_blank">
          publish to a board
        </a>
        <a
          class="me-4"
          href="https://rr-docs.readthedocs.io/en/latest/"
          target="_blank"
        >
          docs
        </a>
        <div class="_img-settings"></div>
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
        <p class="me-3">Choose lang: </p>
        <div class="d-flex">
          <For each={LANGS}>
            {(lang) => (
              <button
                class="button me-2"
                id={`select-${lang}`}
                onClick={() => actions.selectLang(lang)}
              >
                {lang}
              </button>
            )}
          </For>
        </div>
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
