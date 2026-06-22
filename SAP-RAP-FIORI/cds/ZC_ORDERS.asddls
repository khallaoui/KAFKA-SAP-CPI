@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'Vue de Projection - Orders Big Data'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZC_ORDERS
  provider contract transactional_query
  as projection on ZI_ORDERS
{
  key order_uuid,
  order_id,
  client_name,
  
  @Semantics.amount.currencyCode: 'currency'
  amount,
  
  @Semantics.currencyCode: true
  currency,
  
  status,
  local_last_changed
}
