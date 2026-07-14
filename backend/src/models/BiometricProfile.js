const mongoose = require('mongoose');

const biometricProfileSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  deviceId: {
    type: String,
    required: true
  },
  faceEmbeddingHash: {
    type: String,
    required: true // Store salted hash of the face embedding template, never raw templates
  },
  enrolledAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('BiometricProfile', biometricProfileSchema);
