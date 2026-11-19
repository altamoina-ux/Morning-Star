const test = require('node:test');
const assert = require('node:assert/strict');
const {Reader, splitText} = require('../frontend/ocr-reader.js');

function setup() {
  const spoken = [];
  const statuses = [];
  const objectSpeech = {suspended: false, suspend() {this.suspended = true;}, resume() {this.suspended = false;}};
  const synth = {cancel() {}, resume() {}, getVoices() {return [];}, speak(u) {spoken.push(u); u.onstart();}};
  const reader = new Reader({objectSpeech, synth, Utterance: class {constructor(text) {this.text = text;}},
    onStatus: status => statuses.push(status), onText() {}, onBusy() {}});
  return {reader, spoken, statuses, objectSpeech};
}

test('long text is split without losing characters', () => {
  const text = '启明帽'.repeat(150);
  const chunks = splitText(text);
  assert.equal(chunks.join(''), text);
  assert.ok(chunks.every(chunk => chunk.length <= 100));
});

test('recognition speaks sequentially and suspends object announcements', async () => {
  const h = setup();
  await h.reader.recognize(async () => 'image', async () => ({text: '第一句。第二句。', has_text: true}));
  assert.equal(h.objectSpeech.suspended, true);
  assert.equal(h.spoken[0].text, '第一句。');
  h.spoken[0].onend();
  assert.equal(h.spoken[1].text, '第二句。');
  h.spoken[1].onend();
  assert.equal(h.reader.busy, false);
  assert.equal(h.objectSpeech.suspended, false);
});

test('cancelling a pending request ignores late results and aborts fetch', async () => {
  const h = setup();
  let resolve;
  let signal;
  const pending = h.reader.recognize(async () => 'image', async (_, requestSignal) => {
    signal = requestSignal;
    return new Promise(done => {resolve = done;});
  });
  await new Promise(done => setImmediate(done));
  h.reader.cancel();
  assert.equal(signal.aborted, true);
  resolve({text: '过期文字', has_text: true});
  await pending;
  assert.equal(h.spoken.length, 0);
  assert.equal(h.reader.busy, false);
});

test('cancelled speech callbacks cannot start the next paragraph', () => {
  const h = setup();
  h.reader.text = '一。二。';
  h.reader.read();
  h.reader.cancel();
  h.spoken[0].onend();
  assert.equal(h.spoken.length, 1);
  assert.equal(h.objectSpeech.suspended, false);
});

test('no text, truncated output and request failures never auto-read', async () => {
  for (const result of [{text: '未识别到清晰文字', has_text: false}, {text: '部分文字', has_text: true, truncated: true}]) {
    const h = setup();
    await h.reader.recognize(async () => 'image', async () => result);
    assert.equal(h.spoken.length, 0);
    assert.equal(h.reader.busy, false);
  }
  const h = setup();
  await h.reader.recognize(async () => {throw new Error('请先启动摄像头');}, async () => {});
  assert.match(h.statuses.at(-1), /请先启动摄像头/);
  assert.equal(h.objectSpeech.suspended, false);
});

test('speech disabled during recognition still displays text without reading', async () => {
  const h = setup();
  h.reader.configure(false);
  await h.reader.recognize(async () => 'image', async () => ({text: '识别文字', has_text: true}));
  assert.equal(h.reader.text, '识别文字');
  assert.equal(h.spoken.length, 0);
  assert.equal(h.reader.busy, false);
});

test('monitor controls capture the displayed camera, show text, replay and stop reading', async () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const vm = require('node:vm');
  const nodes = Object.fromEntries(['ocrCapture', 'ocrReplay', 'ocrStop', 'ocrStatus', 'ocrText', 'ocrResults']
    .map(id => ['#' + id, {disabled: false, hidden: true, textContent: ''}]));
  const listeners = new Map();
  const spoken = [];
  const requests = [];
  const video = {readyState: 2, videoWidth: 1280, videoHeight: 720};
  const objectSpeech = {allowed: true, suspend() {this.suspended = true;}, resume() {this.suspended = false;}};
  const canvas = {
    getContext() {return {drawImage(source) {assert.equal(source, video);}};},
    toBlob(done) {done({size: 100});},
  };
  const context = {
    module: {exports: {}}, AbortController,
    window: {
      speechSynthesis: {cancel() {}, resume() {}, getVoices() {return [];}, speak(utterance) {spoken.push(utterance); utterance.onstart();}},
      SpeechSynthesisUtterance: class {constructor(text) {this.text = text;}},
      addEventListener(event, callback) {listeners.set(event, callback);},
    },
    document: {
      getElementById(id) {assert.equal(id, 'monitor'); return {querySelector(selector) {assert.ok(nodes[selector]); return nodes[selector];}};},
      createElement(tag) {assert.equal(tag, 'canvas'); return canvas;},
    },
    sessionStorage: {getItem() {return 'test-session';}},
    localStorage: {getItem() {return null;}},
    async fetch(url, options) {
      requests.push({url, options});
      return {ok: true, async json() {return {text: '识字成功。', has_text: true};}};
    },
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../frontend/ocr-reader.js'), 'utf8'), context);
  const reader = context.module.exports.mount({video, objectSpeech, isCameraActive: () => true});
  assert.equal(nodes['#ocrReplay'].disabled, true);
  await nodes['#ocrCapture'].onclick();
  assert.equal(requests[0].url, '/api/ocr/read');
  assert.equal(requests[0].options.headers.Authorization, 'Bearer test-session');
  assert.equal(nodes['#ocrText'].textContent, '识字成功。');
  assert.equal(nodes['#ocrResults'].hidden, false);
  assert.equal(nodes['#ocrCapture'].disabled, true);
  assert.equal(spoken[0].text, '识字成功。');
  spoken[0].onend();
  assert.equal(nodes['#ocrCapture'].disabled, false);
  assert.equal(nodes['#ocrReplay'].disabled, false);
  nodes['#ocrReplay'].onclick();
  assert.equal(spoken.length, 2);
  listeners.get('qiming-camera-stopped')();
  assert.equal(reader.busy, false);
  assert.equal(nodes['#ocrStop'].disabled, true);
  assert.equal(objectSpeech.suspended, false);
  listeners.get('qiming-camera-source-changed')();
  assert.equal(reader.text, '');
  assert.equal(nodes['#ocrText'].textContent, '');
});
