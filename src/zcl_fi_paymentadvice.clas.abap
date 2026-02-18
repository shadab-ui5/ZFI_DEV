CLASS zcl_fi_paymentadvice DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_http_service_extension .

    CLASS-METHODS : read_posts
      IMPORTING VALUE(companycode) TYPE string OPTIONAL
                year               TYPE string
                document           TYPE string
                plant              TYPE  string
      RETURNING VALUE(result12)    TYPE string
      RAISING   cx_static_check .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_FI_PAYMENTADVICE IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.

    DATA(req) = request->get_form_fields(  ).
    response->set_header_field( i_name = 'Access-Control-Allow-Origin' i_value = '*' ).
    response->set_header_field( i_name = 'Access-Control-Allow-Credentials' i_value = 'true' ).

    DATA(companycode) = VALUE #( req[ name = 'comcode' ]-value OPTIONAL ) .
    DATA(year) = VALUE #( req[ name = 'year' ]-value OPTIONAL ) .
    DATA(document) = VALUE #( req[ name = 'document' ]-value OPTIONAL ) .
    DATA(plant)  = VALUE #( req[ name = 'plant' ]-value OPTIONAL ) .
    DATA multi_pdf TYPE string.
    DATA : round       TYPE string,
           pdf_xstring TYPE xstring.
    DATA(l_merger) = cl_rspo_pdf_merger=>create_instance( ).

    DATA:i_doc TYPE RANGE OF char10,
         w_doc LIKE LINE OF i_doc.
    SPLIT document AT ',' INTO TABLE DATA(doc) .
    LOOP AT doc INTO DATA(woc).
      w_doc-sign = 'I'.
      w_doc-option = 'EQ'.
      w_doc-low = woc.
      CONDENSE woc .

      DATA(resp) = read_posts( companycode = companycode
                                year = year
                                document = woc
                                plant = plant ) .

      pdf_xstring = xco_cp=>string( resp )->as_xstring( xco_cp_binary=>text_encoding->base64 )->value.
      l_merger->add_document( pdf_xstring ).

      CLEAR : woc .
    ENDLOOP.
    TRY .
        DATA(l_poczone_pdf) = l_merger->merge_documents( ).
      CATCH cx_rspo_pdf_merger INTO DATA(l_exception).
        " Add a useful error handling here
    ENDTRY.
    DATA(new) = xco_cp=>xstring( l_poczone_pdf )->as_string( xco_cp_binary=>text_encoding->base64  )->value.

    response->set_text( new ) .
  ENDMETHOD.


  METHOD read_posts.


    SELECT SINGLE FROM i_operationalacctgdocitem AS a
    INNER JOIN i_supplier AS b ON b~supplier = a~supplier
    LEFT OUTER JOIN zaddress_2 AS c ON c~addressid = b~addressid
    FIELDS
    a~supplier,
    a~accountingdocument ,
    a~postingdate ,
    a~documentitemtext,
    b~suppliername ,
    b~cityname,
    c~organizationname1 ,
    c~organizationname2 ,
    c~organizationname3 ,
    c~organizationname4 ,
    c~districtname ,
    c~region ,
    c~country,
    c~postalcode ,
    c~streetname,
    c~streetaddrnondeliverablereason,
    c~streetprefixname1,
    c~streetprefixname2,
    c~streetsuffixname1,
    c~streetsuffixname2,
    c~housenumber
      WHERE a~companycode = @companycode AND
            a~fiscalyear = @year AND
            a~accountingdocument = @document AND
            a~supplier IS NOT INITIAL INTO @DATA(vendor_add) .

    CONCATENATE vendor_add-organizationname1 vendor_add-organizationname2
    vendor_add-organizationname3  vendor_add-organizationname4 vendor_add-cityname INTO DATA(vendoraddress) SEPARATED BY ' '.
    CONCATENATE  vendor_add-streetname vendor_add-cityname vendor_add-region vendor_add-country vendor_add-postalcode INTO DATA(vendor_address2) SEPARATED BY ' '.

    SELECT SINGLE * FROM  i_journalentry  WHERE
           companycode = @companycode AND
           fiscalyear = @year AND
           accountingdocument = @document
           INTO @DATA(tabu) .
    SELECT SINGLE * FROM  i_journalentryitem  WHERE
           companycode = @companycode AND
           fiscalyear = @year AND
           accountingdocument = @document  AND  housebank IS NOT INITIAL
           INTO @DATA(tabu1) .

    SELECT SINGLE * FROM i_journalentryitem WHERE
           companycode = @companycode AND
           fiscalyear = @year AND
           financialaccounttype = 'K' AND
           accountingdocument = @vendor_add-accountingdocument
           INTO @DATA(narration).


    SELECT SINGLE * FROM i_journalentry
    WHERE  companycode = @companycode AND
           fiscalyear = @year AND
           accountingdocument = @vendor_add-accountingdocument
           INTO @DATA(narration2).

    DATA : lv_narration TYPE string.

    IF narration-documentitemtext IS NOT INITIAL.
      lv_narration = narration-documentitemtext.
    ELSE.
      lv_narration = narration2-accountingdocumentheadertext.
    ENDIF.


    SELECT * FROM i_supplierinvoiceapi01
    WHERE
    supplierinvoice = @document  AND
    fiscalyear = @year  INTO TABLE @DATA(item) .

    " Work area to read from internal table
    DATA: lt_all_docs TYPE STANDARD TABLE OF i_operationalacctgdocitem,
          wa_tab      TYPE i_operationalacctgdocitem,
          it_tab      TYPE STANDARD TABLE OF i_operationalacctgdocitem,
          lt_filtered TYPE STANDARD TABLE OF i_operationalacctgdocitem,
          lv_kz_count TYPE i,
          ls_item     TYPE i_operationalacctgdocitem,
          ls_item_new TYPE i_operationalacctgdocitem.

    "******************************************************************************************************
    " Fetch base document
    SELECT SINGLE *
      FROM i_operationalacctgdocitem
      WHERE companycode = @companycode
        AND fiscalyear = @year
        AND accountingdocument = @document
        AND financialaccounttype = 'K'
      INTO @wa_tab.

    "***************************************************************************************************
    "  Scenario 1 : Advance Payment
    DATA: lv_clearing_doc           TYPE i_operationalacctgdocitem-clearingjournalentry,
          lt_group_docs             TYPE TABLE OF i_operationalacctgdocitem,
          lt_group_docs_not_cleared TYPE TABLE OF i_operationalacctgdocitem.

    " Step 1: Get clearing document number of the input doc (could be AB, KR or KZ)
    SELECT SINGLE clearingjournalentry

      FROM i_operationalacctgdocitem
      WHERE companycode         = @companycode
        AND fiscalyear          = @year
        AND accountingdocument  = @wa_tab-accountingdocument
        AND financialaccounttype = 'K'
          INTO @lv_clearing_doc.

    " Step 2: If ClearingJournalEntry is found, use it to get the full group
    IF sy-subrc = 0 AND lv_clearing_doc IS NOT INITIAL.
      SELECT *
        FROM i_operationalacctgdocitem
        WHERE companycode          = @companycode
          AND fiscalyear           = @year
          AND clearingjournalentry = @lv_clearing_doc
          AND financialaccounttype = 'K'
        INTO TABLE @lt_group_docs.
    ELSE.
      SELECT *
        FROM i_operationalacctgdocitem
        WHERE companycode          = @companycode
          AND fiscalyear           = @year
          AND accountingdocument = @wa_tab-accountingdocument
          AND financialaccounttype = 'K'
        INTO TABLE @lt_group_docs.

    ENDIF.
    APPEND LINES OF lt_group_docs TO lt_all_docs.



    """"""""""" FOR FINAL OUTPUT """"""""""""""""""""""""""""""""""""""""
    DATA: lv_has_ab_or_cs_or_ur TYPE abap_bool VALUE abap_false,
          lv_vc                 TYPE abap_bool VALUE abap_false,
          lv_lines              TYPE i,
          lt_group_docs_new     TYPE TABLE OF i_operationalacctgdocitem,
          lt_group_docs_new1    TYPE TABLE OF i_operationalacctgdocitem.

    " Step 1: Check if AB or CS exists
    LOOP AT lt_all_docs INTO ls_item.
      IF ls_item-accountingdocumenttype = 'AB' OR ls_item-accountingdocumenttype = 'CS' OR ls_item-accountingdocumenttype = 'UR'.
        lv_has_ab_or_cs_or_ur = abap_true.
        EXIT.
      ENDIF.
      IF  ls_item-accountingdocumenttype = 'VC'.
        lv_vc = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.


    " Step 2: Count entries
    lv_lines = lines( lt_all_docs ).

    " Step 3: Process based on AB/CS presence
    IF lv_has_ab_or_cs_or_ur = abap_true.

      SORT lt_all_docs BY companycode fiscalyear accountingdocument.
      DELETE ADJACENT DUPLICATES FROM lt_all_docs COMPARING companycode fiscalyear accountingdocument.
      DELETE lt_all_docs WHERE accountingdocument = lv_clearing_doc.

    ELSEIF lv_vc = abap_true.
      LOOP AT lt_all_docs INTO ls_item_new.
        SELECT *
               FROM i_operationalacctgdocitem
               WHERE companycode           = @companycode
                 AND fiscalyear            = @ls_item_new-fiscalyear
                 AND clearingjournalentry    = @ls_item_new-accountingdocument
                  INTO TABLE @lt_group_docs_new.
        APPEND LINES OF  lt_group_docs_new TO lt_group_docs_new1.


      ENDLOOP.
      APPEND LINES OF lt_group_docs_new1 TO lt_all_docs.
      DELETE ADJACENT DUPLICATES FROM lt_all_docs COMPARING companycode fiscalyear accountingdocument.
      DELETE lt_all_docs WHERE accountingdocumenttype = 'KZ'.
    ELSE.

      IF ( wa_tab-accountingdocumenttype = 'UV' OR  lv_lines = 2 ) AND wa_tab-accountingdocument = lv_clearing_doc.
        " Delete only if table has 2 entries and match found
        DELETE lt_all_docs WHERE accountingdocument = lv_clearing_doc.
      ENDIF.

      SORT lt_all_docs.
    ENDIF.




    " Remove duplicates
    SORT lt_all_docs BY companycode fiscalyear accountingdocument .
    DELETE ADJACENT DUPLICATES FROM lt_all_docs COMPARING companycode fiscalyear accountingdocument .
    it_tab = lt_all_docs.

    "**********************************************************************************************************
    DATA lv_xml TYPE string .
    DATA n TYPE n .


    lv_xml =
    |<form1> | &&
    |<Vendor_details> | &&
    |<VendorCode>{ vendor_add-supplier }</VendorCode> | &&
    |<ms>{ vendor_add-suppliername  }</ms> | &&
    |<Address1>{ vendor_address2 }</Address1> | &&
    |<Address2></Address2> | &&
    |</Vendor_details> | &&
    |<Document_details> | &&
    |<Documentno>{ vendor_add-accountingdocument }</Documentno>| &&
    |<Documentdate>{ vendor_add-postingdate }</Documentdate> | &&
    |<chqno>{ tabu-documentreferenceid }</chqno> | &&
    |<Bankname>{ tabu1-housebank }</Bankname> | &&
    |</Document_details> | &&
    |    <Text> | &&
    |       <Documenttext></Documenttext> | &&
    |    </Text> | &&
    |    <Lineitem> | &&
    |       <Table1> | &&
    |          <HeaderRow/> |  .

    DATA: amt1 TYPE p DECIMALS 2 VALUE 0,
          amt2 TYPE p DECIMALS 2 VALUE 0,
          amt3 TYPE p DECIMALS 2 VALUE 0.

    LOOP AT it_tab ASSIGNING FIELD-SYMBOL(<fs>).

      SELECT SINGLE *
        FROM i_journalentry
        WHERE companycode        = @companycode
          AND fiscalyear         = @<fs>-fiscalyear
          AND accountingdocument = @<fs>-accountingdocument
        INTO @DATA(tabu12).

      SELECT SINGLE *
        FROM i_journalentryitem
        WHERE companycode        = @companycode
          AND fiscalyear         = @<fs>-fiscalyear
          AND accountingdocument = @<fs>-accountingdocument
        INTO @DATA(tabu13).



      SELECT SINGLE *
        FROM i_journalentryitem
        WHERE companycode        = @companycode
          AND fiscalyear         = @<fs>-fiscalyear
          AND accountingdocument = @wa_tab-accountingdocument
        INTO @DATA(tabu14).


      DATA: lt_lines_s TYPE STANDARD TABLE OF i_journalentryitem,
            ls_line_s  TYPE i_journalentryitem,
            lv_amt_s   TYPE i_journalentryitem-amountintransactioncurrency,
            lv_unit    TYPE string.

      IF tabu13-profitcenter = '0011001100'.
        lv_unit = 'U1'.
      ELSEIF tabu13-profitcenter = '0011001200'.
        lv_unit = 'U2'.
      ELSEIF tabu13-profitcenter = '0011001300'.
        lv_unit = 'U3'.
      ELSEIF tabu13-profitcenter = '0011001400'.
        lv_unit = 'U6'.
      ELSEIF tabu13-profitcenter = '0011002100'.
        lv_unit = 'U4'.
      ELSEIF tabu13-profitcenter = '0011002200'.
        lv_unit = 'U5'.
      ENDIF.


      DATA(lv_docdate)  = tabu12-documentdate.
      DATA(lv_createdt) = tabu12-accountingdocumentcreationdate.
      "n = n + 1.


      "****************************************************

      DATA : lv_passamt    TYPE p DECIMALS 2 VALUE 0,
             lv_netamt     TYPE p DECIMALS 2 VALUE 0,
             lv_tds        TYPE p DECIMALS 2 VALUE 0,
             lv_grandtotal TYPE p DECIMALS 2 VALUE 0.

      DATA(lv_kz_countall) = 0.
      DATA(lv_vc_countall) = 0.
      DATA(lv_passamtcal) = 0.

      LOOP AT it_tab INTO DATA(ls_items).
        IF ls_items-accountingdocumenttype = 'KZ'.
          lv_kz_countall = lv_kz_countall + 1.
        ENDIF.
      ENDLOOP.

      LOOP AT it_tab INTO DATA(ls_itemf).
        IF ls_itemf-accountingdocumenttype = 'VC'.
          lv_vc_countall = lv_vc_countall + 1.
        ENDIF.
      ENDLOOP.




      lv_passamtcal = abs( <fs>-amountincompanycodecurrency ) + abs( <fs>-withholdingtaxamount ).
      lv_passamt = abs( <fs>-amountincompanycodecurrency ) + abs( <fs>-withholdingtaxamount ).
      lv_tds = <fs>-withholdingtaxamount.
      lv_netamt = abs( lv_passamt ) - abs( lv_tds ).



      DATA: passedsum TYPE p DECIMALS 2 VALUE 0,
            netsum    TYPE p DECIMALS 2 VALUE 0,
            tdssum    TYPE p DECIMALS 2 VALUE 0.

      IF lv_kz_countall > 1 .

        IF <fs>-accountingdocumenttype <> 'KR'  .
          amt1 += lv_passamt .

        ENDIF.
      ELSEIF lv_vc_countall > 0.

        IF <fs>-accountingdocumenttype <> 'VC'  .
          amt1 +=  lv_passamt .
        ENDIF.
      ELSEIF  wa_tab-accountingdocument = lv_clearing_doc AND wa_tab-accountingdocumenttype = 'AB'.
        IF <fs>-accountingdocumenttype <> 'KZ'  .
          amt1 +=  lv_passamt .
        ENDIF.
      ELSE.
        IF <fs>-accountingdocumenttype <> 'KZ'  .
          amt1 +=  lv_passamt .
        ELSE.
          IF lv_lines > 1.
            DELETE it_tab INDEX sy-tabix.
            CONTINUE.
          ELSE.
            amt1 +=  lv_passamt .
          ENDIF.
        ENDIF.
      ENDIF.

      "**************19/09/2025******advance without clear against inv******

      if lv_clearing_doc is initial and wa_tab-AccountingDocument = <fs>-AccountingDocument and lv_kz_countall = 1.
      lv_passamt = abs( <fs>-amountincompanycodecurrency ).
      lv_netamt = abs( <fs>-amountincompanycodecurrency ) - abs( <fs>-withholdingtaxamount ).
      endif.


      amt3 += abs( lv_tds ).


      lv_xml = lv_xml && |<Row1>| &&
          |<sno>{ n }</sno>| &&
          |<docno>{ <fs>-accountingdocument }</docno>| &&
          |<docdate>{ lv_createdt }</docdate>| &&
          |<doctype>{ <fs>-accountingdocumenttype }</doctype>| &&
          |<unit>{ lv_unit }</unit>| &&
          |<Billno>{ tabu12-documentreferenceid }</Billno>| &&
          |<Billdt>{ lv_docdate }</Billdt>| &&
          |<Passedamt>{ lv_passamt  }</Passedamt>| &&
          |<Tdsamt>{ 1 * lv_tds }</Tdsamt>| &&
          |<netamt>{ abs( lv_netamt ) }</netamt>| &&
          |</Row1>|.


    ENDLOOP.
    amt2 = abs( amt1 ) - abs( amt3 ).


    "********************************GRAND TOTAL ****************************************
    SELECT SINGLE ( amountintransactioncurrency )
      FROM  i_operationalacctgdocitem
      WHERE companycode           = @companycode
        AND fiscalyear            = @wa_tab-fiscalyear
        AND accountingdocument    = @wa_tab-accountingdocument
        AND financialaccounttype  = 'S'
        INTO @DATA(amts).
    lv_grandtotal = amts.
    IF amts IS INITIAL.
      SELECT SINGLE ( amountintransactioncurrency )
        FROM  i_operationalacctgdocitem
    WHERE companycode           = @companycode
      AND fiscalyear            = @wa_tab-fiscalyear
      AND accountingdocument    = @wa_tab-accountingdocument
      AND financialaccounttype  = 'K'
      INTO @DATA(amts1).
      lv_grandtotal = amts1.
    ENDIF.

*****************************************************

    DATA : plant_address TYPE string,
           e63           TYPE char4.
    IF  plant  CS '1100' .


      plant_address = |E-63,MIDC INDUSTRIAL AREA WALUJ AURANGABAD 431136, MAHARASHTRA , INDIA| .
    ELSE .
      plant_address = |GROUND FLOOR, PLOT NO. N 22,SIDCO INDUSTRIAL ESTATE PHASE III HOSUR 635126, TAMIL NADU , INDIA| .
    ENDIF.

          "**************19/09/2025******advance without clear against inv******

      if lv_clearing_doc is initial and wa_tab-AccountingDocument = <fs>-AccountingDocument and lv_kz_countall = 1.
      amt1 = lv_passamt.
      amt2 = lv_netamt.
      endif.


    lv_xml = lv_xml && |       </Table1> | &&
    |       <Totalpassedamt>{ abs( amt1 ) }</Totalpassedamt> | &&
    |       <Totaltdsamt>{  amt3  }</Totaltdsamt> | &&
    |       <Totalnetamt>{ abs( amt2 ) }</Totalnetamt> | &&
    |       <Grandtotal>{  abs( lv_grandtotal ) }</Grandtotal> | &&
    |    </Lineitem> | &&
    |    <Footer> | &&
    |       <Narration>{ lv_narration }</Narration> | &&
    |    </Footer> | &&
    |    <Hidden> | &&
    |       <Header_address></Header_address> | &&
    |       <cin></cin> | &&
    |       <Tel></Tel> | &&
    |       <Fax></Fax> | &&
    |    </Hidden> | &&
    |<TextField2>{ plant_address }</TextField2>| &&
    | </form1> | .

    result12 =   zcl_form_dev=>getpdf( template = 'PaymentAdvice/PaymentAdvice' xmldata = lv_xml )  .


  ENDMETHOD.
ENDCLASS.
