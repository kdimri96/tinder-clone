/**
 * Parses any error into a clean user-facing message.
 * Never exposes raw stack traces or internal DB details.
 */
const parseError = (error) => {
  // Mongoose validation error — extract the first field message
  if (error.name === 'ValidationError') {
    const first = Object.values(error.errors)[0];
    return first?.message || 'Validation failed. Please check your inputs.';
  }

  // Mongoose duplicate key (e.g. unique email)
  if (error.code === 11000) {
    const field = Object.keys(error.keyValue || {})[0] || 'field';
    const fieldLabel = field === 'email' ? 'Email' : field;
    return `${fieldLabel} is already in use.`;
  }

  // Mongoose cast error (e.g. invalid ObjectId)
  if (error.name === 'CastError') {
    return 'Invalid ID format.';
  }

  // JWT errors
  if (error.name === 'JsonWebTokenError') return 'Invalid token. Please log in again.';
  if (error.name === 'TokenExpiredError') return 'Session expired. Please log in again.';

  // Network / Axios errors from social auth
  if (error.isAxiosError) return 'Could not verify social login. Please try again.';

  return 'Something went wrong. Please try again.';
};

module.exports = { parseError };
