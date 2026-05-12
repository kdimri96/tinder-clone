const express = require('express');
const { body, validationResult } = require('express-validator');
const { register, login, socialLogin, refreshToken, getMe } = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

router.post(
  '/register',
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  ],
  validate,
  register
);

router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  validate,
  login
);

router.post(
  '/social',
  [
    body('provider').notEmpty().withMessage('Provider is required'),
    body('token').notEmpty().withMessage('Token is required'),
  ],
  validate,
  socialLogin
);

router.post('/refresh-token', refreshToken);
router.get('/me', authenticate, getMe);

module.exports = router;
