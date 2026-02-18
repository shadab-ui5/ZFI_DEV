CLASS zfi_other_debitnote DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
    CLASS-DATA : access_token TYPE string .
    CLASS-DATA : xml_file TYPE string .
    TYPES :
      BEGIN OF struct,
        xdp_template TYPE string,
        xml_data     TYPE string,
        form_type    TYPE string,
        form_locale  TYPE string,
        tagged_pdf   TYPE string,
        embed_font   TYPE string,
      END OF struct."
*DATA L1 TYPE NU

    CLASS-METHODS :

      create_client
        IMPORTING url           TYPE string
        RETURNING VALUE(result) TYPE REF TO if_web_http_client
        RAISING   cx_static_check,

      read_posts
        IMPORTING comcode         TYPE string
                  plant           TYPE string
                  date            TYPE string
                  docno           TYPE string
                  year            TYPE string

        RETURNING VALUE(result12) TYPE string
        RAISING   cx_static_check .


    CLASS-DATA :taxable                TYPE  p DECIMALS 2,
                cgst                   TYPE  p DECIMALS 2,
*                cgst1                  TYPE  p DECIMALS 2,
                sgst                   TYPE  p DECIMALS 2,
*                sgst1                  TYPE  p DECIMALS 2,
                igst                   TYPE  p DECIMALS 2,
*                igst1                  TYPE  p DECIMALS 2,
                description            TYPE  string,
                itemtext               TYPE  string,
                taxitemacctgdocitemref TYPE  string,
                taxable1               TYPE  string,
                freight                TYPE p DECIMALS 2,
                Insurance              TYPE p DECIMALS 2,
                Quantity               TYPE p DECIMALS 2,
                Product                type string.


    CLASS-DATA:subamt TYPE p DECIMALS 2,
               totamt TYPE p DECIMALS 2,
               xsml   TYPE string,
               n      TYPE p VALUE 0,
               total  TYPE p DECIMALS 2.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS lc_ads_render TYPE string VALUE '/ads.restapi/v1/adsRender/pdf'.
**     CONSTANTS  lv1_url    TYPE string VALUE 'https://adsrestapi-formsprocessing.cfapps.eu10.hana.ondemand.com/v1/adsRender/pdf?templateSource=storageName&TraceLevel=2'  .
**     CONSTANTS  lv2_url    TYPE string VALUE 'https://sagar.authentication.eu10.hana.ondemand.com/oauth/token'  .
    CONSTANTS lc_storage_name TYPE string VALUE 'templateSource=storageName'.
    CONSTANTS  lc_template_name TYPE string VALUE ''.

ENDCLASS.



CLASS ZFI_OTHER_DEBITNOTE IMPLEMENTATION.


METHOD create_client .
    DATA(dest) = cl_http_destination_provider=>create_by_url( url ).
    result = cl_web_http_client_manager=>create_by_http_destination( dest ).
ENDMETHOD .


METHOD if_oo_adt_classrun~main.

  TRY.
      DATA(return_data) = read_posts( comcode  = ''  plant = ''  date  = '' docno = '' year = ''  ) .
    CATCH cx_static_check.
      "handle exception
  ENDTRY.
ENDMETHOD.


METHOD read_posts.

SELECT SINGLE * FROM i_operationalacctgdocitem WHERE accountingdocument = @docno AND fiscalyear = @year
AND ( transactiontypedetermination = 'EGK' OR transactiontypedetermination = 'JIC'
OR transactiontypedetermination = 'JIS' OR  transactiontypedetermination = 'KBS' ) INTO @DATA(kgdocbymiro)  .

SELECT * FROM i_operationalacctgdocitem AS a
    LEFT JOIN i_productdescription AS b ON ( b~product = a~product AND b~language = 'E' )
    WHERE accountingdocument = @docno AND fiscalyear = @year AND taxitemacctgdocitemref IS NOT  INITIAL
    AND accountingdocumentitemtype NE 'T' INTO TABLE @DATA(it).


IF it IS NOT INITIAL .
READ TABLE it INTO DATA(po) INDEX 1 .
SELECT SINGLE * FROM i_operationalacctgdocitem WHERE accountingdocument = @docno
AND fiscalyear = @year AND supplier IS NOT INITIAL INTO @DATA(gathd).
SELECT SINGLE * FROM i_supplier WHERE supplier = @gathd-supplier INTO @DATA(tab_sup).
      DATA mobnum TYPE string .
      DATA gstnum TYPE string .
      gstnum = tab_sup-taxnumber3 .
      mobnum = tab_sup-phonenumber1 .
IF kgdocbymiro-accountingdocumenttype = 'ZA' OR kgdocbymiro-accountingdocumenttype   EQ 'RE'  .
SELECT SINGLE addressid FROM i_customer  WHERE customer = @kgdocbymiro-customer INTO @tab_sup-addressid .
SELECT SINGLE * FROM i_customer WHERE customer = @kgdocbymiro-customer INTO @DATA(tab_cus).
IF gstnum IS INITIAL .
gstnum = tab_cus-taxnumber3 .
ENDIF .
ENDIF .
SELECT SINGLE * FROM i_address_2 WITH PRIVILEGED ACCESS WHERE addressid = @tab_sup-addressid INTO @DATA(adds).
ENDIF .

SELECT SINGLE
                  a~jrnlentrycntryspecificbp1,
                  a~accountingdocumentheadertext,
                  a~documentreferenceid,
                  a~companycode,
                  a~fiscalyear,
                  A~accountingdocumenttype,

                  a~accountingdocument,
                  a~reversedocument ,
                  a~reversedocumentfiscalyear ,
                  a~reversalreferencedocument ,
                  a~reversalreferencedocumentcntxt ,
                  b~supplierinvoice,
                  e~supplierinvoiceidbyinvcgparty,
                  e~purchaseorder AS purchaseorder1,
                  f~purchaseorder AS purchaseorder2,
                  a~originalreferencedocument,
                  b~invoicegrossamount,
                  c~plant,
                  c~quantityinentryunit,
                  c~quantityinbaseunit,
                  c~batch,
                  c~materialdocument,
                  c~materialdocumentitem,
                  c~material,
                  c~purchaseorder,
                  c~purchaseorderitem ,
                  d~branch,
                  d~taxinvoicerepresentativename1,
                  d~taxnumber1,
                  d~vatregistration
FROM i_journalentry AS a
LEFT OUTER JOIN c_supplierinvoicedex     AS b ON ( b~invoicingparty = @gathd-supplier AND b~isinvoice = 'X' and b~supplierinvoiceidbyinvcgparty = a~documentreferenceid )
LEFT OUTER JOIN c_supplierinvoiceitemdex     AS e ON ( e~supplierinvoiceidbyinvcgparty = a~documentreferenceid  AND e~invoicingparty = @gathd-supplier AND e~isinvoice = 'X' )
LEFT OUTER JOIN c_supplierinvoiceitemdex     AS f ON ( f~supplierinvoiceidbyinvcgparty = a~documentreferenceid  AND f~isinvoice = '' )
LEFT OUTER JOIN i_materialdocumentitem_2 AS c ON ( c~materialdocument = left( a~accountingdocumentheadertext,10 )
                                                 AND  c~materialdocumentitem = right( left( a~accountingdocumentheadertext,14 ),4 ) )
LEFT OUTER  JOIN i_kr_businessplace AS d ON ( d~companycode = a~companycode  AND d~branch = @plant   )
WHERE a~accountingdocument = @docno AND a~fiscalyear = @year AND a~companycode = @comcode INTO @DATA(it1) .


SELECT
   I_REGIONTEXT~COUNTRY,
   I_REGIONTEXT~REGION,
   I_REGIONTEXT~LANGUAGE,
   I_REGIONTEXT~REGIONNAME
 FROM
  I_REGIONTEXT
 WHERE
  COUNTRY = 'IN'
  INTO TABLE @DATA(I_REGI) .



SELECT SINGLE * FROM i_purorditmpricingelementapi01 WHERE purchaseorder = @it1-purchaseorder
AND purchaseorderitem = @it1-purchaseorderitem AND ( conditiontype = 'ZBR0'
OR conditiontype = 'ZBR1' OR conditiontype = 'ZBR2' )  INTO @DATA(sup) .

SELECT SINGLE suppliername FROM i_supplier WHERE supplier = @sup-freightsupplier INTO @DATA(supname) .  " supplier details "
SELECT SINGLE * FROM zsupplier_details WITH PRIVILEGED ACCESS WHERE supplier = @tab_sup-Supplier INTO @DATA(email).

DATA(debitnote) = gathd-accountingdocument .
IF it1-reversedocument <> '' .
DATA(revrefdoc) = it1-reversedocument .
ELSE.
revrefdoc = it1-reversalreferencedocument .
ENDIF .

IF it1-reversedocumentfiscalyear <> '' .
DATA(revrefdocyear) = it1-reversedocumentfiscalyear .
ELSE.
revrefdocyear = it1-reversalreferencedocumentcntxt .
ENDIF .

SELECT SINGLE creationdate FROM i_purchaseorderapi01 with PRIVILEGED ACCESS WHERE purchaseorder = @po-a-purchasingdocument INTO @DATA(po_date)  .

SELECT SINGLE purchaseorderdate FROM i_purchaseorderapi01 with PRIVILEGED ACCESS WHERE purchaseorder = @it1-purchaseorder1 INTO @DATA(po_date1)  .
if sy-subrc <> 0.
SELECT SINGLE PurchasingDocumentOrderDate FROM I_SCHEDGAGRMTHDRAPI01 with PRIVILEGED ACCESS WHERE SchedulingAgreement = @po-a-purchasingdocument INTO @po_date  .
endif.

select Single MaterialDocument, DocumentDate, PostingDate
from I_MaterialDocumentItem_2
where PurchaseOrder  = @it1-purchaseorder1
into  @data(GRndata) .

data : drcr TYPE char25.
if gathd-DebitCreditCode = 'S'.
drcr = 'Debit Note'        .
else.
drcr = 'Credit Note'        .
ENDIF.

***** ****** header address ***************

*SELECT SINGLE FROM I_OperationalAcctgDocItem WITH PRIVILEGED ACCESS AS a
*INNER JOIN I_Plant WITH PRIVILEGED ACCESS AS b ON b~Plant = a~Plant
*INNER JOIN zaddress_2 AS c ON c~AddressID = b~AddressID
* FIELDS a~plant ,
*        b~AddressID ,
*        c~OrganizationName1 ,
*        c~OrganizationName2 ,
*       c~OrganizationName3 ,
*       c~OrganizationName4 ,
*       c~Region
*  WHERE a~AccountingDocument = @docno AND
*         a~CompanyCode = @comcode AND
*          a~FiscalYear = @year AND
*          a~Plant IS NOT INITIAL INTO @DATA(plant_addres) .
*
*CONCATENATE plant_addres-OrganizationName1
* plant_addres-OrganizationName2 plant_addres-OrganizationName3 plant_addres-OrganizationName4 INTO DATA(address) .

*****************

SELECT SINGLE FROM I_OperationalAcctgDocItem as a
LEFT outer JOIN I_PurchaseOrderHistoryAPI01 as b on b~PurchasingHistoryDocument = left( a~OriginalReferenceDocument , 10 )
LEFT OUTER JOIN I_MaterialDocumentItem_2 as c on c~PurchaseOrder = b~PurchaseOrder and c~PurchaseOrderItem = b~PurchaseOrderItem
FIELDS b~PurchaseOrder , b~PostingDate  , c~MaterialDocument , c~PostingDate as Materialdocdate
 WHERE A~AccountingDocument = @docno and a~PostingDate = @date
  and a~AccountingDocumentType = 'DK'
  and a~FiscalYear = @year  INTO @DATA(MIGO).

  select single * from  I_JournalEntry  where
       CompanyCode = @comcode and
       FiscalYear = @year and
       AccountingDocument = @docno
       INTO @data(ls_table) .

data : address TYPE string ,
       region TYPE string,
       unitname type string,
       cin type string,
       gstin type string.

case plant .
when '1100' .
address = |E-63, MIDC INDUSTRIAL AREA WALUJ AURANGABAD 431136, MAHARASHTRA, INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 1|.
cin = |U29130MH1988PTC046951|.
gstin = |27AABCM5791J1Z2|.
region = 'MH' .
when '2100' .
address = |PLOT NO. N 22, SIDCO INDUSTRIAL ESTATE PHASE III HOSUR 635126, TAMIL NADU. INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 4|.
cin = |U29130MH1988PTC046951|.
gstin = |33AABCM5791J1Z9|.
region = 'TN' .
when '1200' .
address = |E-69, MIDC INDUSTRIAL AREA WALUJ AURANGABAD 431136, MAHARASHTRA, INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 2|.
cin = |U29130MH1988PTC046951|.
gstin = |27AABCM5791J1Z2|.
region = 'MH' .
when '1300' .
address = |K22, K23, MIDC INDUSTRIAL AREA WALUJ AURANGABAD 431136, MAHARASHTRA, INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 3|.
cin = |U29130MH1988PTC046951|.
gstin = |27AABCM5791J1Z2|.
region = 'MH' .
when '1400' .
address = |GUT NO. 289, TURKABAD KHARADI, TAL - GANGAPUR, AURANGABAD - 431133, MAHARASHTRA, INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 6|.
cin = |U29130MH1988PTC046951|.
gstin = |27AABCM5791J1Z2|.
region = 'MH' .
when '2200' .
address = |PLOT NO.99, SIPCOT 1, HOSUR - 635126, TAMILNADU, INDIA| .
unitname = |MARATHWADA AUTO COMPO PVT.LTD UNIT 5|.
cin = |U29130MH1988PTC046951|.
gstin = |33AABCM5791J1Z9|.
region = 'TN' .



ENDCASE.

DATA(lv_xml) =
|<form1>| &&
|<Design_subform>| &&
|<address>| &&
|<hEADERADDRESS>| &&
|<unitname>{ unitname }</unitname>| &&
|<address1>{ address }</address1>| &&
|<gstin>{ gstin }</gstin>| &&
|<cin>{ cin }</cin>| &&
|<gstin_header>{ GRndata-PostingDate }</gstin_header>| &&
|<address2>{ tab_sup-Supplier }</address2>| &&
|<address3>{ GRndata-MaterialDocument }</address3>| &&
|<Phone>0240 6625613/14</Phone>| && "{ mobnumber }
|<statecode>{ Region }</statecode>| &&
|</hEADERADDRESS>| &&
|<Header_right>| &&
|<TextField2>{ gathd-AccountingDocument }</TextField2>| &&   "Note No.
|<DateField1>{ gathd-PostingDate }</DateField1>| .           "Note Date
*if it1-AccountingDocumentType = 'DK' OR it1-AccountingDocumentType = 'CR'.
 lv_xml = lv_xml  &&
|<Materialdocument>{ GRndata-MaterialDocument }</Materialdocument>| &&
|<MaterialDocumentdate>{ GRndata-PostingDate }</MaterialDocumentdate>| .
*ENDIF.
lv_xml = lv_xml &&
|<TextField2>{ ls_table-DocumentReferenceID }</TextField2>| &&    "Vendor Invoice Refrence
|<DateField2>{ ls_table-DocumentDate }</DateField2>| .     "Vendor Invoice Refrence Date
*if it1-AccountingDocumentType = 'DK' OR it1-AccountingDocumentType = 'CR'.
lv_xml = lv_xml  &&
|<po_no>{ po-a-PurchasingDocument }</po_no>| &&
|<po_date>{ po_date }</po_date>|.
*ENDIF.

lv_xml = lv_xml &&
|</Header_right>| &&
|</address>| &&
|<Supplier_address>| &&
|<Bill_address>| &&
|<Name>{ tab_sup-SupplierName }</Name>| &&
|<Address>{ tab_sup-StreetName  }</Address>| &&
|<stateuniontext>{ VALUE #( i_regi[ Region =  tab_sup-Region ]-RegionName OPTIONAL )  }</stateuniontext>| &&
|<stateunioncode>{ tab_sup-Region }</stateunioncode>| &&
|<GSTIN>{ tab_sup-TaxNumber3 }</GSTIN>| &&
|</Bill_address>| &&
|<Pay_address>| &&
|<statetext>{ VALUE #( i_regi[ Region =  tab_sup-Region ]-RegionName OPTIONAL )  }</statetext>| &&
|<statecode>{ tab_sup-Region }</statecode>| &&
|<pono>{ po-a-PurchasingDocument }</pono>| &&
|<Podate>{ po_date }</Podate>| &&
|<Linenumber></Linenumber>| &&
|</Pay_address>| &&
|</Supplier_address>| &&
|<Lineitem>| &&
|<Table1>| &&
|<HeaderRow/>| .




**********************************


*+++++++++++++++++++++++++++++++++++++++++

SELECT a~taxitemacctgdocitemref,
a~amountincompanycodecurrency,
a~amountintransactioncurrency,
a~material,
a~glaccount,
b~productdescription
FROM i_operationalacctgdocitem AS a
LEFT JOIN i_productdescription AS b ON ( b~product = a~product AND b~language = 'E' )
WHERE accountingdocument = @docno AND fiscalyear = @year AND companycode = @comcode
INTO TABLE @DATA(it_item).

DELETE it WHERE a-transactiontypedetermination = 'DIF'.
SORT it BY a-taxitemacctgdocitemref .

LOOP AT it INTO DATA(iv) ."WHERE a-transactiontypedetermination <> 'DIF' .
DATA(index) = sy-tabix.

SELECT SINGLE FROM i_glaccounttext
FIELDS glaccount ,
       glaccountname
WHERE  glaccount = @iv-a-glaccount
  AND language = 'E'
INTO @DATA(gltext)  .

taxable = taxable + iv-a-amountincompanycodecurrency .
SELECT SINGLE * FROM I_OperationalAcctgDocItem
WHERE material = @iv-a-material
AND purchasingdocument = @iv-a-purchasingdocument
AND purchasingdocumentitem = @iv-a-purchasingdocumentitem
and OriginalReferenceDocument = @iv-a-OriginalReferenceDocument
INTO @DATA(qty).

totamt  =  totamt + iv-a-amountincompanycodecurrency .

IF iv-b-productdescription IS INITIAL .
  iv-b-product            = gltext-glaccount.
  iv-b-productdescription = gltext-glaccountname.
ENDIF .

READ TABLE it INTO DATA(wa) INDEX index + 1.
IF sy-subrc <> 0.
 clear wa.
ENDIF.

IF wa-a-taxitemacctgdocitemref <> iv-a-taxitemacctgdocitemref .

  n = n + 1.

SELECT SUM( amountintransactioncurrency )
FROM i_operationalacctgdocitem
WHERE accountingdocument = @iv-a-accountingdocument
AND taxitemacctgdocitemref = @iv-a-taxitemacctgdocitemref
AND companycode = @iv-a-companycode
AND fiscalyear = @iv-a-fiscalyear
*AND glaccount = '0002731003'      "CGST
AND TransactionTypeDetermination = 'JIC'      "CGST
INTO @cgst.

SELECT SUM( amountintransactioncurrency )
FROM i_operationalacctgdocitem
WHERE accountingdocument = @iv-a-accountingdocument
AND taxitemacctgdocitemref = @iv-a-taxitemacctgdocitemref
AND companycode = @iv-a-companycode
AND fiscalyear = @iv-a-fiscalyear
*AND glaccount = '0002731004'     "SGST
AND TransactionTypeDetermination = 'JIS'
INTO @sgst.

SELECT SUM( amountintransactioncurrency )
FROM i_operationalacctgdocitem
WHERE accountingdocument = @iv-a-accountingdocument
AND taxitemacctgdocitemref = @iv-a-taxitemacctgdocitemref
AND companycode = @iv-a-companycode
AND fiscalyear = @iv-a-fiscalyear
*AND glaccount = '0002731005'      "IGST
AND TransactionTypeDetermination = 'JII'
INTO @igst.

totamt = taxable + cgst + sgst + igst.
IF taxable LT 0.
  taxable = taxable * -1.
ENDIF.
taxable1 = taxable.

IF cgst LT 0.
  cgst = cgst * -1.
ENDIF.
IF sgst LT 0.
  sgst = sgst * -1.
ENDIF.
IF igst LT 0.
  igst = igst * -1.
ENDIF.
IF totamt LT 0.
  totamt = totamt * -1.
ENDIF.

SELECT single a~ConditionAmount
  FROM I_PurOrdItmPricingElementAPI01 AS a
  Inner JOIN I_PurchaseOrderItemAPI01 AS b ON a~PurchaseOrder = b~PurchaseOrder and  a~PurchaseOrderItem = b~PurchaseOrderItem
  WHERE b~PurchaseOrder = @iv-a-PurchasingDocument
and ltrim( material, '0' ) = ltrim( @iv-a-product, '0' )
and a~ConditionType = 'FVA1'
INTO  @DATA(ls_amt1).

SELECT single a~ConditionAmount
  FROM I_PurOrdItmPricingElementAPI01 AS a
  Inner JOIN I_PurchaseOrderItemAPI01 AS b ON a~PurchaseOrder = b~PurchaseOrder and  a~PurchaseOrderItem = b~PurchaseOrderItem
  WHERE b~PurchaseOrder = @iv-a-PurchasingDocument
and ltrim( material, '0' ) = ltrim( @iv-a-product, '0' )
and a~ConditionType = 'ZI10'
INTO  @DATA(ls_amt2).

freight = ls_amt1.
Insurance = ls_amt2.


IF iv-a-PurchaseOrderQty is initial.
Quantity = '1.00'.
data(GLAcc) = gltext-GLAccountName.
Product = ''.
ELSE.
Quantity = iv-a-PurchaseOrderQty.
GLAcc = ''.
Product = |{ iv-b-Product ALPHA = OUT }|.  " Remove leading zeros
ENDIF.



*DATA(lv_xml2) =
*|<Row1>| &&
*|<Sno>{ n }</Sno>| &&
*|<descriptioncode>{ iv-b-product }</descriptioncode>| &&
*|<description>{ iv-b-productdescription }</description>| &&
*|<Text>{ iv-a-documentitemtext }</Text>| &&
*|<Qty>{ qty-PurchaseOrderQty }</Qty>| &&    "orderquantity
*|<Taxable123>{ taxable1 }</Taxable123>| &&
**         |<CGSTRAte>{ i_code1-gstrate }</CGSTRAte>| &&
*|<CGSTamount>{ cgst }</CGSTamount>| &&
**         |<SGSTRATE>{ i_code2-gstrate  }</SGSTRATE>| &&
*|<SGSTamount>{ sgst }</SGSTamount>| &&
**         |<IGSTRATE>{ i_code-gstrate }</IGSTRATE>| &&
*|<IGSTamount>{ igst }</IGSTamount>| &&
*|<TOT123>{ totamt }</TOT123>| &&
*|</Row1>| .
*{ ls_amt }
**************** Lineitems ******************

lv_xml = lv_xml &&

|<Row1>| &&
|<Refno>{ ls_table-DocumentReferenceID }</Refno>| &&
|<Itemcode>{ Product  }</Itemcode>| &&
|<descservicegoods>{ iv-b-ProductDescription }</descservicegoods>| &&
|<hsnsaccode>{ iv-a-IN_HSNOrSACCode }</hsnsaccode>| &&
|<gldes>{ GLAcc }</gldes>| &&
|<Qty>{ iv-a-PurchaseOrderQty }</Qty>| &&
|<UOM>{ iv-a-BaseUnit }</UOM>| &&
|<Rateper>{ taxable / Quantity }</Rateper>| &&
|<Freight>{ freight + Insurance  }</Freight>| &&
|<Total>{ taxable + freight + Insurance }</Total>| &&
|<discount></discount>| &&
|<abatement></abatement>| &&
|<Taxavlevalue>{ taxable }</Taxavlevalue>| &&
|<cgstrate>{ cgst / taxable * 100  }</cgstrate>| &&
|<cgstamt>{ cgst }</cgstamt>| &&
|<sgstrate>{ Sgst / taxable * 100 }</sgstrate>| &&
|<sgstamt>{ Sgst }</sgstamt>| &&
|<igstrate>{ Igst / taxable * 100 }</igstrate>| &&
|<igstamt>{ Igst }</igstamt>| &&
|<totalrate>{ cgst / taxable * 100 + Sgst / taxable * 100 + Igst / taxable * 100 } </totalrate>| &&
|<totalamt>{ totamt + freight + Insurance  }</totalamt>| &&
|</Row1>|  .

   subamt = subamt + totamt + freight + Insurance.

CLEAR  :
*   iv,i_code,i_code1,i_code2,
totamt,cgst,sgst,igst,description,itemtext,taxable,taxable1,qty.
ENDIF .

ENDLOOP .

READ TABLE it_item INTO DATA(dta) WITH KEY glaccount = '0004601003' .
dta-amountintransactioncurrency  = -1 * dta-amountintransactioncurrency  .

DATA invoicetotal TYPE i_operationalacctgdocitem-amountincompanycodecurrency .

SELECT a~documentitemtext
FROM i_operationalacctgdocitem AS a
WHERE accountingdocument = @docno
AND fiscalyear = @year
AND a~companycode = @comcode
AND a~documentitemtext IS NOT INITIAL
AND a~financialaccounttype = 'K'
 INTO TABLE @DATA(remarktab) .

select single DocumentItemText from I_JournalEntryItem WITH PRIVILEGED ACCESS
where CompanyCode = @comcode and
FiscalYear = @year and
AccountingDocument = @docno and
FinancialAccountType = 'K' and
SourceLedger = '0L' and
Ledger = '0L'
INTO @data(lv_itemtext) .

DATA remark TYPE string .
LOOP AT remarktab INTO DATA(wa1) .
IF remark IS INITIAL .
remark = |{ wa1-documentitemtext }| .
ELSE .
remark = |{ remark } , { wa1-documentitemtext }| .
ENDIF .
ENDLOOP.

IF remark IS INITIAL .
remark = kgdocbymiro-documentitemtext  .
ENDIF .

DATA : template TYPE string ,
       header TYPE string .

if it1-AccountingDocumentType = 'DK' .
template = 'DebitNote_NEW/DebitNote_NEW' .
header = | CREDIT NOTE| .
 ELSEIF ( it1-AccountingDocumentType = 'CR'  or it1-AccountingDocumentType = 'KG' )  and ( it1-purchaseorder2 is INITIAL ) .
 template = 'DebitNote/DebitNote' .
 header = | DEBIT NOTE | .
 elseif   ( it1-AccountingDocumentType = 'CR'  or it1-AccountingDocumentType = 'KG' )  and  ( it1-purchaseorder2 is  not INITIAL ) .
 template = 'Debit_Note_Multi/Debit_note' .
 header = | DEBIT NOTE | .
  endif .
lv_xml = lv_xml &&

|</Table1>| &&
|<Totalamount>{ subamt }</Totalamount>| &&
|</Lineitem>| &&
|<Footer>| &&
|<Remark>{ remark }</Remark>| &&
|<Netpayablevalue>{ subamt }</Netpayablevalue>| &&
|<Netpayablevalueinwords></Netpayablevalueinwords>| &&
|<cgst_amount></cgst_amount>| &&
|<sgst_amount></sgst_amount>| &&
|<igst_amount></igst_amount>| &&
|</Footer>| &&
|<Footer_sign/>| &&
|<TextField3>{ HEADER }</TextField3>| &&
|</Design_subform>| &&
|</form1>| .

data  lxstring type string .
 if it1-AccountingDocumentType = 'DK' and ( it1-purchaseorder2 is INITIAL ) .
 template = 'DebitNote_NEW/DebitNote_NEW' .
 header = | CREDIT NOTE| .
 elseif it1-AccountingDocumentType = 'DK' and ( it1-purchaseorder2 is not INITIAL ) .

 template = 'Credit_Note_Multi/Credit_note' .
 header = | CREDIT NOTE| .
REPLACE ALL OCCURRENCES OF '</form1>' in lv_xml  with '' .
REPLACE ALL OCCURRENCES OF '<form1>' in lv_xml   with '' .
REPLACE ALL OCCURRENCES OF '<Design_subform>' in lv_xml   with '' .
REPLACE ALL OCCURRENCES OF '</Design_subform>' in lv_xml   with '' .
 lxstring = lxstring && lv_xml .



  lxstring = |<form1>| && |<Design_subform>| && lxstring && |</Design_subform>| && lv_xml && lv_xml && |</form1>|  .
  lv_xml = lxstring  .
 ELSEIF ( it1-AccountingDocumentType = 'CR'  or it1-AccountingDocumentType = 'KG' )  and ( it1-purchaseorder2 is INITIAL ) .
 template = 'DebitNote/DebitNote' .
 header = | DEBIT NOTE | .
elseif   ( it1-AccountingDocumentType = 'CR'  or it1-AccountingDocumentType = 'KG' )  and  ( it1-purchaseorder2 is  not INITIAL ) .

REPLACE ALL OCCURRENCES OF '</form1>' in lv_xml  with '' .
REPLACE ALL OCCURRENCES OF '<form1>' in lv_xml   with '' .
REPLACE ALL OCCURRENCES OF '<Design_subform>' in lv_xml   with '' .
REPLACE ALL OCCURRENCES OF '</Design_subform>' in lv_xml   with '' .




 lxstring = lxstring && lv_xml .



  lxstring = |<form1>| && |<Design_subform>| && lxstring && |</Design_subform>| && lv_xml && lv_xml && |</form1>|  .
lv_xml = lxstring  .
 template = 'Debit_Note_Multi/Debit_note' .
 header = | DEBIT NOTE | .
 endif .
result12 =       zcl_form_dev=>getpdf(
                  template = template
                         xmldata = lv_xml )  .

ENDMETHOD.
ENDCLASS.
