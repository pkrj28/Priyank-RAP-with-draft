CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE Travel.

    METHODS earlynumbering_cba_Booking FOR NUMBERING
      IMPORTING entities FOR CREATE Travel\_Booking.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

 METHOD earlynumbering_create.

    data: entity type STRUCTURE FOR CREATE zats_pj_travel,
          travel_id_max type /dmo/travel_id.

    ""Step 1: Ensure that Travel id is not set for the record which is coming
    loop at entities into entity where TravelId is not initial.
        APPEND CORRESPONDING #( entity ) to mapped-travel.
    ENDLOOP.

    data(entities_wo_travelid) = entities.
    delete entities_wo_travelid where TravelId is not INITIAL.

    ""Step 2: Get the seuquence numbers from the SNRO
    try.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = '01'
            object            = CONV #( '/DMO/TRAVL' )
            quantity          =  conv #( lines( entities_wo_travelid ) )
          IMPORTING
            number            = data(number_range_key)
            returncode        = data(number_range_return_code)
            returned_quantity = data(number_range_returned_quantity)
        ).
*        CATCH cx_nr_object_not_found.
*        CATCH cx_number_ranges.

      catch cx_number_ranges into data(lx_number_ranges).
        ""Step 3: If there is an exception, we will throw the error
        loop at entities_wo_travelid into entity.
            append value #( %cid = entity-%cid %key = entity-%key %msg = lx_number_ranges  )
                to reported-travel.
            append value #( %cid = entity-%cid %key = entity-%key ) to failed-travel.
        ENDLOOP.
        exit.
    endtry.

    case number_range_return_code.
        when '1'.
            ""Step 4: Handle especial cases where the number range exceed critical %
            loop at entities_wo_travelid into entity.
                append value #( %cid = entity-%cid %key = entity-%key
                                %msg = new /dmo/cm_flight_messages(
                                            textid = /dmo/cm_flight_messages=>number_range_depleted
                                            severity = if_abap_behv_message=>severity-warning
                                ) )
                    to reported-travel.
            ENDLOOP.
        when '2' OR '3'.
            ""Step 5: The number range return last number, or number exhaused
            append value #( %cid = entity-%cid %key = entity-%key
                                %msg = new /dmo/cm_flight_messages(
                                            textid = /dmo/cm_flight_messages=>not_sufficient_numbers
                                            severity = if_abap_behv_message=>severity-warning
                                ) )
                    to reported-travel.
            append value #( %cid = entity-%cid
                            %key = entity-%key
                            %is_draft = if_abap_behv=>mk-on
                            %fail-cause = if_abap_behv=>cause-conflict
                             ) to failed-travel.
    ENDCASE.

    ""Step 6: Final check for all numbers
    ASSERT number_range_returned_quantity = lines( entities_wo_travelid ).

    ""Step 7: Loop over the incoming travel data and asign the numbers from number range and
    ""        return MAPPED data which will then go to RAP framework
    travel_id_max = number_range_key - number_range_returned_quantity.

    loop at entities_wo_travelid into entity.

        travel_id_max += 1.
        entity-TravelId = travel_id_max.

        append value #( %cid = entity-%cid
                        %key = entity-%key
                        %is_draft = if_abap_behv=>mk-on
                         ) to mapped-travel.
    ENDLOOP.

  ENDMETHOD.

  METHOD earlynumbering_cba_Booking.
    data max_booking_id type /dmo/booking_id.

    ""Step 1: get all the travel requests and their booking data
    read ENTITIES OF zats_pj_travel in local mode
        ENTITY travel by \_Booking
        from CORRESPONDING #( entities )
        link data(bookings).

    ""Loop at unique travel ids
    loop at entities ASSIGNING FIELD-SYMBOL(<travel_group>) GROUP BY <travel_group>-TravelId.
    ""Step 2: get the highest booking number which is already there
        loop at bookings into data(ls_booking) using key entity
            where source-TravelId = <travel_group>-TravelId.
                if max_booking_id < ls_booking-target-BookingId.
                    max_booking_id = ls_booking-target-BookingId.
                ENDIF.
        ENDLOOP.
    ""Step 3: get the asigned booking numbers for incoming request
        loop at entities into data(ls_entity) using key entity
            where TravelId = <travel_group>-TravelId.
                loop at ls_entity-%target into data(ls_target).
                    if max_booking_id < ls_target-BookingId.
                        max_booking_id = ls_target-BookingId.
                    ENDIF.
                ENDLOOP.
        ENDLOOP.
    ""Step 4: loop over all the entities of travel with same travel id
        loop at entities ASSIGNING FIELD-SYMBOL(<travel>)
            USING KEY entity where TravelId = <travel_group>-TravelId.
    ""Step 5: assign new booking IDs to the booking entity inside each travel
            LOOP at <travel>-%target ASSIGNING FIELD-SYMBOL(<booking_wo_numbers>).
                append CORRESPONDING #( <booking_wo_numbers> ) to mapped-booking
                ASSIGNING FIELD-SYMBOL(<mapped_booking>).
                if <mapped_booking>-BookingId is INITIAL.
                   <mapped_booking>-%is_draft = if_abap_behv=>mk-on.
                    max_booking_id += 10.
                    <mapped_booking>-BookingId = max_booking_id.
                ENDIF.
            ENDLOOP.
        ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


ENDCLASS.
