const express = require('express');
const Device = require('../models/Device');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// POST /devices/enroll
router.post('/enroll', verifyToken, async (req, res) => {
  const { deviceId, deviceModel, os, publicKey } = req.body;

  if (!deviceId || !deviceModel || !os || !publicKey) {
    return res.status(400).json({ message: 'deviceId, deviceModel, os, and publicKey are required' });
  }

  try {
    // Check if the device is already enrolled
    let device = await Device.findOne({ deviceId });
    if (device) {
      // Re-enroll device to the current user (in case of re-install)
      device.userId = req.user.id;
      device.deviceModel = deviceModel;
      device.os = os;
      device.publicKey = publicKey;
      device.status = 'Protected';
      await device.save();
      return res.json({ message: 'Device re-enrolled successfully', device });
    }

    device = new Device({
      deviceId,
      userId: req.user.id,
      deviceModel,
      os,
      publicKey
    });
    await device.save();

    return res.status(201).json({ message: 'Device enrolled successfully', device });
  } catch (err) {
    console.error('Device enrollment error:', err);
    return res.status(500).json({ message: 'Error enrolling device', error: err.message });
  }
});

// GET /devices/:id/status
router.get('/:id/status', async (req, res) => {
  const deviceId = req.params.id;

  try {
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ message: 'Device not found' });
    }

    return res.json({ deviceId: device.deviceId, status: device.status });
  } catch (err) {
    console.error('Device status lookup error:', err);
    return res.status(500).json({ message: 'Error fetching device status', error: err.message });
  }
});

// PATCH /devices/:id/status
// Toggle lock protection (Protected/Unprotected)
router.patch('/:id/status', verifyToken, async (req, res) => {
  const deviceId = req.params.id;
  const { status } = req.body;

  if (!status || !['Protected', 'Unprotected'].includes(status)) {
    return res.status(400).json({ message: 'Invalid or missing status value (must be Protected or Unprotected)' });
  }

  try {
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ message: 'Device not found' });
    }

    // Verify user owns this device
    if (device.userId.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Access denied: You do not own this device' });
    }

    device.status = status;
    await device.save();

    return res.json({ message: `Device status updated to ${status}`, device });
  } catch (err) {
    console.error('Device status update error:', err);
    return res.status(500).json({ message: 'Error updating device status', error: err.message });
  }
});

module.exports = router;
