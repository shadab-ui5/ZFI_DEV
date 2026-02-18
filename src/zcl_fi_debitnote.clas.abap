class ZCL_FI_DEBITNOTE definition
  public
  create public .

public section.

  interfaces IF_HTTP_SERVICE_EXTENSION .
protected section.
private section.
ENDCLASS.



CLASS ZCL_FI_DEBITNOTE IMPLEMENTATION.


  method IF_HTTP_SERVICE_EXTENSION~HANDLE_REQUEST.
    DATA(req) = request->get_form_fields(  ).
    response->set_header_field( i_name = 'Access-Control-Allow-Origin' i_value = '*' ).
    response->set_header_field( i_name = 'Access-Control-Allow-Credentials' i_value = 'true' ).
     DATA(comcode) = VALUE #( req[ name = 'comcode' ]-value OPTIONAL ) .
    DATA(docnum) = VALUE #( req[ name = 'docnum' ]-value OPTIONAL ) .
    DATA(year) = VALUE #( req[ name = 'year' ]-value OPTIONAL ) .
    DATA(plant) = VALUE #( req[ name = 'plant' ]-value OPTIONAL ) .

    DATA:i_doc TYPE RANGE OF char10,
         w_doc LIKE LINE OF i_doc.
    SPLIT docnum AT ',' INTO TABLE DATA(doc) .
    LOOP AT doc INTO DATA(woc).
      w_doc-sign = 'I'.
      w_doc-option = 'EQ'.
      w_doc-low = woc.
      APPEND w_doc TO i_doc.
      CLEAR w_doc.
    ENDLOOP.
   LOOP AT i_doc ASSIGNING FIELD-SYMBOL(<fs>)  .

      DATA(fidoc) = |{ <fs>-low }| .
      CONDENSE fidoc .


      SELECT SINGLE * FROM i_operationalacctgdocitem
       WITH PRIVILEGED ACCESS
       WHERE AccountingDocument = @fidoc
       AND fiscalyear = @year
       AND companycode = @comcode
       INTO @DATA(doct)  .

*      IF doct-accountingdocumenttype EQ 'ZA' OR doct-accountingdocumenttype EQ 'RE'    .
*        DATA(pdf2) = zfi_drcr_note=>read_posts( comcode = comcode date = ' '
*         docno = conv #( <fs>-low ) plant = plant year = year   ) .
        DATA(pdf2) = zfi_other_debitnote=>read_posts( comcode = comcode date = ' '
       docno = CONV #( doct-accountingdocument ) plant = plant year = year   ) .



*      ELSEIF   doct-accountingdocumenttype EQ 'VC' OR  doct-accountingdocumenttype EQ 'DG'  .
*
**        pdf2 = zclfi_drcr_fin=>read_posts( comcode = comcode date = ' '
**         docno = CONV #( doct-accountingdocument ) plant = plant year = year   ) .
*
*
*
*      ELSEIF  doct-accountingdocumenttype EQ 'DN'  .
**        pdf2 = zfi_dc_debit_credit=>read_posts( comcode = comcode date = ' '
**         docno = CONV #( <fs>-low ) plant = plant year = year   ) .
*
*
*      ELSEIF  doct-accountingdocumenttype EQ 'KG' .
**        pdf2 = zdebit_printclass=>read_posts( comcode = comcode
**        docno = CONV #( doct-accountingdocument ) plant = plant year = year   ) .
*      ELSEIF doct-accountingdocumenttype EQ 'WE' .
**        pdf2 = zfi_we_debitnote=>read_posts( comcode = comcode date = ' '
**          docno = CONV #( doct-accountingdocument ) plant = plant year = year   ) .
*      ENDIF.



    ENDLOOP.




     response->set_text( pdf2 ) .




  endmethod.
ENDCLASS.
