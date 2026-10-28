(() => {
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  // ---------- Language ----------
  // English lives in the HTML (what search engines index); Turkish is applied on top.
  const tr = {
    'nav.features': 'Özellikler',
    'nav.why': 'Neden',
    'nav.faq': 'SSS',
    'hero.eyebrow': 'Ücretsiz ve açık kaynak · macOS 15+',
    'hero.title': 'Çentiğin artık<br>işe yarıyor.',
    'hero.lead': 'Inlet, MacBook’undaki kamera çentiğini müzik, dosyalar, zamanlayıcılar ve normalde kaçırdığın küçük uyarılar için sakin ve canlı bir şeride dönüştürür.',
    'hero.download': 'macOS için indir',
    'hero.github': 'GitHub’da incele',
    'hero.fact1': 'Yerel Swift',
    'hero.fact2': 'Hesap yok',
    'hero.fact3': 'Takip yok',
    'demo.file': 'Dosya',
    'demo.edit': 'Düzen',
    'demo.view': 'Görüntü',
    'demo.charging': 'Şarj oluyor',
    'demo.percent': '%82',
    'demo.connected': 'Bağlandı',
    'demo.dropTray': 'Tepsiye bırak',
    'chip.music': 'Müzik',
    'chip.player': 'Oynatıcı',
    'chip.files': 'Dosyalar',
    'chip.timer': 'Zamanlayıcı',
    'chip.charging': 'Şarj',
    'features.title': 'Her şey ekranının en üstünde.',
    'features.lead': 'Uygulamadan gerçek ekran görüntüleri. Hiçbiri taslak değil.',
    'f.media.t': 'Şu an çalan',
    'f.media.d': 'Kapak, ilerleme çubuğu ve kontrollerle Music ve Spotify. Şarkı atlamak için trackpad’de yana kaydır.',
    'f.tray.t': 'Tepsi ve AirDrop',
    'f.tray.d': 'Bir dosyayı çentiğe yaklaştır, tepsi açılsın. Orada beklet ya da doğrudan AirDrop’a bırak.',
    'f.lock.t': 'Kilit ekranında da',
    'f.lock.d': 'Bir müzik kartı ve seçtiğin iki küçük widget: Odak, hava durumu, pil ya da sonraki etkinlik.',
    'f.hud.t': 'Daha sakin HUD’lar',
    'f.hud.d': 'Ses ve parlaklık, işinin üstüne düşmek yerine çentikten süzülerek çıkar.',
    'f.timer.t': 'Hızlı zamanlayıcı',
    'f.timer.d': 'Tek dokunuşla 1, 5, 10 ya da 25 dakika. Geri sayım çentikte kalır.',
    'f.cal.t': 'Günün ve küçük şeyler',
    'f.cal.d': 'Bugünkü etkinlikler ve beş dakika önce hatırlatma; şarj, pil zayıf, AirPods ve Caps Lock — her biri bir an görünür, sonra kaybolur.',
    'why.title': 'Neden böyle çalışıyor',
    'why.lead': 'Inlet’in arkasındaki birkaç karar ve nedenleri.',
    'w1.t': 'Zamanlayıcı değil, yay',
    'w1.d': 'Her hareket olduğu yerden başlar ve yarıda tersine dönebilir; ada senaryolu değil fiziksel hissettirir. Sekme yalnızca kaydırman ona ivme verdiyse görünür.',
    'w2.t': 'Varsayılan olarak tıkla aç',
    'w2.d': 'Üzerine gelince açılma bir anahtar uzağında ama başta kapalı: imleci menü çubuğunda gezdirmek üstüne paneller fırlatmamalı.',
    'w3.t': 'Kilit ekranı için bir ikiz',
    'w3.d': 'macOS, kilit ekranının üstündeki pencerelere sürükle-bırak iletmiyor. Bu yüzden gün boyu kullandığın ada normal bir pencere; ikizi yalnızca Mac kilitliyken devreye girer.',
    'w4.t': 'Kopya değil, referans',
    'w4.d': 'Tepsi dosyaları çoğaltmaz, onlara işaret eder. Diskte hiçbir şey birikmez, dosyalar olduğu yerde kalır.',
    'w5.t': 'Sessiz Bluetooth uyarıları',
    'w5.d': 'AirPods arka planda sürekli kısa bağlantılar açar. Inlet ancak ses gerçekten onlara yönlendiğinde haber verir.',
    'w6.t': 'Hesapsız hava durumu',
    'w6.d': 'Tahminler Open-Meteo’dan gelir — ücretsiz, anahtarsız. Mac’inden çıkan tek şey yazdığın şehir.',
    'w7.t': 'Yalnızca gerektiğinde ister',
    'w7.d': 'Takvim, Bluetooth ve Tam Disk Erişimi yalnızca onlara ihtiyaç duyan özellikler için istenir. Birini atlarsan gerisi çalışmaya devam eder.',
    'w8.t': 'Yerel ve hafif',
    'w8.d': 'SwiftUI ve AppKit. Electron yok, web görünümü yok, analiz SDK’sı yok — sadece yoluna çıkmayan küçük bir uygulama.',
    'install.title': 'Bir dakikada kur',
    'install.s1': 'Son sürümden <b>Inlet.zip</b>’i indir ve aç.',
    'install.s2': '<b>Inlet.app</b>’i Uygulamalar klasörüne taşı.',
    'install.s3': 'İlk seferde Inlet’e sağ tıklayıp <b>Aç</b>’ı seç — sürümler henüz notarize edilmedi.',
    'faq.title': 'Sorular',
    'q1.q': 'Gerçekten ücretsiz mi?',
    'q1.a': 'Evet. Inlet MIT lisansıyla açık kaynak — kullan, değiştir, paylaş.',
    'q2.q': 'Hangi Mac’lerde çalışır?',
    'q2.a': 'macOS 15 veya üstü her Mac’te. MacBook çentiğine göre tasarlandı; diğer ekranlarda menü çubuğunun altında küçük bir ada durur ve istersen kapatabilirsin.',
    'q3.q': 'macOS, Inlet’in açılamayacağını söylüyor.',
    'q3.a': 'Sürümler henüz notarize edilmedi. Uygulamaya sağ tıklayıp Aç’ı seç ya da Terminal’de <code>xattr -dr com.apple.quarantine /Applications/Inlet.app</code> komutunu çalıştır.',
    'q4.q': 'Hangi müzik uygulamaları çalışıyor?',
    'q4.a': 'Apple Music ve Spotify. macOS, Inlet’in onlarla konuşması için bir kez izin ister.',
    'q5.q': 'Inlet veri topluyor mu?',
    'q5.a': 'Hayır. Analiz yok, hesap yok. Tek ağ isteği hava durumu widget’ı; o da seçtiğin şehri Open-Meteo’ya gönderir.',
    'q6.q': 'macOS güncellemelerinden sonra her şey çalışmaya devam eder mi?',
    'q6.a': 'Çoğu özellik açık API’ler kullanır. Kilit ekranı penceresi ve parlaklık HUD’ı, Apple’ın değiştirebileceği özel macOS arayüzlerine dayanır; böyle olursa bu iki parça Inlet güncellenene kadar duraklayabilir.',
    'q7.q': 'Hangi dilleri konuşuyor?',
    'q7.a': 'İngilizce ve Türkçe; sistem dilini takip eder ya da Ayarlar’dan birini seçersin. Çevirilere GitHub’da katkı verebilirsin.',
    'footer.license': 'MIT Lisansı',
    'footer.disclaimer': 'Inlet bağımsız bir projedir; Apple Inc. ile bağlantılı değildir, Apple tarafından onaylanmamış veya desteklenmemiştir. Mac, MacBook, AirDrop ve AirPods, Apple Inc.’in ticari markalarıdır. Spotify, Spotify AB’nin ticari markasıdır.',
  };

  const nodes = [...document.querySelectorAll('[data-i18n]')];
  const en = Object.fromEntries(nodes.map((n) => [n.dataset.i18n, n.innerHTML]));
  const langButton = document.getElementById('lang');

  function setLanguage(lang) {
    const dict = lang === 'tr' ? tr : en;
    nodes.forEach((n) => {
      const value = dict[n.dataset.i18n] ?? en[n.dataset.i18n];
      if (value !== undefined) n.innerHTML = value;
    });
    document.querySelectorAll('[data-shot]').forEach((img) => {
      img.src = `assets/shots/${lang}/${img.dataset.shot}.png`;
    });
    document.documentElement.lang = lang;
    langButton.textContent = lang === 'tr' ? 'EN' : 'TR';
    langButton.setAttribute('aria-label', lang === 'tr' ? 'Switch to English' : 'Türkçeye geç');
    store.set('lang', lang);
    current = lang;
  }

  let current = 'en';
  const saved = store.get('lang');
  const initial = saved ?? ((navigator.language || '').toLowerCase().startsWith('tr') ? 'tr' : 'en');
  if (initial === 'tr') setLanguage('tr');
  langButton.addEventListener('click', () => setLanguage(current === 'tr' ? 'en' : 'tr'));

  // ---------- Nav edge ----------
  const nav = document.getElementById('nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // ---------- Clock ----------
  const clock = document.getElementById('clock');
  const tick = () => {
    clock.textContent = new Date().toLocaleTimeString(current === 'tr' ? 'tr-TR' : 'en-US', { hour: 'numeric', minute: '2-digit' });
  };
  tick();
  setInterval(tick, 10_000);

  // ---------- Spring (response + damping ratio, Apple-style) ----------
  // Always animates from the current value and keeps velocity when
  // re-targeted, so every change can be interrupted mid-flight.
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

  // ---------- Island demo ----------
  const bezel = document.getElementById('bezel');
  const island = document.getElementById('island');
  const panes = [...island.querySelectorAll('.pane')];
  const chips = [...document.querySelectorAll('.chip')];

  const base = {
    idle: [170, 30, 14],
    music: [244, 30, 14],
    charging: [330, 30, 14],
    airpods: [340, 30, 14],
    timer: [270, 30, 14],
    files: [460, 150, 30],
    expanded: [460, 172, 30],
  };
  // Shrink the bigger states on narrow screens.
  const size = (name) => {
    const [w, h, r] = base[name];
    const max = bezel.clientWidth - 28;
    return w > max ? [max, h, r] : [w, h, r];
  };

  const springs = { w: new Spring(170), h: new Spring(30), r: new Spring(14) };
  let params = { response: 0.42, damping: 1 };
  let raf = 0;
  let last = 0;
  let state = 'idle';

  function render() {
    island.style.width = `${springs.w.value}px`;
    island.style.height = `${springs.h.value}px`;
    island.style.borderBottomLeftRadius = island.style.borderBottomRightRadius = `${springs.r.value}px`;
  }

  function frame(t) {
    const dt = Math.min(0.05, (t - (last || t)) / 1000);
    last = t;
    const steps = Math.max(1, Math.ceil(dt / (1 / 240)));
    for (let i = 0; i < steps; i++) Object.values(springs).forEach((s) => s.step(dt / steps, params.response, params.damping));
    render();
    if (Object.values(springs).every((s) => s.settled)) {
      Object.values(springs).forEach((s) => s.snap());
      render();
      raf = 0;
      last = 0;
      return;
    }
    raf = requestAnimationFrame(frame);
  }

  function show(name) {
    state = name;
    const [w, h, r] = size(name);
    springs.w.target = w;
    springs.h.target = h;
    springs.r.target = r;
    panes.forEach((p) => p.classList.toggle('on', p.dataset.pane === name));
    island.classList.toggle('big', name === 'expanded' || name === 'files');
    chips.forEach((c) => c.classList.toggle('active', c.dataset.state === name));
    if (reduceMotion.matches) {
      Object.values(springs).forEach((s) => s.snap());
      render();
    } else if (!raf) {
      raf = requestAnimationFrame(frame);
    }
  }

  // Autoplay through the states; any interaction pauses it for a while.
  const sequence = ['music', 'expanded', 'music', 'files', 'timer', 'charging', 'airpods'];
  let step = 0;
  let pausedUntil = 0;
  const advance = () => {
    if (Date.now() < pausedUntil || document.hidden) return;
    show(sequence[step % sequence.length]);
    step += 1;
  };
  const pause = (ms = 9000) => { pausedUntil = Date.now() + ms; };

  setTimeout(advance, 600);
  setInterval(advance, 2600);

  chips.forEach((chip) => chip.addEventListener('click', () => { pause(); show(chip.dataset.state); }));
  island.addEventListener('pointerdown', (e) => {
    if (e.target.closest('button')) return;
    pause();
    show(state === 'expanded' ? 'music' : 'expanded');
  });
  island.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      pause();
      show(state === 'expanded' ? 'music' : 'expanded');
    }
  });
  document.getElementById('demo').addEventListener('pointerenter', () => pause(4000));
  addEventListener('resize', () => show(state));

  // Fake playback in the expanded player.
  const progress = document.getElementById('progress');
  const pp = document.getElementById('pp');
  let playing = true;
  let position = 0.38;
  setInterval(() => {
    if (!playing) return;
    position = (position + 0.004) % 1;
    progress.style.width = `${position * 100}%`;
  }, 500);
  pp.addEventListener('click', () => {
    pause();
    playing = !playing;
    pp.querySelector('use').setAttribute('href', playing ? '#i-pause' : '#i-play');
    island.querySelectorAll('.eq i').forEach((bar) => { bar.style.animationPlayState = playing ? '' : 'paused'; });
  });

  // Timer text counts down while visible.
  const timerText = document.getElementById('timer-text');
  let remaining = 25 * 60 - 1;
  setInterval(() => {
    remaining = remaining > 0 ? remaining - 1 : 25 * 60;
    timerText.textContent = `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}`;
  }, 1000);

  render();
})();
