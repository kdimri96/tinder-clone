const User = require('../models/User');
const path = require('path');
const fs = require('fs');
const { parseError } = require('../utils/errorHandler');

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

    if (req.body.age !== undefined) {
      const age = parseInt(req.body.age);
      if (isNaN(age) || age < 18 || age > 100) {
        return res.status(400).json({ message: 'Age must be between 18 and 100.' });
      }
    }

    if (req.body.gender && !['male', 'female', 'other'].includes(req.body.gender)) {
      return res.status(400).json({ message: 'Gender must be male, female, or other.' });
    }

    if (req.body.bio && req.body.bio.length > 500) {
      return res.status(400).json({ message: 'Bio cannot exceed 500 characters.' });
    }

    if (req.body.latitude !== undefined && req.body.longitude !== undefined) {
      updates.location = {
        type: 'Point',
        coordinates: [parseFloat(req.body.longitude), parseFloat(req.body.latitude)],
      };
    }

    const user = await User.findByIdAndUpdate(req.userId, updates, { new: true, runValidators: true });
    const isComplete = user.name && user.age && user.gender && user.photos && user.photos.length > 0;
    if (isComplete && !user.isProfileComplete) {
      user.isProfileComplete = true;
      await user.save();
    }

    res.json({ message: 'Profile updated successfully.', user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const uploadPhoto = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No photo selected. Please choose an image to upload.' });
    }

    const user = await User.findById(req.userId);
    if (user.photos.length >= 6) {
      return res.status(400).json({ message: 'You can upload a maximum of 6 photos. Delete one to add a new photo.' });
    }

    const photoUrl = `/uploads/${req.file.filename}`;
    const updatedUser = await User.findByIdAndUpdate(
      req.userId,
      { $push: { photos: photoUrl } },
      { new: true }
    );

    res.json({ message: 'Photo uploaded successfully.', photoUrl, user: updatedUser });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const deletePhoto = async (req, res) => {
  try {
    const { photoUrl } = req.body;
    if (!photoUrl) {
      return res.status(400).json({ message: 'Photo URL is required to delete a photo.' });
    }

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

    res.json({ message: 'Photo deleted successfully.', user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const updatePreferences = async (req, res) => {
  try {
    const { genderPreference, minAge, maxAge, maxDistance } = req.body;
    const updates = {};

    if (genderPreference) {
      const valid = ['male', 'female', 'other'];
      const invalid = genderPreference.filter(g => !valid.includes(g));
      if (invalid.length > 0) {
        return res.status(400).json({ message: `Invalid gender values: ${invalid.join(', ')}.` });
      }
      updates['preferences.genderPreference'] = genderPreference;
    }

    if (minAge !== undefined) {
      if (minAge < 18 || minAge > 100) {
        return res.status(400).json({ message: 'Minimum age must be between 18 and 100.' });
      }
      updates['preferences.minAge'] = minAge;
    }

    if (maxAge !== undefined) {
      if (maxAge < 18 || maxAge > 100) {
        return res.status(400).json({ message: 'Maximum age must be between 18 and 100.' });
      }
      if (minAge !== undefined && maxAge < minAge) {
        return res.status(400).json({ message: 'Maximum age cannot be less than minimum age.' });
      }
      updates['preferences.maxAge'] = maxAge;
    }

    if (maxDistance !== undefined) {
      if (maxDistance < 1 || maxDistance > 500) {
        return res.status(400).json({ message: 'Distance must be between 1 and 500 km.' });
      }
      updates['preferences.maxDistance'] = maxDistance;
    }

    const user = await User.findByIdAndUpdate(req.userId, updates, { new: true });
    res.json({ message: 'Preferences saved successfully.', user });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { getProfile, updateProfile, uploadPhoto, deletePhoto, updatePreferences };
