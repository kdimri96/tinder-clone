const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const axios = require('axios');
const User = require('../models/User');
const { parseError } = require('../utils/errorHandler');

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

    if (!name || name.trim().length < 2) {
      return res.status(400).json({ message: 'Name must be at least 2 characters.' });
    }
    if (!email || !email.includes('@')) {
      return res.status(400).json({ message: 'Please enter a valid email address.' });
    }
    if (!password || password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(400).json({ message: 'This email is already registered. Please log in.' });
    }

    const user = await User.create({ name: name.trim(), email: email.toLowerCase(), password });
    const { token, refreshToken } = generateTokens(user._id);

    res.status(201).json({ message: 'Account created successfully!', token, refreshToken, user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }

    const user = await User.findOne({ email: email.toLowerCase() }).select('+password');
    if (!user) {
      return res.status(401).json({ message: 'No account found with this email.' });
    }
    if (!user.password) {
      return res.status(401).json({ message: 'This account uses social login. Please sign in with Google, Facebook or Apple.' });
    }
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Incorrect password. Please try again.' });
    }

    user.lastActive = new Date();
    await user.save({ validateBeforeSave: false });

    const { token, refreshToken } = generateTokens(user._id);
    res.json({ message: 'Logged in successfully!', token, refreshToken, user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const socialLogin = async (req, res) => {
  try {
    const { provider, token, name, email } = req.body;

    if (!provider || !token) {
      return res.status(400).json({ message: 'Provider and token are required.' });
    }

    let providerUserId, verifiedEmail, verifiedName;

    if (provider === 'google') {
      const clientId = process.env.GOOGLE_CLIENT_ID;
      if (!clientId) {
        return res.status(500).json({ message: 'Google Sign-In is not configured on the server.' });
      }
      const ticket = await googleClient.verifyIdToken({ idToken: token, audience: clientId });
      const payload = ticket.getPayload();
      providerUserId = `google_${payload.sub}`;
      verifiedEmail = payload.email;
      verifiedName = payload.name || name;

    } else if (provider === 'facebook') {
      const fbResponse = await axios.get(
        `https://graph.facebook.com/me?fields=id,name,email&access_token=${token}`
      );
      const fbData = fbResponse.data;
      if (!fbData.id) {
        return res.status(401).json({ message: 'Facebook login failed. Please try again.' });
      }
      providerUserId = `facebook_${fbData.id}`;
      verifiedEmail = fbData.email || email;
      verifiedName = fbData.name || name;

    } else if (provider === 'apple') {
      const decoded = jwt.decode(token);
      if (!decoded || !decoded.sub) {
        return res.status(401).json({ message: 'Apple login failed. Please try again.' });
      }
      providerUserId = `apple_${decoded.sub}`;
      verifiedEmail = decoded.email || email;
      verifiedName = name;

    } else {
      return res.status(400).json({ message: `Sign-in with "${provider}" is not supported.` });
    }

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
        password: require('crypto').randomBytes(32).toString('hex'),
      });
    } else if (!user.providerId) {
      user.providerId = providerUserId;
      user.provider = provider;
      await user.save({ validateBeforeSave: false });
    }

    user.lastActive = new Date();
    await user.save({ validateBeforeSave: false });

    const tokens = generateTokens(user._id);
    res.json({ message: 'Logged in successfully!', ...tokens, user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ message: 'Refresh token is required.' });
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(401).json({ message: 'Account no longer exists. Please register again.' });
    }

    const tokens = generateTokens(user._id);
    res.json({ token: tokens.token, refreshToken: tokens.refreshToken });
  } catch (error) {
    res.status(401).json({ message: 'Session expired. Please log in again.' });
  }
};

const getMe = async (req, res) => {
  res.json({ user: req.user });
};

module.exports = { register, login, socialLogin, refreshToken, getMe };
