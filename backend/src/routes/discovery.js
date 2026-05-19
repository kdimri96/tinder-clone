const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getNearby, getLikedYou } = require('../controllers/discoveryController');

const router = express.Router();

router.use(authenticate);
router.get('/nearby', getNearby);
router.get('/liked-you', getLikedYou);

module.exports = router;
