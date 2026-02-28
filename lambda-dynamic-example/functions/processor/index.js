/**
 * Processor Lambda - Handles background processing tasks
 */

const { logger } = require('./shared/utils');

exports.handler = async (event, context) => {
  logger.info('Processor invoked');
  
  // Handle SQS messages
  if (event.Records && event.Records[0]?.eventSource === 'aws:sqs') {
    return processSqsMessages(event.Records);
  }
  
  // Direct invocation
  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Processed', timestamp: new Date().toISOString() }),
  };
};

async function processSqsMessages(records) {
  logger.info(`Processing ${records.length} SQS messages`);
  
  for (const record of records) {
    const body = JSON.parse(record.body);
    logger.info(`Message: ${JSON.stringify(body)}`);
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({ processed: records.length }),
  };
}
