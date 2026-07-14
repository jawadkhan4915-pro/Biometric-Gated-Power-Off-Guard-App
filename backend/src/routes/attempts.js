const express = require('express');
const ShutdownAttempt = require('../models/ShutdownAttempt');
const Device = require('../models/Device');
const Alert = require('../models/Alert');
const { verifyDeviceSignature } = require('../middleware/signature');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// POST /shutdown-attempts
// Enforces cryptographic signature verification to prevent log spoofing
router.post('/', verifyDeviceSignature, async (req, res) => {
  const { signature, signedPayload } = req.body;

  try {
    let parsedPayload;
    try {
      parsedPayload = JSON.parse(signedPayload);
    } catch (e) {
      return res.status(400).json({ message: 'signedPayload must be a valid JSON string' });
    }

    const { deviceId, timestamp, method, result, photoUrl, geolocation } = parsedPayload;

    if (!deviceId || !method || !result) {
      return res.status(400).json({ message: 'deviceId, method, and result are required inside signedPayload' });
    }

    if (deviceId !== req.body.deviceId) {
      return res.status(400).json({ message: 'Device ID in signedPayload does not match request body deviceId' });
    }

    const attempt = new ShutdownAttempt({
      deviceId,
      timestamp: timestamp ? new Date(timestamp) : new Date(),
      method,
      result,
      photoUrl,
      geolocation,
      signature,
      signedPayload
    });

    await attempt.save();

    // Trigger alert and notification generation if a failure occurs
    if (result === 'failure') {
      const alert = new Alert({
        userId: req.device.userId,
        deviceId: deviceId,
        type: method === 'face' || method === 'fingerprint' ? 'failed_biometrics' : 'unauthorized_power_off'
      });
      await alert.save();
      
      // In a real application, here we would invoke Firebase Cloud Messaging (FCM) to trigger push alerts
      console.log(`[ALERT] Unauthorized power-off attempt logged for device: ${deviceId}. Push notification queued.`);
    }

    return res.status(201).json({ 
      message: 'Shutdown attempt logged successfully', 
      attempt,
      alertTriggered: result === 'failure'
    });
  } catch (err) {
    console.error('Log shutdown attempt error:', err);
    return res.status(500).json({ message: 'Error logging shutdown attempt', error: err.message });
  }
});

// GET /shutdown-attempts
// Fetches paginated history of shutdown attempts for devices registered to the logged-in user
router.get('/', verifyToken, async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const deviceId = req.query.deviceId;

  try {
    // 1. Retrieve all devices registered to this user
    const userDevices = await Device.find({ userId: req.user.id });
    const deviceIds = userDevices.map(d => d.deviceId);

    if (deviceIds.length === 0) {
      return res.json({
        attempts: [],
        totalPages: 0,
        currentPage: page,
        totalAttempts: 0
      });
    }

    // 2. Filter query
    const filter = { deviceId: { $in: deviceIds } };
    if (deviceId) {
      if (!deviceIds.includes(deviceId)) {
        return res.status(403).json({ message: 'Access denied: You do not own this device' });
      }
      filter.deviceId = deviceId;
    }

    // 3. Query DB
    const skip = (page - 1) * limit;
    const totalAttempts = await ShutdownAttempt.countDocuments(filter);
    const attempts = await ShutdownAttempt.find(filter)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit);

    return res.json({
      attempts,
      totalPages: Math.ceil(totalAttempts / limit),
      currentPage: page,
      totalAttempts
    });
  } catch (err) {
    console.error('Query shutdown history error:', err);
    return res.status(500).json({ message: 'Error retrieving shutdown attempts', error: err.message });
  }
});

module.exports = router;
