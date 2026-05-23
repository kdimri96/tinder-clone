const Swipe = require('../models/Swipe');
const Match = require('../models/Match');
const User = require('../models/User');
const { parseError } = require('../utils/errorHandler');

const swipe = async (req, res) => {
  try {
    const { targetId, direction } = req.body;
    const swiperId = req.userId;

    if (!targetId) {
      return res.status(400).json({ message: 'Target user ID is required.' });
    }
    if (!['like', 'dislike', 'superlike'].includes(direction)) {
      return res.status(400).json({ message: 'Direction must be like, dislike, or superlike.' });
    }
    if (swiperId === targetId) {
      return res.status(400).json({ message: 'You cannot swipe on yourself.' });
    }

    const targetUser = await User.findById(targetId);
    if (!targetUser) {
      return res.status(404).json({ message: 'This user no longer exists.' });
    }

    await Swipe.findOneAndUpdate(
      { swiperId, targetId },
      { direction },
      { upsert: true, new: true }
    );

    const io = req.app.get('io');
    let match = null;

    if (direction === 'like' || direction === 'superlike') {
      // Notify target user that someone liked them (without revealing who)
      if (io) {
        io.to(targetId).emit('liked:you', { count: 1 });
      }
      const mutualSwipe = await Swipe.findOne({
        swiperId: targetId,
        targetId: swiperId,
        direction: { $in: ['like', 'superlike'] },
      });

      if (mutualSwipe) {
        const existingMatch = await Match.findOne({
          users: { $all: [swiperId, targetId] },
          unmatchedBy: null,
        });

        if (!existingMatch) {
          match = await Match.create({ users: [swiperId, targetId] });
          await match.populate('users', 'name photos age');

          if (io) {
            io.to(swiperId).emit('match', { match });
            io.to(targetId).emit('match', { match });
          }
        }
      }
    }

    res.json({ message: 'Swipe recorded.', match });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const rewind = async (req, res) => {
  try {
    const lastSwipe = await Swipe.findOne({ swiperId: req.userId }).sort({ createdAt: -1 });
    if (!lastSwipe) {
      return res.status(404).json({ message: 'No swipe to undo. Swipe on someone first!' });
    }

    await Match.findOneAndDelete({
      users: { $all: [req.userId, lastSwipe.targetId] },
      createdAt: { $gte: new Date(lastSwipe.createdAt.getTime() - 2000) },
    });

    const targetUser = await User.findById(lastSwipe.targetId)
      .select('name photos age bio job distance');

    if (!targetUser) {
      await lastSwipe.deleteOne();
      return res.status(404).json({ message: 'That user no longer exists.' });
    }

    await lastSwipe.deleteOne();
    res.json({ message: 'Last swipe undone.', user: targetUser });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { swipe, rewind };
