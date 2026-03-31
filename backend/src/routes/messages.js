const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getMessages, sendMessage } = require('../controllers/messageController');

const router = express.Router();

router.use(authenticate);
router.get('/:matchId', getMessages);
router.post('/:matchId', sendMessage);

module.exports = router;
