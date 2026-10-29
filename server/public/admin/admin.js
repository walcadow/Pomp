// Pomp yönetici paneli. Derleme gerektirmeyen düz JavaScript.
// Güvenlik: kullanıcıdan gelen hiçbir metin innerHTML ile eklenmez; her şey textContent ile yazılır.
(function () {
  'use strict';

  var API = '/admin/api';
  var TOKEN_KEY = 'pompAdminToken';

  var REASONS = {
    fake: 'Sahte profil',
    inappropriate_photos: 'Uygunsuz fotoğraf',
    harassment: 'Taciz / rahatsız etme',
    spam: 'Spam / reklam',
    underage: '18 yaş altı',
    other: 'Diğer',
  };
  var GENDERS = { male: 'Erkek', female: 'Kadın', other: 'Diğer' };
  var ACTIONS = { dismiss: 'Yoksayıldı', ban: 'Kullanıcı yasaklandı' };

  var state = {
    reportStatus: 'open',
    users: { q: '', filter: 'all', page: 1, total: 0, pageSize: 50 },
    openUserId: null,
    tab: 'reports',
  };

  // ---------- Yardımcılar ----------

  function $(id) { return document.getElementById(id); }

  // el('div', { className: 'x', onclick: fn, title: '...' }, 'metin', childNode, ...)
  function el(tag, props) {
    var node = document.createElement(tag);
    if (props) {
      Object.keys(props).forEach(function (key) {
        var value = props[key];
        if (value == null || value === false) return;
        if (key === 'className') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key.slice(0, 2) === 'on') node.addEventListener(key.slice(2), value);
        else if (key === 'dataset') Object.keys(value).forEach(function (k) { node.dataset[k] = value[k]; });
        else node.setAttribute(key, value === true ? '' : String(value));
      });
    }
    for (var i = 2; i < arguments.length; i++) append(node, arguments[i]);
    return node;
  }
  function append(node, child) {
    if (child == null || child === false) return;
    if (Array.isArray(child)) { child.forEach(function (c) { append(node, c); }); return; }
    node.appendChild(typeof child === 'object' ? child : document.createTextNode(String(child)));
  }
  function clear(node) { while (node.firstChild) node.removeChild(node.firstChild); }

  function safeUrl(url) {
    return typeof url === 'string' && /^(https?:\/\/|\/)/i.test(url) ? url : null;
  }

  function getToken() { try { return sessionStorage.getItem(TOKEN_KEY); } catch (e) { return null; } }
  function setToken(t) { try { if (t) sessionStorage.setItem(TOKEN_KEY, t); else sessionStorage.removeItem(TOKEN_KEY); } catch (e) { /* yok say */ } }

  var dateFmt = new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  var shortDateFmt = new Intl.DateTimeFormat('tr-TR', { day: 'numeric', month: 'short', year: 'numeric' });
  var rtf = new Intl.RelativeTimeFormat('tr', { numeric: 'auto' });
  var numFmt = new Intl.NumberFormat('tr-TR');

  function fmtDate(v) { return v ? dateFmt.format(new Date(v)) : '—'; }
  function fmtShort(v) { return v ? shortDateFmt.format(new Date(v)) : '—'; }
  function fmtAgo(v) {
    if (!v) return '—';
    var diff = (new Date(v).getTime() - Date.now()) / 1000;
    var abs = Math.abs(diff);
    if (abs < 60) return 'az önce';
    if (abs < 3600) return rtf.format(Math.round(diff / 60), 'minute');
    if (abs < 86400) return rtf.format(Math.round(diff / 3600), 'hour');
    if (abs < 86400 * 30) return rtf.format(Math.round(diff / 86400), 'day');
    return fmtShort(v);
  }

  var toastTimer = null;
  function toast(msg, isError) {
    var t = $('toast');
    t.textContent = msg;
    t.className = 'toast' + (isError ? ' error' : '');
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.hidden = true; }, isError ? 5000 : 2800);
  }

  // ---------- API ----------

  function api(method, path, body) {
    var headers = { Accept: 'application/json' };
    var token = getToken();
    if (token) headers.Authorization = 'Bearer ' + token;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    return fetch(API + path, {
      method: method,
      headers: headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    }).then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (data) {
        if (res.status === 503 && data.disabled) { showView('disabled-view'); throw silentError(); }
        if (res.status === 401 && path !== '/login') {
          logout(data.error || 'Oturumunuzun süresi doldu, tekrar giriş yapın.');
          throw silentError();
        }
        if (!res.ok) throw new Error(data.error || 'İşlem başarısız oldu (' + res.status + ').');
        return data;
      });
    }, function () {
      throw new Error('Sunucuya ulaşılamadı. İnternet bağlantısını ve sunucuyu kontrol edin.');
    });
  }
  function silentError() { var e = new Error('silent'); e.silent = true; return e; }
  function handleError(err) { if (!err.silent) toast(err.message, true); }

  // ---------- Görünümler ----------

  function showView(id) {
    ['boot', 'disabled-view', 'login-view', 'app-view'].forEach(function (v) { $(v).hidden = v !== id; });
    if (id !== 'app-view') { closeDrawer(); }
  }

  function boot() {
    fetch(API + '/status').then(function (r) { return r.json(); }).then(function (s) {
      if (!s.enabled) return showView('disabled-view');
      if (getToken()) enterApp();
      else showLogin();
    }).catch(function () {
      showLogin('Sunucuya ulaşılamadı. Sunucunun çalıştığından emin olun.');
    });
  }

  function showLogin(message) {
    showView('login-view');
    var err = $('login-error');
    err.textContent = message || '';
    err.hidden = !message;
    $('login-password').value = '';
    setTimeout(function () { $('login-password').focus(); }, 0);
  }

  function logout(message) {
    setToken(null);
    showLogin(message);
  }

  $('login-form').addEventListener('submit', function (e) {
    e.preventDefault();
    var btn = $('login-btn');
    var err = $('login-error');
    err.hidden = true;
    btn.disabled = true;
    btn.textContent = 'Giriş yapılıyor…';
    api('POST', '/login', { password: $('login-password').value })
      .then(function (data) { setToken(data.token); enterApp(); })
      .catch(function (e2) {
        if (e2.silent) return;
        err.textContent = e2.message;
        err.hidden = false;
      })
      .then(function () { btn.disabled = false; btn.textContent = 'Giriş yap'; });
  });

  $('logout-btn').addEventListener('click', function () { logout(); });
  $('refresh-btn').addEventListener('click', function () { refreshAll(); });

  function enterApp() {
    showView('app-view');
    switchTab(state.tab);
    loadStats();
  }

  function refreshAll() {
    loadStats();
    if (state.tab === 'reports') loadReports(); else loadUsers();
    if (state.openUserId) openUser(state.openUserId, true);
  }

  // ---------- İstatistikler ----------

  var STAT_CARDS = [
    ['total_users', 'Toplam kullanıcı', 'demo dahil'],
    ['real_users', 'Gerçek kullanıcı', 'demo hariç'],
    ['active_24h', 'Aktif (24 saat)', 'gerçek kullanıcı'],
    ['new_7d', 'Yeni (7 gün)', 'gerçek kullanıcı'],
    ['matches', 'Eşleşme', 'toplam'],
    ['messages_24h', 'Mesaj (24 saat)', 'gönderilen'],
    ['open_reports', 'Açık şikâyet', 'incelenmeyi bekliyor'],
    ['banned_users', 'Yasaklı', 'kullanıcı'],
  ];

  function renderStats(s) {
    var box = $('stats');
    clear(box);
    STAT_CARDS.forEach(function (c) {
      var value = s ? s[c[0]] : null;
      var cls = 'card stat' + (!s ? ' skeleton' : '') + (c[0] === 'open_reports' && value > 0 ? ' alert' : '');
      append(box, el('div', { className: cls },
        el('div', { className: 'stat-label', text: c[1] }),
        el('div', { className: 'stat-value', text: value == null ? '0' : numFmt.format(value) }),
        el('div', { className: 'stat-sub', text: c[2] })));
    });
    var badge = $('tab-badge');
    if (s && s.open_reports > 0) { badge.textContent = String(s.open_reports); badge.hidden = false; }
    else badge.hidden = true;
  }

  function loadStats() {
    return api('GET', '/stats').then(renderStats).catch(handleError);
  }

  // ---------- Sekmeler ----------

  function switchTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tab').forEach(function (b) {
      var on = b.dataset.tab === tab;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    $('reports-panel').hidden = tab !== 'reports';
    $('users-panel').hidden = tab !== 'users';
    if (tab === 'reports') loadReports(); else loadUsers();
  }
  document.querySelectorAll('.tab').forEach(function (b) {
    b.addEventListener('click', function () { switchTab(b.dataset.tab); });
  });

  // ---------- Ortak parçalar ----------

  function initials(name) { return (String(name || '?').trim().charAt(0) || '?').toLocaleUpperCase('tr-TR'); }

  function avatar(photo, name, large) {
    var cls = 'avatar' + (large ? ' avatar-lg' : '');
    var url = safeUrl(photo);
    if (!url) return el('div', { className: cls, text: initials(name), 'aria-hidden': 'true' });
    var img = el('img', { className: cls, alt: '', loading: 'lazy', referrerpolicy: 'no-referrer' });
    img.addEventListener('error', function () {
      img.replaceWith(el('div', { className: cls, text: initials(name), 'aria-hidden': 'true' }));
    });
    img.src = url;
    return img;
  }

  function userBadges(u) {
    return [
      u.is_banned ? el('span', { className: 'badge badge-red', text: 'Yasaklı' }) : null,
      u.is_demo ? el('span', { className: 'badge badge-purple', text: 'Demo' }) : null,
    ];
  }

  function nameAge(u) { return u.age != null ? u.name + ', ' + u.age : u.name; }

  // ---------- Onay penceresi ----------

  var confirmResolve = null;
  function confirmDialog(opts) {
    $('confirm-title').textContent = opts.title;
    $('confirm-text').textContent = opts.text || '';
    $('confirm-text').hidden = !opts.text;
    $('confirm-note-wrap').hidden = !opts.note;
    $('confirm-note-label').textContent = opts.note || '';
    $('confirm-note').value = '';
    var ok = $('confirm-ok');
    ok.textContent = opts.okText || 'Onayla';
    ok.className = 'btn ' + (opts.danger === false ? 'btn-primary' : 'btn-danger');
    $('confirm').hidden = false;
    setTimeout(function () { (opts.note ? $('confirm-note') : ok).focus(); }, 0);
    return new Promise(function (resolve) { confirmResolve = resolve; });
  }
  function closeConfirm(result) {
    $('confirm').hidden = true;
    if (confirmResolve) { var r = confirmResolve; confirmResolve = null; r(result); }
  }
  $('confirm-ok').addEventListener('click', function () { closeConfirm({ note: $('confirm-note').value.trim() }); });
  $('confirm-cancel').addEventListener('click', function () { closeConfirm(null); });
  document.querySelector('#confirm .modal-backdrop').addEventListener('click', function () { closeConfirm(null); });

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    if (!$('confirm').hidden) closeConfirm(null);
    else if (!$('drawer').hidden) closeDrawer();
  });

  // ---------- Şikâyetler ----------

  document.querySelectorAll('#report-filter .seg').forEach(function (b) {
    b.addEventListener('click', function () {
      state.reportStatus = b.dataset.status;
      document.querySelectorAll('#report-filter .seg').forEach(function (x) { x.classList.toggle('active', x === b); });
      loadReports();
    });
  });

  function loadReports() {
    var list = $('reports-list');
    if (!list.firstChild) append(list, el('div', { className: 'card empty', text: 'Yükleniyor…' }));
    return api('GET', '/reports?status=' + encodeURIComponent(state.reportStatus)).then(function (data) {
      clear(list);
      if (!data.reports.length) {
        var msg = state.reportStatus === 'open' ? 'Bekleyen şikâyet yok' : 'Şikâyet bulunamadı';
        append(list, el('div', { className: 'card empty' },
          el('strong', { text: msg }),
          state.reportStatus === 'open' ? 'Her şey yolunda görünüyor.' : null));
        return;
      }
      data.reports.forEach(function (r) { append(list, renderReport(r)); });
    }).catch(handleError);
  }

  function renderReport(r) {
    var u = r.reported;
    var open = r.status === 'open';

    var who = u
      ? el('div', { className: 'report-who' },
          el('div', { className: 'report-name' },
            el('button', { className: 'link', type: 'button', text: nameAge(u), onclick: function () { openUser(u.id); } }),
            userBadges(u),
            u.reports_count > 1 ? el('span', { className: 'badge badge-amber', text: 'Toplam ' + u.reports_count + ' şikâyet' }) : null),
          el('div', { className: 'report-email', text: u.email }))
      : el('div', { className: 'report-who' }, el('div', { className: 'report-name', text: 'Silinmiş hesap' }));

    var reporter = r.reporter
      ? [el('span', { text: 'Şikâyet eden: ' }),
         el('button', { className: 'link', type: 'button', onclick: function () { openUser(r.reporter.id); } }, el('b', { text: r.reporter.name })),
         ' · ' + r.reporter.email]
      : 'Şikâyet eden: silinmiş hesap';

    var actions = null;
    if (open && u) {
      actions = el('div', { className: 'report-actions' },
        el('button', { className: 'btn btn-secondary btn-sm', type: 'button', text: 'Yoksay', onclick: function (e) { resolveReport(r, 'dismiss', e.currentTarget); } }),
        el('button', { className: 'btn btn-danger btn-sm', type: 'button', text: u.is_banned ? 'Kapat (zaten yasaklı)' : 'Yasakla', onclick: function (e) { resolveReport(r, u.is_banned ? 'dismiss' : 'ban', e.currentTarget); } }));
    } else if (open) {
      actions = el('div', { className: 'report-actions' },
        el('button', { className: 'btn btn-secondary btn-sm', type: 'button', text: 'Kapat', onclick: function (e) { resolveReport(r, 'dismiss', e.currentTarget); } }));
    }

    var outcome = !open
      ? el('div', { className: 'report-outcome' },
          el('span', { className: 'badge ' + (r.admin_action === 'ban' ? 'badge-red' : 'badge-green'), text: ACTIONS[r.admin_action] || 'Sonuçlandı' }),
          ' ' + fmtDate(r.resolved_at) + (r.admin_note ? ' — Not: ' + r.admin_note : ''))
      : null;

    return el('article', { className: 'card report' + (open ? '' : ' resolved') },
      el('div', { className: 'report-top' },
        u ? avatar(u.photo, u.name) : avatar(null, '?'),
        who,
        el('div', { className: 'report-date', title: fmtDate(r.created_at), text: fmtAgo(r.created_at) })),
      el('div', { className: 'report-reason' }, el('span', { className: 'reason-chip', text: REASONS[r.reason] || r.reason })),
      r.details ? el('p', { className: 'report-details', text: r.details }) : null,
      outcome,
      el('div', { className: 'report-foot' }, el('div', { className: 'report-by' }, reporter), actions));
  }

  function resolveReport(r, action, btn) {
    var name = r.reported ? r.reported.name : 'Bu kullanıcı';
    var opts = action === 'ban'
      ? { title: name + ' yasaklansın mı?', text: 'Kullanıcı uygulamaya giremez ve bu kişiyle ilgili tüm açık şikâyetler kapatılır. Yasağı daha sonra Kullanıcılar sekmesinden kaldırabilirsiniz.', okText: 'Yasakla', note: 'Sebep / not (isteğe bağlı)' }
      : { title: 'Şikâyet yoksayılsın mı?', text: 'Şikâyet kapatılır, kullanıcıya bir işlem yapılmaz.', okText: 'Yoksay', danger: false, note: 'Not (isteğe bağlı)' };
    confirmDialog(opts).then(function (res) {
      if (!res) return;
      btn.disabled = true;
      var body = { action: action };
      if (res.note) body.note = res.note;
      api('POST', '/reports/' + encodeURIComponent(r.id) + '/resolve', body).then(function () {
        toast(action === 'ban' ? 'Kullanıcı yasaklandı.' : 'Şikâyet yoksayıldı.');
        loadReports();
        loadStats();
      }).catch(function (e) { btn.disabled = false; handleError(e); });
    });
  }

  // ---------- Kullanıcılar ----------

  $('user-search').addEventListener('submit', function (e) {
    e.preventDefault();
    state.users.q = $('user-q').value.trim();
    state.users.filter = $('user-filter').value;
    state.users.page = 1;
    loadUsers();
  });
  $('user-filter').addEventListener('change', function () {
    state.users.filter = $('user-filter').value;
    state.users.q = $('user-q').value.trim();
    state.users.page = 1;
    loadUsers();
  });
  $('prev-page').addEventListener('click', function () { if (state.users.page > 1) { state.users.page--; loadUsers(); } });
  $('next-page').addEventListener('click', function () { state.users.page++; loadUsers(); });

  function loadUsers() {
    var s = state.users;
    var qs = '?page=' + s.page + '&filter=' + encodeURIComponent(s.filter) + (s.q ? '&q=' + encodeURIComponent(s.q) : '');
    return api('GET', '/users' + qs).then(function (data) {
      s.total = data.total;
      s.pageSize = data.pageSize;
      var body = $('users-body');
      clear(body);
      data.users.forEach(function (u) { append(body, renderUserRow(u)); });
      var empty = $('users-empty');
      empty.hidden = data.users.length > 0;
      clear(empty);
      append(empty, el('strong', { text: 'Kullanıcı bulunamadı' }), s.q ? 'Farklı bir arama deneyin.' : null);
      var from = data.total ? (s.page - 1) * s.pageSize + 1 : 0;
      var to = Math.min(s.page * s.pageSize, data.total);
      $('pager-info').textContent = data.total ? numFmt.format(from) + '–' + numFmt.format(to) + ' / ' + numFmt.format(data.total) + ' kullanıcı' : '';
      $('prev-page').disabled = s.page <= 1;
      $('next-page').disabled = to >= data.total;
    }).catch(handleError);
  }

  function renderUserRow(u) {
    var status = el('div', { className: 'badges' }, userBadges(u));
    if (!u.is_banned && !u.is_demo) append(status, el('span', { className: 'badge badge-green', text: 'Aktif' }));
    var tr = el('tr', { tabindex: '0' },
      el('td', null, el('div', { className: 'user-cell' },
        avatar(u.photo, u.name),
        el('div', { className: 'user-cell-text' },
          el('div', { className: 'user-cell-name', text: nameAge(u) }),
          el('div', { className: 'user-cell-email', text: u.email })))),
      el('td', null, status),
      el('td', { className: 'col-num col-hide-sm', text: String(u.photos_count) }),
      el('td', { className: 'col-num' + (u.reports_against > 0 ? ' num-alert' : ''), text: String(u.reports_against) }),
      el('td', { className: 'col-hide-sm nowrap', text: fmtShort(u.created_at) }),
      el('td', { className: 'col-hide-sm nowrap', title: fmtDate(u.last_active_at), text: fmtAgo(u.last_active_at) }));
    tr.addEventListener('click', function () { openUser(u.id); });
    tr.addEventListener('keydown', function (e) { if (e.key === 'Enter') openUser(u.id); });
    return tr;
  }

  // ---------- Kullanıcı detayı ----------

  $('drawer').addEventListener('click', function (e) {
    if (e.target.closest('[data-close]')) closeDrawer();
  });

  function closeDrawer() {
    $('drawer').hidden = true;
    state.openUserId = null;
    document.body.style.overflow = '';
  }

  function openUser(id, keepScroll) {
    state.openUserId = id;
    var drawer = $('drawer');
    var body = $('drawer-body');
    var scroll = body.scrollTop;
    if (drawer.hidden || !keepScroll) {
      clear(body);
      append(body, el('div', { className: 'card empty', text: 'Yükleniyor…' }));
      $('drawer-title').textContent = 'Kullanıcı';
    }
    drawer.hidden = false;
    document.body.style.overflow = 'hidden';
    return api('GET', '/users/' + encodeURIComponent(id)).then(function (data) {
      if (state.openUserId !== id) return;
      renderUser(data);
      if (keepScroll) body.scrollTop = scroll;
    }).catch(function (e) {
      if (e.silent) return;
      clear(body);
      append(body, el('div', { className: 'card empty' }, el('strong', { text: 'Açılamadı' }), e.message));
    });
  }

  function afterUserChange(id) {
    loadStats();
    if (state.tab === 'reports') loadReports(); else loadUsers();
    if (state.openUserId === id) openUser(id, true);
  }

  function renderUser(data) {
    var u = data.user;
    var c = data.counts;
    var body = $('drawer-body');
    $('drawer-title').textContent = u.name;
    clear(body);

    var banBtn = u.is_banned
      ? el('button', { className: 'btn btn-success', type: 'button', text: 'Yasağı kaldır', onclick: function (e) { toggleBan(u, false, e.currentTarget); } })
      : el('button', { className: 'btn btn-danger', type: 'button', text: 'Yasakla', onclick: function (e) { toggleBan(u, true, e.currentTarget); } });

    var meta = [GENDERS[u.gender] || u.gender, 'Kayıt: ' + fmtShort(u.created_at), 'Son aktif: ' + fmtAgo(u.last_active_at)].join(' · ');

    append(body, el('section', { className: 'card section' },
      el('div', { className: 'profile-head' },
        avatar(data.photos[0] && data.photos[0].url, u.name, true),
        el('div', { className: 'info' },
          el('div', { className: 'profile-name', text: nameAge(u) }),
          el('div', { className: 'profile-meta', text: u.email }),
          el('div', { className: 'profile-meta', text: meta }),
          el('div', { className: 'badges' },
            userBadges(u),
            u.email_verified === true ? el('span', { className: 'badge badge-green', text: 'E-posta doğrulandı' }) : null,
            u.email_verified === false ? el('span', { className: 'badge', text: 'E-posta doğrulanmadı' }) : null))),
      u.is_banned ? el('div', { className: 'ban-info', text: 'Yasaklandı: ' + fmtDate(u.banned_at) + (u.ban_reason ? ' — Sebep: ' + u.ban_reason : '') }) : null,
      el('div', { className: 'profile-actions' }, banBtn)));

    var countItems = [
      [c.matches, 'Eşleşme'], [c.messages_sent, 'Gönderilen mesaj'], [c.likes_received, 'Aldığı beğeni'],
      [c.swipes, 'Kaydırma'], [c.reports_made, 'Yaptığı şikâyet'], [c.blocked_by, 'Engelleyen'],
    ];
    append(body, el('section', { className: 'card section' },
      el('h3', { text: 'Etkinlik' }),
      el('div', { className: 'counts' }, countItems.map(function (it) {
        return el('div', { className: 'count' },
          el('div', { className: 'count-value', text: numFmt.format(it[0] || 0) }),
          el('div', { className: 'count-label', text: it[1] }));
      }))));

    // Fotoğraflar
    var photoSection = el('section', { className: 'card section' }, el('h3', { text: 'Fotoğraflar (' + data.photos.length + ')' }));
    if (!data.photos.length) append(photoSection, el('p', { className: 'muted', text: 'Fotoğraf yok.' }));
    else {
      append(photoSection, el('div', { className: 'photo-grid' }, data.photos.map(function (p, i) {
        var url = safeUrl(p.url);
        return el('div', { className: 'photo' },
          url ? el('a', { href: url, target: '_blank', rel: 'noopener noreferrer', title: 'Büyük göster' },
            photoImg(url, i)) : el('div', { className: 'photo-broken', text: 'Geçersiz adres' }),
          el('span', { className: 'photo-pos', text: String(i + 1) }),
          el('button', { className: 'photo-del', type: 'button', text: 'Sil', onclick: function (e) { deletePhoto(u, p, e.currentTarget); } }));
      })));
    }
    append(body, photoSection);

    // Profil bilgileri
    append(body, el('section', { className: 'card section' },
      el('h3', { text: 'Hakkında' }),
      u.bio ? el('p', { className: 'bio', text: u.bio }) : el('p', { className: 'muted', text: 'Boş bırakılmış.' }),
      u.interests && u.interests.length
        ? [el('h3', { text: 'İlgi alanları' }), el('div', { className: 'chips' }, u.interests.map(function (t) { return el('span', { className: 'chip', text: t }); }))]
        : null));

    append(body, el('section', { className: 'card section' },
      el('h3', { text: 'Bilgiler' }),
      el('dl', { className: 'kv' },
        el('dt', { text: 'Doğum tarihi' }), el('dd', { text: u.birthdate ? fmtShort(u.birthdate + 'T12:00:00') : '—' }),
        el('dt', { text: 'İlgilendiği' }), el('dd', { text: (u.interested_in || []).map(function (g) { return GENDERS[g] || g; }).join(', ') || '—' }),
        el('dt', { text: 'Yaş aralığı' }), el('dd', { text: u.min_age + '–' + u.max_age }),
        el('dt', { text: 'Mesafe' }), el('dd', { text: u.max_distance_km + ' km' }),
        el('dt', { text: 'Konum' }), el('dd', { text: u.has_location ? 'Paylaşılmış' : 'Yok' }),
        el('dt', { text: 'Kimlik' }), el('dd', { className: 'small muted', text: u.id }))));

    // Şikâyetler
    var reportSection = el('section', { className: 'card section' }, el('h3', { text: 'Hakkındaki şikâyetler (' + data.reports.length + ')' }));
    if (!data.reports.length) append(reportSection, el('p', { className: 'muted', text: 'Şikâyet yok.' }));
    data.reports.forEach(function (r) {
      append(reportSection, el('div', { className: 'mini-report' },
        el('div', { className: 'mini-report-head' },
          el('span', { className: 'reason-chip', text: REASONS[r.reason] || r.reason }),
          r.status === 'open'
            ? el('span', { className: 'badge badge-amber', text: 'Açık' })
            : el('span', { className: 'badge ' + (r.admin_action === 'ban' ? 'badge-red' : 'badge-green'), text: ACTIONS[r.admin_action] || 'Sonuçlandı' }),
          el('span', { className: 'muted', text: fmtDate(r.created_at) })),
        r.details ? el('p', { className: 'report-details', text: r.details }) : null,
        el('div', { className: 'report-by', text: 'Şikâyet eden: ' + (r.reporter ? r.reporter.name + ' · ' + r.reporter.email : 'silinmiş hesap') }),
        r.admin_note ? el('div', { className: 'report-outcome', text: 'Not: ' + r.admin_note }) : null));
    });
    append(body, reportSection);
  }

  function photoImg(url, i) {
    var img = el('img', { alt: 'Fotoğraf ' + (i + 1), loading: 'lazy', referrerpolicy: 'no-referrer' });
    img.addEventListener('error', function () {
      img.replaceWith(el('div', { className: 'photo-broken', text: 'Fotoğraf yüklenemedi' }));
    });
    img.src = url;
    return img;
  }

  function toggleBan(u, ban, btn) {
    var opts = ban
      ? { title: u.name + ' yasaklansın mı?', text: 'Kullanıcı hemen çıkış yaptırılır ve tekrar giriş yapamaz. Açık şikâyetleri kapatılır.', okText: 'Yasakla', note: 'Sebep (isteğe bağlı)' }
      : { title: u.name + ' için yasak kaldırılsın mı?', text: 'Kullanıcı uygulamayı yeniden kullanabilir.', okText: 'Yasağı kaldır', danger: false };
    confirmDialog(opts).then(function (res) {
      if (!res) return;
      btn.disabled = true;
      var body = ban && res.note ? { reason: res.note } : {};
      api('POST', '/users/' + encodeURIComponent(u.id) + (ban ? '/ban' : '/unban'), body).then(function () {
        toast(ban ? 'Kullanıcı yasaklandı.' : 'Yasak kaldırıldı.');
        afterUserChange(u.id);
      }).catch(function (e) { btn.disabled = false; handleError(e); });
    });
  }

  function deletePhoto(u, p, btn) {
    confirmDialog({ title: 'Fotoğraf silinsin mi?', text: 'Bu işlem geri alınamaz.', okText: 'Sil' }).then(function (res) {
      if (!res) return;
      btn.disabled = true;
      api('DELETE', '/photos/' + encodeURIComponent(p.id)).then(function () {
        toast('Fotoğraf silindi.');
        afterUserChange(u.id);
      }).catch(function (e) { btn.disabled = false; handleError(e); });
    });
  }

  renderStats(null);
  boot();
})();
