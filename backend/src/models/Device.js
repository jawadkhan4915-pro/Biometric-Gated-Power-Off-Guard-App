const mongoose = require('mongoose');

const deviceSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  deviceModel: {
    type: String,
    required: true
  },
  os: {
    type: String,
    enum: ['android', 'ios'],
    required: true
  },
  publicKey: {
    type: String,
    required: true // PEM format key used to verify device-signed payloads
  },
  status: {
    type: String,
    enum: ['Protected', 'Unprotected'],
    default: 'Protected'
  },
  enrolledAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Device', deviceSchema);
