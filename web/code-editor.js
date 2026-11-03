import { basicSetup } from "codemirror";
import { EditorView, keymap } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
import { indentWithTab } from "@codemirror/commands";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";

export function createCodeEditor(parent) {
  let codeChanged = () => {};
  const extensions = [
    basicSetup,
    keymap.of([indentWithTab]),
    StreamLanguage.define(lua),
    EditorView.contentAttributes.of({ autocapitalize: "off", autocorrect: "off", spellcheck: "false", "aria-label": "main.lua" }),
    EditorView.updateListener.of((update) => {
      if (update.docChanged) codeChanged(update.state.doc.toString());
    }),
  ];
  const view = new EditorView({ parent, extensions });
  return {
    setCode(doc) {
      view.setState(EditorState.create({ doc, extensions }));
    },
    onCodeChange(listener) {
      codeChanged = listener;
    },
    focus() {
      view.focus();
    },
  };
}
