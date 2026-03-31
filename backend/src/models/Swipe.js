const mongoose = require('mongoose');

const swipeSchema = new mongoose.Schema({
  swiperId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  targetId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  direction: {
    type: String,
    enum: ['like', 'dislike', 'superlike'],
    required: true,
  },
}, {
  timestamps: true,
});

swipeSchema.index({ swiperId: 1, targetId: 1 }, { unique: true });
swipeSchema.index({ targetId: 1, direction: 1 });

module.exports = mongoose.model('Swipe', swipeSchema);
