const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const mongoose = require('mongoose');
const path = require('path');

// Routes
const authRoutes = require('./routes/auth');
const deviceRoutes = require('./routes/devices');
const biometricRoutes = require('./routes/biometrics');
const attemptRoutes = require('./routes/attempts');
const alertRoutes = require('./routes/alerts');

const app = express();

// Security and utility middlewares
// Disable CSP for Flutter Web rendering compatibility
app.use(helmet({
  contentSecurityPolicy: false,
}));
app.use(cors());
app.use(express.json({ limit: '10mb' })); // Support larger base64 photo sizes
app.use(express.urlencoded({ extended: true }));

// Serve Flutter Web static build files
const frontendWebPath = path.join(__dirname, '../../frontend/build/web');
app.use(express.static(frontendWebPath));

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

// Fallback to Flutter Web index.html for client-side routing
app.get('*', (req, res, next) => {
  const isApiRoute = req.path.startsWith('/auth') || 
                      req.path.startsWith('/devices') || 
                      req.path.startsWith('/biometrics') || 
                      req.path.startsWith('/shutdown-attempts') || 
                      req.path.startsWith('/alerts') ||
                      req.path.startsWith('/health');
  
  if (!isApiRoute) {
    res.sendFile(path.join(frontendWebPath, 'index.html'), (err) => {
      if (err) next();
    });
  } else {
    next();
  }
});

// Error Handling Middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).json({ 
    message: 'An unexpected error occurred on the server',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

module.exports = app;
