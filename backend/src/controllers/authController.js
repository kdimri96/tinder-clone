const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const axios = require('axios');
const User = require('../models/User');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

const generateTokens = (userId) => {
  const token = jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
  });
  const refreshToken = jwt.sign({ id: userId }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  });
  return { token, refreshToken };
};

const register = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    const user = await User.create({ name, email, password });
    const { token, refreshToken } = generateTokens(user._id);

    res.status(201).json({ message: 'Registration successful', token, refreshToken, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select('+password');
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    user.lastActive = new Date();
    await user.save({ validateBeforeSave: false });

    const { token, refreshToken } = generateTokens(user._id);

    res.json({ message: 'Login successful', token, refreshToken, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const socialLogin = async (req, res) => {
  try {
    const { provider, token, name, email } = req.body;

    if (!provider || !token) {
      return res.status(400).json({ message: 'Provider and token are required' });
    }

    let providerUserId, verifiedEmail, verifiedName;

    if (provider === 'google') {
      // Verify Google ID token
      const clientId = process.env.GOOGLE_CLIENT_ID;
      if (!clientId) {
        return res.status(500).json({ message: 'Google Sign-In not configured on server' });
      }
      const ticket = await googleClient.verifyIdToken({
        idToken: token,
        audience: clientId,
      });
      const payload = ticket.getPayload();
      providerUserId = `google_${payload.sub}`;
      verifiedEmail = payload.email;
      verifiedName = payload.name || name;

    } else if (provider === 'facebook') {
      // Verify Facebook access token via Graph API
      const fbResponse = await axios.get(
        `https://graph.facebook.com/me?fields=id,name,email&access_token=${token}`
      );
      const fbData = fbResponse.data;
      if (!fbData.id) {
        return res.status(401).json({ message: 'Invalid Facebook token' });
      }
      providerUserId = `facebook_${fbData.id}`;
      verifiedEmail = fbData.email || email;
      verifiedName = fbData.name || name;

    } else if (provider === 'apple') {
      // Apple identity token is a JWT signed by Apple
      // We decode without verifying here (verification requires fetching Apple's public keys)
      // For production, use a dedicated library like 'apple-signin-auth'
      const decoded = jwt.decode(token);
      if (!decoded || !decoded.sub) {
        return res.status(401).json({ message: 'Invalid Apple token' });
      }
      providerUserId = `apple_${decoded.sub}`;
      verifiedEmail = decoded.email || email;
      verifiedName = name; // Apple only provides name on first login

    } else {
      return res.status(400).json({ message: `Unsupported provider: ${provider}` });
    }

    // Find or create user
    let user = await User.findOne({
      $or: [
        { providerId: providerUserId },
        ...(verifiedEmail ? [{ email: verifiedEmail }] : []),
      ],
    });

    if (!user) {
      user = await User.create({
        name: verifiedName || 'User',
        email: verifiedEmail || `${providerUserId}@noemail.com`,
        providerId: providerUserId,
        provider,
        password: require('crypto').randomBytes(32).toString('hex'), // random unusable password
      });
    } else if (!user.providerId) {
      // Existing email user — link provider
      user.providerId = providerUserId;
      user.provider = provider;
      await user.save({ validateBeforeSave: false });
    }

    user.lastActive = new Date();
    await user.save({ validateBeforeSave: false });

    const tokens = generateTokens(user._id);

    res.json({ message: 'Social login successful', ...tokens, user });
  } catch (error) {
    if (error.response?.data) {
      return res.status(401).json({ message: 'Social token verification failed' });
    }
    res.status(500).json({ message: error.message });
  }
};

const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ message: 'Refresh token required' });
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(401).json({ message: 'User not found' });
    }

    const tokens = generateTokens(user._id);
    res.json({ token: tokens.token, refreshToken: tokens.refreshToken });
  } catch (error) {
    res.status(401).json({ message: 'Invalid refresh token' });
  }
};

const getMe = async (req, res) => {
  res.json({ user: req.user });
};

module.exports = { register, login, socialLogin, refreshToken, getMe };
