const User = require('../models/User');
const path = require('path');
const fs = require('fs');

const getProfile = async (req, res) => {
  res.json({ user: req.user });
};

const updateProfile = async (req, res) => {
  try {
    const allowedFields = ['name', 'age', 'gender', 'bio', 'job', 'school', 'interests', 'preferences'];
    const updates = {};

    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        updates[field] = req.body[field];
      }
    });

    if (req.body.latitude !== undefined && req.body.longitude !== undefined) {
      updates.location = {
        type: 'Point',
        coordinates: [parseFloat(req.body.longitude), parseFloat(req.body.latitude)],
      };
    }

    // Check if profile is complete
    const user = await User.findByIdAndUpdate(req.userId, updates, { new: true, runValidators: true });
    const isComplete = user.name && user.age && user.gender && user.photos && user.photos.length > 0;
    if (isComplete && !user.isProfileComplete) {
      user.isProfileComplete = true;
      await user.save();
    }

    res.json({ message: 'Profile updated', user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const uploadPhoto = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const photoUrl = `/uploads/${req.file.filename}`;
    const user = await User.findByIdAndUpdate(
      req.userId,
      { $push: { photos: photoUrl } },
      { new: true }
    );

    res.json({ message: 'Photo uploaded', photoUrl, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const deletePhoto = async (req, res) => {
  try {
    const { photoUrl } = req.body;
    if (!photoUrl) {
      return res.status(400).json({ message: 'Photo URL required' });
    }

    // Security: only allow deleting from uploads directory
    const filename = path.basename(photoUrl);
    const filePath = path.join(process.env.UPLOAD_DIR || 'uploads', filename);

    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { $pull: { photos: photoUrl } },
      { new: true }
    );

    res.json({ message: 'Photo deleted', user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getProfile, updateProfile, uploadPhoto, deletePhoto };
