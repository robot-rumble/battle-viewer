import { createEffect, onMount } from 'solid-js'
import { basicSetup, EditorState, EditorView } from '@codemirror/basic-setup'
import { ViewUpdate } from '@codemirror/view'
import { useStore } from '../store'

export function Editor() {
  let editorRef: HTMLDivElement
  const [state, actions] = useStore()

  onMount(() => {
    const view = new EditorView({
      state: EditorState.create({
        extensions: [
          basicSetup,
          EditorView.updateListener.of((v: ViewUpdate) => {
            if (v.docChanged) {
              actions.synchronizeCode(v.state.doc.toString())
            }
          }),
        ],
        doc: state.code,
      }),
      parent: editorRef,
    })
    actions.setView(view)
  })

  createEffect(() => {
    if (!state.view) return
    const tr = state.view.state.update({
      changes: {
        from: 0,
        to: state.view.state.doc.length,
        insert: state.code,
      },
    })
    state.view.dispatch(tr)
  })

  return <div ref={editorRef!} />
}
