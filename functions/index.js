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
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");


admin.initializeApp();

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

const GEMINI_API_KEY_SECRET = defineSecret("GEMINI_API_KEY");
const RAZORPAY_KEY_ID_SECRET = defineSecret("RAZORPAY_KEY_ID");
const RAZORPAY_KEY_SECRET_SECRET = defineSecret("RAZORPAY_KEY_SECRET");
const PIAPI_API_KEY_SECRET = defineSecret("PIAPI_API_KEY");
const RAZORPAY_WEBHOOK_SECRET_SECRET = defineSecret("RAZORPAY_WEBHOOK_SECRET");
const GITHUB_TOKEN=defineSecret("GITHUB_TOKEN");

// Verify Firebase ID token middleware
const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!token) return res.status(401).send('Unauthorized');
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded; // Attach user payload to the request object
    return next();
  } catch (e) {
    return res.status(403).send('Unauthorized');
  }
};

// Razorpay: initialize lazily inside handlers to avoid failures during CLI analysis

// Secrets


let razorpay = null;
function getRazorpay() {
  if (!razorpay) {
    razorpay = new Razorpay({
      key_id: RAZORPAY_KEY_ID_SECRET.value(),
      key_secret: RAZORPAY_KEY_SECRET_SECRET.value()
    });
  }
  return razorpay;
}

app.post("/deploy", async (req, res) => {
  try {
    const triggerUrl = "https://api.github.com/repos/mohithacky/Lustra-AI/dispatches";
    const token = GITHUB_TOKEN.value(); // store this in Functions config or .env

    const response = await fetch(triggerUrl, {
      method: "POST",
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": `Bearer ${token}`
      },
      body: JSON.stringify({
        event_type: "deploy_trigger"
      })
    });
  console.log("Response: ", response.body);

    if (!response.ok) {
      throw new Error(`GitHub API error: ${response.statusText}`);
  }
    res.status(200).json({ message: "Triggered deploy workflow successfully!" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// --- DEPLOY STATUS ENDPOINT ---
app.get("/deploy-status", async (req, res) => {
  try {
    const githubToken = GITHUB_TOKEN.value();
    const owner = "mohithacky";
    const repo = "Lustra-AI";

    const response = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/actions/runs?per_page=1`,
      {
        headers: {
          "Accept": "application/vnd.github+json",
          "Authorization": `Bearer ${githubToken}`,
        },
      }
    );

    if (!response.ok) {
      throw new Error(`GitHub API error: ${response.status}`);
    }

    const data = await response.json();
    const latestRun = data.workflow_runs?.[0];

    if (!latestRun) {
      return res.json({ status: "no_runs_found" });
    }

    return res.json({
      status: latestRun.status,
      conclusion: latestRun.conclusion,
      html_url: latestRun.html_url,
      created_at: latestRun.created_at,
      updated_at: latestRun.updated_at,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});




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

// Checkout page (Razorpay Checkout.js)

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
app.post("/generate-collection-banner", verifyFirebaseToken, express.json({ limit: '50mb' }), async (req, res) => {
  try {
    const genAI = getGenAI();
    if (!genAI) return res.status(500).send("GEMINI_API_KEY not configured");

    const { collectionName } = req.body;

    if (!collectionName) {
      return res.status(400).send("A collection name is required.");
    }

    const backgroundImagePath = path.join(__dirname, '..', 'assets', 'white', '16to9.avif');
    const backgroundImage = fs.readFileSync(backgroundImagePath);

    const imageParts = [{
      inlineData: {
        data: backgroundImage.toString('base64'),
        mimeType: 'image/avif'
      }
    }];

    const prompt = `Generate a poster image for a collection named ${collectionName} on the background I have provided in the image . This image will be shown on a ecommerce website for jewelleries. The poster should contain model. Cover the full white background. It's not compulsory that you keep the background just white.`;

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


// -------------------- RAZORPAY WEBHOOK --------------------
app.post("/webhook", express.json({
  verify: (req, res, buf) => { req.rawBody = buf; }
}), async (req, res) => {
    console.log("Entered webhook endpoint");
  const secret = "3522xp002";
  const signature = req.headers['x-razorpay-signature'];

  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(req.rawBody)
    .digest('hex');

  if (crypto.timingSafeEqual(Buffer.from(expectedSignature), Buffer.from(signature))) {
    console.log('✅ Webhook verified');

    const event = req.body.event;

    if (event === 'payment.captured') {
      const payment = req.body.payload.payment.entity;
      console.log(`💰 Payment captured: ₹${payment.amount / 100}`);

      const rzp = getRazorpay();
      const order = await rzp.orders.fetch(payment.order_id);
      const userId = order.notes.userId;

      if (!userId) {
        console.error('❌ User ID not found in order notes');
        return res.status(400).json({ status: 'User ID missing' });
      }

      const amountPaid = payment.amount / 100;
      const coinPlans = {
        99: { coins: 100, name: 'Starter Pack' },
        799: { coins: 550, name: 'Pro Pack' },
        2499: { coins: 2000, name: 'Unlimited Pack' },
      };

      const plan = coinPlans[amountPaid];
      if (!plan) {
        console.error(`No coin plan found for amount: ${amountPaid}`);
        return res.status(400).json({ status: 'Invalid amount' });
      }

      const userRef = admin.firestore().collection('users').doc(userId);

      await admin.firestore().runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        const newCoins = (userDoc.data().coins || 0) + plan.coins;

        transaction.update(userRef, {
          coins: newCoins,
          purchaseHistory: admin.firestore.FieldValue.arrayUnion({
            orderId: payment.order_id,
            amount: amountPaid,
            coins: plan.coins,
            planName: plan.name,
            purchasedAt: new Date(),
          }),
        });
      });

      console.log(`✅ User ${userId} credited with ${plan.coins} coins.`);
    } else if (event === 'payment.failed') {
      console.log('❌ Payment failed event received');
      // Update your DB: mark order as "failed"
    }

    res.status(200).json({ status: 'ok' });
  } else {
    console.error('❌ Invalid webhook signature');
    res.status(400).json({ status: 'invalid signature' });
  }
});


// -------------------- RAZORPAY ORDER --------------------
app.post('/order',verifyFirebaseToken, async (req, res) => {
  console.log("Entered order endpoint");
  const {amount} = req.body;
  const rzp=getRazorpay();
  try {
    const options = {
      amount: amount * 100,
      currency: 'INR',
      receipt: `receipt_${Date.now()}`,
      notes: {
        userId: req.user.uid
      }
    };

    const order = await rzp.orders.create(options);
    res.render('payment', {
      order,
      key_id: rzp.key_id
    });
  } catch (error) {
    console.error('Order creation failed:', error);
    res.status(500).json({ error: 'Order creation failed' });
  }
});

app.get('/payment-success', (req, res) => {
    res.send('Payment Successful!');
});

app.get('/payment-failed', (req, res) => {
    res.send('Payment Failed!');
});


// Export the Express app as a 2nd Gen Cloud Function (public invoker) with secrets
exports.api = onRequest({ invoker: 'public', secrets: [
  GEMINI_API_KEY_SECRET,
  RAZORPAY_KEY_ID_SECRET,
  RAZORPAY_KEY_SECRET_SECRET,
  PIAPI_API_KEY_SECRET,
  RAZORPAY_WEBHOOK_SECRET_SECRET,
  GITHUB_TOKEN
] }, app);