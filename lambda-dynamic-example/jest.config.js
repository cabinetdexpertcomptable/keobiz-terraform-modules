module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  collectCoverageFrom: [
    'functions/**/*.js',
    'shared/**/*.js',
    '!**/node_modules/**',
  ],
  verbose: true,
};
