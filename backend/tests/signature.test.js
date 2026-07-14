const request = require('supertest');
const mongoose = require('mongoose');
const crypto = require('crypto');
const app = require('../src/app');
const User = require('../src/models/User');
const Device = require('../src/models/Device');
const ShutdownAttempt = require('../src/models/ShutdownAttempt');
const Alert = require('../src/models/Alert');

const TEST_MONGODB_URI = 'mongodb://127.0.0.1:27017/power_guard_test';

let authToken;
let publicKeyPem;
let privateKeyPem;
const deviceId = 'crypto_test_device_007';

beforeAll(async () => {
  jest.setTimeout(60000);
  await mongoose.disconnect();
  await mongoose.connect(TEST_MONGODB_URI);

  // Generate a key pair dynamically for testing
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
  });

  publicKeyPem = publicKey;
  privateKeyPem = privateKey;
});

afterAll(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
});

beforeEach(async () => {
  await User.deleteMany({});
  await Device.deleteMany({});
  await ShutdownAttempt.deleteMany({});
  await Alert.deleteMany({});

  // Register user and enroll device with the public key
  const regUser = await request(app)
    .post('/auth/register')
    .send({ email: 'owner@guard.com', password: 'password123' });
  authToken = regUser.body.accessToken;

  await request(app)
    .post('/devices/enroll')
    .set('Authorization', `Bearer ${authToken}`)
    .send({
      deviceId,
      deviceModel: 'Pixel 7 Pro',
      os: 'android',
      publicKey: publicKeyPem
    });
});

describe('Cryptographic Signature Verification on /shutdown-attempts', () => {
  test('POST /shutdown-attempts - Accept valid signed payload & log alert if failure', async () => {
    // 1. Prepare payload
    const data = {
      deviceId,
      timestamp: new Date().toISOString(),
      method: 'face',
      result: 'failure' // Will trigger alert
    };
    const signedPayload = JSON.stringify(data);

    // 2. Cryptographically sign the payload string
    const signer = crypto.createSign('SHA256');
    signer.update(signedPayload);
    const signature = signer.sign(privateKeyPem, 'base64');

    // 3. Post to endpoint
    const res = await request(app)
      .post('/shutdown-attempts')
      .send({
        deviceId,
        timestamp: data.timestamp,
        method: data.method,
        result: data.result,
        signature,
        signedPayload
      });

    expect(res.statusCode).toBe(201);
    expect(res.body.message).toContain('logged successfully');
    expect(res.body.alertTriggered).toBe(true);

    // Verify Alert was created in database
    const alerts = await Alert.find({ deviceId });
    expect(alerts.length).toBe(1);
    expect(alerts[0].type).toBe('failed_biometrics');
  });

  test('POST /shutdown-attempts - Block payload when signature is modified', async () => {
    const data = {
      deviceId,
      timestamp: new Date().toISOString(),
      method: 'fingerprint',
      result: 'success'
    };
    const signedPayload = JSON.stringify(data);

    // Sign payload
    const signer = crypto.createSign('SHA256');
    signer.update(signedPayload);
    const signature = signer.sign(privateKeyPem, 'base64');

    // Alter the signature slightly
    const corruptedSignature = signature.substring(0, signature.length - 4) + 'AAAA';

    const res = await request(app)
      .post('/shutdown-attempts')
      .send({
        deviceId,
        timestamp: data.timestamp,
        method: data.method,
        result: data.result,
        signature: corruptedSignature,
        signedPayload
      });

    expect(res.statusCode).toBe(401);
    expect(res.body.message).toContain('signature is invalid');
  });

  test('POST /shutdown-attempts - Block payload when data is tampered post-signing', async () => {
    const originalData = {
      deviceId,
      timestamp: new Date().toISOString(),
      method: 'fingerprint',
      result: 'failure' // Signed as failure
    };
    const signedPayload = JSON.stringify(originalData);

    const signer = crypto.createSign('SHA256');
    signer.update(signedPayload);
    const signature = signer.sign(privateKeyPem, 'base64');

    // Tamper with body parameter (e.g. try to spoof it as success in outer body)
    const tamperedData = { ...originalData, result: 'success' };

    const res = await request(app)
      .post('/shutdown-attempts')
      .send({
        deviceId,
        timestamp: tamperedData.timestamp,
        method: tamperedData.method,
        result: tamperedData.result, // Attempting to trick the server via outer body
        signature,
        signedPayload // The original payload containing 'failure' is verified
      });

    // The request should be accepted since signature is valid
    expect(res.statusCode).toBe(201);
    // However, the database MUST store the actual verified 'failure' state from signedPayload
    expect(res.body.attempt.result).toBe('failure');
    expect(res.body.alertTriggered).toBe(true);

    // Verify Alert was created in database because it was parsed as a failure
    const alerts = await Alert.find({ deviceId });
    expect(alerts.length).toBe(1);
    expect(alerts[0].type).toBe('failed_biometrics');
  });
});
