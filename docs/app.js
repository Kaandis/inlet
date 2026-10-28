(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  // =========================================================
  // Language — English lives in the HTML (what search engines
  // index); Turkish is applied on top.
  // =========================================================
  const TR = {
    'nav.free': 'Ücretsiz',
    'nav.features': 'Özellikler',
    'nav.faq': 'SSS',
    'hero.line1': 'Çentiğin artık',
    'hero.line2': 'işe yarıyor.',
    'hero.lead': 'MacBook çentiğin için ücretsiz ve açık kaynak bir ada: müzik, dosyalar, zamanlayıcılar ve normalde kaçırdığın küçük şeyler.',
    'hero.download': 'Ücretsiz indir',
    'hero.github': 'GitHub’da yıldızla',
    'mb.file': 'Dosya', 'mb.edit': 'Düzen', 'mb.view': 'Görüntü', 'mb.go': 'Git', 'mb.window': 'Pencere',
    'desk.file': 'son_SON_v3 (gerçekten).pdf',
    'desk.hint': 'Beni çentiğe sürükle',
    'lock.focus': 'Derin Odak (sayılır)',
    'lock.unlock': 'Kilidi açmak için tıkla',
    'lock.unlockNote': 'şifre yok, söz',
    'isl.tray': 'Tepsi',
    'isl.dropTray': 'Tepsiye bırak',
    'ev1': 'E-posta olabilecek toplantı',
    'ev2': 'Öğle yemeği (pazarlık yok)',
    'ev3': 'Dokümanı okuyormuş gibi yap',
    'tray.emptyT': 'Dosyaları adanın üstüne sürükle',
    'tray.emptyD': 'Masaüstündeki PDF’i dene.',
    'timer.10s': '10 sn',
    'demo.hint': 'Hadi, gerçekten çalışıyor: kilidi aç, şarkıyı başlat, PDF’i çentiğe sürükle.',
    'features.title': 'Çentiğin eksik olan her şeyi.',
    'f1.t': 'Şu an çalan', 'f1.d': 'Kapak ve kontrollerle Music ve Spotify.',
    'f2.t': 'Dosya tepsisi', 'f2.d': 'Dosyaları ekranın en üstünde beklet.',
    'f3.t': 'AirDrop’a bırak', 'f3.d': 'Dosyayı çentiğe sürükle ve gönder.',
    'f4.t': 'Kilit ekranı', 'f4.d': 'Kilitliyken de ada seninle.',
    'f5.t': 'Küçük widget’lar', 'f5.d': 'Odak, hava durumu, pil ya da sonraki etkinlik.',
    'f6.t': 'Hızlı zamanlayıcı', 'f6.d': 'Tek dokunuş. Geri sayım çentikte.',
    'f7.t': 'Günün planı', 'f7.d': 'Bugünkü etkinlikler ve öncesinde hatırlatma.',
    'f8.t': 'Sakin HUD’lar', 'f8.d': 'Ses ve parlaklık, yolundan çekilmiş halde.',
    'f9.t': 'Sessiz AirPods', 'f9.d': 'Ses gerçekten geldiğinde haber verir. Öncesinde değil.',
    'f10.t': 'Kaydırma hareketleri', 'f10.d': 'İki parmakla aşağı aç, yana şarkı geç.',
    'f11.t': 'English ve Türkçe', 'f11.d': 'Mac’ini takip eder ya da Ayarlar’dan seç.',
    'f12.t': 'Açık kaynak', 'f12.d': 'MIT lisanslı. Oku, çatalla, geliştir.',
    'cta.title': 'Ücretsiz. Minik. Senin.',
    'cta.lead': 'Bir megabayttan küçük; hesap yok, takip yok.',
    'cta.note': 'macOS 15 veya üstü. Zip’i aç, Inlet’i Uygulamalar’a taşı, ilk seferde sağ tıklayıp Aç’ı seç.',
    'faq.title': 'Sorular',
    'q1.q': 'Gerçekten ücretsiz mi?', 'q1.a': 'Evet. Inlet, MIT lisansıyla açık kaynak. Deneme süresi yok, gizli ücret yok.',
    'q2.q': 'Hangi Mac’lerde çalışır?', 'q2.a': 'macOS 15 veya üstü her Mac’te. MacBook çentiği için yapıldı; diğer ekranlarda menü çubuğunun altında küçük bir ada durur, istersen kapatabilirsin.',
    'q3.q': 'macOS açılamayacağını söylüyor.', 'q3.a': 'Sürümler henüz notarize edilmedi. Inlet’e sağ tıklayıp Aç’ı seç ya da <code>xattr -dr com.apple.quarantine /Applications/Inlet.app</code> komutunu çalıştır.',
    'q4.q': 'Bu sayfadaki şarkı gerçek mi?', 'q4.a': 'Web Audio API ile tarayıcında anlık üretiliyor — kayıt yok, lisans yok, telif yok. The Bezels gerçek bir grup değil. Henüz.',
    'q5.q': 'Veri topluyor mu?', 'q5.a': 'Hayır. Tek ağ isteği hava durumu widget’ı; o da seçtiğin şehri Open-Meteo’ya gönderir.',
    'q6.q': 'Hangi dilleri konuşuyor?', 'q6.a': 'İngilizce ve Türkçe; sistemini takip eder ya da Ayarlar’dan birini seçersin.',
    'footer.license': 'MIT Lisansı',
    'footer.releases': 'Sürümler',
    'footer.disclaimer': 'Inlet bağımsız bir projedir; Apple Inc. ile bağlantılı değildir, Apple tarafından onaylanmamış veya desteklenmemiştir. Mac, MacBook, AirDrop ve AirPods, Apple Inc.’in ticari markalarıdır. Spotify, Spotify AB’nin ticari markasıdır.',
  };

  // Strings the demo builds at runtime.
  const DYN = {
    en: {
      inTray: 'In tray', oneFile: '1 file', empty: 'Empty', timesUp: 'Time’s up', stretch: 'Stretch!',
      airdrop: 'Sent to “Mom’s iPad”. Expect a call about it.',
      quick: 'Quick timer', running: 'Counting down', paused: 'Paused',
    },
    tr: {
      inTray: 'Tepside', oneFile: '1 dosya', empty: 'Boş', timesUp: 'Süre doldu', stretch: 'Esne biraz!',
      airdrop: '“Annemin iPad’i”ne gönderildi. Birazdan arar.',
      quick: 'Hızlı zamanlayıcı', running: 'Geri sayım sürüyor', paused: 'Duraklatıldı',
    },
  };

  const nodes = $$('[data-i18n]');
  const EN = Object.fromEntries(nodes.map((n) => [n.dataset.i18n, n.innerHTML]));
  const langButton = $('#lang');
  let lang = 'en';
  const t = (key) => DYN[lang][key];
  const locale = () => (lang === 'tr' ? 'tr-TR' : 'en-US');

  function setLanguage(next) {
    lang = next;
    const dict = next === 'tr' ? TR : EN;
    nodes.forEach((n) => { n.innerHTML = dict[n.dataset.i18n] ?? EN[n.dataset.i18n]; });
    document.documentElement.lang = next;
    langButton.textContent = next === 'tr' ? 'EN' : 'TR';
    langButton.setAttribute('aria-label', next === 'tr' ? 'Switch to English' : 'Türkçeye geç');
    store.set('lang', next);
    tickClock();
    renderTimer();
    renderTray();
    render();
  }

  // =========================================================
  // Layout: the Mac is built at 960×600 and scaled to fit.
  // =========================================================
  const frame = $('#macFrame');
  const mac = $('#mac');
  let k = 1;
  function fit() {
    const pad = parseFloat(getComputedStyle(frame).paddingLeft);
    k = (frame.clientWidth - pad * 2) / 960;
    mac.style.transform = `scale(${k})`;
    frame.style.height = `${600 * k + pad * 2}px`;
  }
  addEventListener('resize', fit);
  fit();

  const nav = $('#nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // =========================================================
  // Clocks
  // =========================================================
  function tickClock() {
    const now = new Date();
    const time = now.toLocaleTimeString(locale(), { hour: 'numeric', minute: '2-digit' });
    $('#lockTime').textContent = time.replace(/\s?[AP]M$/i, '');
    $('#lockDate').textContent = now.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' });
    $('#menuClock').textContent = `${now.toLocaleDateString(locale(), { weekday: 'short' })} ${time}`;
    $('#calWeekday').textContent = now.toLocaleDateString(locale(), { weekday: 'long' });
    $('#calDay').textContent = now.getDate();
    $('#calMonth').textContent = now.toLocaleDateString(locale(), { month: 'long' });
  }
  setInterval(tickClock, 10_000);

  // =========================================================
  // Generated lo-fi — no recordings, so nothing to license.
  // =========================================================
  const TRACKS = [
    {
      title: 'Notch Lo-Fi', artist: 'The Bezels', bpm: 76, length: 134,
      cover: 'linear-gradient(135deg, #ffb27a, #e8664f 50%, #8e5458)',
      chords: [[53, 57, 60, 64, 67], [52, 55, 59, 62, 66], [50, 53, 57, 60, 64], [48, 52, 55, 59, 62]],
      bass: [41, 40, 38, 36],
    },
    {
      title: 'Menu Bar Blues', artist: 'Camera Cutout', bpm: 84, length: 118,
      cover: 'linear-gradient(135deg, #8fd3c7, #4f7fb8 55%, #2f3a66)',
      chords: [[57, 60, 64, 67, 71], [50, 53, 57, 60, 64], [55, 59, 62, 65, 69], [48, 52, 55, 59, 64]],
      bass: [45, 38, 43, 36],
    },
  ];
  const hz = (midi) => 440 * 2 ** ((midi - 69) / 12);

  class LoFi {
    constructor() {
      this.ctx = null;
      this.playing = false;
      this.trackIndex = 0;
      this.offset = 0;
    }

    get track() { return TRACKS[this.trackIndex]; }

    setup() {
      if (this.ctx) return;
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioCtx();
      this.ctx = ctx;
      this.master = ctx.createGain();
      this.master.gain.value = 0;
      const tone = ctx.createBiquadFilter();
      tone.type = 'lowpass';
      tone.frequency.value = 3400;
      const glue = ctx.createDynamicsCompressor();
      glue.threshold.value = -18;
      glue.ratio.value = 3;
      this.analyser = ctx.createAnalyser();
      this.analyser.fftSize = 64;
      this.analyser.smoothingTimeConstant = 0.7;
      this.master.connect(tone).connect(glue).connect(this.analyser).connect(ctx.destination);
      this.bins = new Uint8Array(this.analyser.frequencyBinCount);

      // White noise for drums, plus a quiet vinyl crackle bed.
      const noise = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
      const data = noise.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
      this.noise = noise;
      const crackleBuf = ctx.createBuffer(1, ctx.sampleRate * 3, ctx.sampleRate);
      const c = crackleBuf.getChannelData(0);
      for (let i = 0; i < c.length; i++) c[i] = Math.random() < 0.0006 ? (Math.random() * 2 - 1) : (Math.random() * 2 - 1) * 0.02;
      const crackle = ctx.createBufferSource();
      crackle.buffer = crackleBuf;
      crackle.loop = true;
      const crackleGain = ctx.createGain();
      crackleGain.gain.value = 0.18;
      const crackleHP = ctx.createBiquadFilter();
      crackleHP.type = 'highpass';
      crackleHP.frequency.value = 1200;
      crackle.connect(crackleHP).connect(crackleGain).connect(this.master);
      crackle.start();
    }

    play() {
      this.setup();
      const { ctx } = this;
      ctx.resume();
      this.playing = true;
      this.startedAt = ctx.currentTime - this.offset;
      this.step = Math.floor(this.offset / this.sixteenth) % 64;
      this.nextTime = ctx.currentTime + 0.06;
      this.master.gain.cancelScheduledValues(ctx.currentTime);
      this.master.gain.setTargetAtTime(0.55, ctx.currentTime, 0.12);
      clearInterval(this.timer);
      this.timer = setInterval(() => this.schedule(), 25);
    }

    pause() {
      if (!this.ctx || !this.playing) return;
      this.offset = this.elapsed;
      this.playing = false;
      clearInterval(this.timer);
      this.master.gain.setTargetAtTime(0, this.ctx.currentTime, 0.08);
    }

    select(index) {
      const wasPlaying = this.playing;
      this.pause();
      this.trackIndex = (index + TRACKS.length) % TRACKS.length;
      this.offset = 0;
      if (wasPlaying) setTimeout(() => this.play(), 120);
    }

    get sixteenth() { return 60 / this.track.bpm / 4; }

    get elapsed() {
      const raw = this.playing && this.ctx ? this.ctx.currentTime - this.startedAt : this.offset;
      return raw % this.track.length;
    }

    levels() {
      if (!this.ctx || !this.playing) return null;
      this.analyser.getByteFrequencyData(this.bins);
      return this.bins;
    }

    schedule() {
      while (this.nextTime < this.ctx.currentTime + 0.12) {
        this.playStep(this.step, this.nextTime);
        // A little swing on the off-beats.
        const swing = this.step % 2 === 0 ? 1.12 : 0.88;
        this.nextTime += this.sixteenth * swing;
        this.step = (this.step + 1) % 64;
      }
    }

    playStep(step, time) {
      const bar = Math.floor(step / 16);
      const s = step % 16;
      const tr = this.track;
      const beat = this.sixteenth * 4;
      if (s === 0) tr.chords[bar].forEach((n, i) => this.keys(time + i * 0.012, n, beat * 2.6, 0.07));
      if (s === 10) tr.chords[bar].slice(1, 4).forEach((n) => this.keys(time, n, beat * 0.9, 0.045));
      if (s === 0 || s === 7) this.bass(time, tr.bass[bar], beat * (s === 0 ? 1.6 : 0.8));
      if (s === 10) this.bass(time, tr.bass[bar] + 7, beat * 0.9);
      if (s === 0 || s === 10 || (s === 7 && bar % 2 === 1)) this.kick(time);
      if (s === 4 || s === 12) this.snare(time);
      if (s % 2 === 0) this.hat(time, s % 4 === 0 ? 0.05 : 0.03);
      // Sparse bell notes on top.
      if ((s === 6 || s === 14) && Math.random() < 0.55) {
        const chord = tr.chords[bar];
        this.bell(time, chord[Math.floor(Math.random() * chord.length)] + 12);
      }
    }

    env(gain, time, peak, attack, dur) {
      gain.gain.setValueAtTime(0.0001, time);
      gain.gain.exponentialRampToValueAtTime(peak, time + attack);
      gain.gain.exponentialRampToValueAtTime(0.0001, time + dur);
    }

    keys(time, midi, dur, vel) {
      const { ctx } = this;
      const g = ctx.createGain();
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 1600;
      [0, 5].forEach((detune, i) => {
        const o = ctx.createOscillator();
        o.type = i === 0 ? 'triangle' : 'sine';
        o.frequency.value = hz(midi);
        o.detune.value = detune;
        o.connect(lp);
        o.start(time);
        o.stop(time + dur + 0.1);
      });
      lp.connect(g).connect(this.master);
      this.env(g, time, vel, 0.015, dur);
    }

    bell(time, midi) {
      const { ctx } = this;
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = hz(midi);
      o.connect(g).connect(this.master);
      this.env(g, time, 0.035, 0.005, 0.9);
      o.start(time);
      o.stop(time + 1);
    }

    bass(time, midi, dur) {
      const { ctx } = this;
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = hz(midi);
      o.connect(g).connect(this.master);
      this.env(g, time, 0.22, 0.02, dur);
      o.start(time);
      o.stop(time + dur + 0.05);
    }

    kick(time) {
      const { ctx } = this;
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.frequency.setValueAtTime(120, time);
      o.frequency.exponentialRampToValueAtTime(42, time + 0.14);
      o.connect(g).connect(this.master);
      this.env(g, time, 0.55, 0.004, 0.32);
      o.start(time);
      o.stop(time + 0.35);
    }

    noiseHit(time, type, freq, peak, dur) {
      const { ctx } = this;
      const src = ctx.createBufferSource();
      src.buffer = this.noise;
      const f = ctx.createBiquadFilter();
      f.type = type;
      f.frequency.value = freq;
      const g = ctx.createGain();
      src.connect(f).connect(g).connect(this.master);
      this.env(g, time, peak, 0.002, dur);
      src.start(time, Math.random());
      src.stop(time + dur + 0.02);
    }

    snare(time) { this.noiseHit(time, 'bandpass', 1900, 0.16, 0.2); }
    hat(time, vel) { this.noiseHit(time, 'highpass', 7500, vel, 0.045); }

    chime() {
      this.setup();
      this.ctx.resume();
      const now = this.ctx.currentTime;
      const out = this.ctx.createGain();
      out.gain.value = 0.6;
      out.connect(this.ctx.destination);
      [76, 83, 88].forEach((n, i) => {
        const o = this.ctx.createOscillator();
        const g = this.ctx.createGain();
        o.type = 'sine';
        o.frequency.value = hz(n);
        o.connect(g).connect(out);
        this.env(g, now + i * 0.12, 0.12, 0.005, 1.2);
        o.start(now + i * 0.12);
        o.stop(now + i * 0.12 + 1.3);
      });
    }
  }
  const player = new LoFi();

  // =========================================================
  // Spring (response + damping ratio). Always animates from the
  // current value and keeps velocity when re-targeted.
  // =========================================================
  class Spring {
    constructor(value) { this.value = value; this.target = value; this.velocity = 0; }
    step(dt, response, damping) {
      const stiffness = (2 * Math.PI / response) ** 2;
      const friction = (4 * Math.PI * damping) / response;
      this.velocity += (-stiffness * (this.value - this.target) - friction * this.velocity) * dt;
      this.value += this.velocity * dt;
    }
    get settled() { return Math.abs(this.value - this.target) < 0.05 && Math.abs(this.velocity) < 0.05; }
    snap() { this.value = this.target; this.velocity = 0; }
  }

  function animateSprings(springs, apply, params = { response: 0.42, damping: 1 }) {
    let last = 0;
    if (springs._raf) cancelAnimationFrame(springs._raf);
    if (reduceMotion.matches) {
      springs.forEach((s) => s.snap());
      apply();
      return;
    }
    const frameFn = (time) => {
      const dt = Math.min(0.05, (time - (last || time)) / 1000);
      last = time;
      const steps = Math.max(1, Math.ceil(dt / (1 / 240)));
      for (let i = 0; i < steps; i++) springs.forEach((s) => s.step(dt / steps, params.response, params.damping));
      apply();
      if (springs.every((s) => s.settled)) {
        springs.forEach((s) => s.snap());
        apply();
        springs._raf = 0;
        return;
      }
      springs._raf = requestAnimationFrame(frameFn);
    };
    springs._raf = requestAnimationFrame(frameFn);
  }

  // =========================================================
  // Island
  // =========================================================
  const island = $('#island');
  const panes = Object.fromEntries($$('.pane', island).map((p) => [p.dataset.pane, p]));
  const S = {
    locked: true,
    expanded: false,
    tab: 'media',
    notice: null,
    drop: null,        // 'tray' | 'airdrop' while a file hovers
    invite: false,     // a drag is in progress anywhere
    hover: false,
    trayFull: false,
  };
  const SIZES = {
    idle: [180, 32, 13],
    locked: [264, 32, 13],
    activity: [264, 32, 13],
    timer: [300, 32, 13],
    notice: [440, 32, 13],
    drop: [560, 196, 30],
    expanded: [560, 200, 30],
  };
  const geo = [new Spring(180), new Spring(32), new Spring(13)];
  const applyGeo = () => {
    island.style.width = `${geo[0].value}px`;
    island.style.height = `${geo[1].value}px`;
    island.style.borderBottomLeftRadius = island.style.borderBottomRightRadius = `${geo[2].value}px`;
  };

  const timer = {
    end: 0, paused: 0, duration: 0,
    get active() { return Boolean(this.end || this.paused); },
    get remaining() { return this.paused || Math.max(0, (this.end - Date.now()) / 1000); },
  };

  function presentation() {
    if (S.drop) return 'drop';
    if (S.expanded) return 'expanded';
    if (S.notice) return 'notice';
    if (S.locked) return 'locked';
    if (timer.active) return 'timer';
    if (player.playing) return 'activity';
    return 'idle';
  }

  let lastPresentation = '';
  let lastPeek = false;
  function render(params) {
    const p = presentation();
    Object.entries(panes).forEach(([name, el]) => el.classList.toggle('on', name === p));
    island.classList.toggle('big', p === 'drop' || p === 'expanded');

    $$('.eq', panes.locked).forEach((eq) => { eq.style.visibility = player.playing ? 'visible' : 'hidden'; });
    $$('.zone', island).forEach((z) => z.classList.toggle('active', z.dataset.zone === S.drop));
    $$('.tabs button', island).forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === S.tab)));
    $$('.tab-body', island).forEach((b) => b.classList.toggle('on', b.dataset.body === S.tab));

    const [w, h, r] = SIZES[p];
    const peek = (S.hover || S.invite) && p !== 'drop' && p !== 'expanded';
    geo[0].target = w + (peek ? 16 : 0);
    geo[1].target = h + (peek ? 5 : 0);
    geo[2].target = r;
    if (p !== lastPresentation || params || peek !== lastPeek) animateSprings(geo, applyGeo, params);
    lastPeek = peek;
    lastPresentation = p;
  }

  let noticeTimer = 0;
  function notify(left, right, ms = 2000) {
    if (S.expanded || S.drop) return;
    clearTimeout(noticeTimer);
    $('#noticeLeft').innerHTML = left;
    $('#noticeRight').innerHTML = right;
    S.notice = true;
    render();
    noticeTimer = setTimeout(() => { S.notice = null; render(); }, ms);
  }
  const svg = (id, cls = '') => `<svg class="${cls}"><use href="#${id}"/></svg>`;

  function expand(tab) {
    if (tab) S.tab = tab;
    S.expanded = true;
    S.notice = null;
    render();
  }
  function collapse() {
    if (!S.expanded) return;
    S.expanded = false;
    render();
  }

  island.addEventListener('pointerdown', (e) => {
    if (e.target.closest('button')) return;
    e.stopPropagation();
    if (!S.expanded) expand();
  });
  island.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); S.expanded ? collapse() : expand(); }
    if (e.key === 'Escape') collapse();
  });
  island.addEventListener('pointerenter', (e) => { if (e.pointerType === 'mouse') { S.hover = true; render(); } });
  island.addEventListener('pointerleave', () => { S.hover = false; render(); });
  mac.addEventListener('pointerdown', (e) => {
    if (!island.contains(e.target) && !e.target.closest('.file')) collapse();
  });

  $$('.tabs button', island).forEach((b) => b.addEventListener('click', () => { S.tab = b.dataset.tab; render(); }));

  // =========================================================
  // Lock & unlock
  // =========================================================
  const lockIcon = $('[data-lockicon]');
  const hint = $('#dragHint');

  $('#unlock').addEventListener('click', () => {
    lockIcon.setAttribute('href', '#i-unlock');
    geo[0].target += 22;
    animateSprings(geo, applyGeo, { response: 0.3, damping: 0.8 });
    setTimeout(() => {
      S.locked = false;
      mac.classList.remove('locked');
      notify(svg('i-unlock', 'ic'), svg('i-check', 'ic muted'), 1100);
      if (!S.trayFull) hint.classList.remove('gone');
    }, reduceMotion.matches ? 0 : 380);
  });

  // A small lock button joins the menu bar so you can go back.
  const relock = document.createElement('button');
  relock.className = 'mb-lock';
  relock.type = 'button';
  relock.setAttribute('aria-label', 'Lock screen');
  relock.innerHTML = svg('i-lock');
  $('.mb-right').prepend(relock);
  relock.addEventListener('click', () => {
    S.locked = true;
    S.expanded = false;
    lockIcon.setAttribute('href', '#i-lock');
    mac.classList.add('locked');
    hint.classList.add('gone');
    render();
  });

  // =========================================================
  // Player UI
  // =========================================================
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
  function renderTrack() {
    const tr = player.track;
    $$('[data-title]').forEach((el) => { el.textContent = tr.title; });
    $$('[data-artist]').forEach((el) => { el.textContent = tr.artist; });
    $$('[data-cover]').forEach((el) => el.style.setProperty('--cover', tr.cover));
    renderProgress();
  }
  function renderProgress() {
    const tr = player.track;
    const e = player.elapsed;
    $$('[data-progress]').forEach((el) => { el.style.width = `${(e / tr.length) * 100}%`; });
    $$('[data-elapsed]').forEach((el) => { el.textContent = fmt(e); });
    $$('[data-left]').forEach((el) => { el.textContent = `-${fmt(tr.length - e)}`; });
  }
  function renderPlayState() {
    $$('[data-pp]').forEach((b) => {
      b.querySelector('use').setAttribute('href', player.playing ? '#i-pause' : '#i-play');
      b.setAttribute('aria-label', player.playing ? 'Pause' : 'Play');
    });
    render();
    if (player.playing) visualize();
  }

  $$('[data-pp]').forEach((b) => b.addEventListener('click', (e) => {
    e.stopPropagation();
    player.playing ? player.pause() : player.play();
    renderPlayState();
  }));
  const skip = (delta) => (e) => {
    e.stopPropagation();
    player.select(player.trackIndex + delta);
    renderTrack();
    setTimeout(renderPlayState, 140);
  };
  $$('[data-next]').forEach((b) => b.addEventListener('click', skip(1)));
  $$('[data-prev]').forEach((b) => b.addEventListener('click', skip(-1)));
  setInterval(renderProgress, 250);

  // Bars follow the music's actual spectrum.
  const eqBars = $$('.eq i');
  const meterBars = $$('[data-meter] i');
  function visualize() {
    const bins = player.levels();
    if (!bins) {
      eqBars.forEach((b) => { b.style.transform = 'scaleY(0.3)'; });
      meterBars.forEach((b) => { b.style.transform = 'scaleY(0.25)'; });
      return;
    }
    const pick = [2, 4, 7, 11, 15];
    eqBars.forEach((b, i) => { b.style.transform = `scaleY(${0.3 + (bins[pick[i % 4]] / 255) * 0.75})`; });
    meterBars.forEach((b, i) => { b.style.transform = `scaleY(${0.25 + (bins[pick[i]] / 255) * 0.8})`; });
    requestAnimationFrame(visualize);
  }

  // =========================================================
  // File drag — follows the pointer 1:1 from where you grabbed it,
  // springs home with its release velocity if dropped elsewhere.
  // =========================================================
  const file = $('#file');
  const HOME = { x: 790, y: 300 };
  const pos = { x: new Spring(0), y: new Spring(0), s: new Spring(1) };
  const posSprings = [pos.x, pos.y, pos.s];
  const applyPos = () => { file.style.transform = `translate(${pos.x.value}px, ${pos.y.value}px) scale(${pos.s.value})`; };
  let drag = null;

  const local = (e) => {
    const r = mac.getBoundingClientRect();
    return { x: (e.clientX - r.left) / k, y: (e.clientY - r.top) / k };
  };

  function zoneAt(p) {
    const cx = 480;
    const open = Boolean(S.drop);
    const half = open ? SIZES.drop[0] / 2 + 40 : 90 + 170;
    const bottom = open ? SIZES.drop[1] + 40 : 32 + 120;
    if (Math.abs(p.x - cx) > half || p.y > bottom) return null;
    const left = cx - SIZES.drop[0] / 2;
    return p.x < left + SIZES.drop[0] * 0.6 ? 'tray' : 'airdrop';
  }

  file.addEventListener('pointerdown', (e) => {
    if (S.locked) return;
    e.preventDefault();
    try { file.setPointerCapture(e.pointerId); } catch { /* synthetic events */ }
    const p = local(e);
    drag = { offX: p.x - (HOME.x + pos.x.value), offY: p.y - (HOME.y + pos.y.value), history: [{ ...p, t: performance.now() }] };
    file.classList.add('dragging');
    hint.classList.add('gone');
    collapse();
    S.invite = true;
    pos.s.target = 1.06;
    animateSprings(posSprings, applyPos, { response: 0.25, damping: 1 });
    render();
  });

  file.addEventListener('pointermove', (e) => {
    if (!drag) return;
    const p = local(e);
    pos.x.value = pos.x.target = p.x - drag.offX - HOME.x;
    pos.y.value = pos.y.target = p.y - drag.offY - HOME.y;
    applyPos();
    drag.history.push({ ...p, t: performance.now() });
    if (drag.history.length > 5) drag.history.shift();
    const zone = zoneAt(p);
    if (zone !== S.drop) { S.drop = zone; render({ response: 0.4, damping: 1 }); }
  });

  function endDrag(e) {
    if (!drag) return;
    const h = drag.history;
    const a = h[0];
    const b = h[h.length - 1];
    const dt = Math.max(1, b.t - a.t) / 1000;
    const velocity = { x: (b.x - a.x) / dt, y: (b.y - a.y) / dt };
    drag = null;
    file.classList.remove('dragging');
    S.invite = false;
    const zone = S.drop;

    if (zone === 'tray') {
      flyInto(-90, () => {
        S.trayFull = true;
        renderTray();
        S.drop = null;
        S.hover = true;
        expand('tray');
      });
    } else if (zone === 'airdrop') {
      flyInto(180, () => {
        S.drop = null;
        render();
        toast(t('airdrop'));
        returnHome();
      });
    } else {
      S.drop = null;
      render();
      // Momentum earns a touch of bounce on the way home.
      pos.x.velocity = velocity.x;
      pos.y.velocity = velocity.y;
      pos.x.target = 0;
      pos.y.target = 0;
      pos.s.target = 1;
      animateSprings(posSprings, applyPos, { response: 0.45, damping: 0.78 });
    }
    if (e && file.hasPointerCapture?.(e.pointerId)) file.releasePointerCapture(e.pointerId);
  }
  file.addEventListener('pointerup', endDrag);
  file.addEventListener('pointercancel', endDrag);

  // The file shrinks into the zone it was dropped on.
  function flyInto(offsetX, done) {
    pos.x.target = 480 + offsetX - HOME.x - 52;
    pos.y.target = 110 - HOME.y - 40;
    pos.s.target = 0.2;
    file.style.transition = 'opacity 260ms ease';
    file.style.opacity = '0';
    animateSprings(posSprings, applyPos, { response: 0.32, damping: 1 });
    setTimeout(done, reduceMotion.matches ? 0 : 280);
  }

  function returnHome() {
    pos.x.value = pos.x.target = 0;
    pos.y.value = pos.y.target = 0;
    pos.x.velocity = pos.y.velocity = 0;
    pos.s.value = 0.6;
    pos.s.target = 1;
    applyPos();
    file.hidden = false;
    file.style.opacity = '1';
    animateSprings(posSprings, applyPos, { response: 0.35, damping: 1 });
  }

  // =========================================================
  // Tray & AirDrop
  // =========================================================
  function renderTray() {
    $('#trayEmpty').hidden = S.trayFull;
    $('#trayFull').hidden = !S.trayFull;
    $('#trayCount').textContent = S.trayFull ? t('oneFile') : t('empty');
    file.hidden = S.trayFull;
  }
  $('#trayClear').addEventListener('click', (e) => {
    e.stopPropagation();
    S.trayFull = false;
    renderTray();
    returnHome();
  });
  $('#trayAirdrop').addEventListener('click', (e) => { e.stopPropagation(); toast(t('airdrop')); });

  let toastTimer = 0;
  function toast(text) {
    const el = $('#toast');
    el.textContent = text;
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 2800);
  }

  // =========================================================
  // Timer
  // =========================================================
  function renderTimer() {
    const rem = timer.active ? timer.remaining : 0;
    $('#ringText').textContent = fmt(Math.ceil(rem));
    $('[data-timer-text]').textContent = fmt(Math.ceil(rem));
    $('#ringArc').style.strokeDashoffset = timer.active ? 276.5 * (1 - rem / timer.duration) : 276.5;
    $('#presets').hidden = timer.active;
    $('#timerRunning').hidden = !timer.active;
    $('#timerLabel').textContent = !timer.active ? t('quick') : timer.paused ? t('paused') : t('running');
    $('#timerPause use').setAttribute('href', timer.paused ? '#i-play' : '#i-pause');
  }
  $$('#presets button').forEach((b) => b.addEventListener('click', (e) => {
    e.stopPropagation();
    timer.duration = Number(b.dataset.secs);
    timer.end = Date.now() + timer.duration * 1000;
    timer.paused = 0;
    renderTimer();
  }));
  $('#timerPause').addEventListener('click', (e) => {
    e.stopPropagation();
    if (timer.paused) { timer.end = Date.now() + timer.paused * 1000; timer.paused = 0; }
    else { timer.paused = timer.remaining; timer.end = 0; }
    renderTimer();
  });
  $('#timerCancel').addEventListener('click', (e) => { e.stopPropagation(); timer.end = 0; timer.paused = 0; renderTimer(); render(); });
  setInterval(() => {
    if (!timer.end) return;
    if (Date.now() >= timer.end) {
      timer.end = 0;
      renderTimer();
      player.chime();
      S.expanded = false;
      notify(`${svg('i-timer', 'orange')}<span class="orange">${t('timesUp')}</span>`, `<span class="orange">${t('stretch')}</span>`, 3200);
      return;
    }
    renderTimer();
    render();
  }, 250);

  // =========================================================
  // Start
  // =========================================================
  mac.classList.add('locked');
  hint.classList.add('gone');
  const saved = store.get('lang');
  // Only trust known values from storage; anything else falls back to the browser language.
  const initial = (saved === 'tr' || saved === 'en') ? saved : ((navigator.language || '').toLowerCase().startsWith('tr') ? 'tr' : 'en');
  renderTrack();
  setLanguage(initial);
  langButton.addEventListener('click', () => setLanguage(lang === 'tr' ? 'en' : 'tr'));
  applyGeo();
  render();
})();
