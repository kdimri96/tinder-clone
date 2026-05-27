const mongoose = require('mongoose');

const matchSchema = new mongoose.Schema({
  users: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  }],
  lastMessage: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null,
  },
  unmatchedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  lastMessageAt: {
    type: Date,
    default: null,
  },
  isSuperLike: {
    type: Boolean,
    default: false,
  },
  superLikeBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
}, {
  timestamps: true,
});

matchSchema.index({ users: 1 });
matchSchema.index({ lastMessageAt: -1 });

module.exports = mongoose.model('Match', matchSchema);
