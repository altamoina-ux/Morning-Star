(function (root) {
  'use strict';

  function splitText(text, limit = 100) {
    const chunks = [];
    let chunk = '';
    for (const character of text) {
      chunk += character;
      if (chunk.length >= limit || /[。！？!?\n]/.test(character)) {
        if (chunk.trim()) chunks.push(chunk.trim());
        chunk = '';
      }
    }
    if (chunk.trim()) chunks.push(chunk.trim());
    return chunks;
  }

  class Reader {
    constructor(options) {
      Object.assign(this, options);
      this.synth = options.synth === undefined ? root.speechSynthesis : options.synth;
      this.Utterance = options.Utterance || root.SpeechSynthesisUtterance;
      this.supported = Boolean(this.synth && this.Utterance);
      this.generation = 0;
      this.busy = false;
      this.controller = null;
      this.utterance = null;
      this.text = '';
      this.allowed = true;
    }

    setBusy(value) {
      this.busy = value;
      if (value) this.objectSpeech.suspend();
      else this.objectSpeech.resume();
      this.onBusy(value);
    }

    cancel(message = '已停止识字或朗读') {
      this.generation += 1;
      if (this.controller) this.controller.abort();
      this.controller = null;
      if (this.busy && this.supported) this.synth.cancel();
      this.utterance = null;
      this.setBusy(false);
      this.onStatus(message);
    }

    async recognize(capture, request) {
      if (this.busy) return;
      this.cancel('正在拍摄并识字，首次加载模型可能较慢…');
      this.text = '';
      this.onText('');
      this.setBusy(true);
      const generation = this.generation;
      this.controller = new AbortController();
      const signal = this.controller.signal;
      try {
        const blob = await capture();
        if (generation !== this.generation) return;
        const result = await request(blob, signal);
        if (generation !== this.generation) return;
        this.text = result.has_text ? result.text : '';
        this.onText(result.text);
        this.controller = null;
        if (!result.has_text) {
          this.setBusy(false);
          this.onStatus('未识别到清晰文字，请靠近文字并保持画面稳定');
        } else if (result.truncated) {
          this.setBusy(false);
          this.onStatus('文字较多，结果可能不完整。请分区域拍摄；可点击“重新朗读”播放当前结果');
        } else {
          this.read();
        }
      } catch (error) {
        if (generation !== this.generation) return;
        this.controller = null;
        this.setBusy(false);
        this.onStatus(error.name === 'AbortError' ? '识字已取消' : '识字失败：' + error.message);
      }
    }

    read() {
      if (!this.text) return;
      this.cancel('准备朗读');
      if (!this.allowed) return this.onStatus('系统语音播报已关闭，识别文字已保留');
      if (!this.supported) return this.onStatus('文字已识别，当前浏览器不支持朗读，请使用 Chrome 或 Edge');
      this.setBusy(true);
      const generation = this.generation;
      const chunks = splitText(this.text);
      let index = 0;
      const next = () => {
        if (generation !== this.generation) return;
        if (index === chunks.length) {
          this.utterance = null;
          this.setBusy(false);
          this.onStatus('朗读完成');
          return;
        }
        const utterance = new this.Utterance(chunks[index++]);
        this.utterance = utterance;
        utterance.lang = 'zh-CN';
        utterance.rate = 1;
        const voices = this.synth.getVoices().filter(voice => /^zh[-_]/i.test(voice.lang));
        const voice = voices.find(item => /^zh[-_]CN$/i.test(item.lang) && item.localService) || voices[0];
        if (voice) utterance.voice = voice;
        utterance.onstart = () => {
          if (generation === this.generation) this.onStatus(`正在朗读（${index}/${chunks.length}）`);
        };
        utterance.onend = next;
        utterance.onerror = event => {
          if (generation !== this.generation) return;
          this.cancel(event.error === 'not-allowed'
            ? '浏览器未允许自动朗读，请点击“重新朗读”'
            : '朗读失败，请检查系统声音后点击“重新朗读”');
        };
        try {
          this.synth.resume();
          this.synth.speak(utterance);
        } catch (error) {
          utterance.onerror({error: error.name});
        }
      };
      next();
    }

    configure(allowed) {
      this.allowed = allowed;
      if (!allowed && this.utterance) this.cancel('系统语音播报已关闭，识别文字已保留');
      this.onBusy(this.busy);
    }
  }

  function mount({video, objectSpeech, isCameraActive, captureFrame}) {
    const panel = document.getElementById('monitor');
    const captureButton = panel.querySelector('#ocrCapture');
    const replayButton = panel.querySelector('#ocrReplay');
    const stopButton = panel.querySelector('#ocrStop');
    const reader = new Reader({
      objectSpeech,
      onStatus: message => { panel.querySelector('#ocrStatus').textContent = message; },
      onText: text => {
        panel.querySelector('#ocrText').textContent = text;
        panel.querySelector('#ocrResults').hidden = !text;
      },
      onBusy: busy => {
        captureButton.disabled = busy;
        stopButton.disabled = !busy;
        replayButton.disabled = busy || !reader.text || !reader.supported || !reader.allowed;
      },
    });
    const capture = async () => {
      if (captureFrame) {
        if (!isCameraActive()) throw new Error('请先启动所选来源，并等待画面出现');
        const blob = await captureFrame();
        if (!blob) throw new Error('当前来源没有可用画面');
        if (blob.size > 6000000) throw new Error('图片过大，请降低摄像头分辨率');
        return blob;
      }
      if (!isCameraActive() || video.readyState < 2 || !video.videoWidth) {
        throw new Error('请先启动摄像头，并等待画面出现');
      }
      const canvas = document.createElement('canvas');
      canvas.width = Math.min(video.videoWidth, 1600);
      canvas.height = Math.round(video.videoHeight * canvas.width / video.videoWidth);
      canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.92));
      if (!blob) throw new Error('拍摄失败，请重新启动摄像头');
      if (blob.size > 6000000) throw new Error('图片过大，请降低摄像头分辨率');
      return blob;
    };
    const request = async (blob, signal) => {
      const token = sessionStorage.getItem('qh_token') || localStorage.getItem('qh_token');
      const response = await fetch('/api/ocr/read', {
        method: 'POST', signal, body: blob,
        headers: {'Content-Type': 'image/jpeg', Authorization: 'Bearer ' + (token || '')},
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.detail || '服务请求失败');
      return result;
    };
    objectSpeech.onConfigure = config => reader.configure(config.speech_enabled !== false);
    reader.configure(objectSpeech.allowed);
    captureButton.onclick = () => reader.recognize(capture, request);
    replayButton.onclick = () => reader.read();
    stopButton.onclick = () => reader.cancel();
    window.addEventListener('qiming-camera-stopped', () => reader.cancel('摄像头已停止，识字和朗读已取消'));
    window.addEventListener('qiming-camera-source-changed', () => {
      reader.cancel('画面来源已切换，请重新拍摄识字');
      reader.text = '';
      reader.onText('');
    });
    window.addEventListener('pagehide', () => reader.cancel());
    return reader;
  }

  const api = {Reader, splitText, mount};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.QimingOCR = api;
})(typeof window === 'undefined' ? globalThis : window);
