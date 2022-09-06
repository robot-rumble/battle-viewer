import { createEffect, onMount } from 'solid-js'
import { useStore } from '../store'
import CodeMirror, { Editor, EditorConfiguration, TextMarker } from 'codemirror'
import { Lang } from '../types'

function getOptionsFromLang(lang: Lang): Partial<EditorConfiguration> {
  switch (lang) {
    case 'Javascript':
      return {
        mode: 'javascript',
        tabSize: 2,
        indentUnit: 2,
      }
    case 'Python':
      return {
        mode: 'python',
        tabSize: 4,
        indentUnit: 4,
      }
  }
}

export function Editor() {
  let editorRef: HTMLDivElement
  const [state, actions] = useStore()

  let marks: TextMarker[] = []
  let editor: Editor | null = null

  const clearMarks = () => {
    marks.forEach((mark) => mark.clear())
    marks = []
  }

  onMount(() => {
    // This is made as a local variable in order to appease Typescript
    const editor_ = CodeMirror(editorRef, {
      ...getOptionsFromLang(state.lang),
      lineNumbers: true,
      lineWrapping: true,
      theme: state.settings.theme === 'dark' ? 'material-ocean' : 'default',
      keyMap: state.settings.keyMap.toLowerCase(),
      value: state.code,
      extraKeys: {
        Tab: (cm) => cm.execCommand('indentMore'),
        'Shift-Tab': (cm) => cm.execCommand('indentLess'),
      },
    })

    editor_.on('change', () => {
      clearMarks()
      actions.synchronizeCode(editor_.getValue())
    })

    document.fonts.ready.then(() => {
      editor_.refresh()
    })

    editor = editor_
  })

  createEffect(() => {
    if (!editor) return
    for (const [k, v] of Object.entries(getOptionsFromLang(state.lang))) {
      editor.setOption(k as keyof EditorConfiguration, v)
    }
  })

  createEffect(() => {
    if (!editor) return
    if (state.code !== editor.getValue()) {
      editor.setValue(state.code)
    }
  })

  return <div ref={editorRef!} />
}
