const Report = require('../models/Report');
const User = require('../models/User');
const Match = require('../models/Match');
const { parseError } = require('../utils/errorHandler');

const reportUser = async (req, res) => {
  try {
    const { reportedId, reason, details } = req.body;

    if (!reportedId) {
      return res.status(400).json({ message: 'User ID to report is required.' });
    }
    if (req.userId === reportedId) {
      return res.status(400).json({ message: 'You cannot report yourself.' });
    }
    if (!reason || reason.trim().length === 0) {
      return res.status(400).json({ message: 'Please provide a reason for the report.' });
    }

    const reportedUser = await User.findById(reportedId);
    if (!reportedUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    await Report.findOneAndUpdate(
      { reporterId: req.userId, reportedId },
      { reason, details: details || '' },
      { upsert: true, new: true }
    );

    await User.findByIdAndUpdate(req.userId, { $addToSet: { blockedUsers: reportedId } });
    await Match.findOneAndUpdate(
      { users: { $all: [req.userId, reportedId] } },
      { unmatchedBy: req.userId }
    );

    res.json({ message: 'User reported and blocked successfully.' });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const blockUser = async (req, res) => {
  try {
    const { blockedId } = req.body;

    if (!blockedId) {
      return res.status(400).json({ message: 'User ID to block is required.' });
    }
    if (req.userId === blockedId) {
      return res.status(400).json({ message: 'You cannot block yourself.' });
    }

    const blockedUser = await User.findById(blockedId);
    if (!blockedUser) {
      return res.status(404).json({ message: 'User not found.' });
    }

    await User.findByIdAndUpdate(req.userId, { $addToSet: { blockedUsers: blockedId } });
    await Match.findOneAndUpdate(
      { users: { $all: [req.userId, blockedId] } },
      { unmatchedBy: req.userId }
    );

    res.json({ message: 'User blocked successfully.' });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { reportUser, blockUser };
