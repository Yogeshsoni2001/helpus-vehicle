const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const landing = $('main');
const footer = $('.site-footer');
const dashboard = $('#dashboardView');
const scanView = $('#scanView');
let toastTimer;

function showView(name) {
  const isHome = name === 'home';
  landing.hidden = !isHome;
  footer.hidden = !isHome;
  dashboard.hidden = name !== 'dashboard';
  scanView.hidden = name !== 'scan';
  document.body.classList.toggle('in-app', !isHome);
  if (isHome) window.scrollTo({ top: 0, behavior: 'smooth' });
  else window.scrollTo({ top: 0, behavior: 'instant' });
  if (name === 'dashboard') setTab('overview');
}

function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 3000);
}

function setTab(tab) {
  $$('.tab-panel').forEach(panel => panel.hidden = panel.id !== `${tab}Panel`);
  $$('[data-tab]').forEach(button => button.classList.toggle('active', button.dataset.tab === tab));
  const titles = {
    overview: ['A little peace of mind, Alex.', "Here's what's happening with your vehicles."],
    vehicles: ['Your garage, at a glance.', 'Manage the vehicles connected to your tags.'],
    alerts: ['You’re in the loop.', 'Helpful updates from people who scanned your vehicle.'],
    settings: ['Your choices, your call.', 'Manage privacy and contact preferences.'],
  };
  $('#dashboardTitle').textContent = titles[tab][0];
  $('#dashboardSubtitle').textContent = titles[tab][1];
}

$$('[data-view]').forEach(button => button.addEventListener('click', () => showView(button.dataset.view)));
$$('[data-scroll]').forEach(button => button.addEventListener('click', () => {
  showView('home');
  setTimeout(() => document.getElementById(button.dataset.scroll)?.scrollIntoView({ behavior: 'smooth' }), 30);
}));
$$('[data-tab]').forEach(button => button.addEventListener('click', () => setTab(button.dataset.tab)));

const menuToggle = $('#menuToggle');
menuToggle.addEventListener('click', () => {
  const open = $('.main-nav').classList.toggle('open');
  menuToggle.setAttribute('aria-expanded', String(open));
});
$$('.main-nav a').forEach(link => link.addEventListener('click', () => $('.main-nav').classList.remove('open')));

$('#languageToggle').addEventListener('click', event => {
  const hindi = document.documentElement.lang !== 'hi';
  document.documentElement.lang = hindi ? 'hi' : 'en';
  event.currentTarget.textContent = hindi ? 'English' : 'हिंदी';
  $('.hero h1').innerHTML = hindi ? 'आपकी गाड़ी,<br /><em>हमेशा संपर्क में।</em>' : 'Your vehicle,<br /><em>always reachable.</em>';
  $('.hero-lede').textContent = hindi
    ? 'एक आसान QR टैग से लोग आपका नंबर देखे बिना आपकी पार्क की हुई गाड़ी के बारे में आपसे संपर्क कर सकते हैं।'
    : 'A simple QR tag helps people contact you about your parked vehicle—without sharing your phone number.';
  $('.hero-actions .button').innerHTML = hindi ? 'अपना HelpUs टैग लें <span>↗</span>' : 'Get your HelpUs tag <span>↗</span>';
  $('.main-nav a:nth-child(1)').textContent = hindi ? 'कैसे काम करता है' : 'How it works';
  $('.main-nav a:nth-child(2)').textContent = hindi ? 'ऐप के फीचर' : 'App features';
  $('.main-nav a:nth-child(3)').textContent = hindi ? 'गोपनीयता' : 'Privacy';
  $('.main-nav a:nth-child(4)').textContent = hindi ? 'कीमत' : 'Pricing';
  showToast(hindi ? 'भाषा हिंदी में बदल गई' : 'Language switched to English');
});

const vehicleModal = $('#vehicleModal');
const vehicleForm = $('#vehicleForm');
const scannerPanel = document.createElement('div');
scannerPanel.className = 'enroll-scanner';
scannerPanel.innerHTML = '<div class="enroll-scanner-heading"><span class="step-icon icon-tag">⌑</span><div><b>Scan a HelpUs QR tag first</b><small>Vehicle registration unlocks after a valid tag is scanned.</small></div></div><video class="tag-camera" id="tagCamera" playsinline muted hidden></video><div class="tag-scan-status" id="tagScanStatus">Scan a HelpUs-formatted tag to continue.</div><button class="button button-outline start-tag-scan" id="startTagScan" type="button">▦ &nbsp; Open camera &amp; scan tag</button>';
vehicleForm.before(scannerPanel);
vehicleForm.hidden = true;
const tagInput = document.createElement('input');
tagInput.type = 'hidden'; tagInput.name = 'tagId'; vehicleForm.append(tagInput);
const scanVideo = $('#tagCamera', scannerPanel);
const scanStatus = $('#tagScanStatus', scannerPanel);
let cameraStream = null;
let scannerRunning = false;

function stopWebCamera() {
  scannerRunning = false;
  if (cameraStream) cameraStream.getTracks().forEach(track => track.stop());
  cameraStream = null;
  scanVideo.srcObject = null;
  scanVideo.hidden = true;
}

function enrollModal() {
  stopWebCamera();
  vehicleForm.hidden = true;
  scannerPanel.hidden = false;
  scanStatus.textContent = 'Scan a HelpUs-formatted tag to continue.';
  $('#startTagScan').hidden = false;
  tagInput.value = '';
  vehicleForm.reset();
  vehicleModal.hidden = false;
}

function normalizeTag(raw) {
  const match = String(raw || '').trim().match(/^(?:HELPUS:|helpus:\/\/tag\/|https?:\/\/(?:www\.)?helpus\.[^/]+\/tag\/)([A-Za-z0-9_-]{4,64})\/?$/i);
  return match ? match[1].toUpperCase() : '';
}

async function startTagScan() {
  if (!('BarcodeDetector' in window) || !navigator.mediaDevices?.getUserMedia) {
    scanStatus.textContent = 'QR camera scanning needs a supported browser on HTTPS. Use the HelpUs Android app scanner on this device.';
    return;
  }
  try {
    const detector = new BarcodeDetector({ formats: ['qr_code'] });
    cameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
    scanVideo.srcObject = cameraStream;
    scanVideo.hidden = false;
    await scanVideo.play();
    scannerRunning = true;
    $('#startTagScan').hidden = true;
    scanStatus.textContent = 'Camera on. Hold the HelpUs QR code inside the frame.';
    const detect = async () => {
      if (!scannerRunning) return;
      try {
        const codes = await detector.detect(scanVideo);
        const raw = codes.map(code => code.rawValue).find(value => normalizeTag(value));
        if (raw) {
          const tagId = normalizeTag(raw);
          stopWebCamera();
          tagInput.value = tagId;
          scannerPanel.hidden = true;
          vehicleForm.hidden = false;
          scanStatus.textContent = `Tag ${tagId} verified. Add vehicle details to finish registration.`;
          showToast('HelpUs tag scanned. Vehicle registration unlocked.');
          return;
        }
        if (codes.length) scanStatus.textContent = 'This QR code is not a HelpUs vehicle tag. Keep scanning.';
      } catch (_) { /* Continue with the next camera frame. */ }
      if (scannerRunning) requestAnimationFrame(detect);
    };
    requestAnimationFrame(detect);
  } catch (error) {
    scanStatus.textContent = error.name === 'NotAllowedError' ? 'Camera permission is needed to scan your HelpUs QR tag.' : 'Could not open the camera. Check browser permissions and try again.';
  }
}

$('#startTagScan').addEventListener('click', startTagScan);
['#addVehicleButton', '#addVehicleButton2', '#addVehicleButton3'].forEach(selector => $(selector).addEventListener('click', enrollModal));
$('#modalClose').addEventListener('click', () => { stopWebCamera(); vehicleModal.hidden = true; });
vehicleModal.addEventListener('click', event => { if (event.target === vehicleModal) { stopWebCamera(); vehicleModal.hidden = true; } });
vehicleForm.addEventListener('submit', event => {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const tagId = String(form.get('tagId') || '');
  if (!tagId) { showToast('Scan a valid HelpUs QR tag before registering.'); return; }
  const name = String(form.get('vehicle')).trim();
  const registration = String(form.get('registration')).trim().toUpperCase();
  const year = String(form.get('year')).trim();
  const card = document.createElement('div');
  card.className = 'vehicle-list-card';
  const icon = document.createElement('div'); icon.className = 'list-car-icon'; icon.textContent = '↗';
  const details = document.createElement('div');
  const title = document.createElement('h3'); title.textContent = name;
  const sub = document.createElement('p'); sub.textContent = [year, registration].filter(Boolean).join(' · ');
  const status = document.createElement('span'); status.className = 'active-pill'; status.textContent = `● Tag active · ${tagId}`;
  details.append(title, sub, status);
  const edit = document.createElement('button'); edit.className = 'button button-outline small-button'; edit.textContent = 'Edit details'; edit.addEventListener('click', () => showToast('Vehicle editing is a demo action.'));
  card.append(icon, details, edit);
  $('.vehicle-list').prepend(card);
  stopWebCamera();
  vehicleModal.hidden = true;
  event.currentTarget.reset();
  showToast(`${name} added to your demo garage`);
  setTab('vehicles');
});

$$('.interactive-switch').forEach(button => button.addEventListener('click', () => {
  button.classList.toggle('on');
  showToast(button.classList.contains('on') ? 'Preference turned on' : 'Preference turned off');
}));

$('#orderButton').addEventListener('click', () => showToast('Demo checkout: no order or payment was created.'));
$('#shareButton').addEventListener('click', async () => {
  const shareData = { title: 'HelpUs', text: 'A little help goes a long way. Take a look at HelpUs.', url: window.location.href };
  try {
    if (navigator.share) await navigator.share(shareData);
    else if (navigator.clipboard) { await navigator.clipboard.writeText(shareData.url); showToast('Demo link copied to clipboard'); }
    else showToast('Share HelpUs with someone you know.');
  } catch (error) { if (error.name !== 'AbortError') showToast('Share HelpUs with someone you know.'); }
});
$('#helpButton').addEventListener('click', () => showToast('Help centre is not connected in this demo.'));
$('#notificationsButton').addEventListener('click', () => { setTab('alerts'); showView('dashboard'); setTab('alerts'); });
$('.manage-edit').addEventListener('click', () => showToast('Vehicle editing is a demo action.'));
$('#markReadButton').addEventListener('click', () => { $$('.unread-dot').forEach(dot => dot.remove()); $$('.alerts-full article').forEach(item => item.classList.add('read-item')); showToast('All scan alerts marked as read'); });

const alertModal = $('#alertModal');
$('#scanAlertButton').addEventListener('click', () => alertModal.hidden = false);
$$('[data-close-alert]').forEach(button => button.addEventListener('click', () => alertModal.hidden = true));
alertModal.addEventListener('click', event => { if (event.target === alertModal) alertModal.hidden = true; });
$$('.alert-choices button').forEach(button => button.addEventListener('click', () => {
  $('#alertFormNote').textContent = `“${button.dataset.message}” · Demo alert not sent`;
  showToast('Thanks for looking out. Demo alert not sent.');
  setTimeout(() => { alertModal.hidden = true; $('#alertFormNote').textContent = "Your name and number won't appear on the owner's page."; }, 1100);
}));
$('#scanCallButton').addEventListener('click', () => showToast('Demo only: masked calling needs a telephony provider.'));

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') { stopWebCamera(); vehicleModal.hidden = true; alertModal.hidden = true; $('.main-nav').classList.remove('open'); }
});
