const camera = document.querySelector('#camera');
const cameraPlaceholder = document.querySelector('#cameraPlaceholder');
const cameraCaption = document.querySelector('#cameraCaption');
const startCameraButton = document.querySelector('#startCamera');
const imagePicker = document.querySelector('#qrImage');
const canvas = document.querySelector('#scanCanvas');
const context = canvas.getContext('2d', { willReadFrequently: true });
const scanResult = document.querySelector('#scanResult');
const resultIcon = document.querySelector('#resultIcon');
const resultTitle = document.querySelector('#resultTitle');
const resultValue = document.querySelector('#resultValue');
const resultNote = document.querySelector('#resultNote');
const continueLink = document.querySelector('#continueRegistration');
const demoQr = document.querySelector('#demoQr');
const demoCanvas = document.querySelector('#demoCanvas');
const downloadDemoButton = document.querySelector('#downloadDemoTag');
let stream = null;
let scanning = false;
let demoTagReady = false;

function parseHelpUsTag(raw) {
  const match = String(raw || '').trim().match(/^(?:HELPUS:|helpus:\/\/tag\/|https?:\/\/(?:www\.)?helpus\.[^/]+\/tag\/)([A-Za-z0-9_-]{4,64})\/?$/i);
  return match ? match[1].toUpperCase() : '';
}

function stopCamera() {
  scanning = false;
  if (stream) stream.getTracks().forEach(track => track.stop());
  stream = null;
  camera.srcObject = null;
  camera.hidden = true;
  cameraPlaceholder.hidden = false;
  startCameraButton.textContent = '▦  Start camera';
}

function showResult(raw) {
  stopCamera();
  const text = String(raw || '').trim();
  const tagId = parseHelpUsTag(text);
  scanResult.hidden = false;
  scanResult.classList.toggle('invalid', !tagId);
  resultIcon.textContent = tagId ? '✓' : '!';
  resultTitle.textContent = tagId ? 'HelpUs tag recognised' : 'QR code found, but it is not a HelpUs tag';
  resultValue.textContent = text.length > 220 ? `${text.slice(0, 220)}…` : text;
  resultNote.textContent = tagId ? `Tag code: ${tagId}. Continue to register the vehicle.` : 'Registration needs a QR payload in HELPUS:TAGCODE format.';
  continueLink.hidden = !tagId;
  if (tagId) {
    continueLink.href = `index.html?register=1`;
    continueLink.dataset.tagId = tagId;
  }
  cameraCaption.textContent = tagId ? 'HelpUs QR tag scanned successfully' : 'QR code scanned';
}

function decodeCanvas() {
  if (!window.jsQR || !canvas.width || !canvas.height) return null;
  const image = context.getImageData(0, 0, canvas.width, canvas.height);
  return window.jsQR(image.data, image.width, image.height, { inversionAttempts: 'attemptBoth' })?.data || null;
}

async function startCamera() {
  if (scanning) { stopCamera(); cameraCaption.textContent = 'Camera stopped'; return; }
  if (!navigator.mediaDevices?.getUserMedia) {
    cameraCaption.textContent = 'Camera needs HTTPS. Use Scan QR photo or open the HelpUs APK.';
    return;
  }
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
    camera.srcObject = stream;
    camera.hidden = false;
    cameraPlaceholder.hidden = true;
    await camera.play();
    scanning = true;
    startCameraButton.textContent = '×  Stop camera';
    cameraCaption.textContent = 'Camera on · hold a QR code inside the frame';
    const detector = !window.jsQR && 'BarcodeDetector' in window ? new BarcodeDetector({ formats: ['qr_code'] }) : null;
    const tick = async () => {
      if (!scanning) return;
      if (camera.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
        const width = Math.min(camera.videoWidth, 900);
        const height = Math.round(camera.videoHeight * width / camera.videoWidth);
        canvas.width = width;
        canvas.height = height;
        context.drawImage(camera, 0, 0, width, height);
        try {
          const found = decodeCanvas();
          if (found) { showResult(found); return; }
          if (detector) {
            const codes = await detector.detect(camera);
            if (codes.length) { showResult(codes[0].rawValue); return; }
          }
        } catch (_) { /* Wait for a clearer frame and try again. */ }
      }
      if (scanning) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  } catch (error) {
    cameraCaption.textContent = error.name === 'NotAllowedError'
      ? 'Allow camera access in your browser settings, then try again.'
      : 'Could not open the camera. Try Scan QR photo instead.';
  }
}

function drawImageToCanvas(image) {
  const scale = Math.min(1, 1400 / Math.max(image.naturalWidth, image.naturalHeight));
  canvas.width = Math.round(image.naturalWidth * scale);
  canvas.height = Math.round(image.naturalHeight * scale);
  context.drawImage(image, 0, 0, canvas.width, canvas.height);
}

async function scanImage(file) {
  if (!file) return;
  stopCamera();
  scanResult.hidden = true;
  continueLink.hidden = true;
  cameraCaption.textContent = 'Reading the QR image…';
  const image = new Image();
  image.onload = async () => {
    drawImageToCanvas(image);
    let value = decodeCanvas();
    if (!value && 'BarcodeDetector' in window) {
      try { const codes = await new BarcodeDetector({ formats: ['qr_code'] }).detect(image); value = codes[0]?.rawValue || null; } catch (_) { /* The QR decoder below provides the browser fallback. */ }
    }
    if (value) showResult(value);
    else cameraCaption.textContent = window.jsQR ? 'No readable QR found. Choose a sharper, well-lit photo.' : 'QR reader is still loading. Check your connection and try again.';
    image.src = '';
  };
  image.onerror = () => { cameraCaption.textContent = 'Could not read that image. Choose a JPG or PNG QR photo.'; };
  image.src = URL.createObjectURL(file);
}

function makeDemoQr() {
  if (demoTagReady || typeof QRCode !== 'function') return;
  new QRCode(demoQr, { text: 'HELPUS:DEMO2026', width: 96, height: 96, colorDark: '#203a29', colorLight: '#ffffff', correctLevel: QRCode.CorrectLevel.M });
  demoTagReady = true;
  downloadDemoButton.disabled = false;
}

startCameraButton.addEventListener('click', startCamera);
imagePicker.addEventListener('change', event => { scanImage(event.currentTarget.files[0]); event.currentTarget.value = ''; });
continueLink.addEventListener('click', event => {
  const tagId = event.currentTarget.dataset.tagId;
  if (!tagId) { event.preventDefault(); return; }
  localStorage.setItem('helpus.pendingTagId', tagId);
});
downloadDemoButton.addEventListener('click', () => {
  makeDemoQr();
  const qrCanvas = demoQr.querySelector('canvas');
  const qrImage = demoQr.querySelector('img');
  let dataUrl = qrCanvas?.toDataURL('image/png');
  if (!dataUrl && qrImage?.src.startsWith('data:')) dataUrl = qrImage.src;
  if (!dataUrl) return;
  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = 'HelpUs-Demo-QR.png';
  link.click();
});

window.addEventListener('beforeunload', stopCamera);
setTimeout(makeDemoQr, 250);
