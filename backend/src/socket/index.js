const jwt = require('jsonwebtoken');
const Message = require('../models/Message');
const Match = require('../models/Match');
const User = require('../models/User');

const setupSocket = (io) => {
  // Auth middleware for socket connections
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('Authentication required'));

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id);
      if (!user) return next(new Error('User not found'));

      socket.userId = user._id.toString();
      socket.user = user;
      next();
    } catch (error) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;

    // Join personal room for direct notifications
    socket.join(userId);

    // Update last active
    await User.findByIdAndUpdate(userId, { lastActive: new Date() });

    // Join all match rooms
    const matches = await Match.find({ users: userId, unmatchedBy: { $ne: userId } });
    matches.forEach((match) => {
      socket.join(match._id.toString());
    });

    // Broadcast online status to match partners
    const matchPartnerIds = matches.flatMap((m) =>
      m.users.filter((u) => u.toString() !== userId).map((u) => u.toString())
    );
    matchPartnerIds.forEach((partnerId) => {
      socket.to(partnerId).emit('presence:online', { userId });
    });

    // Handle sending a message
    socket.on('chat:send', async (data, callback) => {
      try {
        const { matchId, text } = data;

        const match = await Match.findOne({ _id: matchId, users: userId });
        if (!match) {
          return callback?.({ error: 'Match not found' });
        }

        const message = await Message.create({
          matchId,
          senderId: userId,
          text,
          readBy: [userId],
        });

        match.lastMessage = message._id;
        match.lastMessageAt = message.createdAt;
        await match.save();

        await message.populate('senderId', 'name photos');

        io.to(matchId).emit('chat:message', { message });
        callback?.({ success: true, message });
      } catch (error) {
        callback?.({ error: error.message });
      }
    });

    // Handle read receipts
    socket.on('chat:read', async (data) => {
      const { matchId, messageId } = data;
      await Message.updateMany(
        { matchId, readBy: { $ne: userId } },
        { $addToSet: { readBy: userId } }
      );
      socket.to(matchId).emit('chat:read', { matchId, readBy: userId });
    });

    // Typing indicators
    socket.on('typing:start', ({ matchId }) => {
      socket.to(matchId).emit('typing:start', { userId, matchId });
    });

    socket.on('typing:stop', ({ matchId }) => {
      socket.to(matchId).emit('typing:stop', { userId, matchId });
    });

    // Join a new match room (called when a new match is made)
    socket.on('match:join', ({ matchId }) => {
      socket.join(matchId);
    });

    socket.on('disconnect', async () => {
      await User.findByIdAndUpdate(userId, { lastActive: new Date() });
      matchPartnerIds.forEach((partnerId) => {
        socket.to(partnerId).emit('presence:offline', { userId });
      });
    });
  });
};

module.exports = { setupSocket };
