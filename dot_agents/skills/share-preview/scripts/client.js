// window.Shared: live shared state for pages served by share-preview.
//
//   Shared.on(state => render(state))   state: { key: { value, by, at } }
//   Shared.set('pick:12', 'abc')         null deletes the key
//   Shared.name                          who this browser is (asked once)
//
// Opened from file:// there is no server: set() updates local state only,
// so the page still works as a plain file.
(() => {
  const served = location.protocol.startsWith('http');
  let name = localStorage.getItem('share-preview-name') || '';
  if (served && !name) {
    name = (prompt('your name (shown next to your changes)') || 'anon').trim();
    localStorage.setItem('share-preview-name', name);
  }
  let state = {};
  const listeners = new Set();
  const emit = () => listeners.forEach(cb => cb(state));
  if (served) {
    new EventSource('/_shared/events').onmessage = e => {
      state = JSON.parse(e.data);
      emit();
    };
  }
  window.Shared = {
    name,
    get state() { return state; },
    on(cb) { listeners.add(cb); cb(state); return () => listeners.delete(cb); },
    set(key, value) {
      // Optimistic: update now, the server echo confirms.
      state = { ...state };
      if (value === null || value === undefined) delete state[key];
      else state[key] = { value, by: name, at: new Date().toISOString() };
      emit();
      if (served) {
        fetch('/_shared/set', { method: 'POST', body: JSON.stringify({ key, value, by: name }) });
      }
    },
  };
})();
