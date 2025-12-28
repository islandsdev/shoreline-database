// Custom error classes for better error handling
export class SubscriptionHandlerError extends Error {
  eventType;
  subscriptionId;
  companyId;
  originalError;
  constructor(message, eventType, subscriptionId, companyId, originalError){
    super(message);
    this.eventType = eventType;
    this.subscriptionId = subscriptionId;
    this.companyId = companyId;
    this.originalError = originalError;
    this.name = 'SubscriptionHandlerError';
  }
}
export class ValidationError extends SubscriptionHandlerError {
  constructor(message, eventType, subscriptionId){
    super(message, eventType, subscriptionId);
    this.name = 'ValidationError';
  }
}
export class DatabaseError extends SubscriptionHandlerError {
  operation;
  constructor(message, eventType, operation, subscriptionId, companyId, originalError){
    super(message, eventType, subscriptionId, companyId, originalError);
    this.operation = operation;
    this.name = 'DatabaseError';
  }
}
export class StripeError extends SubscriptionHandlerError {
  constructor(message, eventType, subscriptionId, originalError){
    super(message, eventType, subscriptionId, undefined, originalError);
    this.name = 'StripeError';
  }
}
