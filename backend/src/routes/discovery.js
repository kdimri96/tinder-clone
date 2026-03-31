const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getNearby } = require('../controllers/discoveryController');

const router = express.Router();

router.use(authenticate);
router.get('/nearby', getNearby);

module.exports = router;
