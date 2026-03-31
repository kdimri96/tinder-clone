const express = require('express');
const { authenticate } = require('../middleware/auth');
const { getMatches, getMatch, unmatch } = require('../controllers/matchController');

const router = express.Router();

router.use(authenticate);
router.get('/', getMatches);
router.get('/:matchId', getMatch);
router.delete('/:matchId', unmatch);

module.exports = router;
