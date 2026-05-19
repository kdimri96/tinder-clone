const express = require('express');
const { authenticate } = require('../middleware/auth');
const { reportUser, blockUser } = require('../controllers/reportController');
const { body, validationResult } = require('express-validator');
const router = express.Router();
router.use(authenticate);
router.post('/report', [body('reportedId').notEmpty(), body('reason').notEmpty()], (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
}, reportUser);
router.post('/block', [body('blockedId').notEmpty()], (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
}, blockUser);
module.exports = router;
