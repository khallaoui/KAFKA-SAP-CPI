
CLASS lcl_handler IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Autorisation systématique pour le mode Test/Trial
    IF requested_authorizations-%create EQ if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update EQ if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete EQ if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD order_created_event.
    " 1. Lecture des données de la commande fraîchement créée dans l'UI Fiori
    READ ENTITIES OF ZI_ORDERS IN LOCAL MODE
      ENTITY Order
        FIELDS ( order_id client_name amount currency status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    DATA: lv_access_token TYPE string.

    " 2. Boucle de traitement sur les commandes créées
    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<fs_order>).
      TRY.
          " -------------------------------------------------------------
          " ÉTAPE A : RÉCUPÉRATION DU JETON (Identique à zcl_test_kafka_send)
          " -------------------------------------------------------------
          DATA(lo_token_destination) = cl_http_destination_provider=>create_by_url(
            i_url = 'https://95f9af01trial.authentication.us10.hana.ondemand.com/oauth/token?grant_type=client_credentials'
          ).
          DATA(lo_token_client) = cl_web_http_client_manager=>create_by_http_destination( lo_token_destination ).
          DATA(lo_token_request) = lo_token_client->get_http_request( ).

          " Vos identifiants BTP Runtime qualifiés
          DATA(lv_credentials) = |sb-bc9fba83-41e0-4515-a9eb-6f73dfe7efe1!b656948\|it-rt-95f9af01trial!b26655:3ee964c7-b5d0-4c09-92a9-d6e4cbfae8e4$8mm-OpVfHpPip7Sj-nU57UI3SuX9YhWPkyPZMpbYlXQ=|.
          DATA(lv_base64_auth) = cl_web_http_utility=>encode_base64( lv_credentials ).
          lo_token_request->set_header_field( i_name = 'Authorization' i_value = |Basic { lv_base64_auth }| ).

          DATA(lo_token_response) = lo_token_client->execute( if_web_http_client=>post ).
          DATA(lv_token_response_raw) = lo_token_response->get_text( ).

          " Extraction ultra-fiable par REGEX du token
          CLEAR lv_access_token.
          FIND REGEX '"access_token"\s*:\s*"([^"]+)"' IN lv_token_response_raw SUBMATCHES lv_access_token.

          " -------------------------------------------------------------
          " ÉTAPE B : ENVOI DE LA COMMANDE A SAP CPI
          " -------------------------------------------------------------
          IF lv_access_token IS NOT INITIAL.
            DATA(lo_cpi_destination) = cl_http_destination_provider=>create_by_url(
              i_url = 'https://95f9af01trial.it-cpitrial05-rt.cfapps.us10-001.hana.ondemand.com/http/v1/orders'
            ).
            DATA(lo_cpi_client) = cl_web_http_client_manager=>create_by_http_destination( lo_cpi_destination ).
            DATA(lo_cpi_request) = lo_cpi_client->get_http_request( ).

            " Correction de la structure ici : "client_name" au lieu de "client"
            DATA(lv_order_json) = |\{| &&
                                  |"order_id":"{ <fs_order>-order_id }",| &&
                                  |"client_name":"{ <fs_order>-client_name }",| &&
                                  |"amount":{ <fs_order>-amount },| &&
                                  |"currency":"{ <fs_order>-currency }",| &&
                                  |"status":"{ <fs_order>-status }"| &&
                                  |\}|.

            lo_cpi_request->set_text( lv_order_json ).
            lo_cpi_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
            lo_cpi_request->set_header_field( i_name = 'Authorization' i_value = |Bearer { lv_access_token }| ).

            " Envoi synchrone à l'iFlow Aller de CPI
            DATA(lo_cpi_response) = lo_cpi_client->execute( if_web_http_client=>post ).
          ENDIF.

        CATCH cx_root INTO DATA(lx_error).
          " Enregistre le message d'erreur technique pour le suivi en cas de coupure réseau
          DATA(lv_message) = lx_error->get_text( ).
          " Pour le debug en environnement de test, vous pouvez décommenter la ligne suivante :
          " ASSERT 1 = 0.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.