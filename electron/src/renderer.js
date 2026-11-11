'use strict';

const api = window.onDeck;
const isMac = api.platform === 'darwin';
const isModifierDown = (event) => (isMac ? event.metaKey : event.ctrlKey);

// Labels follow each platform's conventions: ⌘ glyphs on a Mac, "Ctrl+Up" style and F-keys on Windows.
const KEYS = isMac
  ? {
      add: '⌘N',
      rename: '⌘R',
      toggle: 'Space / Return',
      moveUp: '⌘↑',
      moveDown: '⌘↓',
      delete: 'Delete',
      select: '↑ / ↓',
      reorder: '⌘↑ / ⌘↓',
      zoom: '⌘+ / ⌘−',
      help: '?',
      close: '⌘W',
      submit: 'Return',
      cancel: 'Esc',
    }
  : {
      add: 'Ctrl+N',
      rename: 'F2',
      toggle: 'Space / Enter',
      moveUp: 'Ctrl+Up',
      moveDown: 'Ctrl+Down',
      delete: 'Del',
      select: 'Up / Down',
      reorder: 'Ctrl+Up / Ctrl+Down',
      zoom: 'Ctrl+Plus / Ctrl+Minus',
      help: 'F1',
      close: 'Alt+F4',
      submit: 'Enter',
      cancel: 'Esc',
    };

// MARK: - Icons

const ICON_PATHS = {
  circle: '<circle cx="8" cy="8" r="6.4" fill="none" stroke="currentColor" stroke-width="1.4"/>',
  checkCircle:
    '<circle cx="8" cy="8" r="7" fill="currentColor"/><path d="M4.9 8.2l2.1 2.1 4-4.2" fill="none" stroke="var(--on-accent)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowUp: '<path d="M8 13V3.5M3.8 7.6 8 3.4l4.2 4.2" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowDown: '<path d="M8 3v9.5M3.8 8.4 8 12.6l4.2-4.2" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
  pencil: '<path d="M10.6 2.9l2.5 2.5-7.6 7.6-3.1.6.6-3.1z M9.2 4.3l2.5 2.5" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/>',
  plus: '<path d="M8 3v10M3 8h10" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  xmark: '<path d="M4.2 4.2l7.6 7.6M11.8 4.2l-7.6 7.6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
  check: '<path d="M3.2 8.6l3 3L12.8 4.8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
  minimize: '<path d="M3.5 8h9" fill="none" stroke="currentColor" stroke-width="1"/>',
  style:
    '<circle cx="8" cy="8" r="5.6" fill="none" stroke="currentColor" stroke-width="1.2"/><path d="M8 2.4a5.6 5.6 0 0 1 0 11.2z" fill="currentColor"/>',
  close: '<path d="M4 4l8 8M12 4l-8 8" fill="none" stroke="currentColor" stroke-width="1"/>',
  warning:
    '<path d="M8 1.8 15 14H1z" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linejoin="round"/><path d="M8 6v4" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/><circle cx="8" cy="12" r=".8" fill="currentColor"/>',
};

function icon(name) {
  const span = document.createElement('span');
  span.className = 'icon';
  span.setAttribute('aria-hidden', 'true');
  span.innerHTML = `<svg viewBox="0 0 16 16" width="16" height="16">${ICON_PATHS[name]}</svg>`;
  return span;
}

function h(tag, props = {}, ...children) {
  const element = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value === undefined || value === null || value === false) continue;
    if (key === 'class') element.className = value;
    else if (key.startsWith('on')) element.addEventListener(key.slice(2).toLowerCase(), value);
    else if (key in element && typeof value !== 'string') element[key] = value;
    else element.setAttribute(key, value === true ? '' : value);
  }
  element.append(...children.flat().filter((child) => child !== null && child !== undefined));
  return element;
}

function iconButton(props, iconName, label) {
  return h('button', { tabindex: '-1', 'aria-label': label, ...props }, icon(iconName));
}

// MARK: - Actions

const ACTIONS = {
  add: { title: () => 'New Task', shortcut: KEYS.add, isEnabled: () => true },
  rename: { title: () => 'Rename Task', shortcut: KEYS.rename, isEnabled: (i) => i !== null },
  toggleCompletion: {
    title: (isComplete) => (isComplete ? 'Mark Incomplete' : 'Mark Complete'),
    shortcut: KEYS.toggle,
    isEnabled: (i) => i !== null,
  },
  moveUp: { title: () => 'Raise Priority', shortcut: KEYS.moveUp, isEnabled: (i) => i !== null && i > 0 },
  moveDown: {
    title: () => 'Lower Priority',
    shortcut: KEYS.moveDown,
    isEnabled: (i, count) => i !== null && i + 1 < count,
  },
  delete: { title: () => 'Delete Task', shortcut: KEYS.delete, isEnabled: (i) => i !== null },
};

const ZOOM = { min: -2, max: 6 };

// MARK: - State

const state = {
  tasks: [],
  loadError: null,
  selectedId: null,
  zoomStep: 0,
  interaction: { kind: 'browsing' },
};

let saveQueue = Promise.resolve();

const draft = () => (state.interaction.kind === 'editing' ? state.interaction.draft : null);
const isBrowsing = () => state.interaction.kind === 'browsing';
const acceptsCommands = () => state.loadError === null && isBrowsing();
const indexOf = (id) => {
  const index = state.tasks.findIndex((task) => task.id === id);
  return index === -1 ? null : index;
};
const selectionIndex = () => indexOf(state.selectedId);
const renamingId = () => {
  const target = draft()?.target;
  return target && target !== 'new' ? target.rename : null;
};

// Mirrors TaskInteraction.send in the Mac app.
function send(event) {
  const current = state.interaction;
  switch (event.type) {
    case 'showShortcuts':
      if (current.kind === 'browsing') state.interaction = { kind: 'shortcuts' };
      break;
    case 'dismissShortcuts':
      if (current.kind === 'shortcuts') state.interaction = { kind: 'browsing' };
      break;
    case 'beginEditing':
      if (current.kind === 'browsing') state.interaction = { kind: 'editing', draft: event.draft };
      break;
    case 'changeTitle':
      if (current.kind === 'editing') current.draft.title = event.title;
      return; // Typing doesn't need a re-render.
    case 'finishEditing':
      if (current.kind === 'editing') state.interaction = { kind: 'browsing' };
      break;
    case 'requestDeletion':
      if (current.kind === 'browsing') state.interaction = { kind: 'confirmingDeletion', task: event.task };
      break;
    case 'dismissDeletion':
      if (current.kind === 'confirmingDeletion') state.interaction = { kind: 'browsing' };
      break;
    case 'dismissError':
      if (current.kind === 'reportingError') {
        state.interaction = current.resume
          ? { kind: 'editing', draft: current.resume }
          : { kind: 'browsing' };
      }
      break;
    case 'saveFailed':
      if (current.kind !== 'reportingError') {
        state.interaction = { kind: 'reportingError', message: event.message, resume: draft() };
      }
      break;
  }
  render();
}

// MARK: - Persistence

function enqueue(job) {
  saveQueue = saveQueue.then(async () => {
    try {
      await job();
    } catch (error) {
      send({ type: 'saveFailed', message: error.message });
      return;
    }
    render();
  });
}

async function persist(updated) {
  const result = await api.save(updated);
  if (!result.ok) throw new Error(result.error);
  state.tasks = updated;
}

function mutate(transform) {
  enqueue(async () => {
    const updated = transform(state.tasks.map((task) => ({ ...task })));
    if (updated) await persist(updated);
  });
}

// MARK: - Commands

function perform(action, id) {
  if (!acceptsCommands()) return;
  const index = indexOf(id);
  if (!ACTIONS[action].isEnabled(index, state.tasks.length)) return;

  switch (action) {
    case 'add':
      beginEditing({ target: 'new', title: '' });
      break;
    case 'rename':
      state.selectedId = id;
      beginEditing({ target: { rename: id }, title: state.tasks[index].title });
      break;
    case 'toggleCompletion':
      mutate((tasks) => {
        const i = tasks.findIndex((task) => task.id === id);
        if (i === -1) return null;
        tasks[i].isComplete = !tasks[i].isComplete;
        return tasks;
      });
      break;
    case 'moveUp':
    case 'moveDown': {
      const offset = action === 'moveUp' ? -1 : 1;
      mutate((tasks) => {
        const i = tasks.findIndex((task) => task.id === id);
        const j = i + offset;
        if (i === -1 || j < 0 || j >= tasks.length) return null;
        [tasks[i], tasks[j]] = [tasks[j], tasks[i]];
        return tasks;
      });
      break;
    }
    case 'delete':
      send({ type: 'requestDeletion', task: state.tasks[index] });
      break;
  }
}

function beginEditing(newDraft) {
  send({ type: 'beginEditing', draft: newDraft });
}

function finishEditing() {
  send({ type: 'finishEditing' });
}

function commitEditing() {
  const current = draft();
  const title = current?.title.trim();
  if (!title) return;

  enqueue(async () => {
    // Ignore a repeated Return that arrives after this draft was already saved.
    if (draft() !== current) return;
    if (current.target === 'new') {
      const task = { id: crypto.randomUUID().toUpperCase(), title, isComplete: false };
      await persist([...state.tasks, task]);
      state.selectedId = task.id;
    } else {
      const tasks = state.tasks.map((task) => ({ ...task }));
      const i = tasks.findIndex((task) => task.id === current.target.rename);
      if (i !== -1 && tasks[i].title !== title) {
        tasks[i].title = title;
        await persist(tasks);
      }
    }
    state.interaction = { kind: 'browsing' };
  });
}

function deleteTask(task) {
  enqueue(async () => {
    const index = indexOf(task.id);
    if (index === null) return;
    await persist(state.tasks.filter((item) => item.id !== task.id));
    if (state.selectedId === task.id) {
      state.selectedId = state.tasks.length
        ? state.tasks[Math.min(index, state.tasks.length - 1)].id
        : null;
    }
  });
}

function select(id) {
  if (state.selectedId === id) return;
  state.selectedId = id;
  if (renamingId() && renamingId() !== id) {
    finishEditing();
  } else {
    render();
  }
}

function moveSelection(offset) {
  const count = state.tasks.length;
  if (!count) return;
  const index = selectionIndex();
  const next =
    index === null
      ? offset > 0
        ? 0
        : count - 1
      : Math.min(Math.max(index + offset, 0), count - 1);
  select(state.tasks[next].id);
}

async function zoom(kind) {
  const step = state.zoomStep;
  const target =
    kind === 'increase' ? Math.min(step + 1, ZOOM.max) : kind === 'decrease' ? Math.max(step - 1, ZOOM.min) : 0;
  if (target === step) return;
  state.zoomStep = target;
  state.zoomStep = await api.setZoom(target);
}

function showContextMenu(task) {
  const index = indexOf(task.id);
  const count = state.tasks.length;
  const entry = (action) => ({
    id: `${action}:${task.id}`,
    label: ACTIONS[action].title(task.isComplete),
    enabled: acceptsCommands() && ACTIONS[action].isEnabled(index, count),
  });
  api.showContextMenu([
    entry('rename'),
    entry('toggleCompletion'),
    { separator: true },
    entry('moveUp'),
    entry('moveDown'),
    { separator: true },
    entry('delete'),
  ]);
}

api.onContextAction((value) => {
  const separator = value.indexOf(':');
  perform(value.slice(0, separator), value.slice(separator + 1));
});

// MARK: - Views

function inputField({ placeholder, label }) {
  const current = draft();
  const field = h('input', {
    class: 'field',
    type: 'text',
    placeholder,
    'aria-label': label,
    value: current?.title ?? '',
  });
  field.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      commitEditing();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      finishEditing();
    }
    event.stopPropagation();
  });
  return field;
}

function bindSubmit(field, button) {
  const update = () => {
    button.disabled = field.value.trim() === '';
  };
  field.addEventListener('input', () => {
    send({ type: 'changeTitle', title: field.value });
    update();
  });
  update();
}

function composer() {
  const field = inputField({ placeholder: 'What needs doing?', label: 'Task title' });
  const submit = iconButton(
    { class: 'plain-icon', title: `Add Task (${KEYS.submit})`, onclick: commitEditing },
    'check',
    'Add Task'
  );
  bindSubmit(field, submit);
  return h(
    'div',
    { class: 'composer glass' },
    h('div', { class: 'caption-text', role: 'heading', 'aria-level': '2' }, 'New task'),
    h(
      'div',
      { class: 'composer-row' },
      field,
      iconButton({ class: 'plain-icon', title: `Cancel (${KEYS.cancel})`, onclick: finishEditing }, 'xmark', 'Cancel'),
      submit
    )
  );
}

function renameField() {
  const field = inputField({ placeholder: 'Task title', label: 'Task title' });
  const submit = iconButton(
    { class: 'plain-icon', title: `Save Rename (${KEYS.submit})`, onclick: commitEditing },
    'check',
    'Save Rename'
  );
  bindSubmit(field, submit);
  return h('div', { class: 'rename' }, field, submit);
}

function newTaskButton(large = false) {
  return h(
    'button',
    {
      class: `new-task glass${large ? ' large' : ''}`,
      tabindex: '-1',
      title: `New Task (${KEYS.add})`,
      onclick: () => perform('add', null),
    },
    icon('plus'),
    h('span', {}, 'New Task')
  );
}

function taskRow(task, index) {
  const isSelected = task.id === state.selectedId;
  const isRenaming = task.id === renamingId();
  const toggleLabel = task.isComplete ? `Mark “${task.title}” incomplete` : `Mark “${task.title}” complete`;

  const row = h(
    'div',
    {
      class: `row glass${isSelected ? ' selected' : ''}${task.isComplete ? ' complete' : ''}`,
      role: 'option',
      'aria-selected': String(isSelected),
      'data-id': task.id,
      onmousedown: (event) => {
        if (event.button === 0 && !event.target.closest('input, button')) select(task.id);
      },
      oncontextmenu: (event) => {
        event.preventDefault();
        showContextMenu(task);
      },
    },
    h('span', { class: 'number', 'aria-label': `Priority ${index + 1}` }, String(index + 1).padStart(2, '0')),
    iconButton(
      {
        class: 'toggle',
        title: task.isComplete ? 'Mark incomplete' : 'Mark complete',
        onclick: () => perform('toggleCompletion', task.id),
      },
      task.isComplete ? 'checkCircle' : 'circle',
      toggleLabel
    ),
    isRenaming ? renameField() : h('span', { class: 'title' }, task.title)
  );
  return row;
}

function dock() {
  const context = { index: selectionIndex(), count: state.tasks.length };
  const enabled = acceptsCommands();
  const control = (action, iconName) => {
    const title = ACTIONS[action].title(false);
    return iconButton(
      {
        class: 'dock-control',
        title: `${title} (${ACTIONS[action].shortcut})`,
        disabled: !enabled || !ACTIONS[action].isEnabled(context.index, context.count),
        onclick: () => perform(action, state.selectedId),
      },
      iconName,
      title
    );
  };
  const addButton = newTaskButton(true);
  addButton.disabled = !enabled;
  return h(
    'div',
    { class: 'dock', role: 'toolbar', 'aria-label': 'Task controls' },
    h(
      'div',
      { class: 'dock-group glass' },
      control('moveUp', 'arrowUp'),
      control('moveDown', 'arrowDown'),
      h('span', { class: 'dock-divider' }),
      control('rename', 'pencil')
    ),
    addButton
  );
}

function emptyView() {
  const isAdding = draft()?.target === 'new';
  return h(
    'div',
    { class: 'empty' },
    h('h1', { class: 'empty-heading' }, 'Off duty.'),
    h('p', { class: 'empty-message' }, 'Your list is clear. Enjoy the quiet.'),
    h('div', { class: 'empty-controls' }, isAdding ? composer() : newTaskButton())
  );
}

function errorView() {
  return h(
    'div',
    { class: 'unavailable' },
    icon('warning'),
    h('h1', {}, 'Couldn’t Open Tasks'),
    h('p', {}, state.loadError)
  );
}

function listView() {
  const isAdding = draft()?.target === 'new';
  const list = h(
    'div',
    { class: 'list', id: 'list', role: 'listbox', tabindex: '-1', 'aria-label': 'Priority list' },
    state.tasks.map(taskRow)
  );
  return [isAdding ? h('div', { class: 'composer-wrap' }, composer()) : null, list, dock()];
}

// MARK: - Rendering

const content = document.getElementById('content');
const statusLabel = document.getElementById('status');

function render() {
  const previousList = document.getElementById('list');
  const scrollTop = previousList?.scrollTop ?? 0;

  const open = state.tasks.filter((task) => !task.isComplete).length;
  statusLabel.textContent = state.tasks.length && !state.loadError ? `${open} of ${state.tasks.length} open` : '';

  if (state.loadError) content.replaceChildren(errorView());
  else if (state.tasks.length === 0) content.replaceChildren(emptyView());
  else content.replaceChildren(...listView().filter(Boolean));

  const list = document.getElementById('list');
  if (list) {
    list.scrollTop = scrollTop;
    const focusId = renamingId() ?? state.selectedId;
    list.querySelector(`[data-id="${CSS.escape(focusId ?? '')}"]`)?.scrollIntoView({ block: 'nearest' });
  }

  syncDialogs();
  refreshLiquidGlass();

  const field = content.querySelector('input.field');
  if (field && state.interaction.kind === 'editing') {
    field.focus();
    field.select();
  } else if (isBrowsing()) {
    (list ?? document.body).focus({ preventScroll: true });
  }
}

// MARK: - Dialogs

const dialogs = {
  delete: document.getElementById('delete-dialog'),
  error: document.getElementById('error-dialog'),
  shortcuts: document.getElementById('shortcuts-dialog'),
};

function syncDialogs() {
  const { kind } = state.interaction;
  const wanted = {
    delete: kind === 'confirmingDeletion',
    error: kind === 'reportingError',
    shortcuts: kind === 'shortcuts',
  };
  if (wanted.delete) {
    document.getElementById('delete-message').textContent =
      `“${state.interaction.task.title}” will be removed from the list.`;
  }
  if (wanted.error) {
    document.getElementById('error-message').textContent = state.interaction.message;
  }
  for (const [name, dialog] of Object.entries(dialogs)) {
    if (wanted[name] && !dialog.open) dialog.showModal();
    if (!wanted[name] && dialog.open) dialog.close();
  }
}

const dismissals = {
  delete: { kind: 'confirmingDeletion', event: 'dismissDeletion' },
  error: { kind: 'reportingError', event: 'dismissError' },
  shortcuts: { kind: 'shortcuts', event: 'dismissShortcuts' },
};

for (const [name, dialog] of Object.entries(dialogs)) {
  // Covers Esc and any other way the dialog closes while the state still expects it.
  dialog.addEventListener('close', () => {
    if (state.interaction.kind === dismissals[name].kind) send({ type: dismissals[name].event });
  });
}

document.getElementById('delete-cancel').addEventListener('click', () => send({ type: 'dismissDeletion' }));
document.getElementById('delete-confirm').addEventListener('click', () => {
  const { task } = state.interaction;
  send({ type: 'dismissDeletion' });
  if (task) deleteTask(task);
});
document.getElementById('error-ok').addEventListener('click', () => send({ type: 'dismissError' }));
document.getElementById('shortcuts-done').addEventListener('click', () => send({ type: 'dismissShortcuts' }));

const SHORTCUTS = [
  ['Select a task', KEYS.select],
  ['Add a task', KEYS.add],
  ['Rename a task', KEYS.rename],
  ['Reorder', KEYS.reorder],
  ['Toggle done', KEYS.toggle],
  ['Delete a task', KEYS.delete],
  ['Zoom', KEYS.zoom],
  ['Show shortcuts', KEYS.help],
  ['Close window', KEYS.close],
];
document
  .getElementById('shortcut-grid')
  .append(...SHORTCUTS.flatMap(([title, keys]) => [h('span', {}, title), h('kbd', {}, keys)]));

// MARK: - Window controls

const minimizeButton = document.getElementById('minimize');
const closeButton = document.getElementById('close');
minimizeButton.append(icon('minimize'));
closeButton.append(icon('close'));
minimizeButton.addEventListener('click', () => api.minimize());
closeButton.addEventListener('click', () => api.close());
document.body.classList.add(isMac ? 'mac' : 'windows');

// Windows lists the primary button first.
if (!isMac) {
  const buttons = document.querySelector('#delete-dialog .dialog-buttons');
  buttons.prepend(document.getElementById('delete-confirm'));
}

// MARK: - Style

const styleButton = document.getElementById('style');
styleButton.append(icon('style'));
styleButton.addEventListener('click', () => {
  const rect = styleButton.getBoundingClientRect();
  api.showMaterialMenu({ x: rect.left, y: rect.bottom });
});

let currentMaterial = api.material;

// rt-liquid-glass gives every element carrying the rt-liquid-glass attribute its own
// displacement filter. Tag the glass surfaces after each render, then ask it to rescan.
function refreshLiquidGlass() {
  const isLiquid = currentMaterial === 'liquid';
  document.querySelectorAll('.glass').forEach((element) => {
    if (isLiquid) element.setAttribute('rt-liquid-glass', '');
    else element.removeAttribute('rt-liquid-glass');
  });
  window.rtLiquidGlass?.refresh();
}

function applyMaterial(material) {
  currentMaterial = material;
  for (const name of ['liquid', 'frosted', 'acrylic', 'mica']) {
    document.body.classList.toggle(`material-${name}`, name === material);
  }
  refreshLiquidGlass();
}

applyMaterial(api.material);
api.onMaterialChange(applyMaterial);

// MARK: - Keyboard

document.addEventListener('keydown', (event) => {
  const modifier = isModifierDown(event);
  const key = event.key;
  const kind = state.interaction.kind;

  if (modifier && !event.altKey && key.toLowerCase() === 'w') {
    event.preventDefault();
    api.close();
    return;
  }

  if (modifier && !event.altKey && kind !== 'confirmingDeletion' && kind !== 'reportingError') {
    const zoomKind = { '=': 'increase', '+': 'increase', '-': 'decrease', _: 'decrease', 0: 'reset' }[key];
    if (zoomKind) {
      event.preventDefault();
      zoom(zoomKind);
      return;
    }
  }

  if (!acceptsCommands() || event.target.closest?.('input, dialog')) return;

  const plain = !modifier && !event.altKey;
  // Ctrl+Up/Down everywhere; Alt+Up/Down too on Windows, as in many Windows list editors.
  const reorder = (modifier && !event.altKey) || (!isMac && event.altKey && !event.ctrlKey);
  let action = null;
  let handled = true;

  if (reorder && key === 'ArrowUp') action = 'moveUp';
  else if (reorder && key === 'ArrowDown') action = 'moveDown';
  else if (modifier && !event.altKey && !event.shiftKey && key.toLowerCase() === 'n') action = 'add';
  else if (modifier && !event.altKey && !event.shiftKey && key.toLowerCase() === 'r') action = 'rename';
  else if (plain && key === 'F2') action = 'rename';
  else if (plain && (key === ' ' || key === 'Enter')) action = 'toggleCompletion';
  else if (plain && (key === 'Delete' || (isMac && key === 'Backspace'))) action = 'delete';
  else if (plain && (key === '?' || key === 'F1')) send({ type: 'showShortcuts' });
  else if (plain && key === 'ArrowUp') moveSelection(-1);
  else if (plain && key === 'ArrowDown') moveSelection(1);
  else if (plain && key === 'Home' && state.tasks.length) select(state.tasks[0].id);
  else if (plain && key === 'End' && state.tasks.length) select(state.tasks.at(-1).id);
  else handled = false;

  if (action) perform(action, action === 'add' ? null : state.selectedId);
  if (handled) event.preventDefault();
});

// Ctrl+mouse wheel zooms on Windows, as it does in most Windows apps.
document.addEventListener(
  'wheel',
  (event) => {
    if (isMac || !event.ctrlKey) return;
    event.preventDefault();
    if (event.deltaY) zoom(event.deltaY < 0 ? 'increase' : 'decrease');
  },
  { passive: false }
);

// Keep clicks on chrome from stealing focus from the list.
document.addEventListener('mousedown', (event) => {
  if (event.target.closest('button') && !event.target.closest('dialog')) event.preventDefault();
});

// MARK: - Start

api.load().then(({ tasks, error, zoomStep }) => {
  state.tasks = tasks;
  state.loadError = error;
  state.zoomStep = zoomStep;
  render();
});
