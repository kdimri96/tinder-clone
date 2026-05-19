const Swipe = require('../models/Swipe');
const Match = require('../models/Match');
const User = require('../models/User');

const swipe = async (req, res) => {
  try {
    const { targetId, direction } = req.body;
    const swiperId = req.userId;

    if (swiperId === targetId) {
      return res.status(400).json({ message: 'Cannot swipe on yourself' });
    }

    const targetUser = await User.findById(targetId);
    if (!targetUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Record the swipe (upsert in case of re-swipe)
    await Swipe.findOneAndUpdate(
      { swiperId, targetId },
      { direction },
      { upsert: true, new: true }
    );

    let match = null;

    // Check for mutual match if the swipe is positive
    if (direction === 'like' || direction === 'superlike') {
      const mutualSwipe = await Swipe.findOne({
        swiperId: targetId,
        targetId: swiperId,
        direction: { $in: ['like', 'superlike'] },
      });

      if (mutualSwipe) {
        // Check if match already exists
        const existingMatch = await Match.findOne({
          users: { $all: [swiperId, targetId] },
          unmatchedBy: null,
        });

        if (!existingMatch) {
          match = await Match.create({
            users: [swiperId, targetId],
          });

          await match.populate('users', 'name photos age');

          // Emit match event via socket
          const io = req.app.get('io');
          if (io) {
            io.to(swiperId).emit('match', { match });
            io.to(targetId).emit('match', { match });
          }
        }
      }
    }

    res.json({ message: 'Swipe recorded', match });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const rewind = async (req, res) => {
  try {
    const lastSwipe = await Swipe.findOne({ swiperId: req.userId })
      .sort({ createdAt: -1 });
    if (!lastSwipe) {
      return res.status(404).json({ message: 'No swipe to rewind' });
    }
    // If it was a like that created a match, remove the match too
    await Match.findOneAndDelete({
      users: { $all: [req.userId, lastSwipe.targetId] },
      createdAt: { $gte: new Date(lastSwipe.createdAt.getTime() - 2000) },
    });
    const targetUser = await User.findById(lastSwipe.targetId)
      .select('name photos age bio job distance');
    await lastSwipe.deleteOne();
    res.json({ message: 'Swipe rewound', user: targetUser });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { swipe, rewind };
