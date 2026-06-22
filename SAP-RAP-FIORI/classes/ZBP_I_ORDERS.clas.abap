CLASS lcl_handler DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Order RESULT result.

    METHODS order_created_event FOR DETERMINE ON SAVE
      IMPORTING keys FOR Order~order_created_event.
ENDCLASS.