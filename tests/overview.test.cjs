const test = require('node:test');
const assert = require('node:assert/strict');
const {chartModel, trendSVG} = require('../frontend/overview.js');

test('trend includes zero, separates sources and scales above the largest count', () => {
  const data = chartModel([{date: '2026-11-17', real: 134, simulation: 8}]);
  assert.equal(data.total, 142);
  assert.ok(data.maximum >= 134);
  const svg = trendSVG(data.days);
  assert.match(svg, /polyline/);
  assert.match(svg, /stroke-dasharray/);
  assert.match(svg, /实际采集：134/);
  assert.match(svg, />0<\/text>/);
});

test('empty and invalid dates never create broken SVG or inject markup', () => {
  const svg = trendSVG([{date: '<script>alert(1)</script>', real: -1, simulation: NaN}]);
  assert.match(svg, /暂无预警记录/);
  assert.doesNotMatch(svg, /<script|NaN|Infinity/);
});

function harness(fetchResult) {
  const vm = require('node:vm');
  const fs = require('node:fs');
  const path = require('node:path');
  class Node {
    constructor() {this.children = []; this.className = ''; this.classList = {add() {}, remove() {}};}
    append(...nodes) {this.children.push(...nodes);}
    replaceChildren(...nodes) {this.children = nodes;}
  }
  const nodes = new Map();
  const events = new Map();
  const document = {getElementById(id) {if (!nodes.has(id)) nodes.set(id, new Node()); return nodes.get(id);},
    createElement() {return new Node();}, querySelectorAll() {return [];}};
  const requests = [];
  const window = {document, setInterval() {return 1;}, clearInterval() {}, addEventListener(name, callback) {events.set(name, callback);}};
  const context = {window, module: {exports: {}}, AbortController, Intl, Date};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../frontend/overview.js'), 'utf8'), context);
  const api = context.module.exports;
  const mounted = api.mount({document, timeZone: 'Asia/Shanghai', getToken: () => 'test-session', getCamera: () => ({active: true}),
    fetch: async (url, options) => {requests.push({url, options}); return fetchResult();}});
  return {nodes, events, requests, mounted};
}

test('overview renders actual totals, distinguishes simulated devices and uses safe text nodes', async () => {
  const data = {devices: {real_online: 0, simulation_online: 1, seen: 0},
    today_alerts: {total: 134, real: 130, simulation: 4}, today_voices: {total: 2, real: 0, simulation: 2},
    mode: 'simulation', trend: [{date: '2026-11-17', real: 130, simulation: 4}],
    yolo: {state: 'ready', label: '已加载', detail: 'test'}, llm: {state: 'offline', label: '服务未连接', detail: 'test'},
    recent_alerts: [], recent_voices: [{user_text: '<img src=x onerror=alert(1)>', reply_text: '<script>bad</script>', source: 'simulation', occurred_at: '2026-11-17T00:00:00Z'}],
    generated_at: '2026-11-17T01:00:00Z', timezone: 'Asia/Shanghai'};
  const h = harness(async () => ({ok: true, json: async () => data}));
  await h.mounted.ready;
  assert.equal(h.nodes.get('alertCount').textContent, 134);
  assert.equal(h.nodes.get('device').textContent, '未接入');
  assert.equal(h.nodes.get('model').textContent, '模拟模式');
  assert.equal(h.nodes.get('overviewLlmState').textContent, '服务未连接');
  assert.equal(h.nodes.get('overviewCameraState').textContent, '已开启');
  const record = h.nodes.get('overviewVoices').children[0];
  assert.equal(record.children[0].children[0].textContent, '<img src=x onerror=alert(1)>');
  assert.equal(record.children[1].textContent, '<script>bad</script>');
  assert.match(h.requests[0].url, /tz=Asia%2FShanghai/);
  assert.equal(h.requests[0].options.headers.Authorization, 'Bearer test-session');
  h.events.get('qiming-camera-stopped')();
  assert.equal(h.nodes.get('overviewCameraState').textContent, '未开启');
  h.events.get('pagehide')();
});

test('failed requests show an explicit failure instead of zero or healthy status', async () => {
  const h = harness(async () => ({ok: false, status: 401}));
  await h.mounted.ready;
  assert.match(h.nodes.get('overviewUpdated').textContent, /登录已过期/);
  assert.equal(h.nodes.get('overviewBackendState').textContent, '更新失败');
  assert.equal(h.nodes.get('overviewAlerts').textContent, '记录暂不可用');
  h.events.get('pagehide')();
});
