window.inputFilters = (function () {
  function isControlKey(e) {
    return e.ctrlKey || e.metaKey || e.altKey || e.key.length !== 1;
  }

  function allowLetters(e) {
    if (isControlKey(e)) return true;
    if (!/[A-Za-z]/.test(e.key)) { e.preventDefault(); return false; }
    return true;
  }

  function allowLettersSpacesAccents(e) {
    if (isControlKey(e)) return true;
    if (!/[A-Za-zÀ-ÿ\s]/.test(e.key)) { e.preventDefault(); return false; }
    return true;
  }

  function allowLiquidacion(e, el) {
    if (isControlKey(e)) return true;
    if (/[0-9]/.test(e.key)) return true;
    if (e.key === '-') {
      const v = el.value || '';
      if (v.includes('-')) { e.preventDefault(); return false; }
      if (v.replace(/[^0-9]/g, '').length < 4) { e.preventDefault(); return false; }
      return true;
    }
    e.preventDefault();
    return false;
  }

  function pasteLetters(e, el, maxLen) {
    const data = (e.clipboardData || window.clipboardData).getData('text') || '';
    const cleaned = (data.match(/[A-Za-z]+/g) || []).join('').slice(0, maxLen || 10);
    el.value = cleaned;
    e.preventDefault();
    el.dispatchEvent(new Event('input'));
    return false;
  }

  function pasteMetodo(e, el) {
    const data = (e.clipboardData || window.clipboardData).getData('text') || '';
    const cleaned = (data.match(/[A-Za-zÀ-ÿ\s]+/g) || []).join(' ');
    el.value = cleaned;
    e.preventDefault();
    el.dispatchEvent(new Event('input'));
    return false;
  }

  function pasteLiquidacion(e, el) {
    const data = (e.clipboardData || window.clipboardData).getData('text') || '';
    const digits = (data.match(/[0-9]+/g) || []).join('');
    const p1 = digits.slice(0, 4);
    const p2 = digits.slice(4, 14);
    el.value = p2.length ? `${p1}-${p2}` : p1;
    e.preventDefault();
    el.dispatchEvent(new Event('input'));
    return false;
  }

  return {
    allowLetters,
    allowLettersSpacesAccents,
    allowLiquidacion,
    pasteLetters,
    pasteMetodo,
    pasteLiquidacion,
  };
})();

window.restrictToLetters = function (arg) {
  if (typeof arg === 'string') {
    return /^[A-Za-z]$/.test(arg);
  }
  var e = arg;
  var isControl = e.ctrlKey || e.metaKey || e.altKey || e.key.length !== 1;
  if (isControl) return true;
  var ok = /^[A-Za-z]$/.test(e.key);
  if (!ok) { e.preventDefault(); return false; }
  return true;
};

window.attachStrictFilter = function (id, type, maxLen) {
  var el = document.getElementById(id);
  if (!el) return;
  function handleKeyDown(e) {
    if (type === 'letters') return inputFilters.allowLetters(e);
    if (type === 'letters_spaces') return inputFilters.allowLettersSpacesAccents(e);
    if (type === 'liquidacion') return inputFilters.allowLiquidacion(e, el);
    return true;
  }
  function handlePaste(e) {
    if (type === 'letters') return inputFilters.pasteLetters(e, el, maxLen || 10);
    if (type === 'letters_spaces') return inputFilters.pasteMetodo(e, el);
    if (type === 'liquidacion') return inputFilters.pasteLiquidacion(e, el);
    return true;
  }
  el.addEventListener('keydown', handleKeyDown, { capture: true });
  el.addEventListener('paste', handlePaste, { capture: true });
};
