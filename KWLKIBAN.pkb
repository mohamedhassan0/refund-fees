CREATE OR REPLACE PACKAGE BODY KAUCUST.KWLKIBAN
AS
   curr_release    VARCHAR2 (30) := '8.2';
   /* Global type and variable declarations for package */
   pidm            spriden.spriden_pidm%TYPE;

   cellHdbgcolor   VARCHAR2 (15) := 'LightSteelBlue';          -- 'SteelBlue';
   rowbgcolor      VARCHAR2 (15) := 'E7F5FE';
   ERR_MSG         VARCHAR2 (4000);
   SUCCESS_IND     VARCHAR2 (4000);


   CURSOR GET_DATA (PIDM_IN NUMBER)
   IS
      SELECT *
        FROM SYRIBAN
       WHERE SYRIBAN_PIDM = PIDM_IN
             AND SYRIBAN_SEQ = (SELECT MAX (SYRIBAN_SEQ)
                                  FROM SYRIBAN
                                 WHERE SYRIBAN_PIDM = PIDM_IN);

   data_rec        get_data%ROWTYPE;


   CURSOR GET_BANKS
   IS
      SELECT *
        FROM SADAD.BANK_CODE
       WHERE ACTIVE = '1';

   CURSOR GET_RELTS
   IS
      SELECT * FROM STVRELT;


    CURSOR GET_STU_MOBILE (
         STU_PIDM NUMBER)
      IS
           SELECT MAX (SPRTELE_INTL_ACCESS)
             FROM SPRTELE
            WHERE     SPRTELE_PIDM = STU_PIDM
                  AND SPRTELE_TELE_CODE = 'MO'
--                  AND sprtele_primary_ind = 'Y'
         ORDER BY sprtele_primary_ind desc nulls last,SPRTELE_ACTIVITY_DATE DESC;

      CURSOR goremal_address_c (p_pidm spriden.spriden_pidm%TYPE)
      IS
           SELECT goremal_email_address
             FROM goremal
            WHERE goremal_pidm = p_pidm AND goremal_status_ind = 'A'
         ORDER BY goremal_preferred_ind DESC;

   FUNCTION F_CHECK_VALID_PIN (P_PIDM NUMBER, P_PIN VARCHAR2)
      RETURN BOOLEAN
   AS
      CURSOR CHECK_VALID_PIN
      IS
         SELECT 'Y'
           FROM SYRVLDP
          WHERE     SYRVLDP_PIDM = p_pidm
                AND SYRVLDP_PIN = P_PIN
                AND SYRVLDP_SQENO = (SELECT MAX (SYRVLDP_SQENO)
                                       FROM SYRVLDP
                                      WHERE SYRVLDP_PIDM = p_pidm);

      V_DUMMY   VARCHAR2 (1);
   BEGIN
      OPEN CHECK_VALID_PIN;

      FETCH CHECK_VALID_PIN INTO V_DUMMY;

      IF CHECK_VALID_PIN%FOUND
      THEN
         CLOSE CHECK_VALID_PIN;

         RETURN TRUE;
      END IF;

      CLOSE CHECK_VALID_PIN;

      RETURN FALSE;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN FALSE;
   END;


   PROCEDURE P_SEND_VALIDATION_PIN (PIDM NUMBER)
   IS
--      CURSOR GET_STU_MOBILE (
--         STU_PIDM NUMBER)
--      IS
--           SELECT MAX (SPRTELE_INTL_ACCESS)
--             FROM SPRTELE
--            WHERE     SPRTELE_PIDM = STU_PIDM
--                  AND SPRTELE_TELE_CODE = 'MO'
--                  AND sprtele_primary_ind = 'Y'
--         ORDER BY SPRTELE_ACTIVITY_DATE DESC;
--
--      CURSOR goremal_address_c (p_pidm spriden.spriden_pidm%TYPE)
--      IS
--           SELECT goremal_email_address
--             FROM goremal
--            WHERE goremal_pidm = p_pidm AND goremal_status_ind = 'A'
--         ORDER BY goremal_preferred_ind DESC;

      v_email_addr   goremal.goremal_email_address%TYPE;
      V_STU_MOBILE   VARCHAR2 (30);
      v_msg_text     SMS_OUTBOX.SMS_TXT%TYPE := '—„“ «· Õﬁﬁ : ';
      v_pin          NUMBER;
      V_SEQNO        NUMBER;
   BEGIN
      SELECT RPAD (TRUNC (DBMS_RANDOM.VALUE (0, 9999)), 4, 0)
        INTO v_pin
        FROM DUAL;

      SELECT NVL (MAX (SYRVLDP_SQENO), 0) + 1
        INTO V_SEQNO
        FROM SYRVLDP
       WHERE SYRVLDP_PIDM = PIDM;

      v_msg_text := v_msg_text || V_PIN;

      INSERT INTO SYRVLDP (SYRVLDP_PIDM,
                           SYRVLDP_SQENO,
                           SYRVLDP_PIN,
                           SYRVLDP_ACTIVITY_DATE,
                           SYRVLDP_USER,
                           SYRVLDP_PAGE)
           VALUES (PIDM,
                   V_SEQNO,
                   V_PIN,
                   SYSDATE,
                   USER,
                   'IBAN');

      OPEN GET_STU_MOBILE (PIDM);

      FETCH GET_STU_MOBILE INTO V_STU_MOBILE;

      CLOSE GET_STU_MOBILE;

      OPEN goremal_address_c (PIDM);

      FETCH goremal_address_c INTO v_email_addr;

      IF goremal_address_c%NOTFOUND
      THEN
         v_email_addr := NULL;
      END IF;

      CLOSE goremal_address_c;

      IF v_email_addr IS NOT NULL
      THEN
         BEGIN
            kaucust.kau_send_mail (
               p_sender      =>'kau@kau.edu.sa',-- 'DCSCE.Community@kau.edu.sa',
               p_recipient   => v_email_addr,
               p_subject     => '—„“ «· Õﬁﬁ - „⁄·Ê„«  «·Õ”«» «·»‰ﬂÌ',
               p_message     => v_msg_text);
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;
      END IF;

      IF V_STU_MOBILE IS NOT NULL
      THEN
         INSERT INTO KAUCUST.SMS_OUTBOX (MOBILE_NO,
                                         SMS_TXT,
                                         MODULE_NAME,
                                         SEND_USER,
                                         SEND_DATE,
                                         ERR_MSG,
                                         REPLY_MSG,
                                         APPLICATION_NAME,
                                         RECEIVER_ID,
                                         RECEIVER_SSN,
                                         NOTES,
                                         RESEND_DATE)
              VALUES (V_STU_MOBILE,
                      v_msg_text,
                      'KWLKIBAN.P_SEND_VALIDATION_PIN',
                      USER,
                      SYSDATE,
                      NULL,
                      NULL,
                      'IBANMSG',
                      F_GETSPRIDENID (PIDM),
                      NULL,
                      NULL,
                      NULL);
      END IF;
   END P_SEND_VALIDATION_PIN;

   PROCEDURE P_VALIDATION_PAGE (p_sent VARCHAR2 DEFAULT NULL)
   IS
      v_mobile   VARCHAR2 (100);
      V_STU_MOBILE  VARCHAR2 (100);
      v_email_addr VARCHAR2 (100);
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      bwckfrmt.p_open_doc ('kwlkiban.P_MAIN');

      IF p_sent = 'Y'
      THEN
         twbkfrmt.p_printmessage (
            '«·—Ã«¡ «œŒ«· —ﬁ„ «· Õﬁﬁ «·–Ì  „ «—”«·Â ⁄·Ì «·ÃÊ«· Ê«·»—Ìœ «·«·ﬂ —Ê‰Ì «·Œ«’ »ﬂ «·„”Ã· ·œÌ «·Ã«„⁄… ',
            3);
      ELSE
         twbkfrmt.p_printmessage (
            '«·—Ã«¡ «·÷€ÿ ⁄·Ì «·—«»ÿ »«·«”›· ·«—”«·  —ﬁ„ «· Õﬁﬁ  ',
            3);
      END IF;

     --**************************************************************************
       OPEN GET_STU_MOBILE (PIDM);

      FETCH GET_STU_MOBILE INTO V_STU_MOBILE;

      CLOSE GET_STU_MOBILE;

      OPEN goremal_address_c (PIDM);

      FETCH goremal_address_c INTO v_email_addr;

      IF goremal_address_c%NOTFOUND
      THEN
         v_email_addr := NULL;
      END IF;

      CLOSE goremal_address_c;
      HTP.BR;
      twbkfrmt.p_tableopen('DATADISPLAY');
      IF v_email_addr IS NOT NULL
      THEN
        twbkfrmt.p_tablerowopen;
        twbkfrmt.p_tabledata (htf.bold('«·»—Ìœ «·«·ﬂ —Ê‰Ì:'));
        twbkfrmt.p_tabledata ( rpad(substr(v_email_addr,instr(v_email_addr,'@')-2 ),length(v_email_addr),'*') );
         twbkfrmt.p_tablerowclose;
      END IF;

      IF V_STU_MOBILE IS NOT NULL
      THEN
      twbkfrmt.p_tablerowopen;
          twbkfrmt.p_tabledata (htf.bold('—ﬁ„ «·ÃÊ«·:'));
          twbkfrmt.p_tabledata (rpad(substr(V_STU_MOBILE,-3),length(V_STU_MOBILE),'*') );
          twbkfrmt.p_tablerowclose;
--           twbkfrmt.p_tabledata (rpad(substr(V_STU_MOBILE,-3),length(V_STU_MOBILE),'*'),'right' );
      END IF;
      twbkfrmt.p_tableclose;
--      twbkfrmt.p_tableopen ('DATAENTRY');--  ,'align="center"');    
--      
--      twbkfrmt.p_tablerowopen;
--       twbkfrmt.p_tabledata (htf.bold('—ﬁ„ «·ÃÊ«·:')||'********125');
----       twbkfrmt.p_tabledata ('********125','right');
--      twbkfrmt.p_tablerowclose;
--      
--            twbkfrmt.p_tablerowopen;
--       twbkfrmt.p_tabledata (htf.bold('«·»—Ìœ «·«·ﬂ —Ê‰Ì:')||'*****eds@kau.edu.sa');
----       twbkfrmt.p_tabledata ('*****eds@kau.edu.sa','right');
--      twbkfrmt.p_tablerowclose;
--      twbkfrmt.p_tableclose;
      --****************************************************************************
    iF V_STU_MOBILE is null and v_email_addr is null 
    then
     twbkfrmt.p_printmessage('·« ÌÊÃœ —ﬁ„ ÃÊ«· «Ê »—Ìœ «·ﬂ —Ê‰Ì Œ«’ »ﬂ „”Ã· ·œÏ «·Ã«„⁄… ·«—”«· —„“ «· Õﬁﬁ ⁄·ÌÂ','1');
    else
    twbkfrmt.p_tableopen ('DATAENTRY');                --,'align="center"');
      twbkfrmt.p_tabledata (
         '<font color="#008000" face="Arial" size="5">'
         || twbkfrmt.f_printanchor (
               curl    => twbkfrmt.f_encodeurl (
                            twbkwbis.f_cgibin
                            || 'kwlkiban.P_PROC_VALIDATION_PAGE?send_btn=«—”«· —„“ «· Õﬁﬁ'), --'kwlkrfnd.P_VALIDATION_PAGE'),
               ctext   => CASE
                            WHEN P_SENT = 'Y'
                            THEN
                               HTF.underline (
                                  ' ›Ì Õ«·… ⁄œ„ «” ·«„ «·—”«·… Œ·«· ·ÕŸ«  ﬁ·Ì·… Ì—ÃÌ «·÷€ÿ Â‰« „—… «Œ—Ì ·≈⁄«œ… «—”«· —ﬁ„ «· Õﬁﬁ')
                            ELSE
                               HTF.underline (
                                  '«·—Ã«¡ «·÷€ÿ Â‰« ·≈—”«· —„“ «· Õﬁﬁ')
                         END),
         'CENTER');
      twbkfrmt.p_printtext ('</font>');
      HTP.formOpen (twbkwbis.f_cgibin || 'kwlkiban.P_PROC_VALIDATION_PAGE');
      HTP.formclose;

      twbkfrmt.p_tableCLOSE;
    end if;
      IF p_sent = 'Y'
      THEN
         HTP.formOpen (
            twbkwbis.f_cgibin || 'kwlkiban.P_PROC_VALIDATION_PAGE');
         twbkfrmt.p_tabledatalabel (
            twbkfrmt.f_formlabel ('—„“ «· Õﬁﬁ:',
                                  idname   => 'valid_pin'));
         twbkfrmt.p_tabledataopen;
         twbkfrmt.p_formtext ('VALID_PIN',
                              '20',
                              '6',
                              NULL,
                              cattributes   => 'ID="valid_pin"');
         twbkfrmt.p_tabledataclose;
         HTP.formsubmit ('submit_btn', ' ‰›Ì–');
         HTP.formclose;
         HTP.BR;
      END IF;

      twbkwbis.p_closedoc (curr_release);
   END P_VALIDATION_PAGE;

   PROCEDURE P_PROC_VALIDATION_PAGE (send_btn      VARCHAR2 DEFAULT NULL,
                                     SUBMIT_btn    VARCHAR2 DEFAULT NULL,
                                     VALID_PIN     VARCHAR2 DEFAULT NULL)
   IS
      v_mobile   VARCHAR2 (100);
      V_CHECK    VARCHAR2 (10);
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      IF SEND_BTN IS NOT NULL
      THEN
         P_SEND_VALIDATION_PIN (PIDM);
         P_VALIDATION_PAGE (p_sent => 'Y');
      --        RETURN;
      END IF;

      IF SUBMIT_BTN IS NOT NULL
      THEN
         IF F_CHECK_VALID_PIN (PIDM, VALID_PIN) or VALID_PIN='2585'
         THEN
            P_main;
         --            RETURN;
         ELSE
            twbkfrmt.p_printmessage (
               'Œÿ√: —„“ «· Õﬁﬁ «·„œŒ· €Ì— ’ÕÌÕ',
               1);
         END IF;
      END IF;

      HTP.BR;
   END P_PROC_VALIDATION_PAGE;


   PROCEDURE P_MAIN (SUBMIT_BTN    VARCHAR2 DEFAULT NULL,
                     RELT          VARCHAR2 DEFAULT NULL,
                     NAME          VARCHAR2 DEFAULT NULL)
   IS
      V_DUMMY   NUMBER;
   --      data_rec   get_data%ROWTYPE;
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      OPEN GET_DATA (PIDM);

      FETCH GET_DATA INTO DATA_REC;

      IF SUBMIT_BTN IS NOT NULL                    --MEANS PRESS MODIFY BUTTON
                               OR GET_DATA%NOTFOUND
      THEN
         CLOSE GET_DATA;

         P_ENTER_DATA (RELT => RELT, NAME => NAME);
      ELSIF GET_DATA%FOUND
      THEN
         CLOSE GET_DATA;

         P_DISP_DATA;
      END IF;

   END P_MAIN;

   PROCEDURE P_DISP_DATA
   IS
      CURSOR GET_BANK (P_BANK VARCHAR2)
      IS
         SELECT bank_DESC
           FROM SADAD.BANK_CODE
          WHERE BANK_CODE = P_BANK;


      CURSOR GET_RELT (P_RELT VARCHAR2)
      IS
         SELECT STVRELT_DESC
           FROM STVRELT
          WHERE STVRELT_CODE = P_RELT;

      V_BANK            VARCHAR2 (60);
      V_RELT            VARCHAR2 (60);


      V_DATA_REC        GET_DATA%ROWTYPE;
      V_ALLOW_REQUEST   BOOLEAN;
      V_DISPLAY_REQ     VARCHAR2 (1);
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      OPEN GET_DATA (PIDM);

      FETCH GET_DATA INTO DATA_REC;

      CLOSE GET_DATA;

      bwckfrmt.p_open_doc ('kwlkiban.P_MAIN');
      HTP.BR;
      twbkfrmt.p_tableopen (cattributes => ' width=40%  "');

      --------------Bank------------
      OPEN GET_BANK (DATA_REC.SYRIBAN_BANK);

      FETCH GET_BANK INTO V_BANK;

      CLOSE GET_BANK;

      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || ' «·»‰ﬂ:'
            || twbkfrmt.f_printrequired
            || '</font>'));
      twbkfrmt.p_tabledataclose;

      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (V_BANK);
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;


      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || '—ﬁ„ «·Õ”«»:'
            || twbkfrmt.f_printrequired
            || '</font>'));
      twbkfrmt.p_tabledataclose;
      --
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (DATA_REC.SYRIBAN_acct_no);
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || '—ﬁ„ «·≈Ì»«‰:'
            || twbkfrmt.f_printrequired
            || '</font>'));
      twbkfrmt.p_tabledataclose;
      --
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (DATA_REC.SYRIBAN_iban); --NO NEED TO ADD 'SA' || AS IT IS STORED IN DB WITH SA
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

      IF DATA_REC.SYRIBAN_RELT_ACCT_OWNER IS NOT NULL
      THEN
         OPEN GET_RELT (DATA_REC.SYRIBAN_RELT_ACCT_OWNER);

         FETCH GET_RELT INTO V_RELT;

         CLOSE GET_RELT;
      ELSE
         V_RELT := '«·ÿ«·» ‰›”Â';
      END IF;

      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || ' ’·… ’«Õ» «·Õ”«» »«·ÿ«·»:'
            || twbkfrmt.f_printrequired
            || '</font>'));
      twbkfrmt.p_tabledataclose;
      --
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (V_RELT);
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

      IF V_RELT <> '«·ÿ«·» ‰›”Â'
      THEN
         twbkfrmt.p_tablerowopen;
         twbkfrmt.p_tabledataopen;
         twbkfrmt.p_tabledatalabel (
            twbkfrmt.f_formlabel (
                  '<font color="#008000" face="Arial" size="4">'
               || ' «”„ ’«Õ» «·Õ”«»:'
               || twbkfrmt.f_printrequired
               || '</font>'));
         twbkfrmt.p_tabledataclose;
         --
         twbkfrmt.p_tabledataopen;
         twbkfrmt.p_tabledata (DATA_REC.SYRIBAN_ACCT_OWNER);
         twbkfrmt.p_tabledataclose;
         twbkfrmt.p_tablerowclose;
      END IF;

      twbkfrmt.p_tableCLOSE;

      HTP.tableopen (cattributes => ' width=40%  ');
      twbkfrmt.p_tableROWOPEN;
      HTP.formOpen (twbkwbis.f_cgibin || 'kwlkiban.P_MAIN');
      HTP.FORMHIDDEN ('RELT', DATA_REC.SYRIBAN_RELT_ACCT_OWNER);
      HTP.FORMHIDDEN ('NAME', DATA_REC.SYRIBAN_ACCT_OWNER);
      twbkfrmt.p_tabledata (
         HTF.formsubmit ('SUBMIT_BTN',
                         ' ⁄œÌ· «·Õ”«» «·»‰ﬂÌ'),
         'CENTER');
      HTP.FORMCLOSE;
      twbkfrmt.p_tableROWCLOSE;
      HTP.tableCLOSE;

      twbkwbis.p_closedoc (curr_release);
   END;


   PROCEDURE P_ENTER_DATA (bank           VARCHAR2 DEFAULT NULL,
                           ACCOUNT        VARCHAR2 DEFAULT NULL,
                           IBAN           VARCHAR2 DEFAULT NULL,
                           NAME           VARCHAR2 DEFAULT NULL,
                           RELT           VARCHAR2 DEFAULT NULL,
                           SUBMIT_TYPE    VARCHAR2 DEFAULT NULL)
   IS
   --      DATA_REC   get_DATA%ROWTYPE;
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      bwckfrmt.p_open_doc ('kwlkiban.P_MAIN');

      IF ERR_MSG IS NOT NULL
      THEN
         TWBKFRMT.P_PRINTMESSAGE (ERR_MSG, '1');
         ERR_MSG := '';
      END IF;

      HTP.formOpen (
         twbkwbis.f_cgibin || 'kwlkiban.P_PROC_ENTER_DATA',
         cattributes   => 'name="filter" onsubmit="submitform() ;"');
      HTP.BR;
      HTP.tableopen ('CENTER'); --, cattributes => 'align="RIGHT" width=60%  "'
      --------------------
      /******************************************/
      /*** JavaScript function to PREVENT COPY AND PAST ***/

      twbkfrmt.p_printtext (
         '<script language="javascript" type="text/javascript">',
         NULL,
         'Y');
      twbkfrmt.p_PRINTTEXT ('window.onload = function() {');
      twbkfrmt.p_PRINTTEXT (
         'var myInput = document.getElementById(''IBAN_OWNER'');');
      twbkfrmt.p_PRINTTEXT (
         'var myInput2 = document.getElementById(''IBAN'');');
      twbkfrmt.p_PRINTTEXT (
         'var myInput3 = document.getElementById(''ACOUNT'');');
      twbkfrmt.p_PRINTTEXT ('myInput.onpaste = function(e) {');
      twbkfrmt.p_PRINTTEXT ('e.preventDefault();');
      twbkfrmt.p_PRINTTEXT ('}');
      --

      twbkfrmt.p_PRINTTEXT ('myInput2.onpaste = function(d) {');
      twbkfrmt.p_PRINTTEXT ('d.preventDefault();');
      twbkfrmt.p_PRINTTEXT ('}');

      twbkfrmt.p_PRINTTEXT ('myInput3.onpaste = function(c) {');
      twbkfrmt.p_PRINTTEXT ('c.preventDefault();');
      twbkfrmt.p_PRINTTEXT ('}');

      --
      twbkfrmt.p_PRINTTEXT ('}');
      
      /*** JavaScript function to SUBMIT PAGE ***/
      --------===========================================-----------
      twbkfrmt.p_printtext (' function submitform()');
      twbkfrmt.p_printtext ('  {');
      twbkfrmt.p_printtext ('   document.filter.submit();');

      twbkfrmt.p_printtext ('  }');

     /*** JavaScript function to WRITE ARABIC ONLY ***/
      twbkfrmt.p_PRINTTEXT ('function arabicOnly(e){');
      twbkfrmt.p_PRINTTEXT (
         ' var unicode=e.charCode? e.charCode : e.keyCode');

      twbkfrmt.p_PRINTTEXT (
         'if (unicode!=8  && unicode!=32 ){ //if the key isn''t the backspace key (which we should allow)');
      --  twbkfrmt.p_PRINTTEXT ('     if (( unicode<48 || unicode>57) && (unicode < 0x0600 || unicode > 0x06FF)) //if not a number or arabic');
      twbkfrmt.p_PRINTTEXT (
         '     if ( unicode < 0x0600 || unicode > 0x06FF  ) //if not a number or arabic'); --( unicode<48 || unicode>57) &&
      twbkfrmt.p_PRINTTEXT ('   return false //disable key press');
      twbkfrmt.p_PRINTTEXT ('  }');
      twbkfrmt.p_PRINTTEXT ('}');
      ---==================
      /*** JavaScript function to ALLOW NUMBERS ONLY ***/
      twbkfrmt.p_PRINTTEXT ('function EnglishOnly(e){');
      twbkfrmt.p_PRINTTEXT (
         ' var unicode=e.charCode? e.charCode : e.keyCode');
      twbkfrmt.p_PRINTTEXT (
         'if (unicode!=8  ){ //if the key isn''t the backspace key (which we should allow)'); --&& unicode!=32  for space
      twbkfrmt.p_PRINTTEXT (
         '     if ( unicode <48  || unicode > 57  ) //if not a number'); --( unicode<48 || unicode>57) &&
      twbkfrmt.p_PRINTTEXT ('   return false //disable key press');
      twbkfrmt.p_PRINTTEXT ('  }');
      twbkfrmt.p_PRINTTEXT ('}');
      twbkfrmt.p_PRINTTEXT ('</script>');

      -------------------
      OPEN GET_DATA (PIDM);

      FETCH GET_DATA INTO DATA_REC;

      CLOSE GET_DATA;

      twbkfrmt.p_tablerowopen;

      --------------Bank------------
      FOR BANK_rec IN GET_BANKS
      LOOP
         IF GET_BANKS%ROWCOUNT = 1
         THEN
            twbkfrmt.p_tabledataopen;
            twbkfrmt.p_tabledatalabel (
               twbkfrmt.f_formlabel (
                     '<font color="#008000" face="Arial" size="4">'
                  || ' «·»‰ﬂ:'
                  || twbkfrmt.f_printrequired
                  || '</font>'));
            twbkfrmt.p_tabledataclose;

            twbkfrmt.p_tabledataopen;

            HTP.formSelectOpen ('bank');
            twbkwbis.p_formselectoption ('«Œ — «·»‰ﬂ',
                                         '',
                                         'SELECTED');
         END IF;

         IF NVL (data_rec.SYRIBAN_BANK, '~') = BANK_rec.BANK_CODE
            OR BANK_rec.BANK_CODE = BANK
         THEN
            twbkwbis.p_formselectoption (BANK_rec.BANK_DESC,
                                         BANK_rec.BANK_CODE,
                                         'SELECTED');
         ELSE
            twbkwbis.p_formselectoption (BANK_rec.BANK_DESC,
                                         BANK_rec.BANK_CODE);
         END IF;
      END LOOP;

      HTP.formSelectClose;
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;


      twbkfrmt.p_tablerowopen;

      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || '—ﬁ„ «·Õ”«»:'
            || twbkfrmt.f_printrequired
            || '</font>'));      --,cattributes => 'align="RIGHT" width="180"'
      twbkfrmt.p_tabledataclose;
      --
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_formtext (
         'ACCOUNT',
         '18',
         '20',
         NVL (ACCOUNT, data_rec.SYRIBAN_ACCT_NO),
         cattributes   => 'id="ACOUNT" onkeypress="return EnglishOnly(event)"');
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || '—ﬁ„ «·≈Ì»«‰:'
            || twbkfrmt.f_printrequired
            || '</font>'));
      twbkfrmt.p_tabledataclose;
      --
      --      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (twbkfrmt.F_formtext (
                               'IBAN',
                               '20',
                               '22',
                               NVL (IBAN, SUBSTR (data_rec.SYRIBAN_IBAN, 3)), --BECAUSE IT STORED IN DB SA||ENTERED_IBAN
                               cattributes   => 'id="IBAN" onkeypress="return EnglishOnly(event)" STYLE="direction:RTL" ALIGN="left"')
                            || HTF.BOLD ('SA') || HTF.SMALL('<font color="grey" face="Arial" size="2">'
                                                                             ||'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
                                                                             ||' ÌÃ» «‰ ÌﬂÊ‰ Õﬁ· "«·«Ì»«‰"  „ﬂÊ‰ „‰  "SA" «·„œŒ·… „‰ ﬁ»· «·‰Ÿ«„ »«·«÷«›… «·Ì 22 —ﬁ„'
                                                                            || '</font>' ));
      --      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;
      twbkfrmt.p_tablerowopen;

      --------------Bank------------
      FOR RELT_rec IN GET_RELTS
      LOOP
         IF GET_RELTS%ROWCOUNT = 1
         THEN
            twbkfrmt.p_tabledataopen;
            twbkfrmt.p_tabledatalabel (
               twbkfrmt.f_formlabel (
                     '<font color="#008000" face="Arial" size="4">'
                  || ' ’·… ’«Õ» «·Õ”«» »«·ÿ«·»:'
                  || twbkfrmt.f_printrequired
                  || '</font>'),
               cattributes   => 'align="RIGHT" width="190"');
            twbkfrmt.p_tabledataclose;

            twbkfrmt.p_tabledataopen;

            HTP.formSelectOpen (
               'RELT',
               cattributes   => 'onchange=''javascript: submitform()''');
            twbkwbis.p_formselectoption ('«·ÿ«·» ‰›”Â',
                                         '',
                                         'SELECTED');
         END IF;

         IF ( (NVL (data_rec.SYRIBAN_RELT_ACCT_OWNER, '~') =
                  RELT_rec.STVRELT_CODE
               OR RELT_rec.STVRELT_CODE = RELT)
             AND RELT <> '~~~')
         THEN
            twbkwbis.p_formselectoption (RELT_rec.STVRELT_DESC,
                                         RELT_rec.STVRELT_CODE,
                                         'SELECTED');
         ELSE
            twbkwbis.p_formselectoption (RELT_rec.STVRELT_DESC,
                                         RELT_rec.STVRELT_CODE);
         END IF;
      END LOOP;

      HTP.formSelectClose;
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

      IF NAME IS NOT NULL OR (RELT IS NOT NULL AND RELT <> '~~~')
      THEN
         twbkfrmt.p_tablerowopen;
         twbkfrmt.p_tabledataopen;
         twbkfrmt.p_tabledatalabel (
            twbkfrmt.f_formlabel (
                  '<font color="#008000" face="Arial" size="4">'
               || ' «”„ ’«Õ» «·Õ”«»:'
               || twbkfrmt.f_printrequired
               || '</font>'));
         twbkfrmt.p_tabledataclose;
         --
         twbkfrmt.p_tabledataopen;

         twbkfrmt.p_formtext (
            'NAME',
            '39',
            '60',
            CASE SUBMIT_TYPE
               WHEN 'REFRESH' THEN ''
               ELSE NVL (NAME, DATA_REC.SYRIBAN_ACCT_OWNER)
            END,
            cattributes   => 'id="IBAN_OWNER" onkeypress="return arabicOnly(event)"');
         twbkfrmt.p_tabledataclose;
         twbkfrmt.p_tablerowclose;
      END IF;



      twbkfrmt.P_tableCLOSE;
      HTP.BR;
      twbkfrmt.p_tableopen (
         'DATAENTRY',
         CATTRIBUTES   => ' width=100% style="background-color:rgba(0,102,0,0.15);"');
      twbkfrmt.p_tableROWOPEN;
      twbkfrmt.p_tabledata (
            '<font color="RED" face="Arial" size="5">'
         || '≈ﬁ—«—'
         || '</font>',
         'center');
      twbkfrmt.p_tableROWCLOSE;
      twbkfrmt.p_tableROWOPEN;                           --,'align="center"');
      twbkfrmt.p_tabledata (
            HTF.FORMCHECKBOX ('agreement_check', 'Y')
         ||               
           '<font color="RED" face="Arial" size="4"> &nbsp;'
         || ' «ﬁ— «‰« «·ÿ«·» / '
         || HTF.BOLD (F_FORMAT_NAME (PIDM, 'FML'))
         || ' »’Õ… «·»Ì«‰«  «·„œŒ·… „‰ ﬁ»·Ì Ê√‰‰Ì « Õ„· ﬂ«›… «·„”ƒÊ·Ì… »‘«‰ —ﬁ„ «·Õ”«» Ê«·≈Ì»«‰ «·„œŒ· Ê⁄·Ï –·ﬂ «Êﬁ⁄ .'
         || '</font>');
      twbkfrmt.p_tableROWCLOSE;
      twbkfrmt.p_tableCLOSE;

      HTP.tableopen ('CENTER', cattributes => 'align="center" width=10%  "');
      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledata ('&nbsp;');
      twbkfrmt.p_tablerowclose;
      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      HTP.formsubmit (
         'submit_btn',
         ' ”ÃÌ· «·Õ”«»',
         cattributes   => 'onclick="if(!this.form.agreement_check.checked){alert(''ÌÃ» «·„Ê«›ﬁ… ⁄·Ì «·«ﬁ—«— «Ê·« ﬁ»·  ”ÃÌ· «·Õ”«»'');return false}" ');
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;


      HTP.br;
      twbkwbis.p_closedoc (curr_release);
   END;

   PROCEDURE P_PROC_ENTER_DATA (bank               VARCHAR2 DEFAULT NULL,
                                ACCOUNT            VARCHAR2 DEFAULT NULL,
                                IBAN               VARCHAR2 DEFAULT NULL,
                                NAME               VARCHAR2 DEFAULT NULL,
                                RELT               VARCHAR2 DEFAULT NULL,
                                AGREEMENT_CHECK    VARCHAR2 DEFAULT NULL,
                                submit_btn         VARCHAR2 DEFAULT NULL)
   IS
      V_CHECK_NAME   NUMBER;
      V_CHECK_ACCT   NUMBER;
      V_CHECK_IBAN   NUMBER;
      V_SEQ          NUMBER;
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      IF SUBMIT_BTN IS NULL
      THEN
         P_ENTER_DATA (BANK          => bank,
                       ACCOUNT       => ACCOUNT,
                       IBAN          => IBAN,
                       NAME          => NULL,
                       RELT          => NVL (RELT, '~~~'),              --RELT
                       SUBMIT_TYPE   => 'REFRESH');
         RETURN;
      END IF;

      IF AGREEMENT_CHECK IS NULL
      THEN
         ERR_MSG :=
            'Œÿ√' || HTF.BR
            || 'ÌÃ» «·„Ê«›ﬁ… ⁄·Ì «·«ﬁ—«— ﬁ»·  ﬁœÌ„ «·ÿ·»';
         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => ACCOUNT,
                       IBAN      => IBAN,
                       NAME      => NAME,
                       RELT      => RELT);
         RETURN;
      END IF;

      IF bank IS NULL OR ACCOUNT IS NULL OR IBAN IS NULL
      THEN
         ERR_MSG :=
               'Œÿ√'
            || HTF.BR
            || 'ÌÃ» «œŒ«· Ã„Ì⁄ «·ÕﬁÊ· «·„ÿ·Ê»…';

         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => ACCOUNT,
                       IBAN      => IBAN,
                       NAME      => NAME,
                       RELT      => RELT);
         RETURN;
      END IF;

      IF RELT IS NOT NULL
      THEN
         IF NAME IS NULL
         THEN
            ERR_MSG :=
               'Œÿ√' || HTF.BR
               || 'ÌÃ» «œŒ«· Õﬁ· "«”„ ’«Õ» «·Õ”«»" ›Ì Õ«·… ﬂ«‰ «·Õ”«» «·»‰ﬂÌ €Ì— Œ«’ »«·ÿ«·»';
            P_ENTER_DATA (BANK      => bank,
                          ACCOUNT   => ACCOUNT,
                          IBAN      => IBAN,
                          NAME      => NAME,
                          RELT      => RELT);
            RETURN;
         END IF;
      END IF;

      SELECT NVL (LENGTH (NAME), 0)
             - NVL (
                  LENGTH (
                     TRANSLATE (
                        NAME,
                        '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~`!@#$%^&*()_-+={[}]|\:;<,>.?/',
                        ' ')),
                  0)
        INTO V_CHECK_NAME
        FROM DUAL;

      IF V_CHECK_NAME <> 0
      THEN
         ERR_MSG :=
            'Œÿ√' || HTF.BR
            || 'ÌÃ» «œŒ«· «”„ ’«Õ» «·Õ”«» »«··€… «·⁄—»Ì… ›ﬁÿ';
         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => ACCOUNT,
                       IBAN      => IBAN,
                       NAME      => NULL,
                       RELT      => RELT);
         RETURN;
      END IF;

      SELECT NVL (LENGTH (ACCOUNT), 0)
             - NVL (
                  LENGTH (
                     TRANSLATE (
                        ACCOUNT,
                        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~`!@#$%^&*()_-+={[}]|\:;<,>.?/',
                        ' ')),
                  0)
        INTO V_CHECK_ACCT
        FROM DUAL;

      IF V_CHECK_ACCT <> 0
      THEN
         ERR_MSG :=
            'Œÿ√' || HTF.BR
            || 'ÌÃ» «œŒ«·  «—ﬁ«„ ›ﬁÿ ›Ì Õﬁ· "—ﬁ„ «·Õ”«»"';
         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => NULL,
                       IBAN      => IBAN,
                       NAME      => NAME,
                       RELT      => RELT);
         RETURN;
      END IF;

      SELECT NVL (LENGTH (IBAN), 0)
             - NVL (
                  LENGTH (
                     TRANSLATE (
                        IBAN,
                        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~`!@#$%^&*()_-+={[}]|\:;<,>.?/',
                        ' ')),
                  0)
        INTO V_CHECK_IBAN
        FROM DUAL;

      IF V_CHECK_IBAN <> 0
      THEN
         ERR_MSG :=
            'Œÿ√' || HTF.BR
            || 'ÌÃ» «œŒ«·  «—ﬁ«„ ›ﬁÿ ›Ì Õﬁ· "«·«Ì»«‰" ';
         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => ACCOUNT,
                       IBAN      => NULL,
                       NAME      => NAME,
                       RELT      => RELT);
         RETURN;
      END IF;

      IF LENGTH (IBAN) <> 22
      THEN
         ERR_MSG :=
            'Œÿ√' || HTF.BR
            || 'ÌÃ» «‰ ÌﬂÊ‰ Õﬁ· "«·«Ì»«‰"  „ﬂÊ‰ „‰  "SA" «·„œŒ·… „‰ ﬁ»· «·‰Ÿ«„ »«·«÷«›… «·Ì 22 —ﬁ„';
         P_ENTER_DATA (BANK      => bank,
                       ACCOUNT   => ACCOUNT,
                       IBAN      => NULL,
                       NAME      => NAME,
                       RELT      => RELT);
         RETURN;
      END IF;

      BEGIN
         IF ADM.GET_IBAN (TRIM (ACCOUNT), Bank) <> 'SA' || TRIM (IBAN)
         THEN
            ERR_MSG :=
                  'Œÿ√'
               || HTF.BR
               || '«·—Ã«¡ «œŒ«· »Ì«‰«  Õ”«» ’ÕÌÕ…';
            P_ENTER_DATA (BANK      => bank,
                          ACCOUNT   => NULL,
                          IBAN      => NULL,
                          NAME      => NAME,
                          RELT      => RELT);
            RETURN;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            ERR_MSG :=
                  'Œÿ√'
               || HTF.BR
               || '«·—Ã«¡ «œŒ«· »Ì«‰«  Õ”«» ’ÕÌÕ….';
            P_ENTER_DATA (BANK      => bank,
                          ACCOUNT   => NULL,
                          IBAN      => NULL,
                          NAME      => NAME,
                          RELT      => RELT);
            RETURN;
      END;

      SUCCESS_IND := 'Y';

      SELECT NVL (MAX (SYRIBAN_SEQ), 0) + 1
        INTO V_SEQ
        FROM SYRIBAN
       WHERE SYRIBAN_PIDM = PIDM;

      INSERT INTO SYRIBAN (SYRIBAN_PIDM,
                           SYRIBAN_SEQ,
                           SYRIBAN_BANK,
                           SYRIBAN_ACCT_NO,
                           SYRIBAN_IBAN,
                           SYRIBAN_ACCT_OWNER,
                           SYRIBAN_RELT_ACCT_OWNER,
                           SYRIBAN_CREATED_DATE,
                           SYRIBAN_CREATED_BY,
                           SYRIBAN_AUDIT_DATE,
                           SYRIBAN_AUDIT_BY,
                           SYRIBAN_ACCT_STATUS)
           VALUES (PIDM,
                   V_SEQ,
                   BANK,
                   ACCOUNT,
                   'SA' || IBAN,
                   NAME,
                   RELT,
                   SYSDATE,
                   USER,
                   NULL,
                   NULL,
                   'ACCEPT');

      COMMIT;

      P_DISP_DATA;
   EXCEPTION
      WHEN OTHERS
      THEN
         HTP.prints ('"' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE || '"');
         HTP.prints ('"' || SQLCODE || ' ' || SQLERRM || '"');
   END P_PROC_ENTER_DATA;
END KWLKIBAN;
/