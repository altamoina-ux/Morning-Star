const test = require('node:test');
const assert = require('node:assert/strict');
const {Monitor} = require('../frontend/camera-monitor.js');

function deferred() {
  let resolve;
  const promise = new Promise(done => {resolve = done;});
  return {promise, resolve};
}

function response({status = 200, sources, location, seq = 1, blob = {size: 100}} = {}) {
  return {ok: status === 200, status, headers: {get() {return String(seq);}},
    async json() {return location || sources || [];}, async blob() {return blob;}};
}

function harness({saved = null, fetch, getUserMedia, devices = []} = {}) {
  const nodes = new Map(), timers = new Map(), timeouts = new Map(), requests = [], mediaRequests = [], revoked = [];
  const stored = new Map(saved === null ? [] : [['qh_camera_source', saved]]);
  const tracks = [{readyState: 'live', stopped: false, stop() {this.stopped = true;}}];
  const stream = {getTracks: () => tracks, getVideoTracks: () => tracks};
  let timerId = 0, urlId = 0;
  class Node {
    constructor(tag = 'div') {
      this.tag = tag; this.children = []; this._value = ''; this.hidden = false;
      this.style = {}; this.textContent = ''; this.width = 640; this.height = 360;
      this.readyState = 2; this.videoWidth = 1280; this.videoHeight = 720;
      this.naturalWidth = 320; this.naturalHeight = 240;
      const classes = new Set();
      this.classList = {toggle(name, active) {active ? classes.add(name) : classes.delete(name);}, contains: name => classes.has(name)};
    }
    set value(value) {this._value = this.tag === 'select' && !this.children.some(item => item.value === value) ? '' : value;}
    get value() {return this._value;}
    replaceChildren(...children) {
      this.children = children;
      if (this.tag === 'select' && !children.some(item => item.value === this._value)) this._value = children[0]?.value || '';
    }
    removeAttribute(name) {delete this[name];}
    getBoundingClientRect() {return {width: 640, height: 360};}
    getContext() {return {setTransform() {}, clearRect() {}, strokeRect() {}, fillRect() {}, fillText() {}, drawImage() {},
      measureText: () => ({width: 100}), getImageData: () => ({data: [255, 255, 255, 255]})};}
    toBlob(done) {done({size: 100});}
    play() {return Promise.resolve();}
  }
  const document = {getElementById(id) {
    if (!nodes.has(id)) nodes.set(id, new Node(id === 'cameraSelect' ? 'select' : 'div'));
    return nodes.get(id);
  }, createElement: tag => new Node(tag)};
  const speech = {announced: [], sourceId: null, start() {}, stop() {}, reset() {},
    setSource(id) {this.sourceId = id;}, announce(result) {this.announced.push(result);}};
  const monitor = new Monitor({document, objectSpeech: speech,
    storage: {getItem: key => stored.get(key) || null, setItem: (key, value) => stored.set(key, value)},
    getToken: () => 'test-token',
    mediaDevices: {enumerateDevices: async () => devices,
      getUserMedia: async constraints => {mediaRequests.push(constraints); return getUserMedia ? getUserMedia(constraints) : stream;}},
    fetch: async (url, options) => {requests.push({url, options}); return fetch ? fetch(url, options) : response();},
    url: {createObjectURL: () => 'blob:frame-' + (++urlId), revokeObjectURL: value => revoked.push(value)},
    setInterval(fn) {timers.set(++timerId, fn); return timerId;}, clearInterval(id) {timers.delete(id);},
    setTimeout(fn) {timeouts.set(++timerId, fn); return timerId;}, clearTimeout(id) {timeouts.delete(id);},
  });
  return {monitor, nodes, requests, mediaRequests, tracks, stream, speech, stored, timers, timeouts, revoked};
}

test('first source list prefers a live hat but an explicit local choice stays local', async () => {
  const sources = [{source_id: 'esp32s3_cam_001', label: '帽端摄像头', kind: 'device', online: true}];
  const first = harness({fetch: async () => response({sources})});
  await first.monitor.refreshSources();
  assert.equal(first.monitor.sourceId, 'esp32s3_cam_001');
  assert.equal(first.nodes.get('cameraSelect').value, 'remote:esp32s3_cam_001');
  assert.equal(first.nodes.get('cameraSelect').hidden, false);
  const local = harness({saved: 'local_camera', fetch: async () => response({sources})});
  await local.monitor.refreshSources();
  assert.equal(local.monitor.sourceId, 'local_camera');
  assert.equal(local.mediaRequests.length, 0);
});

test('starting a hat preview never opens or uploads the computer camera', async () => {
  const h = harness({saved: 'esp32s3_cam_001'});
  await h.monitor.start();
  h.nodes.get('cameraRemote').onload();
  await Promise.resolve();
  await h.monitor.sendLocalFrame();
  assert.equal(h.monitor.active(), true);
  assert.equal(h.speech.sourceId, 'esp32s3_cam_001');
  assert.equal(h.mediaRequests.length, 0);
  const frameRequest = h.requests.find(request => request.url === '/api/tablet/cameras/esp32s3_cam_001/frame');
  assert.ok(frameRequest);
  assert.equal(frameRequest.options.headers.Authorization, 'Bearer test-token');
  const armRequest = h.requests.find(request => request.url === '/api/tablet/motor-monitor');
  assert.equal(JSON.parse(armRequest.options.body).active, true);
  assert.equal(h.monitor.motorMonitorActive, true);
  assert.equal(h.stored.get('qh_camera_source'), 'esp32s3_cam_001');
  h.monitor.stop();
  assert.equal(JSON.parse(h.requests.at(-1).options.body).active, false);
});

test('hat monitor displays authenticated Wi-Fi location and labels the estimate', async () => {
  const h = harness({saved: 'esp32s3_cam_001', fetch: async url => url.includes('/location?')
    ? response({location: {available: true, latitude: 31.2, longitude: 121.5,
      accuracy_m: 85, access_points_used: 3, provider: 'BeaconDB', updated_at: '2026-01-01T00:00:00Z'}})
    : response()});
  await h.monitor.start();
  await Promise.resolve();
  assert.match(h.nodes.get('wifiLocationStatus').textContent, /31\.20000, 121\.50000.*±85 米/);
  assert.match(h.nodes.get('wifiLocationDetail').textContent, /3 个 Wi-Fi 热点估算.*BeaconDB/);
  const request = h.requests.find(item => item.url.includes('/location?'));
  assert.equal(request.options.headers.Authorization, 'Bearer test-token');
  h.monitor.stop();
});

test('source refresh, missing source and stale image retain the selected hat without fallback', async () => {
  let stale = false;
  const h = harness({saved: 'esp32s3_cam_001', fetch: async url =>
    url.endsWith('/frame') ? response({status: stale ? 410 : 200}) : response({sources: []})});
  await h.monitor.start();
  h.nodes.get('cameraRemote').onload();
  h.monitor.handleDetection({device_id: 'esp32s3_cam_001', image_seq: 1, model_status: 'ready', objects: [{class: 'person', confidence: .9, direction: 'front'}]});
  assert.equal(h.nodes.get('objects').children.length, 1);
  stale = true;
  await h.monitor.pollRemote();
  await h.monitor.refreshSources();
  assert.equal(h.monitor.sourceId, 'esp32s3_cam_001');
  assert.equal(h.nodes.get('cameraSelect').value, 'remote:esp32s3_cam_001');
  assert.equal(h.monitor.hasFrame, false);
  assert.equal(h.nodes.get('objects').children.length, 0);
  assert.equal(h.mediaRequests.length, 0);
  assert.match(h.nodes.get('cameraStatus').textContent, /不会切换/);
  assert.equal(h.revoked.length, 1);
});

test('local device selection survives permission label refresh and starting the stream', async () => {
  const h = harness({saved: 'local_camera', devices: [
    {kind: 'videoinput', deviceId: 'integrated', label: 'Integrated Camera'},
    {kind: 'videoinput', deviceId: 'usb', label: 'USB Camera'},
  ]});
  await h.monitor.listLocalCameras();
  h.nodes.get('cameraSelect').value = 'local:usb';
  await h.nodes.get('cameraSelect').onchange();
  await h.monitor.start();
  await h.monitor.listLocalCameras();
  assert.equal(h.nodes.get('cameraSelect').value, 'local:usb');
  assert.equal(h.mediaRequests[0].video.deviceId.exact, 'usb');
  assert.equal(h.monitor.localStream, h.stream);
});

test('the same camera dropdown always offers the ESP32 even without a connection or a source list', async () => {
  const h = harness({saved: 'local_camera', devices: [
    {kind: 'videoinput', deviceId: 'integrated', label: 'Integrated Camera'},
  ], fetch: async () => response({status: 401})});
  await h.monitor.listLocalCameras();
  await h.monitor.refreshSources();
  const select = h.nodes.get('cameraSelect');
  assert.ok(select.children.some(option => option.value === 'local:integrated'));
  assert.ok(select.children.some(option => option.value === 'remote:esp32s3_cam_001' && /ESP32.*等待/.test(option.textContent)));
  select.value = 'remote:esp32s3_cam_001';
  await select.onchange();
  await h.monitor.start();
  assert.equal(h.monitor.sourceId, 'esp32s3_cam_001');
  assert.equal(select.hidden, false);
  assert.equal(select.value, 'remote:esp32s3_cam_001');
  assert.equal(h.mediaRequests.length, 0);
  assert.match(h.nodes.get('cameraStatus').textContent, /登录已失效/);
});

test('one dropdown switches a running local camera to ESP32 and back to the selected computer device', async () => {
  const h = harness({saved: 'local_camera', devices: [
    {kind: 'videoinput', deviceId: 'integrated', label: 'Integrated Camera'},
  ]});
  await h.monitor.listLocalCameras();
  const select = h.nodes.get('cameraSelect');
  select.value = 'local:integrated';
  await select.onchange();
  await h.monitor.start();
  select.value = 'remote:esp32s3_cam_001';
  await select.onchange();
  h.nodes.get('cameraRemote').onload();
  assert.equal(h.tracks[0].stopped, true);
  assert.equal(h.monitor.localStream, null);
  assert.equal(h.monitor.active(), true);
  await h.monitor.listLocalCameras();
  await h.monitor.refreshSources();
  assert.equal(select.value, 'remote:esp32s3_cam_001');
  assert.equal(h.mediaRequests.length, 1);
  select.value = 'local:integrated';
  await select.onchange();
  assert.equal(h.monitor.sourceId, 'local_camera');
  assert.equal(h.mediaRequests.length, 2);
  assert.equal(h.mediaRequests[1].video.deviceId.exact, 'integrated');
  assert.equal(select.value, 'local:integrated');
});

test('switching to the hat releases a local permission request that resolves late', async () => {
  const pending = deferred();
  const h = harness({saved: 'local_camera', getUserMedia: () => pending.promise});
  const starting = h.monitor.start();
  await h.monitor.selectSource('esp32s3_cam_001');
  pending.resolve(h.stream);
  await starting;
  assert.equal(h.monitor.sourceId, 'esp32s3_cam_001');
  assert.equal(h.monitor.localStream, null);
  assert.equal(h.tracks[0].stopped, true);
  assert.equal(h.nodes.get('cameraVideo').srcObject, null);
});

test('late image responses cannot overwrite the newly selected source', async () => {
  const pending = deferred();
  const h = harness({saved: 'first_hat', fetch: async url => url.includes('first_hat') ? pending.promise : response({seq: 22})});
  const first = h.monitor.start();
  await h.monitor.selectSource('second_hat');
  h.nodes.get('cameraRemote').onload();
  const visible = h.nodes.get('cameraRemote').src;
  pending.resolve(response({seq: 1}));
  await first;
  assert.equal(h.monitor.sourceId, 'second_hat');
  assert.equal(h.nodes.get('cameraRemote').src, visible);
  assert.equal(h.monitor.frameSeq, '22');
  assert.equal(h.mediaRequests.length, 0);
});

test('only one remote request is in flight and stop ignores a late response', async () => {
  const pending = deferred();
  const h = harness({saved: 'esp32s3_cam_001', fetch: () => pending.promise});
  const starting = h.monitor.start();
  await h.monitor.pollRemote();
  assert.equal(h.requests.filter(request => request.url.endsWith('/frame')).length, 1);
  h.monitor.stop();
  pending.resolve(response());
  await starting;
  assert.equal(h.monitor.running, false);
  assert.equal(h.monitor.hasFrame, false);
  assert.equal(h.nodes.get('cameraRemote').src, undefined);
  assert.equal(h.timers.size, 0);
});

test('detections and OCR use the selected remote source and clear on source change', async () => {
  const blob = {size: 123};
  const h = harness({saved: 'esp32s3_cam_001', fetch: async () => response({blob})});
  await h.monitor.start();
  h.nodes.get('cameraRemote').onload();
  const result = {image_seq: 1, model_status: 'ready', objects: []};
  h.monitor.handleDetection({...result, device_id: 'local_camera'});
  h.monitor.handleDetection({...result, device_id: 'other_hat'});
  assert.equal(h.speech.announced.length, 0);
  h.monitor.handleDetection({...result, device_id: 'esp32s3_cam_001'});
  assert.equal(h.speech.announced.length, 1);
  assert.equal(await h.monitor.captureFrame(), blob);
  h.monitor.stop();
  await assert.rejects(h.monitor.captureFrame(), /等待画面/);
});

test('a hung remote request times out and retains the source without opening local hardware', async () => {
  const h = harness({saved: 'esp32s3_cam_001', fetch: (url, options) => new Promise((resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), {name: 'AbortError'})));
  })});
  const starting = h.monitor.start();
  [...h.timeouts.values()][0]();
  await starting;
  assert.equal(h.monitor.sourceId, 'esp32s3_cam_001');
  assert.equal(h.monitor.hasFrame, false);
  assert.equal(h.mediaRequests.length, 0);
  assert.match(h.nodes.get('cameraStatus').textContent, /超时.*保留当前来源/);
});

test('dashboard scripts compile and the source controller is wired to all required DOM nodes', () => {
  const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
  const html = fs.readFileSync(path.join(__dirname, '../frontend/index.html'), 'utf8');
  const source = fs.readFileSync(path.join(__dirname, '../frontend/camera-monitor.js'), 'utf8');
  for (const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(match[1]);
  for (const match of source.matchAll(/this\.get\('([^']+)'\)/g)) assert.ok(html.includes('id="' + match[1] + '"'), match[1]);
  assert.match(html, /<script src="\/camera-monitor\.js"><\/script>/);
  assert.match(html, /cameraMonitor\.handleDetection\(x\)/);
  assert.match(html, /captureFrame:\(\)=>cameraMonitor\.captureFrame\(\)/);
  assert.doesNotMatch(html, /async function startCamera\(/);
});
