require('dotenv').config();
const app = require('./app');
const mongoose = require('mongoose');

const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/power_guard';

// Connect to MongoDB
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('MongoDB successfully connected.');
    // Start listening
    app.listen(PORT, () => {
      console.log(`Secure Power-Off Guard Server is running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Critical database connection failed:', err);
    process.exit(1);
  });
