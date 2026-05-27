const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getMessages, sendMessage, sendPhotoMessage, sendAudioMessage, sendSnapMessage, viewSnap } = require('../controllers/messageController');
const { upload } = require('../middleware/upload');

const router = express.Router();

router.use(authenticate);
router.get('/:matchId', getMessages);
router.post('/:matchId', sendMessage);
router.post('/:matchId/photo', upload.single('photo'), sendPhotoMessage);
router.post('/:matchId/audio', upload.single('audio'), sendAudioMessage);
router.post('/:matchId/snap', upload.single('snap'), sendSnapMessage);
router.post('/snap/:messageId/view', viewSnap);

module.exports = router;
