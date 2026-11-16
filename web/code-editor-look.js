import { EditorView } from "@codemirror/view";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

const screen = EditorView.theme(
  {
    "&": { height: "100%", color: "var(--code-text)", backgroundColor: "var(--code-screen)" },
    "&.cm-focused": { outline: "none" },
    ".cm-scroller": { font: "var(--type-code)" },
    ".cm-cursor": {
      border: "none",
      marginLeft: "0",
      width: "calc(7 * var(--u))",
      backgroundColor: "var(--code-cursor)",
      mixBlendMode: "difference",
    },
    ".cm-activeLine": { backgroundColor: "var(--code-active-line)" },
    ".cm-selectionBackground, &.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground": {
      background: "var(--code-selection)",
    },
    ".cm-gutters": { color: "var(--code-line-number)", backgroundColor: "var(--code-gutter)", border: "none" },
    ".cm-activeLineGutter": { color: "var(--code-text)", backgroundColor: "var(--code-active-line)" },
    ".cm-foldGutter .cm-gutterElement": { width: "calc(7 * var(--u))" },
    ".cm-gutter-lint": { width: "calc(11 * var(--u))" },
    ".cm-gutter-lint .cm-gutterElement": { display: "grid", placeItems: "center", padding: "0" },
    ".cm-lint-marker-error": { content: "none", width: "calc(5 * var(--u))", height: "calc(5 * var(--u))", backgroundColor: "var(--coral)" },
    ".cm-lintRange-error": { backgroundImage: "none", boxShadow: "inset 0 calc(-1 * var(--u)) 0 0 var(--coral)" },
    ".cm-tooltip.cm-tooltip-lint": {
      color: "var(--ink)",
      backgroundColor: "var(--coral)",
      border: "var(--u) solid var(--ink)",
      font: "var(--type-code)",
    },
    ".cm-diagnostic-error": { borderLeft: "none" },
  },
  { dark: true },
);

const syntax = HighlightStyle.define([
  { tag: tags.keyword, color: "var(--code-keyword)" },
  { tag: tags.string, color: "var(--code-string)" },
  { tag: tags.number, color: "var(--code-number)" },
  { tag: tags.comment, color: "var(--code-comment)" },
  { tag: tags.standard(tags.variableName), color: "var(--code-builtin)" },
]);

export const codeEditorLook = [screen, syntaxHighlighting(syntax)];
