const User = require('../models/User');
const Swipe = require('../models/Swipe');

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
          _id: { $ne: user._id, $nin: swipedIds },
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

module.exports = { getNearby };
