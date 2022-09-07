import { createEffect, onMount } from 'solid-js'
import { ErrorLoc, useStore } from '../store'
import CodeMirror, { Editor, EditorConfiguration, TextMarker } from 'codemirror'
import { Lang } from '../constants'
import { Settings } from '../settings'

import 'codemirror/mode/javascript/javascript.js'
import 'codemirror/mode/python/python.js'
import 'codemirror/keymap/vim.js'
import 'codemirror/keymap/emacs.js'
import 'codemirror/keymap/sublime.js'

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

class CodeMirrorWrapper {
  private editor: Editor
  private marks: TextMarker[] = []

  constructor(
    node: HTMLElement,
    lang: Lang,
    settings: Settings,
    code: string,
    onChange: (code: string) => void,
  ) {
    this.editor = CodeMirror(node, {
      ...getOptionsFromLang(lang),
      lineNumbers: true,
      lineWrapping: true,
      theme: settings.theme === 'dark' ? 'material-ocean' : 'default',
      keyMap: settings.keyMap.toLowerCase(),
      value: code,
      extraKeys: {
        Tab: (cm) => cm.execCommand('indentMore'),
        'Shift-Tab': (cm) => cm.execCommand('indentLess'),
      },
    })

    this.editor.on('change', () => {
      this.clearMarks()
      onChange(this.editor.getValue())
    })

    document.fonts.ready.then(() => {
      this.editor.refresh()
    })
  }

  clearMarks() {
    this.marks.forEach((mark) => mark.clear())
    this.marks = []
  }

  changeLang(lang: Lang) {
    for (const [k, v] of Object.entries(getOptionsFromLang(lang))) {
      this.editor.setOption(k as keyof EditorConfiguration, v)
    }
  }

  setCode(code: string) {
    if (code !== this.editor.getValue()) {
      this.editor.setValue(code)
    }
  }

  setErrorLoc(errorLoc: ErrorLoc) {
    const from = {
      line: errorLoc.start[0] - 1,
      ch: errorLoc.start[1] ? errorLoc.start[1] - 1 : 0,
    }
    const to = {
      line: errorLoc.end?.[0] ? errorLoc.end?.[0] - 1 : from.line,
      // if the line is empty, set ch to 1 so that the error indicator is still shown
      ch: errorLoc.end?.[1]
        ? errorLoc.end?.[1] - 1
        : this.editor.getLine(from.line).length || 1,
    }

    let mark = this.editor.markText(from, to, {
      className: 'inline-error',
    })

    // error is in area that doesn't have a character, eg no colon in python function definition
    // @ts-ignore
    if (!mark.lines.length) {
      this.editor.replaceRange(' ', from, to)
      to.ch += 1
      mark = this.editor.markText(from, to, {
        className: 'inline-error',
      })
    }

    this.marks.push(mark)
  }
}

export function Editor() {
  let editorRef: HTMLDivElement
  const [state, actions] = useStore()

  let editor: CodeMirrorWrapper | null = null

  onMount(() => {
    editor = new CodeMirrorWrapper(
      editorRef,
      state.lang,
      state.settings,
      state.code,
      actions.synchronizeCode,
    )
  })

  createEffect(() => {
    editor?.changeLang(state.lang)
  })

  createEffect(() => {
    editor?.setCode(state.code)
  })

  createEffect(() => {
    if (!editor) return
    if (state.workerErrorLoc) {
      editor.setErrorLoc(state.workerErrorLoc)
    } else {
      editor.clearMarks()
    }
  })

  return <div class="_editor" ref={editorRef!} />
}
