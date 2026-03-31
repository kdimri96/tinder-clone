const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true,
    maxlength: [50, 'Name cannot exceed 50 characters'],
  },
  email: {
    type: String,
    required: [true, 'Email is required'],
    unique: true,
    lowercase: true,
    trim: true,
    match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
  },
  password: {
    type: String,
    required: [true, 'Password is required'],
    minlength: [6, 'Password must be at least 6 characters'],
    select: false,
  },
  age: {
    type: Number,
    min: [18, 'Must be at least 18'],
    max: [100, 'Age cannot exceed 100'],
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other'],
  },
  bio: {
    type: String,
    maxlength: [500, 'Bio cannot exceed 500 characters'],
    default: '',
  },
  photos: [{
    type: String,
  }],
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      default: [0, 0],
    },
  },
  preferences: {
    genderPreference: {
      type: [String],
      enum: ['male', 'female', 'other'],
      default: ['male', 'female', 'other'],
    },
    minAge: { type: Number, default: 18 },
    maxAge: { type: Number, default: 50 },
    maxDistance: { type: Number, default: 50 }, // km
  },
  interests: [{ type: String }],
  job: { type: String, default: '' },
  school: { type: String, default: '' },
  lastActive: { type: Date, default: Date.now },
  isProfileComplete: { type: Boolean, default: false },
  pushTokens: [{ type: String }],
}, {
  timestamps: true,
});

userSchema.index({ location: '2dsphere' });

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
