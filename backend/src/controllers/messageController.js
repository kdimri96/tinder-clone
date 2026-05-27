const fs = require('fs');
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
      const otherUserId = match.users.map((u) => u.toString()).find((id) => id !== req.userId.toString());
      if (otherUserId) {
        io.to(otherUserId).emit('chat:notification', {
          matchId,
          senderName: message.senderId?.name || 'Someone',
          text: text.trim(),
        });
      }
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
      const otherUserId = match.users.map((u) => u.toString()).find((id) => id !== req.userId.toString());
      if (otherUserId) {
        io.to(otherUserId).emit('chat:notification', {
          matchId,
          senderName: message.senderId?.name || 'Someone',
          text: '📷 Photo',
        });
      }
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const sendAudioMessage = async (req, res) => {
  try {
    const { matchId } = req.params;
    const duration = parseFloat(req.body.duration) || 0;

    if (!req.file) return res.status(400).json({ message: 'No audio file provided.' });

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) return res.status(403).json({ message: 'No access to this conversation.' });
    if (match.unmatchedBy) return res.status(403).json({ message: 'This match has been removed.' });

    const mediaUrl = `/uploads/${req.file.filename}`;
    const message = await Message.create({
      matchId,
      senderId: req.userId,
      text: '🎵 Voice message',
      mediaUrl,
      mediaType: 'audio',
      audioDuration: duration,
      readBy: [req.userId],
    });

    match.lastMessage = message._id;
    match.lastMessageAt = message.createdAt;
    await match.save();
    await message.populate('senderId', 'name photos');

    const io = req.app.get('io');
    if (io) {
      io.to(matchId).emit('chat:message', { message });
      const otherId = match.users.map((u) => u.toString()).find((id) => id !== req.userId.toString());
      if (otherId) {
        io.to(otherId).emit('chat:notification', { matchId, senderName: message.senderId?.name || 'Someone', text: '🎵 Voice message' });
      }
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const sendSnapMessage = async (req, res) => {
  try {
    const { matchId } = req.params;

    if (!req.file) return res.status(400).json({ message: 'No file provided.' });

    const match = await Match.findOne({ _id: matchId, users: req.userId });
    if (!match) return res.status(403).json({ message: 'No access to this conversation.' });
    if (match.unmatchedBy) return res.status(403).json({ message: 'This match has been removed.' });

    const mediaUrl = `/uploads/${req.file.filename}`;
    const message = await Message.create({
      matchId,
      senderId: req.userId,
      text: '📸 Snap',
      mediaUrl,
      mediaType: 'snap',
      isSnap: true,
      snapViewedBy: [],
      readBy: [req.userId],
    });

    match.lastMessage = message._id;
    match.lastMessageAt = message.createdAt;
    await match.save();
    await message.populate('senderId', 'name photos');

    const io = req.app.get('io');
    if (io) {
      io.to(matchId).emit('chat:message', { message });
      const otherId = match.users.map((u) => u.toString()).find((id) => id !== req.userId.toString());
      if (otherId) {
        io.to(otherId).emit('chat:notification', { matchId, senderName: message.senderId?.name || 'Someone', text: '📸 Snap' });
      }
    }

    res.status(201).json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const viewSnap = async (req, res) => {
  try {
    const { messageId } = req.params;
    const message = await Message.findOne({ _id: messageId, isSnap: true });

    if (!message) return res.status(404).json({ message: 'Snap not found.' });

    // Prevent the sender from "viewing" their own snap through this endpoint
    if (message.senderId.toString() === req.userId.toString()) {
      return res.status(400).json({ message: 'Sender cannot view their own snap.' });
    }

    // Already viewed
    if (message.snapViewedBy.map((id) => id.toString()).includes(req.userId.toString())) {
      return res.json({ message, alreadyViewed: true });
    }

    message.snapViewedBy.push(req.userId);
    await message.save();

    // Delete the file from disk so it can never be retrieved again
    if (message.mediaUrl) {
      const filePath = path.join(process.cwd(), message.mediaUrl);
      fs.unlink(filePath, () => {}); // best-effort, ignore errors
    }

    await message.populate('senderId', 'name photos');

    // Notify the sender in real-time that the snap was opened
    const io = req.app.get('io');
    if (io) {
      io.to(message.matchId.toString()).emit('snap:viewed', {
        messageId: message._id,
        viewedBy: req.userId,
      });
    }

    res.json({ message });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { getMessages, sendMessage, sendPhotoMessage, sendAudioMessage, sendSnapMessage, viewSnap };
