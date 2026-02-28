/**
 * API Lambda - Handles HTTP requests via API Gateway
 */

const { response, logger } = require('./shared/utils');

const ENVIRONMENT = process.env.ENVIRONMENT || 'dev';

exports.handler = async (event, context) => {
  const { httpMethod, path, body, pathParameters } = event;
  
  logger.info(`API Request: ${httpMethod} ${path}`);
  
  try {
    // Health check
    if (path === '/health' || path === '/api/health') {
      return response(200, { status: 'healthy', service: 'api', environment: ENVIRONMENT });
    }
    
    // GET /users
    if (httpMethod === 'GET' && path === '/users') {
      const users = [
        { id: 1, name: 'Alice', email: 'alice@example.com' },
        { id: 2, name: 'Bob', email: 'bob@example.com' },
      ];
      return response(200, { users, total: users.length });
    }
    
    // POST /users
    if (httpMethod === 'POST' && path === '/users') {
      const data = JSON.parse(body || '{}');
      if (!data.name || !data.email) {
        return response(400, { error: 'Name and email are required' });
      }
      const newUser = { id: 3, name: data.name, email: data.email };
      return response(201, { user: newUser, message: 'User created' });
    }
    
    return response(404, { error: 'Not found', path });
    
  } catch (error) {
    logger.error(`Error: ${error.message}`);
    return response(500, { error: 'Internal server error' });
  }
};
