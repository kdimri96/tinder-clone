const mongoose = require('mongoose');
const reportSchema = new mongoose.Schema({
  reporterId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  reportedId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  reason: { type: String, enum: ['inappropriate', 'spam', 'fake', 'harassment', 'other'], required: true },
  details: { type: String, default: '' },
}, { timestamps: true });
reportSchema.index({ reporterId: 1, reportedId: 1 }, { unique: true });
module.exports = mongoose.model('Report', reportSchema);
