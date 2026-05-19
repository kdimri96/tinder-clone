const User = require('../models/User');
const Swipe = require('../models/Swipe');
const Match = require('../models/Match');

const getNearby = async (req, res) => {
  try {
    const user = req.user;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    // Get IDs of users already swiped
    const swipedIds = await Swipe.find({ swiperId: req.userId }).distinct('targetId');

    const maxDistance = (user.preferences?.maxDistance || 50) * 1000; // km to meters
    const minAge = user.preferences?.minAge || 18;
    const maxAge = user.preferences?.maxAge || 99;
    const genderPrefs = user.preferences?.genderPreference || ['male', 'female', 'other'];
    const myGender = user.gender || 'other';
    const myInterests = user.interests || [];
    const blockedUserIds = user.blockedUsers || [];

    const [longitude, latitude] = user.location?.coordinates || [0, 0];

    const candidates = await User.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: [longitude, latitude] },
          distanceField: 'distance',
          maxDistance,
          spherical: true,
        },
      },
      {
        $match: {
          _id: { $nin: [...swipedIds, ...blockedUserIds, user._id] },
          blockedUsers: { $ne: user._id },
          // Matches the current user's gender preference
          gender: { $in: genderPrefs },
          // The candidate must also be interested in the current user's gender (mutual preference)
          'preferences.genderPreference': myGender,
          age: { $gte: minAge, $lte: maxAge },
          isProfileComplete: true,
        },
      },
      {
        // Score by number of shared interests — more overlap = higher score
        $addFields: {
          interestScore: myInterests.length > 0
            ? {
                $size: {
                  $ifNull: [
                    { $setIntersection: ['$interests', myInterests] },
                    [],
                  ],
                },
              }
            : 0,
        },
      },
      {
        // Sort: most shared interests first, then closest distance
        $sort: { interestScore: -1, distance: 1 },
      },
      {
        $project: {
          password: 0,
          pushTokens: 0,
        },
      },
      { $skip: skip },
      { $limit: limit },
    ]);

    res.json({ users: candidates, page, limit });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getLikedYou = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    // Users who swiped right on me, whom I haven't matched with yet
    const matchedUserIds = await Match.find({ users: req.userId }).distinct('users');

    const likedSwipes = await Swipe.find({
      targetId: req.userId,
      direction: { $in: ['like', 'superlike'] },
      swiperId: { $nin: matchedUserIds },
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('swiperId', 'name photos age bio job');

    res.json({ users: likedSwipes.map(s => s.swiperId), total: likedSwipes.length });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getNearby, getLikedYou };
