# UI kit: qs.Ui and qs.Commons

`import qs.Ui` and `import qs.Commons`. Registry: `/usr/share/omarchy/shell/Ui/qmldir`.
Read a component's QML before using an unfamiliar property.

## Two widget + panel patterns

**A. The panel is the widget** (power, agents). The manifest's `barWidget`
entry points at `Panel.qml`. The root is a `Panel` holding a
`BarIconButton` and a `KeyboardPanel`:

```qml
Panel {
  id: root; moduleName: "my.id"; ipcTarget: "my.id"
  implicitWidth: button.implicitWidth; implicitHeight: button.implicitHeight
  BarIconButton { id: button; anchors.fill: parent; bar: root.bar; text: "󰊚"; onPressed: root.toggle() }
  KeyboardPanel { id: panel; anchorItem: button; owner: root; bar: root.bar; open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)
    PanelKeyCatcher { id: keys; anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.switchPanel(d) }
      Column { id: column; width: parent.width } } }
}
```

Simple, but `ipcTarget` here is registered once per monitor (only the first
is used), and any state or polling in it runs per monitor.

**B. A widget that loads a panel** (weather, clock; the skill's template).
`BarWidget` + `Loader { source: "Panel.qml" }` + `injectPanel()` copying
`bar`, `settings`, `anchorItem`, `hostWidget` and the service into the panel.
The panel uses `manageIpc: false` and `owner: hostWidget || root`. Use this
with a service.

## Bar side

| Component | Use |
|---|---|
| `BarWidget` | Root of a widget. `bar`, `moduleName`, `settings`, `setting(k, fallback)`, `broadcast(method)`, `vertical`, `barSize`. |
| `WidgetButton` | Text button in the bar. `bar`, `text`, `active` (panel open), `dimmed`, `foreground`, `tooltipText`, signals `pressed(button)`, `wheelMoved(delta)`. Registers as a click target, so clicks reach it while another panel is open. |
| `BarIconButton` | One glyph, optically centred. `iconComponent`, `slotSize`. |
| `BarIndicator` | Status glyph with active/inactive texts and tooltips. |

## Panel side

| Component | Use |
|---|---|
| `Panel` | Root of a popup. `open()`, `close()`, `toggle()`, `opened`, `controller.show()/hide()`, `switchPanel(dir)`, `ipcTarget`, `manageIpc`. |
| `KeyboardPanel` | The popup window. Required: `anchorItem`, `bar`. Set `owner`, `open`, `focusTarget`, `contentWidth: fittedContentWidth(w)`, `contentHeight: fittedContentHeight(h)` (both clamp to the screen). Handles click-outside, fades, one popout per bar, dismiss surfaces on other monitors. |
| `PopupCard` | Older popup; does not take keyboard focus from a hotkey. Prefer `KeyboardPanel`. |
| `PanelKeyCatcher` | Key dispatcher around the content: `moveRequested(dx, dy)` (arrows, h/j/k/l), `activateRequested` (Enter, Space), `returnRequested`, `closeRequested` (Esc), `tabRequested(dir)`, `deleteRequested` (x), `textKey(text)`. `blocked` passes everything to children. |
| `PanelHero` | Header: `iconComponent`, `title`, `meta`, `detail`, `trailingControl`, `foreground`, `fontFamily`. |
| `PanelSectionHeader` | Small bold section title. |
| `PanelSeparator` | 1 px rule. |
| `PanelActionButton` | Small icon button at the end of a row: `iconText`, `tooltipText`, `foreground`, `hoverColor` (pass `bar.urgent` for destructive), `clicked()`. |
| `Button` | `text`, `iconText`, `tooltipText`, `bordered`, `selected`, `active`, `clicked()`, `rightClicked()`. |
| `ButtonGroup` | Pick one of `options` (`{value, label, icon, tooltip}`); `changed(value)`. |
| `TextField` | Qt TextField with the kit's styling; `password`, `foreground`. |
| `Toggle` / `ToggleSwitch` | Labeled row / bare switch. Stateless: flip `checked` yourself. |
| `Dropdown`, `SearchableDropdown` | `options`, `value`, `changed(string)`, `popupOpen`. |
| `MultiSelect` | `values`, `changed(var)`; can load options from `optionsCommand`. |
| `NumberField`, `PanelSlider` | Numbers. |
| `ConfirmDialog` | In-panel confirmation: `opened`, `message`, `confirmText`, `confirmed()`, `canceled()`; forward keys with `handleKey(event)`. |
| `PanelToolTip` | Tooltip inside a hovered item. |
| `CursorSurface` | Row highlight driven by `hasCursor`, never by hover directly. |

## Keyboard conventions

h/j/k/l and arrows move, Enter or Space activates, Esc closes, Tab and
Shift+Tab go to the next or previous bar panel, x deletes, single letters are
shortcuts (`textKey`). The first move only shows the cursor
(`cursorActive`); reset it when the panel opens. Hover moves the same cursor:
`onHovered: function(h) { if (h) { root.cursorActive = true; root.index = index } }`.

Set `blocked` on the `PanelKeyCatcher` while an inline editor or a dropdown
popup is active (`blocked: field.activeFocus || dropdown.popupOpen`).

## Commons

- **Color**: `foreground`, `background`, `accent`, `urgent`, `muted`, and per
  surface `Color.bar.*`, `Color.popups.*`, `Color.tooltip.*`. Theme switches
  update them live. In widgets and panels use `bar.foreground`, `bar.urgent`,
  `bar.fontFamily`; dim text is `Qt.darker(foreground, 1.4)`. There is no
  warning color: use `urgent` for attention, `accent` for "new".
- **Style**: `Style.space(px)` scales with the font size; wrap every pixel
  literal in it. Fonts: `Style.font.caption` (10), `bodySmall`, `body` (12),
  `subtitle`, `title`, `heading`, `display` (24). `Style.font.family`,
  `Style.cornerRadius`, `Style.spacing.*`, `Style.bar.iconSlot`.
- **Util**: `alpha(color, a)`, `clamp`, `shellQuote`, `execDetached`,
  `parseModuleJson`, `fileUrl`, `cloneJson`.

## Layout habits

- Wrap the content in a `Flickable` (`contentHeight: column.implicitHeight`,
  `clip: true`, `boundsBehavior: Flickable.StopAtBounds`) so a long panel
  scrolls on small screens.
- Lists inside the panel: `ListView` with `height: Math.min(contentHeight, Style.space(360))`.
- Every Text with outside data: `textFormat: Text.PlainText`, `elide`, a width.
- Hide a widget that has nothing to show: `visible: false` and `implicitWidth: 0`.
- Nerd Font glyphs (`󰋚`) render in the bar font; note the glyph name in a comment.
