const LANGS = ['Python', 'Javascript'] as const
export type Lang = typeof LANGS[number]
