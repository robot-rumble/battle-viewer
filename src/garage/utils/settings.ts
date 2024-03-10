import { GameMode } from "./constants"

export const THEMES = ['light', 'dark'] as const
export type Theme = typeof THEMES[number]

export const KEYMAPS = ['default', 'sublime', 'emacs', 'vim'] as const
export type KeyMap = typeof KEYMAPS[number]

export const TURN_TIMEOUT_ENABLED = ['turn timeout enabled', 'turn timeout disabled'] as const
export type TurnTimeoutEnabled = typeof TURN_TIMEOUT_ENABLED[number]

export interface Settings {
  theme: Theme
  keyMap: KeyMap
  timeoutEnabled: TurnTimeoutEnabled
  gameMode: GameMode
}

const DEFAULT_SETTINGS: Settings = {
  theme: 'light',
  keyMap: 'default',
  timeoutEnabled: 'turn timeout enabled',
  gameMode: 'Normal'
}

const KEY = 'settings'

export function loadSettings() {
  let settings = DEFAULT_SETTINGS
  const storedSettings = localStorage.getItem(KEY)
  if (storedSettings) {
    try {
      settings = JSON.parse(storedSettings) as Settings
    } catch (_e) { }
  }
  return settings
}

export function saveSettings(settings: Settings) {
  window.localStorage.setItem(KEY, JSON.stringify(settings))
}
