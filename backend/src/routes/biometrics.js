const express = require('express');
const BiometricProfile = require('../models/BiometricProfile');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// POST /biometrics/enroll
router.post('/enroll', verifyToken, async (req, res) => {
  const { deviceId, faceEmbeddingHash } = req.body;

  if (!deviceId || !faceEmbeddingHash) {
    return res.status(400).json({ message: 'deviceId and faceEmbeddingHash are required' });
  }

  try {
    // Check if a profile already exists for this device/user
    let profile = await BiometricProfile.findOne({ userId: req.user.id, deviceId });
    if (profile) {
      profile.faceEmbeddingHash = faceEmbeddingHash;
      profile.enrolledAt = new Date();
      await profile.save();
      return res.json({ message: 'Biometric profile updated successfully', profile });
    }

    profile = new BiometricProfile({
      userId: req.user.id,
      deviceId,
      faceEmbeddingHash
    });
    await profile.save();

    return res.status(201).json({ message: 'Biometric profile enrolled successfully', profile });
  } catch (err) {
    console.error('Biometric profile enrollment error:', err);
    return res.status(500).json({ message: 'Error enrolling biometric profile', error: err.message });
  }
});

module.exports = router;
