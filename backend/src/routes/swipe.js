const express = require('express');
const { authenticate } = require('../middleware/auth');
const { swipe, rewind } = require('../controllers/swipeController');

const router = express.Router();

router.use(authenticate);
router.post('/', swipe);
router.post('/rewind', rewind);

module.exports = router;
