export const LANGS = ['Python', 'Javascript'] as const
export type Lang = typeof LANGS[number]

export const GAME_MODES = ['Normal', 'NormalHeal'] as const
export type GameMode = typeof GAME_MODES[number]

export const OUR_TEAM = 'Blue'
