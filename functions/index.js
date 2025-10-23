const {onRequest} = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const Razorpay = require("razorpay");
const Busboy = require("busboy");
const sharp = require("sharp");
const axios = require("axios");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

// Verify Firebase ID token middleware
const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) return res.status(401).send('Unauthorized');
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded;
    return next();
  } catch (e) {
    return res.status(403).send('Unauthorized');
  }
};

// Razorpay: initialize lazily inside handlers to avoid failures during CLI analysis

// Secrets
const GEMINI_API_KEY_SECRET = defineSecret("GEMINI_API_KEY");
const RAZORPAY_KEY_ID_SECRET = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET_SECRET = defineSecret("RAZORPAY_KEY_SECRET");
const PIAPI_API_KEY_SECRET = defineSecret("PIAPI_API_KEY");

// Lazy Gemini client factory
const getGenAI = () => {
  const apiKey = GEMINI_API_KEY_SECRET.value() || process.env.GEMINI_API_KEY;
  if (!apiKey) return null;
  return new GoogleGenerativeAI(apiKey);
};

// Helper to parse multipart/form-data using Busboy
function parseMultipart(req) {
  return new Promise((resolve, reject) => {
    try {
      const bb = Busboy({ headers: req.headers });
      const fields = {};
      const files = [];

      bb.on("field", (name, val) => {
        fields[name] = val;
      });

      bb.on("file", (name, file, info) => {
        const chunks = [];
        file.on("data", (data) => chunks.push(data));
        file.on("limit", () => {
          // Optional: handle file size limits
        });
        file.on("end", () => {
          files.push({
            fieldname: name,
            originalname: info.filename,
            encoding: info.encoding,
            mimetype: info.mimeType,
            buffer: Buffer.concat(chunks),
          });
        });
      });

      bb.on("error", (err) => reject(err));
      bb.on("finish", () => resolve({ fields, files }));

      req.pipe(bb);
    } catch (err) {
      reject(err);
    }
  });
}

app.get("/", (req, res) => {
  res.json({ status: "Server is running" });
});

app.post("/create_order", async (req, res) => {
  try {
    const { amount, currency = "INR", receipt } = req.body;

    if (!amount || !receipt) {
      return res.status(400).json({
        error: "Missing required fields: amount and receipt are required",
      });
    }

    const rp = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID,
      key_secret: process.env.RAZORPAY_KEY_SECRET,
    });

    const options = {
      amount: Math.round(amount * 100), // Convert to paise
      currency: currency,
      receipt: receipt,
      payment_capture: 1, // Auto capture payment
    };

    const order = await rp.orders.create(options);

    res.json({
      id: order.id,
      amount: order.amount,
      currency: order.currency,
    });
  } catch (error) {
    console.error("Error creating order:", error);
    res.status(500).json({
      error: "Failed to create order",
      details: error.error?.description || error.message,
    });
  }
});

// Payment verification (Razorpay signature check)
app.post("/payment-verification", async (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
  const key_secret = process.env.RAZORPAY_KEY_SECRET;

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ status: "error", message: "Missing required fields." });
  }

  const crypto = require("crypto");
  const body = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expectedSignature = crypto
    .createHmac("sha256", key_secret)
    .update(body)
    .digest("hex");

  if (expectedSignature === razorpay_signature) {
    return res.status(200).json({ status: "success", message: "Payment verified." });
  }
  return res.status(400).json({ status: "error", message: "Invalid signature. Payment verification failed." });
});

// Checkout page (Razorpay Checkout.js)
app.get("/checkout/:order_id", (req, res) => {
  const { order_id } = req.params;
  const key_id = process.env.RAZORPAY_KEY_ID;
  if (!order_id) return res.status(400).send("Order ID is required");

  const html = `<!DOCTYPE html>
  <html><head><meta name="viewport" content="width=device-width, initial-scale=1"/><title>Complete Payment</title></head>
  <body>
  <p>Loading payment gateway...</p>
  <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
  <script>
    var options = {
      key: "${key_id}",
      order_id: "${order_id}",
      name: "Lustra AI",
      description: "Coin Purchase",
      handler: function (response){
        document.body.innerHTML = '<h2>Payment Successful! Verifying...</h2>';
        fetch('/payment-verification', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_order_id: response.razorpay_order_id,
          razorpay_signature: response.razorpay_signature,
        })}).then(r=>r.json()).then(data=>{
          if(data.status==='success'){
            if (window.PaymentHandler && window.PaymentHandler.postMessage) { window.PaymentHandler.postMessage('success'); }
            document.body.innerHTML = '<h2>Payment Verified!</h2><p>Processing... You can close this window.</p>';
          } else {
            document.body.innerHTML = '<h2>Verification Failed.</h2><p>' + data.message + '</p>';
          }
        }).catch(()=>{ document.body.innerHTML = '<h2>An error occurred during verification.</h2>'; });
      },
      modal: { ondismiss: function(){ document.body.innerHTML = '<h2>Payment Cancelled.</h2><p>You can close this window.</p>'; } },
      theme: { color: '#E3C887' }
    };
    var rzp1 = new Razorpay(options);
    rzp1.on('payment.failed', function (response){ document.body.innerHTML = '<h2>Payment Failed.</h2><p>Error: ' + response.error.description + '</p>'; });
    rzp1.open();
  </script>
  </body></html>`;

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(html);
});

// Image generation without upload (Gemini)
app.post("/upload_without_image", verifyFirebaseToken, async (req, res) => {
  try {
    const genAI = getGenAI();
    if (!genAI) return res.status(500).send("GEMINI_API_KEY not configured");
    const { prompt } = req.body || {};
    if (!prompt) return res.status(400).send("A prompt is required.");
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-image-preview" });

    let result;
    for (let i = 0; i < 3; i++) {
      try {
        result = await model.generateContent(prompt);
        break;
      } catch (err) {
        if (err.status === 500 && i < 2) await new Promise(r => setTimeout(r, 1000 * (i + 1))); else throw err;
      }
    }
    const response = await result.response;
    const part = response.candidates?.[0]?.content?.parts?.find(p => p.inlineData);
    if (!part) return res.status(500).send("No image data found in AI response.");
    return res.json({ generatedImage: part.inlineData.data });
  } catch (error) {
    return res.status(500).send(`Error generating image with Gemini: ${error.message}`);
  }
});

// Image generation with upload (Gemini)
app.post("/upload", verifyFirebaseToken, express.json({ limit: '50mb' }), async (req, res) => {
  try {
    const genAI = getGenAI();
    if (!genAI) return res.status(500).send("GEMINI_API_KEY not configured");

    const { prompt, imgBase64 } = req.body;

    if (!prompt || !imgBase64 || !Array.isArray(imgBase64) || imgBase64.length === 0) {
      return res.status(400).send("A prompt and an array of base64 images are required.");
    }

    const imageParts = [];
    for (const base64Image of imgBase64) {
      const buffer = Buffer.from(base64Image, 'base64');
      const processedBuffer = await sharp(buffer).jpeg().toBuffer();
      imageParts.push({ inlineData: { data: processedBuffer.toString("base64"), mimeType: "image/jpeg" } });
    }

    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-image-preview" });
    let result;
    for (let i = 0; i < 3; i++) {
      try {
        result = await model.generateContent([prompt, ...imageParts]);
        break;
      } catch (err) {
        if (err.status === 500 && i < 2) await new Promise(r => setTimeout(r, 1000 * (i + 1))); else throw err;
      }
    }
    const response = await result.response;
    const part = response.candidates?.[0]?.content?.parts?.find(p => p.inlineData);
    if (!part) return res.status(500).send("No image data found in AI response.");
    return res.json({ generatedImage: part.inlineData.data });
  } catch (error) {
    return res.status(500).send(`Error generating image with Gemini: ${error.message}`);
  }
});

// Video generation task storage helpers (Firestore)
const tasksCol = () => admin.firestore().collection("videoTasks");

// Webhook to receive video status callbacks
app.post("/webhook/:taskId", async (req, res) => {
  const { taskId } = req.params;
  await tasksCol().doc(taskId).set({ status: req.body.status || "unknown", result: req.body, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  return res.status(200).send("Webhook received");
});

// Start video generation
app.post("/generate-video", verifyFirebaseToken, async (req, res) => {
  try {
    if (!req.headers["content-type"]?.includes("multipart/form-data")) {
      return res.status(400).send("Content-Type must be multipart/form-data");
    }

    const { fields, files } = await parseMultipart(req);
    const prompt = fields.prompt;
    const imageFile = files.find(f => f.fieldname === "image") || files[0];
    if (!prompt || !imageFile) return res.status(400).send("Prompt and image are required.");

    const taskId = `vid_${Date.now()}`;
    await tasksCol().doc(taskId).set({ status: "processing", result: null, createdAt: admin.firestore.FieldValue.serverTimestamp() });

    // Resize and compress image
    const processedImageBuffer = await sharp(imageFile.buffer)
      .resize({ width: 768, height: 768, fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();

    // Upload to Cloud Storage to get a public URL
    const bucket = admin.storage().bucket();
    const filename = `video_inputs/vid_input_${Date.now()}.jpg`;
    const file = bucket.file(filename);
    await file.save(processedImageBuffer, { contentType: "image/jpeg" });
    // Create a signed URL valid for 1 hour
    const [signedUrl] = await file.getSignedUrl({ action: "read", expires: Date.now() + 60 * 60 * 1000 });

    const webhookUrl = `${req.protocol}://${req.get("host")}/webhook/${taskId}`;

    const payload = {
      model: "hailuo",
      task_type: "video_generation",
      input: { model: "i2v-02", prompt, image_url: signedUrl, duration: 6, resolution: 768 },
      config: { service_mode: "public", webhook_config: { endpoint: webhookUrl, secret: "123456" } }
    };

    await axios.post("https://api.piapi.ai/api/v1/task", payload, {
      headers: { "X-API-Key": PIAPI_API_KEY_SECRET.value() || process.env.PIAPI_API_KEY, "Content-Type": "application/json" }
    });

    return res.status(202).json({ taskId });
  } catch (error) {
    await (async () => { try { const taskId = req?.body?.taskId; if (taskId) await tasksCol().doc(taskId).set({ status: "failed" }, { merge: true }); } catch {} })();
    return res.status(500).send("Error starting video generation task.");
  }
});

// Poll video task status
app.get("/video-status/:taskId", verifyFirebaseToken, async (req, res) => {
  const { taskId } = req.params;
  const doc = await tasksCol().doc(taskId).get();
  if (!doc.exists) return res.status(404).send("Task not found.");
  return res.json(doc.data());
});

// Export the Express app as a 2nd Gen Cloud Function (public invoker) with secrets
exports.api = onRequest({ invoker: 'public', secrets: [
  GEMINI_API_KEY_SECRET,
  RAZORPAY_KEY_ID_SECRET,
  RAZORPAY_KEY_SECRET_SECRET,
  PIAPI_API_KEY_SECRET,
] }, app);