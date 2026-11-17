const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const landing = $('main');
const footer = $('.site-footer');
const dashboard = $('#dashboardView');
const scanView = $('#scanView');
let toastTimer;
let authSession = null;
let accountName = 'there';
const supabaseConfig = window.HELPUS_SUPABASE || {};
const authClient = window.supabase?.createClient && supabaseConfig.url && supabaseConfig.anonKey
  ? window.supabase.createClient(supabaseConfig.url, supabaseConfig.anonKey)
  : null;

function showView(name) {
  if (name === 'dashboard' && !authSession) { openPhoneLogin(); return; }
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

const phoneLoginBackdrop = document.createElement('div');
phoneLoginBackdrop.className = 'modal-backdrop';
phoneLoginBackdrop.id = 'phoneLoginBackdrop';
phoneLoginBackdrop.hidden = true;
phoneLoginBackdrop.innerHTML = '<div class="modal phone-login-modal" role="dialog" aria-modal="true" aria-labelledby="phoneLoginTitle"><button class="modal-close" id="phoneLoginClose" aria-label="Close">×</button><span class="step-icon icon-shield">♡</span><div class="eyebrow">SECURE PHONE SIGN IN</div><h2 id="phoneLoginTitle">Welcome to HelpUs.</h2><p>Sign in or register with your mobile number. We’ll text you a one-time code.</p><div class="auth-form"><label>Your name <span>(for new accounts)</span><input id="authDisplayName" autocomplete="name" placeholder="Your name" /></label><label>Mobile number<input id="authPhone" type="tel" autocomplete="tel" inputmode="tel" value="+91 " placeholder="+91 98765 43210" /></label><div class="auth-status" id="authStatus" role="status"></div><button class="button button-primary auth-action" id="authSendOtp" type="button">Send one-time code <span>↗</span></button><div class="otp-step" id="otpStep" hidden><label>6-digit code<input id="authOtp" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="000000" /></label><button class="button button-primary auth-action" id="authVerifyOtp" type="button">Verify &amp; continue <span>↗</span></button><button class="text-link resend-otp" id="authResendOtp" type="button">Send a new code</button></div></div><small class="auth-footnote">By continuing, you agree to use your number for account verification and HelpUs alerts.</small></div>';
document.body.append(phoneLoginBackdrop);

function openPhoneLogin() {
  phoneLoginBackdrop.hidden = false;
  $('.phone-login-modal .eyebrow').textContent = authClient ? 'SECURE PHONE SIGN IN' : 'FREE OTP DEMO';
  $('.phone-login-modal>p').textContent = authClient
    ? 'Sign in or register with your mobile number. We’ll text you a one-time code.'
    : 'Try the phone login screen for free. A demo code appears here; no SMS is sent and no phone ownership is verified.';
  $('#authStatus').textContent = authClient
    ? 'Your number stays private. SMS delivery depends on the configured provider.'
    : 'Free demo mode: a code will be generated here. No SMS is sent and the number is not verified.';
  $('#authStatus').classList.toggle('demo-mode', !authClient);
  $('.auth-footnote').textContent = authClient
    ? 'By continuing, you agree to use your number for account verification and HelpUs alerts.'
    : 'Demo only: do not use this flow to protect real accounts or personal vehicle data.';
  $('#authSendOtp').disabled = false;
  $('#authDisplayName').focus();
}

function closePhoneLogin() { phoneLoginBackdrop.hidden = true; }

function normalizePhone(raw) {
  const value = raw.replace(/[\s()-]/g, '');
  if (/^\d{10}$/.test(value)) return `+91${value}`;
  return /^\+[1-9]\d{7,14}$/.test(value) ? value : '';
}

function showAuthStatus(message, isError = false) {
  const status = $('#authStatus');
  status.textContent = message;
  status.classList.toggle('error', isError);
}

$('#phoneLoginClose').addEventListener('click', closePhoneLogin);
phoneLoginBackdrop.addEventListener('click', event => { if (event.target === phoneLoginBackdrop) closePhoneLogin(); });

$('#authSendOtp').addEventListener('click', async () => {
  const phone = normalizePhone($('#authPhone').value);
  if (!phone) { showAuthStatus('Enter a valid number with country code, such as +91 98765 43210.', true); return; }
  const button = $('#authSendOtp');
  button.disabled = true;
  showAuthStatus('Sending your verification code…');
  try {
    if (!authClient) {
      window.helpUsPendingPhone = phone;
      window.helpUsDemoOtp = String(Math.floor(100000 + Math.random() * 900000));
      $('#otpStep').hidden = false;
      $('#authOtp').focus();
      showAuthStatus(`DEMO CODE: ${window.helpUsDemoOtp}. No SMS was sent; this only opens a sample account.`);
      return;
    }
    const displayName = $('#authDisplayName').value.trim();
    const { error } = await authClient.auth.signInWithOtp({ phone, options: { shouldCreateUser: true, data: { display_name: displayName } } });
    if (error) throw error;
    window.helpUsPendingPhone = phone;
    $('#otpStep').hidden = false;
    $('#authOtp').focus();
    showAuthStatus(`Code sent to ${phone}. It may take a minute to arrive.`);
  } catch (error) { showAuthStatus(error.message || 'Could not send the code. Check your number and try again.', true); }
  finally { button.disabled = false; }
});

$('#authVerifyOtp').addEventListener('click', async () => {
  const phone = window.helpUsPendingPhone;
  const token = $('#authOtp').value.replace(/\D/g, '');
  if (!phone || token.length < 6) { showAuthStatus('Enter the 6-digit code sent to your phone.', true); return; }
  if (!authClient) {
    if (token !== window.helpUsDemoOtp) { showAuthStatus('That demo code is incorrect. Use the code shown above.', true); return; }
    authSession = { demo: true, user: { id: 'local-demo', phone, user_metadata: { display_name: $('#authDisplayName').value.trim() || 'Demo driver' } } };
    accountName = authSession.user.user_metadata.display_name.split(' ')[0];
    $$('.user-mini b').forEach(node => node.textContent = authSession.user.user_metadata.display_name);
    $$('.user-mini small').forEach(node => node.textContent = `${phone} · demo only`);
    closePhoneLogin();
    showToast('Demo sign-in complete. The phone number was not verified.');
    showView('dashboard');
    return;
  }
  $('#authVerifyOtp').disabled = true;
  showAuthStatus('Checking your code…');
  try {
    const { data, error } = await authClient.auth.verifyOtp({ phone, token, type: 'sms' });
    if (error) throw error;
    authSession = data.session;
    closePhoneLogin();
    await loadAccountData();
    showView('dashboard');
  } catch (error) { showAuthStatus(error.message || 'That code did not work. Request a new one and try again.', true); }
  finally { $('#authVerifyOtp').disabled = false; }
});

$('#authResendOtp').addEventListener('click', () => { $('#otpStep').hidden = true; $('#authSendOtp').click(); });

async function loadAccountData() {
  if (!authClient || !authSession?.user) return;
  const user = authSession.user;
  const { data: profile } = await authClient.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
  const displayName = profile?.display_name || user.user_metadata?.display_name || user.phone || 'HelpUs member';
  accountName = displayName.split(' ')[0];
  $$('.user-mini b').forEach(node => node.textContent = displayName);
  $$('.user-mini small').forEach(node => node.textContent = user.phone || 'Phone account');
  const firstName = displayName.split(' ')[0];
  $('#dashboardTitle').textContent = `A little peace of mind, ${firstName}.`;
  const { data: vehicles, error } = await authClient.from('vehicles').select('id,tag_code,make_model,registration_number,model_year,color,is_active,created_at').order('created_at', { ascending: false });
  if (error) { showToast('Could not load vehicles. Please refresh and sign in again.'); return; }
  const list = $('.vehicle-list');
  list.replaceChildren();
  for (const vehicle of vehicles || []) {
    const card = document.createElement('div'); card.className = 'vehicle-list-card';
    const icon = document.createElement('div'); icon.className = 'list-car-icon'; icon.textContent = '↗';
    const details = document.createElement('div');
    const title = document.createElement('h3'); title.textContent = vehicle.make_model;
    const sub = document.createElement('p'); sub.textContent = [vehicle.model_year, vehicle.color, vehicle.registration_number].filter(Boolean).join(' · ');
    const status = document.createElement('span'); status.className = 'active-pill'; status.textContent = `${vehicle.is_active ? '● Tag active' : '○ Paused'} · ${vehicle.tag_code}`;
    details.append(title, sub, status); card.append(icon, details); list.append(card);
  }
  const first = vehicles?.[0];
  $('.vehicle-info h3').textContent = first?.make_model || 'No vehicle registered yet';
  $('.vehicle-info span').textContent = first ? `${first.model_year || ''}${first.model_year ? ' · ' : ''}${first.color || ''} · ${first.registration_number}` : 'Scan a HelpUs QR tag to add your first vehicle.';
  $('.vehicle-status').innerHTML = `<i></i> ${first ? (first.is_active ? 'Tag active' : 'Tag paused') : 'No tag linked'}`;
}

if (authClient) {
  authClient.auth.getSession().then(({ data }) => {
    authSession = data.session;
    if (authSession) loadAccountData();
  });
  authClient.auth.onAuthStateChange((_event, session) => {
    authSession = session;
    if (!session && !dashboard.hidden) showView('home');
  });
}

$('#signOutButton')?.addEventListener('click', async () => {
    if (authClient) await authClient.auth.signOut();
    authSession = null;
    window.helpUsDemoOtp = null;
    showView('home');
});

function setTab(tab) {
  $$('.tab-panel').forEach(panel => panel.hidden = panel.id !== `${tab}Panel`);
  $$('[data-tab]').forEach(button => button.classList.toggle('active', button.dataset.tab === tab));
  const titles = {
    overview: [`A little peace of mind, ${accountName}.`, "Here's what's happening with your vehicles."],
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
vehicleForm.addEventListener('submit', async event => {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const tagId = String(form.get('tagId') || '');
  if (!tagId) { showToast('Scan a valid HelpUs QR tag before registering.'); return; }
  if (!authSession?.user) { showToast('Sign in before registering a vehicle.'); openPhoneLogin(); return; }
  const name = String(form.get('vehicle')).trim();
  const registration = String(form.get('registration')).trim().toUpperCase();
  const year = String(form.get('year')).trim();
  const submitButton = $('.modal-submit', vehicleForm);
  submitButton.disabled = true;
  if (!authClient) {
    const card = document.createElement('div'); card.className = 'vehicle-list-card';
    const icon = document.createElement('div'); icon.className = 'list-car-icon'; icon.textContent = '↗';
    const details = document.createElement('div');
    const title = document.createElement('h3'); title.textContent = name;
    const subtitle = document.createElement('p'); subtitle.textContent = [year, registration].filter(Boolean).join(' · ');
    const status = document.createElement('span'); status.className = 'active-pill'; status.textContent = `● Demo tag · ${tagId}`;
    details.append(title, subtitle, status); card.append(icon, details); $('.vehicle-list').prepend(card);
    $('.vehicle-info h3').textContent = name;
    $('.vehicle-info span').textContent = [year, registration].filter(Boolean).join(' · ');
    stopWebCamera(); vehicleModal.hidden = true; event.currentTarget.reset();
    showToast('Added to this demo session only. It is not saved to a server.');
    setTab('vehicles');
    return;
  }
  try {
    const { error } = await authClient.rpc('register_vehicle', { p_tag_code: tagId, p_make_model: name, p_registration_number: registration, p_vehicle_type: 'car', p_model_year: year ? Number(year) : null, p_color: '' });
    if (error) throw error;
  } catch (error) {
    showToast(error.message || 'Could not register this tag. Check the tag and try again.');
    submitButton.disabled = false;
    return;
  }
  stopWebCamera();
  vehicleModal.hidden = true;
  event.currentTarget.reset();
  await loadAccountData();
  showToast(`${name} registered to your HelpUs account`);
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
