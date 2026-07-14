const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretjwtkey_change_in_production_123!';

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ message: 'Authorization header is missing' });
  }

  const token = authHeader.split(' ')[1];
  if (!token) {
    return res.status(401).json({ message: 'Token is missing' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
};

// Rate limiter for emergency overrides (max 3 requests per 15 minutes)
const emergencyOverrideRateLimiter = rateLimit({
  windowMs: (process.env.EMERGENCY_OVERRIDE_COOLDOWN_MINUTES || 15) * 60 * 1000,
  max: 3,
  message: {
    message: 'Too many emergency override attempts. Please wait before trying again.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  verifyToken,
  emergencyOverrideRateLimiter
};
