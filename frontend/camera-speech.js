(function (root) {
  'use strict';

  const names = {
    person: '行人', bicycle: '自行车', car: '汽车', motorcycle: '摩托车', airplane: '飞机',
    bus: '公交车', train: '火车', truck: '卡车', boat: '船', 'traffic light': '红绿灯',
    'fire hydrant': '消防栓', 'stop sign': '停车标志', 'parking meter': '停车计时器', bench: '长椅',
    bird: '鸟', cat: '猫', dog: '狗', horse: '马', sheep: '羊', cow: '牛', elephant: '大象',
    bear: '熊', zebra: '斑马', giraffe: '长颈鹿', backpack: '背包', umbrella: '雨伞',
    handbag: '手提包', tie: '领带', suitcase: '行李箱', frisbee: '飞盘', skis: '滑雪板',
    snowboard: '单板滑雪板', 'sports ball': '球', kite: '风筝', 'baseball bat': '棒球棒',
    'baseball glove': '棒球手套', skateboard: '滑板', surfboard: '冲浪板', 'tennis racket': '网球拍',
    bottle: '瓶子', 'wine glass': '高脚杯', cup: '水杯', fork: '叉子', knife: '刀', spoon: '勺子',
    bowl: '碗', banana: '香蕉', apple: '苹果', sandwich: '三明治', orange: '橙子', broccoli: '西兰花',
    carrot: '胡萝卜', 'hot dog': '热狗', pizza: '披萨', donut: '甜甜圈', cake: '蛋糕',
    chair: '椅子', couch: '沙发', 'potted plant': '盆栽', bed: '床', 'dining table': '餐桌',
    toilet: '马桶', tv: '电视', laptop: '笔记本电脑', mouse: '鼠标', remote: '遥控器',
    keyboard: '键盘', 'cell phone': '手机', microwave: '微波炉', oven: '烤箱', toaster: '烤面包机',
    sink: '水槽', refrigerator: '冰箱', book: '书', clock: '时钟', vase: '花瓶', scissors: '剪刀',
    'teddy bear': '玩具熊', 'hair drier': '吹风机', toothbrush: '牙刷'
  };
  const directions = {front: '前方', left: '左侧', right: '右侧'};

  function objectName(label) {
    const value = String(label || '').trim().slice(0, 60);
    return names[value.toLowerCase()] || value;
  }

  class Announcer {
    constructor(options = {}) {
      this.synth = options.synth === undefined ? root.speechSynthesis : options.synth;
      this.Utterance = options.Utterance || root.SpeechSynthesisUtterance;
      this.now = options.now || Date.now;
      this.schedule = options.schedule || root.setTimeout.bind(root);
      this.unschedule = options.unschedule || root.clearTimeout.bind(root);
      this.status = options.onStatus || (() => {});
      this.sourceId = options.sourceId || 'local_camera';
      this.supported = Boolean(this.synth && this.Utterance);
      this.enabled = true;
      this.allowed = true;
      this.active = false;
      this.suspended = false;
      this.threshold = 0.35;
      this.gap = 2000;
      this.repeat = Infinity;
      this.latest = [];
      this.lastSpoken = new Map();
      this.lastEnded = -Infinity;
      this.busy = false;
      this.failed = false;
      this.generation = 0;
      this.timer = null;
      this.utterance = null;
    }

    configure(config) {
      const allowed = config.speech_enabled !== false;
      if (this.allowed && !allowed) this.reset();
      this.allowed = allowed;
      if (Number.isFinite(config.confidence)) this.threshold = config.confidence;
      if (Number.isFinite(config.alert_cooldown_ms)) this.gap = Math.max(2000, config.alert_cooldown_ms);
      if (!allowed) this.status('系统语音播报已关闭');
      if (this.onConfigure) this.onConfigure(config);
    }

    setEnabled(enabled) {
      this.enabled = Boolean(enabled);
      this.reset();
      if (!this.enabled) this.status('识别播报已关闭');
      else if (!this.allowed) this.status('系统语音播报已关闭');
      else if (this.active) this.say('物品识别语音播报已开启');
      else this.status('识别播报已开启，启动摄像头后自动播报');
    }

    start() {
      this.reset();
      this.active = true;
      if (this.enabled && this.allowed) this.say('物品识别语音播报已开启');
    }

    stop() {
      this.active = false;
      this.reset();
      this.status(this.enabled ? '摄像头未启动，识别播报已暂停' : '识别播报已关闭');
    }

    suspend() {
      this.reset();
      this.suspended = true;
    }

    resume() {
      this.suspended = false;
    }

    reset() {
      this.generation += 1;
      if (this.timer !== null) this.unschedule(this.timer);
      this.timer = null;
      this.latest = [];
      this.lastSpoken.clear();
      this.lastEnded = -Infinity;
      this.busy = false;
      this.failed = false;
      this.utterance = null;
      if (this.supported && !this.suspended) this.synth.cancel();
    }

    test() {
      this.reset();
      if (!this.allowed) return this.status('系统语音播报已关闭');
      this.say('语音播报测试，识别到物品后将自动播报名称。');
    }

    setSource(sourceId) {
      if (sourceId === this.sourceId) return;
      this.reset();
      this.sourceId = sourceId;
    }

    announce(result) {
      if (!this.active || !this.enabled || !this.allowed || this.failed || this.suspended) return;
      if (result.device_id !== this.sourceId) return;
      if (result.model_status !== 'ready' || result.simulation) {
        this.latest = [];
        return;
      }
      const unique = new Map();
      for (const item of result.objects || []) {
        if (!Number.isFinite(item.confidence) || item.confidence < this.threshold) continue;
        const name = objectName(item.class);
        if (!name) continue;
        const direction = directions[item.direction] ? item.direction : 'front';
        const key = direction + ':' + name;
        unique.set(key, {key, name, direction});
      }
      this.latest = Array.from(unique.values());
      this.latestAt = this.now();
      this.drain();
    }

    drain() {
      if (!this.active || !this.enabled || !this.allowed || this.failed || this.busy || this.suspended) return;
      const now = this.now();
      if (now - this.latestAt > 4000) return;
      const items = this.latest.filter(item => !this.lastSpoken.has(item.key) || now - this.lastSpoken.get(item.key) >= this.repeat).slice(0, 6);
      if (!items.length) return;
      const wait = this.gap - (now - this.lastEnded);
      if (wait > 0) {
        if (this.timer === null) this.timer = this.schedule(() => { this.timer = null; this.drain(); }, wait);
        return;
      }
      const text = Object.entries(directions).map(([direction, label]) => {
        const group = items.filter(item => item.direction === direction);
        return group.length ? label + '有' + group.map(item => item.name).join('、') : '';
      }).filter(Boolean).join('，') + '。';
      this.say(text, items);
    }

    say(text, items = []) {
      if (this.suspended) return;
      if (!this.supported) return this.status('当前浏览器不支持语音播报，请使用 Chrome 或 Edge');
      const generation = this.generation;
      const utterance = new this.Utterance(text);
      utterance.lang = 'zh-CN';
      utterance.rate = 0.88;
      utterance.volume = 1;
      const voices = this.synth.getVoices();
      const chinese = voices.filter(voice => /^zh[-_]/i.test(voice.lang));
      const voice = chinese.find(item => /^zh[-_]CN$/i.test(item.lang) && item.localService) ||
        chinese.find(item => /^zh[-_]CN$/i.test(item.lang)) || chinese[0];
      if (voice) utterance.voice = voice;
      this.busy = true;
      this.utterance = utterance;
      utterance.onstart = () => {
        if (generation !== this.generation) return;
        const started = this.now();
        for (const item of items) this.lastSpoken.set(item.key, started);
        this.status('正在播报：' + text);
      };
      utterance.onend = () => {
        if (generation !== this.generation) return;
        this.busy = false;
        this.utterance = null;
        this.lastEnded = this.now();
        this.status('上次播报：' + text);
        this.drain();
      };
      utterance.onerror = event => {
        if (generation !== this.generation) return;
        this.busy = false;
        this.utterance = null;
        this.failed = true;
        this.status(event.error === 'not-allowed' ? '浏览器尚未允许播报，请点击“测试播报”启用声音' : '语音播报失败，请检查系统声音并点击“测试播报”重试');
      };
      try {
        this.synth.resume();
        this.synth.speak(utterance);
      } catch (error) {
        utterance.onerror({error: error.name});
      }
    }
  }

  const api = {create: options => new Announcer(options), objectName};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.QimingCameraSpeech = api;
})(typeof window === 'undefined' ? globalThis : window);
