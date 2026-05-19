const Report = require('../models/Report');
const User = require('../models/User');
const Match = require('../models/Match');

const reportUser = async (req, res) => {
  try {
    const { reportedId, reason, details } = req.body;
    if (req.userId === reportedId) return res.status(400).json({ message: 'Cannot report yourself' });
    await Report.findOneAndUpdate(
      { reporterId: req.userId, reportedId },
      { reason, details: details || '' },
      { upsert: true, new: true }
    );
    // Also block the user
    await User.findByIdAndUpdate(req.userId, { $addToSet: { blockedUsers: reportedId } });
    // Remove any match between them
    await Match.findOneAndUpdate(
      { users: { $all: [req.userId, reportedId] } },
      { unmatchedBy: req.userId }
    );
    res.json({ message: 'User reported and blocked' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const blockUser = async (req, res) => {
  try {
    const { blockedId } = req.body;
    await User.findByIdAndUpdate(req.userId, { $addToSet: { blockedUsers: blockedId } });
    await Match.findOneAndUpdate(
      { users: { $all: [req.userId, blockedId] } },
      { unmatchedBy: req.userId }
    );
    res.json({ message: 'User blocked' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { reportUser, blockUser };
