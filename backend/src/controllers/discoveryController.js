const User = require('../models/User');
const Swipe = require('../models/Swipe');
const Match = require('../models/Match');
const { parseError } = require('../utils/errorHandler');

const getNearby = async (req, res) => {
  try {
    const user = req.user;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const swipedIds = await Swipe.find({ swiperId: req.userId }).distinct('targetId');

    const maxDistance = (user.preferences?.maxDistance || 50) * 1000; // km to metres
    const minAge = user.preferences?.minAge || 18;
    const maxAge = user.preferences?.maxAge || 99;

    // Gender preference — always enforced regardless of distance
    const genderPrefs = (user.preferences?.genderPreference?.length > 0)
      ? user.preferences.genderPreference
      : ['male', 'female', 'other'];

    const myInterests = user.interests || [];
    const blockedUserIds = user.blockedUsers || [];
    const [longitude, latitude] = user.location?.coordinates || [0, 0];
    const hasLocation = !(longitude === 0 && latitude === 0);

    // Gender + age + blocked filters — always applied
    const baseMatch = {
      _id: { $nin: [...swipedIds, ...blockedUserIds, user._id] },
      blockedUsers: { $ne: user._id },
      gender: { $in: genderPrefs },
      age: { $gte: minAge, $lte: maxAge },
      isProfileComplete: true,
    };

    const interestScoreStage = {
      $addFields: {
        interestScore: myInterests.length > 0
          ? { $size: { $ifNull: [{ $setIntersection: ['$interests', myInterests] }, []] } }
          : 0,
      },
    };

    let candidates = [];
    let expandedSearch = false;

    if (hasLocation) {
      // Step 1: try within user's preferred distance
      candidates = await User.aggregate([
        {
          $geoNear: {
            near: { type: 'Point', coordinates: [longitude, latitude] },
            distanceField: 'distance',
            maxDistance,
            spherical: true,
          },
        },
        { $match: baseMatch },
        interestScoreStage,
        { $sort: { interestScore: -1, distance: 1 } },
        { $project: { password: 0, pushTokens: 0 } },
        { $skip: skip },
        { $limit: limit },
      ]);

      // Step 2: if no results within distance, expand to worldwide (still gender-filtered)
      if (candidates.length === 0) {
        expandedSearch = true;
        candidates = await User.aggregate([
          {
            $geoNear: {
              near: { type: 'Point', coordinates: [longitude, latitude] },
              distanceField: 'distance',
              spherical: true,
            },
          },
          { $match: baseMatch },
          interestScoreStage,
          { $sort: { interestScore: -1, distance: 1 } },
          { $project: { password: 0, pushTokens: 0 } },
          { $skip: skip },
          { $limit: limit },
        ]);
      }
    } else {
      // No location — skip distance entirely, apply all other filters
      candidates = await User.aggregate([
        { $match: baseMatch },
        interestScoreStage,
        { $sort: { interestScore: -1 } },
        { $project: { password: 0, pushTokens: 0 } },
        { $skip: skip },
        { $limit: limit },
      ]);
    }

    res.json({ users: candidates, page, limit, expandedSearch });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

const getLikedYou = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const matchedUserIds = await Match.find({ users: req.userId }).distinct('users');

    const query = {
      targetId: req.userId,
      direction: { $in: ['like', 'superlike'] },
      swiperId: { $nin: matchedUserIds },
    };

    const [likedSwipes, total] = await Promise.all([
      Swipe.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('swiperId', 'name photos age bio job'),
      Swipe.countDocuments(query),
    ]);

    res.json({ users: likedSwipes.map(s => s.swiperId), total });
  } catch (error) {
    res.status(500).json({ message: parseError(error) });
  }
};

module.exports = { getNearby, getLikedYou };
