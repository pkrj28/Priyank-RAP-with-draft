//@EndUserText.label: 'My Travel processor projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZATS_PJ_BOOKSUPPL_PROCESSOR 
    as projection on ZATS_PJ_BOOKSUPPL
{
    key TravelId,
    key BookingId,
    key BookingSupplementId,
    SupplementId,
    Price,
    CurrencyCode,
    LastChangedAt,
    /* Associations */
    _Booking: redirected to parent ZATS_PJ_BOOKING_PROCESSOR,
    _Travel: redirected to  ZATS_PJ_TRAVEL_PROCESSOR
}
