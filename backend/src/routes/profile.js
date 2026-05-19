const express = require('express');
const { authenticate } = require('../middleware/auth');
const { upload } = require('../middleware/upload');
const { getProfile, updateProfile, uploadPhoto, deletePhoto, updatePreferences } = require('../controllers/profileController');

const router = express.Router();

router.use(authenticate);

router.get('/', getProfile);
router.put('/', updateProfile);
router.patch('/', updateProfile);
router.post('/photo', upload.single('photo'), uploadPhoto);
router.delete('/photo', deletePhoto);
router.patch('/preferences', updatePreferences);

module.exports = router;
