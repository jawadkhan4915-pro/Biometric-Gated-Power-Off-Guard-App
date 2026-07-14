const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const User = require('../src/models/User');

const TEST_MONGODB_URI = 'mongodb://127.0.0.1:27017/power_guard_test';

beforeAll(async () => {
  jest.setTimeout(60000);
  // Disconnect from standard connection if active
  await mongoose.disconnect();
  await mongoose.connect(TEST_MONGODB_URI);
});

afterAll(async () => {
  await mongoose.connection.db.dropDatabase();
  await mongoose.disconnect();
});

beforeEach(async () => {
  await User.deleteMany({});
});

describe('Authentication API Endpoints', () => {
  const testUser = {
    email: 'test@guard.com',
    password: 'password123'
  };

  test('POST /auth/register - Register new user successfully', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send(testUser);

    expect(res.statusCode).toBe(201);
    expect(res.body).toHaveProperty('accessToken');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body.user.email).toBe(testUser.email);
  });

  test('POST /auth/register - Fail duplicate registrations', async () => {
    await request(app).post('/auth/register').send(testUser);
    const res = await request(app).post('/auth/register').send(testUser);

    expect(res.statusCode).toBe(400);
    expect(res.body.message).toContain('already exists');
  });

  test('POST /auth/login - Login successfully with valid credentials', async () => {
    // Pre-create user
    await request(app).post('/auth/register').send(testUser);

    const res = await request(app)
      .post('/auth/login')
      .send(testUser);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('accessToken');
    expect(res.body).toHaveProperty('refreshToken');
  });

  test('POST /auth/login - Fail login with invalid password', async () => {
    await request(app).post('/auth/register').send(testUser);

    const res = await request(app)
      .post('/auth/login')
      .send({
        email: testUser.email,
        password: 'wrongpassword'
      });

    expect(res.statusCode).toBe(401);
    expect(res.body.message).toContain('Invalid');
  });

  test('POST /auth/refresh - Refresh token successfully', async () => {
    const regRes = await request(app).post('/auth/register').send(testUser);
    const { refreshToken } = regRes.body;

    const res = await request(app)
      .post('/auth/refresh')
      .send({ refreshToken });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('accessToken');
    expect(res.body).toHaveProperty('refreshToken');
  });
});
