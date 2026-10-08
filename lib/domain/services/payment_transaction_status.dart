const _activePaymentTransactionStatuses = {
  'created',
  'pending',
  'waiting_confirmation',
};

const _gatewaySyncStatuses = {
  'created',
  'pending',
};

const _terminalPaymentTransactionStatuses = {
  'success',
  'failed',
  'expired',
  'cancelled',
  'rejected',
};

bool isActivePaymentTransactionStatus(String status) {
  return _activePaymentTransactionStatuses.contains(status);
}

bool shouldSyncPaymentGatewayStatus(String status) {
  return _gatewaySyncStatuses.contains(status);
}

bool isTerminalPaymentTransactionStatus(String status) {
  return _terminalPaymentTransactionStatuses.contains(status);
}

bool shouldRefreshTenantPaymentData(String status) {
  return _terminalPaymentTransactionStatuses.contains(status);
}
