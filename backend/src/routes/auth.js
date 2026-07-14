const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || 'supersecretjwtkey_change_in_production_123!';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'supersecretjwtrefreshkey_change_in_production_456!';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

// Generate token helper
const generateTokens = (user) => {
  const payload = { id: user._id, email: user.email, role: user.role };
  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  const refreshToken = jwt.sign({ id: user._id }, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });
  return { accessToken, refreshToken };
};

// POST /auth/register
router.post('/register', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required' });
  }

  try {
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists with this email' });
    }

    const user = new User({ email, password });
    await user.save();

    const tokens = generateTokens(user);
    return res.status(201).json({
      message: 'User registered successfully',
      user: { id: user._id, email: user.email, role: user.role },
      ...tokens
    });
  } catch (err) {
    console.error('Registration error:', err);
    return res.status(500).json({ message: 'Error registering user', error: err.message });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required' });
  }

  try {
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const tokens = generateTokens(user);
    return res.json({
      message: 'Login successful',
      user: { id: user._id, email: user.email, role: user.role },
      ...tokens
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ message: 'Error logging in', error: err.message });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ message: 'Refresh token is required' });
  }

  try {
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const tokens = generateTokens(user);
    return res.json(tokens);
  } catch (err) {
    return res.status(403).json({ message: 'Invalid or expired refresh token' });
  }
});

module.exports = router;
