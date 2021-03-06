import CodeMirror from 'codemirror'
import 'codemirror/mode/javascript/javascript.js'
import 'codemirror/mode/python/python.js'
import 'codemirror/keymap/vim.js'
import 'codemirror/keymap/emacs.js'
import 'codemirror/keymap/sublime.js'

import defaultCode from './defaultCode'

function getOptionsFromLang(lang) {
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

customElements.define(
  'code-editor',
  class extends HTMLElement {
    constructor() {
      super()
      this.marks = []
      this.errorCounter = 0
      this.previousErrorCount = 0
      this.settings = null
    }

    clearMarks() {
      this.marks.forEach((mark) => mark.clear())
      this.marks = []
    }

    set errorLoc(errorLoc) {
      if (errorLoc) {
        if (this.errorCounter !== this.previousErrorCount) {
          this.previousErrorCount = this.errorCounter

          const from = {
            line: errorLoc.line - 1,
            ch: errorLoc.ch ? errorLoc.ch - 1 : 0,
          }
          const to = {
            line: errorLoc.endline ? errorLoc.endline - 1 : from.line,
            // if the line is empty, set ch to 1 so that the error indicator is still shown
            ch: errorLoc.endch
              ? errorLoc.endch - 1
              : this._editor.getLine(from.line).length || 1,
          }

          let mark = this._editor.markText(from, to, {
            className: 'inline-error',
          })

          // error is in area that doesn't have a character, eg no colon in python function definition
          if (!mark.lines.length) {
            this._editor.replaceRange(' ', from, to)
            to.ch += 1
            mark = this._editor.markText(from, to, {
              className: 'inline-error',
            })
          }

          this.marks.push(mark)
        }
      } else {
        this.clearMarks()
      }
    }

    set setLang(lang) {
      this.lang = lang
      if (this._editor) {
        for (const [k, v] of Object.entries(getOptionsFromLang(lang))) {
          this._editor.setOption(k, v)
        }
      }
    }

    set setCode(code) {
      this.code = code
      if (this._editor) {
        if (code !== this._editor.getValue()) {
          this._editor.setValue(code)
        }
      }
    }

    connectedCallback() {
      // const localSave = JSON.parse(localStorage.getItem('code_' + this.name))
      // const localCode = localSave ? localSave.code : ''
      // const localLastEdit = localSave ? localSave.lastEdit : 0
      //
      // let initialValue
      // if (this.code && localCode) {
      //   initialValue = this.lastEdit > localLastEdit ? this.code : localCode
      // } else {
      //   initialValue = this.code || localCode || sampleRobot
      // }

      if (!this.lang || !this.settings || !this.code) {
        throw new Error('Missing properties: lang|settings|code')
      }

      this._editor = CodeMirror(this, {
        ...getOptionsFromLang(this.lang),
        lineNumbers: true,
        matchBrackets: true,
        autoRefresh: true,
        lineWrapping: true,
        theme: this.settings.theme === 'Dark' ? 'material-ocean' : 'default',
        keyMap: this.settings.keyMap.toLowerCase(),
        // value: initialValue,
        value: this.code,
        extraKeys: {
          Tab: (cm) => cm.execCommand('indentMore'),
          'Shift-Tab': (cm) => cm.execCommand('indentLess'),
        },
      })

      this._editor.on('change', () => {
        this.clearMarks()
        localStorage.setItem(
          'code_' + this.name,
          JSON.stringify({
            code: this._editor.getValue(),
            lastEdit: Math.floor(Date.now() / 1000),
          }),
        )
        window.code = this._editor.getValue()

        this.dispatchEvent(new CustomEvent('editorChanged', { detail: this._editor.getValue() }))
      })

      document.fonts.ready.then(() => {
        if (this._editor) this._editor.refresh()
      })
    }
  },
)
