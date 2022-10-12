/* Formatted on 30/08/15 10:47:10 ’ (QP5 v5.163.1008.3004) */
CREATE OR REPLACE PACKAGE BODY KAUCUST.KWLKRFND
AS
   curr_release    VARCHAR2 (30) := '8.2';
   /* Global type and variable declarations for package */
   pidm            spriden.spriden_pidm%TYPE;

   cellHdbgcolor   VARCHAR2 (15) := 'LightSteelBlue';          -- 'SteelBlue';
   rowbgcolor      VARCHAR2 (15) := 'E7F5FE';
   ERR_MSG         VARCHAR2 (4000);
   SUCCESS_IND     VARCHAR2 (4000);

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
      CURSOR GET_STU_MOBILE (
         STU_PIDM NUMBER)
      IS
           SELECT MAX (SPRTELE_INTL_ACCESS)
             FROM SPRTELE
            WHERE     SPRTELE_PIDM = STU_PIDM
                  AND SPRTELE_TELE_CODE = 'MO'
                  AND sprtele_primary_ind = 'Y'
         ORDER BY SPRTELE_ACTIVITY_DATE DESC;

      CURSOR goremal_address_c (p_pidm spriden.spriden_pidm%TYPE)
      IS
           SELECT goremal_email_address
             FROM goremal
            WHERE goremal_pidm = p_pidm AND goremal_status_ind = 'A'
         ORDER BY goremal_preferred_ind DESC;

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
                           SYRVLDP_USER)
           VALUES (PIDM,
                   V_SEQNO,
                   V_PIN,
                   SYSDATE,
                   USER);

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
            kaucust.kau_send_mail (p_sender      => 'kau@kau.edu.sa',
                                   p_recipient   => v_email_addr,
                                   p_subject     => 'KAU.EDU.SA',
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
                      'KWLKRFND.P_SEND_VALIDATION_PIN',
                      USER,
                      SYSDATE,
                      NULL,
                      NULL,
                      'REFUNDMSG',
                      F_GETSPRIDENID (PIDM),
                      NULL,
                      NULL,
                      NULL);
      END IF;
   END P_SEND_VALIDATION_PIN;


 PROCEDURE P_INSERT_FEES (PIDM NUMBER, IBAN VARCHAR2,account varchar2,bank varchar2,name varchar2, reason varchar2)
   IS
      CURSOR GET_SSN
      IS
         SELECT SPBPERS_SSN
           FROM SPBPERS
          WHERE SPBPERS_PIDM = PIDM;

      V_SSN               VARCHAR2 (20);

      CURSOR GET_ATTS
      IS
         SELECT SGRSATT_ATTS_CODE
           FROM SGRSATT A
          WHERE SGRSATT_TERM_CODE_EFF =
                   (SELECT MAX (SGRSATT_TERM_CODE_EFF)
                      FROM SGRSATT
                     WHERE SGRSATT_PIDM = A.SGRSATT_PIDM)
                AND SGRSATT_PIDM = PIDM
                AND SGRSATT_ATTS_CODE IN
                       ('EXT', 'DLRN', 'AFST', 'REGL', 'PARA');

      CURSOR GET_MAX_CURENT_TERM
      IS
         SELECT MAX (STVTERM_CODE)
           FROM STVTERM
          WHERE SYSDATE BETWEEN STVTERM_START_DATE AND STVTERM_END_DATE;

      CURSOR GET_STU_REC
      IS
         SELECT *
           FROM SGBSTDN
          WHERE SGBSTDN_PIDM = PIDM
                AND SGBSTDN_TERM_CODE_EFF =
                       (SELECT MAX (SGBSTDN_TERM_CODE_EFF)
                          FROM SGBSTDN
                         WHERE SGBSTDN_PIDM = PIDM);

      V_ATTS              VARCHAR2 (50);
      V_ADM_ID            VARCHAR (30);
      V_MAX_CURENT_TERM   VARCHAR (30);
      V_ID                VARCHAR (30);
      V_STU_REC           GET_STU_REC%ROWTYPE;
   BEGIN
      OPEN GET_SSN;

      FETCH GET_SSN INTO V_SSN;

      CLOSE GET_SSN;

      OPEN GET_ATTS;

      FETCH GET_ATTS INTO V_ATTS;

      CLOSE GET_ATTS;

      OPEN GET_MAX_CURENT_TERM;

      FETCH GET_MAX_CURENT_TERM INTO V_MAX_CURENT_TERM;

      CLOSE GET_MAX_CURENT_TERM;

      OPEN GET_STU_REC;

      FETCH GET_STU_REC INTO V_STU_REC;

      CLOSE GET_STU_REC;

      IF V_ATTS IN ('EXT', 'DLRN', 'ASFT')
      THEN
         V_ADM_ID := 'E';
      ELSIF V_ATTS IN ('REGL', 'PARA')
      THEN
         V_ADM_ID := 'R';
      ELSE
         V_ADM_ID := '';
      END IF;

      v_ID := f_getspridenid (pidm);
     INSERT INTO  SADAD.FEES_REFUND (APPLICATION_NO,
                         SPBPERS_SSN,
                         ADM_ID,
                         BILL_NUMBER,
                         PIDM,
                         TERM,
                         IBAN_NO,
                         ACCOUNT_NO,
                         BANK_NAME,
                         IBAN_OWNER,
                         RECEIPT_WAY,
                         SPTN,
                         SDAD_AMOUNT,
                         SDAD_DATE,
                         ATTRIBUTE,
                         REFUND_REASON,
                         ACCEPTED_DATE,
                         STUDENT_TYPE,
                         CREATED_BY,
                         CREATED_DATE,
                      --   MOD_BY,
                   --      MOD_DATE,
                    --     ADMSION_TYPE,
                    --     SITE,
                     --    STAGE,
                     --    DEDUCT_AMOUNT,
                         STUDENT_NO,
                         STU_LEVEL)
                         VALUES(null,
           V_SSN,
           V_ADM_ID,
           v_id,
           pidm,
           V_MAX_CURENT_TERM,
           IBAN,
           ACCOUNT,
           BANK,
           NAME,
           '1',
           NULL,
           NULL,
           NULL,
           V_ATTS,
           reason,
           SYSDATE,
           'O',
           USER,
           SYSDATE,
           v_id,
           V_STU_REC.sgbstdn_levl_code
           );
         COMMIT;
   END;
   PROCEDURE P_MAIN
   IS
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');

      IF GET_BAL (pidm) < 0
      THEN
         P_VALIDATION_PAGE;
      ELSE
         twbkfrmt.p_printmessage (
            twbkfrmt.f_tabledata (
               '<font color="RED" face="Arial" size="4"> ·Ì” ·œÌﬂ „»·€ ··≈” —Ã«⁄</font>'),
            2);
      END IF;

      HTP.br;
      twbkwbis.p_closedoc (curr_release);
   END P_MAIN;

   PROCEDURE P_VALIDATION_PAGE (p_sent VARCHAR2 DEFAULT NULL)
   IS
      v_mobile   VARCHAR2 (100);
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      --      bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');
      --      P_SEND_VALIDATION_PIN (PIDM);
      --      bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');
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

      twbkfrmt.p_tableopen ('DATAENTRY');                --,'align="center"');
      twbkfrmt.p_tabledata (
         '<font color="#008000" face="Arial" size="5">'
         || twbkfrmt.f_printanchor (
               curl    => twbkfrmt.f_encodeurl (
                            twbkwbis.f_cgibin
                            || 'kwlkrfnd.P_PROC_VALIDATION_PAGE?send_btn=«—”«· —„“ «· Õﬁﬁ'), --'kwlkrfnd.P_VALIDATION_PAGE'),
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
      HTP.formOpen (twbkwbis.f_cgibin || 'kwlkrfnd.P_PROC_VALIDATION_PAGE');
      --      HTP.formsubmit ('send_btn',
      --                      '«÷€ÿ Â‰« ·«—”«· —„“ «· Õﬁﬁ');
      HTP.formclose;

      twbkfrmt.p_tableCLOSE;

      IF p_sent = 'Y'
      THEN
         HTP.formOpen (
            twbkwbis.f_cgibin || 'kwlkrfnd.P_PROC_VALIDATION_PAGE');
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
      END IF;
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

      bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');

      IF SEND_BTN IS NOT NULL
      THEN
         P_SEND_VALIDATION_PIN (PIDM);
         P_VALIDATION_PAGE (p_sent => 'Y');
      --        RETURN;
      END IF;

      IF SUBMIT_BTN IS NOT NULL
      THEN
         IF F_CHECK_VALID_PIN (PIDM, VALID_PIN)
         THEN
            P_DISPLAY_RFND;
         --            RETURN;
         ELSE
            twbkfrmt.p_printmessage (
               'Œÿ√: —„“ «· Õﬁﬁ «·„œŒ· €Ì— ’ÕÌÕ',
               1);
         END IF;
      END IF;

      HTP.BR;
      twbkwbis.p_closedoc (curr_release);
   END P_PROC_VALIDATION_PAGE;

   PROCEDURE P_DISPLAY_RFND
   IS
      CURSOR GET_BANKS
      IS
         SELECT *
           FROM SADAD.BANK_CODE
          WHERE ACTIVE = '1';
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      IF SUCCESS_IND = 'Y'
      THEN
         bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');
         TWBKFRMT.P_PRINTMESSAGE (' „  ‰›Ì– «·ÿ·»', 3);
         twbkwbis.p_closedoc (curr_release);
         RETURN;
      END IF;

      IF ERR_MSG IS NOT NULL
      THEN
         bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');
         TWBKFRMT.P_PRINTMESSAGE (ERR_MSG, 1);
      END IF;

      HTP.tableopen ('CENTER', cattributes => 'align="center" width=70%  "');
      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledata (
         '<font color="#008000" face="Arial" size="5">'
         || ('»Ì«‰«  «·Õ”«» «·»‰ﬂÌ «·„ÿ·Ê»  ÕÊÌ· «·—”Ê„ ·Â'
             || '</font>'),
         'CENTER');

      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;
      HTP.tableclose;
      HTP.formOpen (twbkwbis.f_cgibin || 'kwlkrfnd.P_PROC_DISPLAY_RFND');
      HTP.tableopen ('CENTER', cattributes => 'align="center" width=80%  "');
      --
      twbkfrmt.p_tablerowopen;

      --------------Bank------------
      FOR BANK_rec IN GET_BANKS
      LOOP
         IF GET_BANKS%ROWCOUNT = 1
         THEN
            --            twbkfrmt.p_tabledatalabel (' «·›’· «·œ—«”Ï:');

            twbkfrmt.p_tabledataopen;
            twbkfrmt.p_tabledatalabel (
               twbkfrmt.f_formlabel (
                     '<font color="#008000" face="Arial" size="4">'
                  || ' «·»‰ﬂ:'
                  || twbkfrmt.f_printrequired
                  || '</font>'));
            twbkfrmt.p_tabledataclose;

            twbkfrmt.p_tabledataopen;

            HTP.formSelectOpen (
               'bank',
               --               HTF.bold (
               --                     '<font color="#008000" face="Arial" size="4">'
               --                  || ' «·»‰ﬂ:'
               --                  || '</font>'),
               cattributes   => 'onchange=''javascript: submitform()''');
            twbkwbis.p_formselectoption ('«Œ — «·»‰ﬂ',
                                         '',
                                         'SELECTED');
         ---------------

         END IF;


         twbkwbis.p_formselectoption (BANK_rec.BANK_DESC, BANK_rec.BANK_CODE);
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
            || '</font>'));
      twbkfrmt.p_tabledataclose;
      --
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_formtext ('ACCOUNT', '40', '40');
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
      twbkfrmt.p_formtext ('IBAN', '40', '40');
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;

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
      twbkfrmt.p_formtext ('NAME', '40', '40');
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;


      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      twbkfrmt.p_tabledatalabel (
         twbkfrmt.f_formlabel (
               '<font color="#008000" face="Arial" size="4">'
            || '”»»  ﬁœÌ„ «·ÿ·»:'
            || twbkfrmt.f_printrequired
            || '</font>',
            idname   => 'reason_id'));
      twbkfrmt.p_tabledataclose;



      twbkfrmt.p_tabledataopen;
      ---
      twbkfrmt.p_printtext (HTF.formtextareaopen2 (
                               'reason',
                               5,
                               70,
                               cattributes   => 'ID="reason_id"')
                            || HTF.formTextareaClose);
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;
      ---

      HTP.tableCLOSE;
      HTP.tableopen ('CENTER', cattributes => 'align="center" width=10%  "');
      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledata ('&nbsp;');
      twbkfrmt.p_tablerowclose;
      twbkfrmt.p_tablerowopen;
      twbkfrmt.p_tabledataopen;
      HTP.formsubmit ('', ' ”ÃÌ· «·ÿ·»');
      twbkfrmt.p_tabledataclose;
      twbkfrmt.p_tablerowclose;
      HTP.tableCLOSE;
      HTP.formclose;

      IF ERR_MSG IS NOT NULL
      THEN
         ERR_MSG := '';
         twbkwbis.p_closedoc (curr_release);
      END IF;
   END;

   PROCEDURE P_PROC_DISPLAY_RFND (bank       VARCHAR2 DEFAULT NULL,
                                  ACCOUNT    VARCHAR2 DEFAULT NULL,
                                  IBAN       VARCHAR2 DEFAULT NULL,
                                  NAME       VARCHAR2 DEFAULT NULL,
                                  reason     VARCHAR2 DEFAULT NULL)
   IS
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      IF    bank IS NULL
         OR ACCOUNT IS NULL
         OR IBAN IS NULL
         OR NAME IS NULL
         OR REASON IS NULL
      THEN
         ERR_MSG :=
               'Œÿ√'
            || HTF.BR
            || 'ÌÃ» «œŒ«· Ã„Ì⁄ «·ÕﬁÊ· «·„ÿ·Ê»…';
         P_DISPLAY_RFND;
         RETURN;
      END IF;

      IF ADM.GET_IBAN (ACCOUNT, Bank) <> IBAN
      THEN
         ERR_MSG :=
               'Œÿ√'
            || HTF.BR
            || '«·—Ã«¡ «œŒ«· »Ì«‰«  Õ”«» ’ÕÌÕ…';
         P_DISPLAY_RFND;
         RETURN;
      END IF;

      SUCCESS_IND := 'Y';
      ----
      P_INSERT_FEES (PIDM,
                     IBAN,
                     ACCOUNT,
                     BANK,
                     NAME,
                     reason);
     
      ----
      P_DISPLAY_RFND;
   END P_PROC_DISPLAY_RFND;

  
END KWLKRFND;
/