import 'dart:convert';

/// Selectors observed on coop.ch product detail pages on 2026-11-15.
/// Scope every control to the exact SKU; never click recommendation tiles.
class CoopBasketScripts {
  static const String _helpers = r'''
  function visible(el) {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
    // Coop's narrow layout uses display:contents for the SKU container.
    // It has no box of its own even though its product controls are visible.
    return style.display === 'contents'
      ? Array.from(el.children).some(visible)
      : el.getClientRects().length > 0;
  }
  function enabled(el) {
    return visible(el) && !el.disabled && el.getAttribute('aria-disabled') !== 'true';
  }
  function inspect(id) {
    const validHost = location.protocol === 'https:' &&
      ['coop.ch', 'www.coop.ch'].includes(location.hostname) &&
      (!location.port || location.port === '443');
    const match = location.pathname.match(/\/p\/(\d+)\/?$/);
    const loginRequired = validHost && (
      Array.from(document.querySelectorAll('input[type="password"]')).some(visible) ||
      Array.from(document.querySelectorAll('[data-testauto="basket"]')).some(el =>
        visible(el) && /\/login(?:\/|\?|$)/.test(el.getAttribute('href') || ''))
    );
    const diagnostic = {validHost, pathProductId: match ? match[1] : null,
      documentReady: document.readyState,
      detailIds: Array.from(document.querySelectorAll('[data-product-basic-info]'))
        .map(el => el.getAttribute('data-productid')),
      detailVisibility: Array.from(document.querySelectorAll('[data-product-basic-info]'))
        .map(el => ({display: getComputedStyle(el).display,
          visibility: getComputedStyle(el).visibility, opacity: getComputedStyle(el).opacity,
          rects: el.getClientRects().length}))};
    const empty = {productId: '', quantity: null, ready: false, loginRequired, canAdd: false, diagnostic};
    if (!validHost || !match || match[1] !== id || document.readyState !== 'complete') return {state: empty};
    const roots = Array.from(document.querySelectorAll('[data-product-basic-info]'))
      .filter(el => el.getAttribute('data-productid') === id && visible(el));
    if (roots.length !== 1) return {state: empty};
    const root = roots[0];
    const inputs = Array.from(root.querySelectorAll('input[data-product-quantity]')).filter(visible);
    const adds = Array.from(root.querySelectorAll('[data-testauto="productbasket"]')).filter(visible);
    const pluses = Array.from(root.querySelectorAll('[data-testauto^="productbasketplus"]')).filter(visible);
    Object.assign(diagnostic, {inputs: inputs.length, adds: adds.length, pluses: pluses.length});
    let quantity = null;
    // Do not mistake the product's weight or a basket total for its pack count.
    if (inputs.length === 1 && /^\d+$/.test(inputs[0].value)) quantity = Number(inputs[0].value);
    else if (inputs.length === 0 && adds.length === 1 && pluses.length === 0) quantity = 0;
    const buttons = quantity === 0 ? adds : pluses;
    const button = buttons.length === 1 ? buttons[0] : null;
    return {state: {productId: id, quantity, ready: quantity !== null,
      loginRequired, canAdd: enabled(button), diagnostic}, button};
  }
''';

  static String read(String productId) =>
      '''
(() => {
$_helpers
  return JSON.stringify(inspect(${jsonEncode(productId)}).state);
})();
''';

  static String addOne(String productId, int expectedQuantity) =>
      '''
(() => {
$_helpers
  const {state, button} = inspect(${jsonEncode(productId)});
  if (!state.ready || state.loginRequired || !state.canAdd ||
      state.quantity !== $expectedQuantity) return JSON.stringify({clicked: false});
  button.click();
  return JSON.stringify({clicked: true});
})();
''';
}
