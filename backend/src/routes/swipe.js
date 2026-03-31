const express = require('express');
const { authenticate } = require('../middleware/auth');
const { swipe } = require('../controllers/swipeController');

const router = express.Router();

router.use(authenticate);
router.post('/', swipe);

module.exports = router;
