const Razorpay = require('razorpay');
const crypto = require('crypto');
const User = require('../models/User');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// Plan definitions (amounts in paise — 1 INR = 100 paise)
const PLANS = {
  unlimited_likes_monthly: {
    amount: 39900,       // ₹399
    currency: 'INR',
    description: 'Unlimited Likes — 30 days',
    durationDays: 30,
    feature: 'unlimited_likes',
  },
  boost_profile_24h: {
    amount: 9900,        // ₹99
    currency: 'INR',
    description: 'Profile Boost — 24 hours',
    durationDays: 1,
    feature: 'boost',
  },
  premium_monthly: {
    amount: 49900,       // ₹499
    currency: 'INR',
    description: 'KneedYou Gold — 30 days (Unlimited Likes + Boost)',
    durationDays: 30,
    feature: 'premium',
  },
};

/**
 * GET /api/payments/plans
 * Returns available plans and current premium status.
 */
const getPlans = async (req, res) => {
  try {
    const user = await User.findById(req.userId).select(
      'isPremium isUnlimitedLikes isBoosted premiumExpiresAt boostExpiresAt unlimitedLikesExpiresAt'
    );

    const now = new Date();

    res.json({
      plans: Object.entries(PLANS).map(([id, plan]) => ({
        id,
        amount: plan.amount,
        amountDisplay: `₹${plan.amount / 100}`,
        currency: plan.currency,
        description: plan.description,
        durationDays: plan.durationDays,
        feature: plan.feature,
      })),
      currentStatus: {
        isPremium: user.isPremium && user.premiumExpiresAt > now,
        isUnlimitedLikes: user.isUnlimitedLikes && user.unlimitedLikesExpiresAt > now,
        isBoosted: user.isBoosted && user.boostExpiresAt > now,
        premiumExpiresAt: user.premiumExpiresAt,
        unlimitedLikesExpiresAt: user.unlimitedLikesExpiresAt,
        boostExpiresAt: user.boostExpiresAt,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

/**
 * POST /api/payments/create-order
 * Body: { planId }
 * Creates a Razorpay order and returns the order details to the client.
 */
const createOrder = async (req, res) => {
  try {
    const { planId } = req.body;
    const plan = PLANS[planId];

    if (!plan) {
      return res.status(400).json({ message: 'Invalid plan ID' });
    }

    const order = await razorpay.orders.create({
      amount: plan.amount,
      currency: plan.currency,
      notes: {
        userId: req.userId.toString(),
        planId,
        feature: plan.feature,
      },
    });

    res.json({
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
      planId,
      description: plan.description,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

/**
 * POST /api/payments/verify
 * Body: { razorpay_order_id, razorpay_payment_id, razorpay_signature, planId }
 * Verifies the payment signature and activates the plan.
 */
const verifyPayment = async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, planId } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature || !planId) {
      return res.status(400).json({ message: 'Missing payment verification fields' });
    }

    // Verify HMAC signature
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    if (expectedSignature !== razorpay_signature) {
      return res.status(400).json({ message: 'Payment verification failed — invalid signature' });
    }

    const plan = PLANS[planId];
    if (!plan) {
      return res.status(400).json({ message: 'Invalid plan ID' });
    }

    // Activate the plan
    const now = new Date();
    const expiresAt = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);
    const update = {};

    if (plan.feature === 'unlimited_likes') {
      update.isUnlimitedLikes = true;
      update.unlimitedLikesExpiresAt = expiresAt;
    } else if (plan.feature === 'boost') {
      update.isBoosted = true;
      update.boostExpiresAt = expiresAt;
    } else if (plan.feature === 'premium') {
      update.isPremium = true;
      update.premiumExpiresAt = expiresAt;
      update.isUnlimitedLikes = true;
      update.unlimitedLikesExpiresAt = expiresAt;
      update.isBoosted = true;
      update.boostExpiresAt = expiresAt;
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $set: update },
      { new: true }
    );

    res.json({
      message: 'Payment verified and plan activated',
      feature: plan.feature,
      expiresAt,
      user,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { getPlans, createOrder, verifyPayment };
