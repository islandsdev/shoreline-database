// Default configuration
export const DEFAULT_CONFIG = {
  BATCH_SIZE: 5,
  MAX_RETRIES: 1,
  RETRY_DELAY: 1000,
  INTER_BATCH_DELAY: 100,
  STRIPE_INVOICE_DAYS_UNTIL_DUE: 7,
  STRIPE_CURRENCY: "usd",
  ENABLE_DEBUG_LOGGING: false,
  LOG_LEVEL: "info",
};
// Environment-based configuration
export function getConfig() {
  return {
    BATCH_SIZE: parseInt(
      Deno.env.get("BATCH_SIZE") || DEFAULT_CONFIG.BATCH_SIZE.toString()
    ),
    MAX_RETRIES: parseInt(
      Deno.env.get("MAX_RETRIES") || DEFAULT_CONFIG.MAX_RETRIES.toString()
    ),
    RETRY_DELAY: parseInt(
      Deno.env.get("RETRY_DELAY") || DEFAULT_CONFIG.RETRY_DELAY.toString()
    ),
    INTER_BATCH_DELAY: parseInt(
      Deno.env.get("INTER_BATCH_DELAY") ||
        DEFAULT_CONFIG.INTER_BATCH_DELAY.toString()
    ),
    STRIPE_INVOICE_DAYS_UNTIL_DUE: parseInt(
      Deno.env.get("STRIPE_INVOICE_DAYS_UNTIL_DUE") ||
        DEFAULT_CONFIG.STRIPE_INVOICE_DAYS_UNTIL_DUE.toString()
    ),
    STRIPE_CURRENCY:
      Deno.env.get("STRIPE_CURRENCY") || DEFAULT_CONFIG.STRIPE_CURRENCY,
    ENABLE_DEBUG_LOGGING: Deno.env.get("ENABLE_DEBUG_LOGGING") === "true",
    LOG_LEVEL: Deno.env.get("LOG_LEVEL") || DEFAULT_CONFIG.LOG_LEVEL,
  };
}
// Utility function to validate configuration
export function validateConfig(config) {
  if (config.BATCH_SIZE < 1 || config.BATCH_SIZE > 50) {
    throw new Error("BATCH_SIZE must be between 1 and 50");
  }
  if (config.MAX_RETRIES < 0 || config.MAX_RETRIES > 10) {
    throw new Error("MAX_RETRIES must be between 0 and 10");
  }
  if (config.RETRY_DELAY < 100 || config.RETRY_DELAY > 10000) {
    throw new Error("RETRY_DELAY must be between 100ms and 10 seconds");
  }
  if (config.INTER_BATCH_DELAY < 0 || config.INTER_BATCH_DELAY > 5000) {
    throw new Error("INTER_BATCH_DELAY must be between 0ms and 5 seconds");
  }
  if (
    config.STRIPE_INVOICE_DAYS_UNTIL_DUE < 1 ||
    config.STRIPE_INVOICE_DAYS_UNTIL_DUE > 90
  ) {
    throw new Error(
      "STRIPE_INVOICE_DAYS_UNTIL_DUE must be between 1 and 90 days"
    );
  }
}
