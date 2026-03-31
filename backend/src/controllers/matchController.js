const Match = require('../models/Match');
const Message = require('../models/Message');

const getMatches = async (req, res) => {
  try {
    const matches = await Match.find({
      users: req.userId,
      unmatchedBy: { $ne: req.userId },
    })
      .populate('users', 'name photos age bio lastActive')
      .populate('lastMessage')
      .sort({ lastMessageAt: -1, createdAt: -1 });

    // Format matches to show the other user's info
    const formatted = matches.map((match) => {
      const matchObj = match.toObject();
      matchObj.otherUser = matchObj.users.find(
        (u) => u._id.toString() !== req.userId
      );
      return matchObj;
    });

    res.json({ matches: formatted });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getMatch = async (req, res) => {
  try {
    const match = await Match.findOne({
      _id: req.params.matchId,
      users: req.userId,
    }).populate('users', 'name photos age bio job school interests lastActive');

    if (!match) {
      return res.status(404).json({ message: 'Match not found' });
    }

    const matchObj = match.toObject();
    matchObj.otherUser = matchObj.users.find(
      (u) => u._id.toString() !== req.userId
    );

    res.json({ match: matchObj });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const unmatch = async (req, res) => {
  try {
    const match = await Match.findOne({
      _id: req.params.matchId,
      users: req.userId,
    });

    if (!match) {
      return res.status(404).json({ message: 'Match not found' });
    }

    match.unmatchedBy = req.userId;
    await match.save();

    res.json({ message: 'Unmatched successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getMatches, getMatch, unmatch };
