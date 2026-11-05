import { basicSetup } from "codemirror";
import { EditorView, keymap } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
import { indentWithTab } from "@codemirror/commands";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { lintGutter, setDiagnostics } from "@codemirror/lint";

export function createCodeEditor(parent) {
  let codeChanged = () => {};
  const extensions = [
    basicSetup,
    keymap.of([indentWithTab]),
    StreamLanguage.define(lua),
    lintGutter(),
    EditorView.contentAttributes.of({ autocapitalize: "off", autocorrect: "off", spellcheck: "false", "aria-label": "main.lua" }),
    EditorView.updateListener.of((update) => {
      if (update.docChanged) codeChanged(update.state.doc.toString());
    }),
  ];
  const view = new EditorView({ parent, extensions });
  const clampedLine = (lineNumber) => {
    const doc = view.state.doc;
    return doc.line(Math.min(Math.max(lineNumber, 1), doc.lines));
  };
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
    showError(lineNumber, message) {
      const { from, to } = clampedLine(lineNumber);
      view.dispatch(setDiagnostics(view.state, [{ from, to, severity: "error", message }]));
    },
    clearError() {
      view.dispatch(setDiagnostics(view.state, []));
    },
    moveCursorToLine(lineNumber) {
      view.dispatch({ selection: { anchor: clampedLine(lineNumber).from }, scrollIntoView: true });
    },
  };
}
