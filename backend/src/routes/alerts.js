const express = require('express');
const Alert = require('../models/Alert');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();

// GET /alerts
// Retrieve unread and historical security alerts for the logged-in user
router.get('/', verifyToken, async (req, res) => {
  try {
    const alerts = await Alert.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(50); // limit to last 50 alerts

    return res.json({ alerts });
  } catch (err) {
    console.error('Fetch alerts error:', err);
    return res.status(500).json({ message: 'Error retrieving alerts', error: err.message });
  }
});

// POST /alerts/ack
// Acknowledge one or all alerts for the user
router.post('/ack', verifyToken, async (req, res) => {
  const { alertIds } = req.body; // Can pass list of alert IDs, or empty to acknowledge all

  try {
    const filter = { userId: req.user.id };
    if (alertIds && Array.isArray(alertIds) && alertIds.length > 0) {
      filter._id = { $in: alertIds };
    }

    const result = await Alert.updateMany(filter, { $set: { read: true } });

    return res.json({
      message: 'Alerts acknowledged successfully',
      modifiedCount: result.modifiedCount
    });
  } catch (err) {
    console.error('Acknowledge alerts error:', err);
    return res.status(500).json({ message: 'Error acknowledging alerts', error: err.message });
  }
});

module.exports = router;
