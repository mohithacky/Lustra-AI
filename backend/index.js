require('dotenv').config();
const express = require('express');
const multer = require('multer');
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');
const cors = require('cors');
const axios = require('axios');
const sharp = require('sharp');
const ngrok = require('@ngrok/ngrok');
const { execa } = require('execa');
const admin = require('firebase-admin');

// --- Environment Variable and API Key Validation ---
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
  console.error('--- CRITICAL: GEMINI_API_KEY is not defined in your .env file. ---');
  console.error('Please ensure you have a .env file in the /backend directory with your key.');
  process.exit(1); // Stop the server
}
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// --- Firebase Admin SDK Setup ---
try {
  // Ensure you have a .env file with GOOGLE_APPLICATION_CREDENTIALS pointing to your service account key
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('GOOGLE_APPLICATION_CREDENTIALS is not set in .env file.');
  }
  const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('--- Firebase Admin SDK initialized successfully. ---');
} catch (error) {
    console.error('--- CRITICAL: Firebase Admin SDK initialization failed. ---');
    console.error('Please ensure the GOOGLE_APPLICATION_CREDENTIALS environment variable is set to the path of your service account key file.');
    console.error(error.message);
    process.exit(1);
}

// Middleware to verify Firebase ID token
const verifyFirebaseToken = async (req, res, next) => {
    const idToken = req.headers.authorization?.split('Bearer ')[1];

    if (!idToken) {
        return res.status(401).send('Unauthorized: No token provided.');
    }

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken; // Add user info to the request object
        console.log(`--- User ${decodedToken.uid} authenticated successfully. ---`);
        next();
    } catch (error) {
        console.error('--- Error verifying Firebase ID token: ---', error);
        return res.status(403).send('Unauthorized: Invalid token.');
    }
};

const app = express();
const port = 3000;
let ngrokBaseUrl = ''; // Will be populated at startup
const videoTasks = {}; // In-memory store for video generation tasks

// Middleware
app.use(cors());
app.use(express.json());
app.use('/public', express.static(path.join(__dirname, 'public')));

// --- Storage Configurations ---

// Memory storage for AI processing
const memoryStorage = multer.memoryStorage();
const uploadForAI = multer({ storage: memoryStorage });

// Disk storage for saving template images
const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'public/uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const uploadForDisk = multer({ storage: diskStorage });

// Gemini AI setup

// Converts a file from a file path to a GoogleGenerativeAI.Part object.
function fileToGenerativePart(file) {
  return {
    inlineData: {
      data: file.buffer.toString("base64"),
      mimeType: file.mimetype,
    },
  };
}

// --- API Endpoints ---

app.get('/templates', (req, res) => {
  const { type } = req.query;
  console.log(`--- Received /templates request for type: ${type} ---`);

  fs.readFile('templates.json', 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading templates:', err);
      return res.status(500).send('Error reading templates.');
    }
    const templates = JSON.parse(data);
    if (type) {
      const filtered = templates.filter(t => Array.isArray(t.type) && t.type.includes(type));
      res.json(filtered);
    } else {
      res.json(templates); // Fallback to sending all if no type is specified
    }
  });
});

app.post('/add-template', uploadForDisk.single('image'), (req, res) => {
  console.log('--- Received /add-template request ---');
  const { name, type, prompt } = req.body;
  if (!name || !type || !prompt || !req.file) {
    return res.status(400).send('Missing required template fields or image.');
  }

  const newTemplate = {
    id: Date.now(),
    name,
    type: ['Product Photoshoot', 'Model Photoshoot'], // Assign to both types
    prompt,
    imageUrl: `/uploads/${req.file.filename}`
  };

  fs.readFile('templates.json', 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading templates file for update:', err);
      return res.status(500).send('Error saving template.');
    }
    const templates = JSON.parse(data);
    templates.push(newTemplate);
    fs.writeFile('templates.json', JSON.stringify(templates, null, 2), (writeErr) => {
      if (writeErr) {
        console.error('Error writing templates file:', writeErr);
        return res.status(500).send('Error saving template.');
      }
      console.log('--- Template Added Successfully ---');
      res.status(201).json(newTemplate);
    });
  });
});

app.post('/upload_without_image', express.json(), async (req, res) => {
  console.log('--- Received /upload_without_image request ---');
  const { prompt } = req.body;

  if (!prompt) {
    return res.status(400).send('A prompt is required.');
  }

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-image-preview' });

    let result;
    const maxRetries = 3;
    for (let i = 0; i < maxRetries; i++) {
      try {
        console.log(`--- Gemini API Call Attempt #${i + 1} ---`);
        result = await model.generateContent(prompt);
        break; // Success, exit loop
      } catch (error) {
        if (error.status === 500 && i < maxRetries - 1) {
          console.warn(`--- Gemini API returned 500, retrying in ${i + 1} second(s)... ---`);
          await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        } else {
          throw error; // Re-throw if not a 500 or last attempt
        }
      }
    }

    const response = await result.response;
    const responseImagePart = response.candidates[0].content.parts.find(part => part.inlineData);

    if (!responseImagePart) {
      const textPart = response.candidates[0].content.parts.find(part => part.text);
      console.error('--- No Image Data in Response ---');
      if (textPart) {
        console.error('AI Response Text:', textPart.text);
      }
      console.error('---------------------------------');
      return res.status(500).send('No image data found in the response from the AI.');
    }

    const imageData = responseImagePart.inlineData.data;
    res.json({ generatedImage: imageData });

  } catch (error) {
    console.error('--- Full Gemini API Error ---', error);
    if (error.message && (error.message.includes('API key not valid') || error.message.includes('API key is invalid'))) {
      res.status(401).send('The configured GEMINI_API_KEY is invalid. Please check your .env file.');
    } else {
      res.status(500).send(`Error generating image with Gemini: ${error.message}`);
    }
  }
});

app.post('/upload', uploadForAI.any(), async (req, res) => {
  console.log('--- Received /upload request ---');
  
  const jewelleryImages = req.files.filter(f => f.fieldname.startsWith('image_'));
  console.log(`Number of jewellery images received: ${jewelleryImages.length}`);
  const logoImage = req.files.find(f => f.fieldname === 'logo_image');

  if (jewelleryImages.length === 0 || !req.body.prompt) {
    return res.status(400).send('At least one jewellery image and a prompt are required.');
  }

  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-image-preview' });
    let prompt = req.body.prompt;
    const imageParts = [];

    // Process all jewellery images
    for (const file of jewelleryImages) {
      const buffer = await sharp(file.buffer).jpeg().toBuffer();
      imageParts.push({
        inlineData: {
          data: buffer.toString("base64"),
          mimeType: 'image/jpeg',
        },
      });
    }

    // Process logo image if it exists
    if (logoImage) {
      console.log('--- Logo image found, adding to request ---');
      const logoBuffer = await sharp(logoImage.buffer).jpeg().toBuffer();
      imageParts.push({
        inlineData: {
          data: logoBuffer.toString("base64"),
          mimeType: 'image/jpeg',
        },
      });
      prompt += ' The last image provided is a logo; please place it tastefully onto the final generated image as a watermark or branding element.';
    }

    let result;
    const maxRetries = 3;
    for (let i = 0; i < maxRetries; i++) {
      try {
        console.log(`--- Gemini API Call Attempt #${i + 1} ---`);
        result = await model.generateContent([prompt, ...imageParts]);
        break; // Success, exit loop
      } catch (error) {
        if (error.status === 500 && i < maxRetries - 1) {
          console.warn(`--- Gemini API returned 500, retrying in ${i + 1} second(s)... ---`);
          await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        } else {
          throw error; // Re-throw if not a 500 or last attempt
        }
      }
    }


    const response = await result.response;
    const responseImagePart = response.candidates[0].content.parts.find(part => part.inlineData);

    if (!responseImagePart) {
      const textPart = response.candidates[0].content.parts.find(part => part.text);
      console.error('--- No Image Data in Response ---');
      if (textPart) {
        console.error('AI Response Text:', textPart.text);
      }
      console.error('---------------------------------');
      return res.status(500).send('No image data found in the response from the AI.');
    }

    const imageData = responseImagePart.inlineData.data;
    res.json({ generatedImage: imageData });

  } catch (error) {
    console.error('--- Full Gemini API Error ---', error);
    if (error.message && (error.message.includes('API key not valid') || error.message.includes('API key is invalid'))) {
      res.status(401).send('The configured GEMINI_API_KEY is invalid. Please check your .env file.');
    } else {
      res.status(500).send(`Error generating image with Gemini: ${error.message}`);
    }
  }
});

// --- Video Generation Endpoints ---

// Endpoint to receive webhook callbacks from Hailuo AI
app.post('/webhook/:taskId', (req, res) => {
  const { taskId } = req.params;
  console.log(`--- Webhook received for task ${taskId} ---`);
  console.log('Webhook Body:', JSON.stringify(req.body, null, 2));

  // Unify task storage
  if (videoTasks[taskId]) {
    videoTasks[taskId].status = req.body.status; // e.g., 'completed', 'failed'
    videoTasks[taskId].result = req.body; // Store the full webhook payload
  } else {
    // If for some reason the task isn't in memory, store it anyway
    videoTasks[taskId] = { 
      status: req.body.status, 
      result: req.body 
    };
  }

  res.status(200).send('Webhook received');
});

app.post('/generate-video', uploadForAI.single('image'), async (req, res) => {
  console.log('--- Received /generate-video request ---');
  const { prompt } = req.body;
  const imageFile = req.file;

  if (!prompt || !imageFile) {
    return res.status(400).send('Prompt and image are required.');
  }

  const taskId = `vid_${Date.now()}`;
  videoTasks[taskId] = { status: 'processing', result: null };

  // Resize and compress the image to prevent size errors
  const processedImageBuffer = await sharp(imageFile.buffer)
    .resize({ width: 768, height: 768, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 80 })
    .toBuffer();

  // Save the processed image to a file to generate a public URL
  const filename = `vid_input_${Date.now()}.jpg`;
  const filepath = path.join(__dirname, 'public', 'uploads', filename);
  fs.writeFileSync(filepath, processedImageBuffer);

    const imageUrl = `${ngrokBaseUrl}/public/uploads/${filename}`;
  const webhookUrl = `${ngrokBaseUrl}/webhook/${taskId}`;

  console.log(`--- Generated public image URL: ${imageUrl} ---`);

  const payload = {
    model: 'hailuo',
    task_type: 'video_generation',
    input: {
      model: 'i2v-02',
      prompt: prompt,
      image_url: imageUrl,
      duration: 6,
      resolution: 768,
    },
    config: {
      service_mode: 'public',
      webhook_config: {
        endpoint: webhookUrl,
        secret: '123456'
      }
    }
  };

  try {

    const response = await axios.post('https://api.piapi.ai/api/v1/task', payload, {
      headers: {
        'X-API-Key': process.env.PIAPI_API_KEY, // Use the correct header and load from .env
        'Content-Type': 'application/json'
      }
    });

    console.log('--- Hailuo AI task created ---', response.data);
    res.status(202).json({ taskId });

  } catch (error) {
    console.error('--- Hailuo AI Error ---');
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      console.error('Data:', error.response.data);
      console.error('Status:', error.response.status);
      console.error('Headers:', error.response.headers);
    } else if (error.request) {
      // The request was made but no response was received
      console.error('Request:', error.request);
    } else {
      // Something happened in setting up the request that triggered an Error
      console.error('Error', error.message);
    }
    console.error('Config:', error.config);
    videoTasks[taskId].status = 'failed';
    res.status(500).send('Error starting video generation task.');
  }
});

// --- Deployment Endpoint ---
app.post('/deploy', verifyFirebaseToken, async (req, res) => {
    console.log(`--- Received /deploy request from user ${req.user.uid} ---`);

    try {
        console.log('--- Starting Flutter web build... ---');
        const projectRoot = path.resolve(__dirname, '..');

        // Using execa for command execution
        const { stdout: buildStdout } = await execa(
            'flutter', 
            ['build', 'web', '-t', 'lib/website.dart'], 
            { cwd: projectRoot, shell: true }
        );
        console.log('--- Flutter build successful ---', buildStdout);

        console.log('--- Starting Firebase deployment... ---');
        const { stdout: deployStdout } = await execa(
            'firebase', 
            ['deploy', '--only', 'hosting'], 
            { cwd: projectRoot, shell: true }
        );
        console.log('--- Firebase deployment successful ---', deployStdout);

        const userRef = admin.firestore().collection('users').doc(req.user.uid);

        // Fetch user data to get shopName and logoUrl
        const userDoc = await userRef.get();
        if (!userDoc.exists) {
            throw new Error('User document not found.');
        }
        const userData = userDoc.data();
        console.log('--- User data from Firestore: ---', userData);
        const shopName = encodeURIComponent(userData.shopName || '');
        const logoUrl = encodeURIComponent(userData.logoUrl || ''); // This URL must be encoded

        let websiteUrl = 'https://lustra-ai.web.app'; // Your Firebase hosting URL
        const queryParams = [];
        if (shopName) queryParams.push(`shopName=${shopName}`);
        if (logoUrl) queryParams.push(`logoUrl=${logoUrl}`);
        queryParams.push(`userId=${req.user.uid}`); // Always add the userId

        if (queryParams.length > 0) {
            websiteUrl += `?${queryParams.join('&')}`;
        }

        console.log('--- Final Website URL: ---', websiteUrl);

        // Update user document in Firestore
        await userRef.set({
            isWebsiteCreated: true,
            websiteUrl: websiteUrl
        }, { merge: true });

        console.log(`--- User ${req.user.uid} document updated with website URL. ---`);

        res.status(200).json({ message: 'Deployment successful!', websiteUrl: websiteUrl });

    } catch (error) {
        console.error('--- Deployment pipeline failed ---', error);
        res.status(500).send(`Deployment failed: ${error.stderr || error.message}`);
    }
});

app.get('/video-status/:taskId', (req, res) => {
  const { taskId } = req.params;
  const task = videoTasks[taskId];

  if (task) {
    res.json(task);
  } else {
    res.status(404).send('Task not found.');
  }
});


const server = app.listen(port, '0.0.0.0', async () => {
  console.log(`Server running on port ${port} and accessible on your local network`);
  try {
    const listener = await ngrok.forward({
      addr: port,
      authtoken_from_env: true,
      domain: 'central-miserably-sunbird.ngrok-free.app'
    });
    ngrokBaseUrl = listener.url();
    console.log(`--- ngrok tunnel created: ${ngrokBaseUrl} ---`);
      } catch (err) {
    console.error('--- CRITICAL: Failed to start ngrok. ---', err);
    process.exit(1);
  }
});

server.on('error', (err) => {
  console.error('--- SERVER FAILED TO START ---', err);
  process.exit(1);
});
