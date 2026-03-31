const Message = require('../models/Message');
const Match = require('../models/Match');

const getMessages = async (req, res) => {
  try {
    const { matchId } = req.params;
    const limit = parseInt(req.query.limit) || 30;
    const before = req.query.before;

    // Verify user is part of this match
    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const query = { matchId };
    if (before) {
      const beforeMsg = await Message.findById(before);
      if (beforeMsg) query.createdAt = { $lt: beforeMsg.createdAt };
    }

    const messages = await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate('senderId', 'name photos');

    // Mark unread messages as read
    await Message.updateMany(
      { matchId, readBy: { $ne: req.userId } },
      { $addToSet: { readBy: req.userId } }
    );

    res.json({ messages: messages.reverse() });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const sendMessage = async (req, res) => {
  try {
    const { matchId } = req.params;
    const { text } = req.body;

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) {
      return res.status(403).json({ message: 'Access denied' });
    }

    const message = await Message.create({
      matchId,
      senderId: req.userId,
      text,
      readBy: [req.userId],
    });

    // Update match's last message
    match.lastMessage = message._id;
    match.lastMessageAt = message.createdAt;
    await match.save();

    await message.populate('senderId', 'name photos');

    // Emit via socket
    const io = req.app.get('io');
    if (io) {
      io.to(matchId).emit('chat:message', { message });
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getMessages, sendMessage };
