const Match = require('../models/Match');
const Message = require('../models/Message');
const { parseError } = require('../utils/errorHandler');

const getMatches = async (req, res) => {
  try {
    const matches = await Match.find({
      users: req.userId,
      unmatchedBy: { $ne: req.userId },
    })
      .populate('users', 'name photos age bio lastActive')
      .populate('lastMessage')
      .sort({ lastMessageAt: -1, createdAt: -1 });

    const formatted = matches.map((match) => {
      const matchObj = match.toObject();
      matchObj.otherUser = matchObj.users.find(
        (u) => u._id.toString() !== req.userId
      );
      return matchObj;
    });

    res.json({ matches: formatted });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const getMatch = async (req, res) => {
  try {
    const match = await Match.findOne({
      _id: req.params.matchId,
      users: req.userId,
    }).populate('users', 'name photos age bio job school interests lastActive');

    if (!match) {
      return res.status(404).json({ message: 'Match not found or you do not have access to it.' });
    }

    const matchObj = match.toObject();
    matchObj.otherUser = matchObj.users.find(
      (u) => u._id.toString() !== req.userId
    );

    res.json({ match: matchObj });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const unmatch = async (req, res) => {
  try {
    const match = await Match.findOne({
      _id: req.params.matchId,
      users: req.userId,
    });

    if (!match) {
      return res.status(404).json({ message: 'Match not found or already removed.' });
    }

    match.unmatchedBy = req.userId;
    await match.save();

    res.json({ message: 'Unmatched successfully.' });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { getMatches, getMatch, unmatch };
