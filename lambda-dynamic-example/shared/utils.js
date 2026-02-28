/**
 * Shared utilities for all Lambda functions
 */

const logger = {
  info: (message) => console.log(JSON.stringify({ level: 'INFO', message, timestamp: new Date().toISOString() })),
  warn: (message) => console.log(JSON.stringify({ level: 'WARN', message, timestamp: new Date().toISOString() })),
  error: (message) => console.log(JSON.stringify({ level: 'ERROR', message, timestamp: new Date().toISOString() })),
};

function response(statusCode, body, headers = {}) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      ...headers,
    },
    body: JSON.stringify(body),
  };
}

module.exports = { logger, response };
