const express = require('express');
const { body, validationResult } = require('express-validator');
const { getPlans, createOrder, verifyPayment } = require('../controllers/paymentController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

router.use(authenticate);

router.get('/plans', getPlans);

router.post(
  '/create-order',
  [body('planId').notEmpty().withMessage('planId is required')],
  validate,
  createOrder
);

router.post(
  '/verify',
  [
    body('razorpay_order_id').notEmpty(),
    body('razorpay_payment_id').notEmpty(),
    body('razorpay_signature').notEmpty(),
    body('planId').notEmpty(),
  ],
  validate,
  verifyPayment
);

module.exports = router;
