@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'Vue de base - gOrders Big Data'
define root view entity ZI_ORDERS
  as select from ztm_orders
{
  key order_uuid,
  order_id,
  client_name,
  @Semantics.amount.currencyCode: 'currency'
  amount,
  currency,
  status,
  local_last_changed
}
