import { Index } from 'solid-js'
import { useStore } from '../store'
import { KEYMAPS, THEMES } from '../utils/settings'

function createSelect<T>(
  options: readonly string[],
  selected: string,
  onChange: (value: T) => void,
) {
  return (
    <select onChange={(e) => onChange(e.currentTarget.value as unknown as T)}>
      <Index each={options}>
        {(val) => (
          <option value={val()} selected={val() === selected}>
            {val()}
          </option>
        )}
      </Index>
    </select>
  )
}

export const SettingsMenu = () => {
  const [state, actions] = useStore()

  return (
    <div class="m-3">
      <div class="d-flex">
        <div class="me-3">
          <p>keymap</p>
          {createSelect(KEYMAPS, state.settings.keyMap, actions.setKeyMap)}
        </div>
        <div>
          <p>theme</p>
          {createSelect(THEMES, state.settings.theme, actions.setTheme)}
        </div>
      </div>
      <button class="button mt-2" onClick={actions.toggleSettingsMenu}>
        close
      </button>
      <p class="mt-2 text-grey">Please note that you may have to reload the page for all the changes to go into effect.</p>
    </div>
  )
}

export default SettingsMenu