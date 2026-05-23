const Message = require('../models/Message');
const Match = require('../models/Match');
const { parseError } = require('../utils/errorHandler');
const path = require('path');

const getMessages = async (req, res) => {
  try {
    const { matchId } = req.params;
    const limit = parseInt(req.query.limit) || 30;
    const before = req.query.before;

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) {
      return res.status(403).json({ message: 'You do not have access to this conversation.' });
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

    await Message.updateMany(
      { matchId, readBy: { $ne: req.userId } },
      { $addToSet: { readBy: req.userId } }
    );

    res.json({ messages: messages.reverse() });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const sendMessage = async (req, res) => {
  try {
    const { matchId } = req.params;
    const { text } = req.body;

    if (!text || text.trim().length === 0) {
      return res.status(400).json({ message: 'Message cannot be empty.' });
    }
    if (text.length > 1000) {
      return res.status(400).json({ message: 'Message is too long. Maximum 1000 characters.' });
    }

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) {
      return res.status(403).json({ message: 'You do not have access to this conversation.' });
    }
    if (match.unmatchedBy) {
      return res.status(403).json({ message: 'This match has been removed. You can no longer send messages.' });
    }

    const message = await Message.create({
      matchId,
      senderId: req.userId,
      text: text.trim(),
      readBy: [req.userId],
    });

    match.lastMessage = message._id;
    match.lastMessageAt = message.createdAt;
    await match.save();

    await message.populate('senderId', 'name photos');

    const io = req.app.get('io');
    if (io) {
      io.to(matchId).emit('chat:message', { message });
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const sendPhotoMessage = async (req, res) => {
  try {
    const { matchId } = req.params;

    if (!req.file) {
      return res.status(400).json({ message: 'No photo provided.' });
    }

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) {
      return res.status(403).json({ message: 'You do not have access to this conversation.' });
    }
    if (match.unmatchedBy) {
      return res.status(403).json({ message: 'This match has been removed. You can no longer send messages.' });
    }

    const mediaUrl = `/uploads/${req.file.filename}`;

    const message = await Message.create({
      matchId,
      senderId: req.userId,
      text: '📷 Photo',
      mediaUrl,
      readBy: [req.userId],
    });

    match.lastMessage = message._id;
    match.lastMessageAt = message.createdAt;
    await match.save();

    await message.populate('senderId', 'name photos');

    const io = req.app.get('io');
    if (io) {
      io.to(matchId).emit('chat:message', { message });
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { getMessages, sendMessage, sendPhotoMessage };
