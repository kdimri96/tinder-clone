const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  matchId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Match',
    required: true,
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  text: {
    type: String,
    default: '',
    maxlength: [2000, 'Message cannot exceed 2000 characters'],
  },
  mediaUrl: {
    type: String,
    default: null,
  },
  // 'image' | 'audio' | 'snap'  (null = plain text)
  mediaType: {
    type: String,
    enum: ['image', 'audio', 'snap', null],
    default: null,
  },
  audioDuration: {
    type: Number,   // seconds
    default: null,
  },
  isSnap: {
    type: Boolean,
    default: false,
  },
  snapViewedBy: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
  readBy: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
}, {
  timestamps: true,
});

messageSchema.index({ matchId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);
