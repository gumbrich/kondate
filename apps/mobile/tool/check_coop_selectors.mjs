// Runs the production JavaScript helpers against small DOM fixtures.
// Node 18+; no packages, network, account, or browser session required.
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

const source = readFileSync(new URL('../lib/coop_basket_scripts.dart', import.meta.url), 'utf8');
const helpers = source.match(/static const String _helpers = r'''([\s\S]*?)''';/)?.[1];
assert.ok(helpers, 'Production script helpers must be found');

function inspect({quantity = 0, label = 'In den Warenkorb', attribute = null,
                  step = '1', display = 'flex', duplicate = false, sku = '123', host = 'www.coop.ch'} = {}) {
  const element = (attrs = {}, textContent = '') => ({
    attrs, textContent, children: [], disabled: false,
    getAttribute(name) { return this.attrs[name] ?? null; },
    getClientRects() { return this.style?.display === 'contents' ? [] : [{}]; },
  });
  const button = element({'data-product-quantity': attribute}, label);
  const input = element({step});
  input.value = String(quantity);
  const root = element({'data-productid': sku});
  root.style = {display, visibility: 'visible', opacity: '1'};
  root.children = [button];
  root.querySelectorAll = selector => ({
    'input[data-product-quantity]': quantity > 0 ? [input] : [],
    '[data-testauto="productbasket"]': quantity === 0 ? [button] : [],
    '[data-testauto^="productbasketplus"]': quantity > 0 ? [button] : [],
  })[selector] ?? [];
  const document = {readyState: 'complete', querySelectorAll: selector =>
    selector === '[data-product-basic-info]' ? (duplicate ? [root, root] : [root]) : []};
  const window = {getComputedStyle: node => node.style ?? {display: 'block', visibility: 'visible', opacity: '1'}};
  return runInNewContext(`${helpers}\ninspect('123').state`, {
    document, window, getComputedStyle: window.getComputedStyle,
    location: {protocol: 'https:', hostname: host, pathname: '/p/123', port: ''},
  });
}

assert.equal(inspect().canAdd, true);
assert.equal(inspect({display: 'contents'}).canAdd, true);
assert.equal(inspect({label: 'In den Warenkorb(2)'}).canAdd, false);
assert.equal(inspect({attribute: '1', label: 'In den Warenkorb(2)'}).canAdd, false);
assert.equal(inspect({quantity: 1, label: '+(2)', step: '1'}).canAdd, false);
assert.equal(inspect({quantity: 1, attribute: '2', step: '1'}).canAdd, false);
assert.equal(inspect({quantity: 1, label: '+', step: '2'}).canAdd, false);
assert.equal(inspect({quantity: 1, label: '+', step: '1'}).canAdd, true);
assert.equal(inspect({attribute: 'invalid'}).canAdd, false);
assert.equal(inspect({duplicate: true}).ready, false);
assert.equal(inspect({sku: '456'}).ready, false);
assert.equal(inspect({host: 'coop.ch.example'}).ready, false);
console.log('12 Coop selector checks passed.');
