const mongoose = require('mongoose');

const shutdownAttemptSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    index: true
  },
  timestamp: {
    type: Date,
    required: true,
    default: Date.now
  },
  method: {
    type: String,
    enum: ['fingerprint', 'face', 'pin', 'override'],
    required: true
  },
  result: {
    type: String,
    enum: ['success', 'failure'],
    required: true
  },
  photoUrl: {
    type: String,
    default: null
  },
  geolocation: {
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null }
  },
  signature: {
    type: String,
    required: true // Cryptographic signature verifying the payload
  },
  signedPayload: {
    type: String,
    required: true // The raw payload data that was signed on the device
  }
});

module.exports = mongoose.model('ShutdownAttempt', shutdownAttemptSchema);
