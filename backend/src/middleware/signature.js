const crypto = require('crypto');
const Device = require('../models/Device');

/**
 * Signature Verification Middleware
 * Validates that requests reporting hardware/auth events are legitimately signed by the device's registered private key.
 */
const verifyDeviceSignature = async (req, res, next) => {
  const { deviceId, signature, signedPayload } = req.body;

  if (!deviceId || !signature || !signedPayload) {
    return res.status(400).json({ 
      message: 'Cryptographic verification failed: deviceId, signature, and signedPayload are required.' 
    });
  }

  try {
    // 1. Fetch the registered public key for this device
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ message: `Device with ID ${deviceId} is not registered.` });
    }

    // 2. Perform signature validation using Node's crypto library
    const verifier = crypto.createVerify('SHA256');
    verifier.update(signedPayload);
    
    // The public key must be in PEM format
    const isVerified = verifier.verify(device.publicKey, signature, 'base64');

    if (!isVerified) {
      return res.status(401).json({ message: 'Cryptographic signature is invalid. Payload spoofing detected.' });
    }

    // Attach device object to request for downstream controller usage
    req.device = device;
    next();
  } catch (err) {
    console.error('Signature validation error:', err);
    return res.status(500).json({ message: 'Internal signature verification failure', error: err.message });
  }
};

module.exports = {
  verifyDeviceSignature
};
