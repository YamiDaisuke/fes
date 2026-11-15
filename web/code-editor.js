import { basicSetup } from "codemirror";
import { EditorView, keymap } from "@codemirror/view";
import { EditorState } from "@codemirror/state";
import { indentWithTab } from "@codemirror/commands";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { lintGutter, setDiagnostics } from "@codemirror/lint";

export function createCodeEditor(parent) {
  let codeChanged = () => {};
  const extensionsFor = (name) => [
    basicSetup,
    keymap.of([indentWithTab]),
    StreamLanguage.define(lua),
    lintGutter(),
    EditorView.contentAttributes.of({ autocapitalize: "off", autocorrect: "off", spellcheck: "false", "aria-label": name }),
    EditorView.updateListener.of((update) => {
      if (update.docChanged) codeChanged(update.state.doc.toString());
    }),
  ];
  const view = new EditorView({ parent });
  const storedFiles = new Map();
  let shownName;
  const clampedLine = (lineNumber) => {
    const doc = view.state.doc;
    return doc.line(Math.min(Math.max(lineNumber, 1), doc.lines));
  };
  return {
    openFile(name, text) {
      if (shownName !== undefined) storedFiles.set(shownName, { state: view.state, scroll: view.scrollSnapshot() });
      shownName = name;
      const stored = storedFiles.get(name);
      if (stored && stored.state.doc.toString() === text) {
        view.setState(stored.state);
        view.dispatch({ effects: stored.scroll });
      } else {
        view.setState(EditorState.create({ doc: text, extensions: extensionsFor(name) }));
      }
    },
    forgetFiles() {
      storedFiles.clear();
      shownName = undefined;
    },
    forgetFile(name) {
      storedFiles.delete(name);
      if (shownName === name) shownName = undefined;
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
