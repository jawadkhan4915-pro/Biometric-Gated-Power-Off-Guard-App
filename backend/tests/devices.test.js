const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const User = require('../src/models/User');
const Device = require('../src/models/Device');

const TEST_MONGODB_URI = 'mongodb://127.0.0.1:27017/power_guard_test';

let authToken;
let otherAuthToken;
let userId;

beforeAll(async () => {
  jest.setTimeout(60000);
  await mongoose.disconnect();
  await mongoose.connect(TEST_MONGODB_URI);
});

afterAll(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
});

beforeEach(async () => {
  await User.deleteMany({});
  await Device.deleteMany({});

  // Create testing users
  const regUser = await request(app)
    .post('/auth/register')
    .send({ email: 'user@guard.com', password: 'password123' });
  authToken = regUser.body.accessToken;
  userId = regUser.body.user.id;

  const otherUser = await request(app)
    .post('/auth/register')
    .send({ email: 'other@guard.com', password: 'password123' });
  otherAuthToken = otherUser.body.accessToken;
});

describe('Device Management API Endpoints', () => {
  const dummyPublicKey = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz7...\n-----END PUBLIC KEY-----';
  
  const testDevice = {
    deviceId: 'dev_iphone_123',
    deviceModel: 'iPhone 13 Pro',
    os: 'ios',
    publicKey: dummyPublicKey
  };

  test('POST /devices/enroll - Register new device successfully', async () => {
    const res = await request(app)
      .post('/devices/enroll')
      .set('Authorization', `Bearer ${authToken}`)
      .send(testDevice);

    expect(res.statusCode).toBe(201);
    expect(res.body.device.deviceId).toBe(testDevice.deviceId);
    expect(res.body.device.userId).toBe(userId);
  });

  test('GET /devices/:id/status - Fetch protection status of enrolled device', async () => {
    // Enroll first
    await request(app)
      .post('/devices/enroll')
      .set('Authorization', `Bearer ${authToken}`)
      .send(testDevice);

    const res = await request(app)
      .get(`/devices/${testDevice.deviceId}/status`);

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('Protected');
  });

  test('PATCH /devices/:id/status - Update device protection state', async () => {
    await request(app)
      .post('/devices/enroll')
      .set('Authorization', `Bearer ${authToken}`)
      .send(testDevice);

    const res = await request(app)
      .patch(`/devices/${testDevice.deviceId}/status`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({ status: 'Unprotected' });

    expect(res.statusCode).toBe(200);
    expect(res.body.device.status).toBe('Unprotected');
  });

  test('PATCH /devices/:id/status - Block status updates from non-owner accounts', async () => {
    await request(app)
      .post('/devices/enroll')
      .set('Authorization', `Bearer ${authToken}`)
      .send(testDevice);

    const res = await request(app)
      .patch(`/devices/${testDevice.deviceId}/status`)
      .set('Authorization', `Bearer ${otherAuthToken}`) // Different user
      .send({ status: 'Unprotected' });

    expect(res.statusCode).toBe(403);
    expect(res.body.message).toContain('You do not own this device');
  });
});
