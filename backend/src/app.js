const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const mongoose = require('mongoose');

// Routes
const authRoutes = require('./routes/auth');
const deviceRoutes = require('./routes/devices');
const biometricRoutes = require('./routes/biometrics');
const attemptRoutes = require('./routes/attempts');
const alertRoutes = require('./routes/alerts');

const app = express();

// Security and utility middlewares
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' })); // Support larger base64 photo sizes
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', uptime: process.uptime() });
});

// Mounting Router Middleware
app.use('/auth', authRoutes);
app.use('/devices', deviceRoutes);
app.use('/biometrics', biometricRoutes);
app.use('/shutdown-attempts', attemptRoutes);
app.use('/alerts', alertRoutes);

// Error Handling Middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({ 
    message: 'An unexpected error occurred on the server',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

module.exports = app;
