const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getMessages, sendMessage, sendPhotoMessage } = require('../controllers/messageController');
const { upload } = require('../middleware/upload');

const router = express.Router();

router.use(authenticate);
router.get('/:matchId', getMessages);
router.post('/:matchId', sendMessage);
router.post('/:matchId/photo', upload.single('photo'), sendPhotoMessage);

module.exports = router;
