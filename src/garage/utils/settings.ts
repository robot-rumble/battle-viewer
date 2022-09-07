export const THEMES = ['light', 'dark'] as const
export type Theme = typeof THEMES[number]

export const KEYMAPS = ['default', 'sublime', 'emacs', 'vim'] as const
export type KeyMap = typeof KEYMAPS[number]

export interface Settings {
  theme: Theme
  keyMap: KeyMap
}

const DEFAULT_SETTINGS: Settings = {
  theme: 'light',
  keyMap: 'default',
}

const KEY = 'settings'

export function loadSettings() {
  let settings = DEFAULT_SETTINGS
  const storedSettings = localStorage.getItem(KEY)
  if (storedSettings) {
    try {
      settings = JSON.parse(storedSettings) as Settings
    } catch (_e) {}
  }
  return settings
}

export function saveSettings(settings: Settings) {
  window.localStorage.setItem(KEY, JSON.stringify(settings))
}
