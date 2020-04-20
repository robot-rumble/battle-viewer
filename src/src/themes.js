const darkTheme = {
  white: 'black',
  black: 'white',
  red: '#B73860',
  blue: '#226ea2',
  orange: '#EF8509',
  'light-red': '#ff6797',
  'light-blue': '#4db6ff',
  'grey-1': '#999999',
  'grey-2': '#383838',
  'grey-3': '#262626',
}

export function applyTheme (theme) {
  if (theme === 'Dark') {
    for (const [key, val] of Object.entries(darkTheme)) {
      document.documentElement.style.setProperty(`--${key}`, val)
    }
  }
}
