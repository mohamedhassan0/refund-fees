CREATE OR REPLACE PACKAGE BODY KAUCUST.KWLKRFND
AS
   curr_release    VARCHAR2 (30) := '8.2';
   /* Global type and variable declarations for package */
   pidm            spriden.spriden_pidm%TYPE;

   cellHdbgcolor   VARCHAR2 (15) := 'LightSteelBlue';          -- 'SteelBlue';
   rowbgcolor      VARCHAR2 (15) := 'E7F5FE';
   ERR_MSG         VARCHAR2 (4000);
   SUCCESS_IND     VARCHAR2 (4000);

   CURSOR GET_MAX_CURENT_TERM
   IS
      SELECT MIN (STVTERM_CODE)
        FROM STVTERM
       WHERE SYSDATE BETWEEN STVTERM_HOUSING_START_DATE
                         AND STVTERM_HOUSING_END_DATE;

   FUNCTION F_ALLOW_REQUEST (P_PIDM            NUMBER,
                             P_REASON      OUT VARCHAR2,
                             DISPLAY_REQ   OUT VARCHAR2)
      RETURN BOOLEAN
   AS
      CURSOR CHECK_ACCEPTED (P_TERM VARCHAR2)
      IS
         SELECT DELIVERY_SUM--SDAD_AMOUNT
           FROM SADAD.FEES_REFUND
          WHERE PIDM = P_PIDM AND TERM = P_TERM;

      CURSOR CHECK_DETECT (P_TERM VARCHAR2)
      IS
         SELECT STAGE_STATUS                                               --1
           FROM ADM.RFUND_DETECT
          WHERE STUDENT_NO = F_GETSPRIDENID (P_PIDM) AND TERM_CODE = P_TERM;

      --   AND STAGE_STATUS = 'X';

      -----------NOT IN THE SAME TERM--------
      CURSOR CHECK_NOT_APRV_NOT_RJCT
      IS
         SELECT 1
           FROM SADAD.FEES_REFUND A, ADM.RFUND_DETECT B
          WHERE     A.PIDM = P_PIDM
                AND B.STUDENT_NO = F_GETSPRIDENID (P_PIDM)
                AND A.TERM = B.TERM_CODE
                AND A.DELIVERY_SUM IS NULL
                AND B.STAGE_STATUS <> 'X';

      CURSOR CHECK_RJCT
      IS
         SELECT 1
           FROM ADM.RFUND_DETECT
          WHERE STUDENT_NO = F_GETSPRIDENID (P_PIDM) AND STAGE_STATUS = 'X';

      ----------------------------------------------------
      V_TERM       VARCHAR2 (10);
      V_ACCEPTED   NUMBER;
      v_DETECT     VARCHAR2 (30);
      V_DUMMY      NUMBER;
   BEGIN
      OPEN GET_MAX_CURENT_TERM;

      FETCH GET_MAX_CURENT_TERM INTO V_TERM;

      CLOSE GET_MAX_CURENT_TERM;

      OPEN CHECK_ACCEPTED (V_TERM);

      FETCH CHECK_ACCEPTED INTO V_ACCEPTED;

      IF CHECK_ACCEPTED%FOUND
      THEN
         CLOSE CHECK_ACCEPTED;

         IF V_ACCEPTED IS NOT NULL
         THEN
            --MEAN YOUR REQUEST HAS BEEN ACCEPTED
            P_REASON :=
               '€Ì— „”„ÊÕ ·ﬂ » ﬁœÌ„ «ﬂÀ— „‰ ÿ·» ›Ì ‰›” «·›’· «·œ—«”Ì';
            RETURN FALSE;
         ELSE
            OPEN CHECK_DETECT (V_TERM);

            FETCH CHECK_DETECT INTO V_DETECT;

            IF CHECK_DETECT%FOUND
            THEN
               --MEAN YOUR REQUEST HAS BEEN ACCEPTED
               CLOSE CHECK_DETECT;

               IF NVL (V_DETECT, '~') = 'X'
               THEN
                  P_REASON :=
                     '€Ì— „”„ÊÕ ·ﬂ » ﬁœÌ„ «ﬂÀ— „‰ ÿ·» ›Ì ‰›” «·›’· «·œ—«”Ì';
                  RETURN FALSE;
               ELSE
                  P_REASON :=
                     'Ã«—Ì «·⁄„· ⁄·Ì  œﬁÌﬁ «·ÿ·» «·„ﬁœ„';
                  DISPLAY_REQ := 'Y';
                  RETURN FALSE;
               END IF;
            ELSE
               CLOSE CHECK_DETECT;

               P_REASON :=
                  'Ì„ﬂ‰ﬂ «· ⁄œÌ· ⁄·Ì «·ÿ·» ÕÌÀ ·„   „ „—«Ã⁄ Â »⁄œ';
               RETURN TRUE;
            END IF;

            CLOSE CHECK_DETECT;
         END IF;
      ELSE                                              --NOT IN THE SAME TERM
         CLOSE CHECK_ACCEPTED;

         OPEN CHECK_NOT_APRV_NOT_RJCT;

         FETCH CHECK_NOT_APRV_NOT_RJCT INTO V_DUMMY;

         IF CHECK_NOT_APRV_NOT_RJCT%FOUND
         THEN
            CLOSE CHECK_NOT_APRV_NOT_RJCT;

            --             DISPALY_REQ:='Y';
            P_REASON :=
               '€Ì— „”„ÊÕ ·ﬂ » ﬁœÌ„ ÿ·» ÕÌÀ ·œÌﬂ ÿ·» €Ì— „ﬂ „· ›Ì ›’· œ—«”Ì ”«»ﬁ';
            RETURN FALSE;
         ELSE
            CLOSE CHECK_NOT_APRV_NOT_RJCT;

            RETURN TRUE;
         END IF;
      --         RETURN TRUE;
      END IF;
   END;

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


   PROCEDURE P_INSERT_FEES (P_PIDM       NUMBER,
                            IBAN       VARCHAR2,
                            account    VARCHAR2,
                            bank       VARCHAR2,
                            name       VARCHAR2,
                            reason     VARCHAR2)
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
                AND SGRSATT_PIDM = P_PIDM
                AND SGRSATT_ATTS_CODE IN
                       ('EXT', 'DLRN', 'AFST', 'REGL', 'PARA');



      CURSOR GET_STU_REC
      IS
         SELECT *
           FROM SGBSTDN
          WHERE SGBSTDN_PIDM = P_PIDM
                AND SGBSTDN_TERM_CODE_EFF =
                       (SELECT MAX (SGBSTDN_TERM_CODE_EFF)
                          FROM SGBSTDN
                         WHERE SGBSTDN_PIDM = P_PIDM);

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

      v_ID := f_getspridenid (P_pidm);

      UPDATE SADAD.FEES_REFUND
         SET IBAN_NO = IBAN,
             ACCOUNT_NO = ACCOUNT,
             BANK_NAME = BANK,
             IBAN_OWNER = name,
             REFUND_REASON = REASON,
             MOD_BY = USER,
             MOD_DATE = SYSDATE
       WHERE PIDM = P_PIDM AND TERM = V_MAX_CURENT_TERM;

      IF SQL%NOTFOUND
      THEN
         INSERT INTO SADAD.FEES_REFUND (APPLICATION_NO,
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
              VALUES (NULL,
                      V_SSN,
                      V_ADM_ID,
                      v_id,
                      P_pidm,
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
                      V_STU_REC.sgbstdn_levl_code);
      END IF;

      COMMIT;
   END;

   PROCEDURE P_MAIN
   IS
      CURSOR CHECK_CSH_EXISTS
      IS
         SELECT 1
           FROM tbraccd t
          WHERE t.tbraccd_pidm = pidm
                AND t.tbraccd_detail_code IN
                       (SELECT de.tbbdetc_detail_code
                          FROM TBBDETC de
                         WHERE de.TBBDETC_DCAT_CODE IN ('CSH'));

      V_DUMMY   NUMBER;
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;

      bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');

      IF GET_BAL (pidm) < 0
      THEN
         OPEN CHECK_CSH_EXISTS;
         FETCH CHECK_CSH_EXISTS INTO V_DUMMY;
       
         IF CHECK_CSH_EXISTS%FOUND THEN
          P_VALIDATION_PAGE;
         ELSE
                   twbkfrmt.p_printmessage (
            twbkfrmt.f_tabledata (
               '<font color="RED" face="Arial" size="4"> ·Ì” ·œÌﬂ „»·€ ··≈” —Ã«⁄</font>'),
            2);
         END IF;
         CLOSE CHECK_CSH_EXISTS;
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

      V_REASON                VARCHAR2 (300);

      CURSOR GET_NOT_REVIEWED_DATA (
         P_PIDM NUMBER)
      IS
         SELECT *
           FROM SADAD.FEES_REFUND A
          WHERE PIDM = P_PIDM
                AND NOT EXISTS
                           (SELECT 1
                              FROM ADM.RFUND_DETECT B
                             WHERE STUDENT_NO = F_GETSPRIDENID (P_PIDM)
                                   AND A.TERM = B.TERM_CODE);

      CURSOR GET_IN_PROGRESS_DATA (
         P_PIDM NUMBER)
      IS
         SELECT *
           FROM SADAD.FEES_REFUND A
          WHERE PIDM = P_PIDM
                AND EXISTS
                       (SELECT 1
                          FROM ADM.RFUND_DETECT B
                         WHERE STUDENT_NO  = F_GETSPRIDENID (P_PIDM)
                               AND A.TERM = B.TERM_CODE);


      REC_NOT_REVIEWED_DATA   GET_NOT_REVIEWED_DATA%ROWTYPE;
      V_ALLOW_REQUEST         BOOLEAN;
      V_DISPLAY_REQ           VARCHAR2 (1);
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

      V_ALLOW_REQUEST := F_ALLOW_REQUEST (pidm, V_REASON, V_DISPLAY_REQ);

      IF V_REASON IS NOT NULL
      THEN
         --         bwckfrmt.p_open_doc ('kwlkrfnd.P_MAIN');
         TWBKFRMT.P_PRINTMESSAGE (V_REASON, 3);
      END IF;

      --   TWBKFRMT.P_PRINTMESSAGE (case V_ALLOW_REQUEST when true then 'true' when false then 'false'||V_REASON end, 3);


      IF V_ALLOW_REQUEST OR NVL (V_DISPLAY_REQ, '~') = 'Y'
      THEN
--               IF V_ALLOW_REQUEST
--               THEN
--                twbkfrmt.p_tableopen ('DATAENTRY',CATTRIBUTES=>'style="background-color:rgba(0,102,0,0.29);"'); 
--                 twbkfrmt.p_tableROWOPEN;
--                  twbkfrmt.p_tabledata ( '<font color="RED" face="Arial" size="10">'
--                                                  ||'≈ﬁ—«—'
--                                                   ||'</font>','center');
--                 twbkfrmt.p_tableROWCLOSE; 
--                 twbkfrmt.p_tableROWOPEN;               --,'align="center"');
--                twbkfrmt.p_tabledata (
----                 TWBKFRMT.P_PRINTTEXT(---"#008000"
--                  '<font color="RED" face="Arial" size="5"> &nbsp;'
--                                                      ||  ' «ﬁ— «‰« «·ÿ«·» / ' ||HTF.BOLD(F_FORMAT_NAME(PIDM,'FML' ))
--                                                      || ' »’Õ… «·»Ì«‰«  «·„œŒ·… „‰ ﬁ»·Ì Ê√‰‰Ì « Õ„· ﬂ«›… «·„”ƒÊ·Ì… »‘«‰ —ﬁ„ «·Õ”«» Ê«·≈Ì»«‰ «·„œŒ· Ê⁄·Ï –·ﬂ «Êﬁ⁄ .'
--                                                      ||'</font>'
--                                                      );
--                twbkfrmt.p_tableROWCLOSE;       
--                
--                  twbkfrmt.p_tableROWOPEN;               --,'align="center"');
--                twbkfrmt.p_tabledata (
----                 TWBKFRMT.P_PRINTTEXT(---"#008000"
--                  '<font color="#008000" face="Arial" size="5">'
--                                                      ||HTF.UNDERLINE(HTF.BOLD( '„·ÕÊŸ…'))
--                                                      ||'<BR>'
--                                                      || ' ·« Ì„ﬂ‰  ⁄œÌ· —ﬁ„ «·Õ”«» «Ê «·«Ì»«‰ »⁄œ  ⁄»∆… «·‰„Ê–Ã Ê «ﬂÌœÂ .'
--                                                      ||'</font>'
--                                                      );
--                twbkfrmt.p_tableROWCLOSE;                                                  
--                twbkfrmt.p_tableCLOSE;                                                      
--               END IF;
         HTP.tableopen ('CENTER',
                        cattributes   => 'align="center" width=70%  "');
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

         IF V_REASON IS NOT NULL
         THEN
            IF NVL (V_DISPLAY_REQ, '~') = 'Y'
            THEN
               OPEN GET_IN_PROGRESS_DATA (PIDM);

               FETCH GET_IN_PROGRESS_DATA INTO REC_NOT_REVIEWED_DATA;

               CLOSE GET_IN_PROGRESS_DATA;
            ELSE
               --         TWBKFRMT.P_PRINTMESSAGE (PIDM, 3);
               OPEN GET_NOT_REVIEWED_DATA (PIDM);

               FETCH GET_NOT_REVIEWED_DATA INTO REC_NOT_REVIEWED_DATA;

               CLOSE GET_NOT_REVIEWED_DATA;
            END IF;
         END IF;
      END IF;

      IF V_ALLOW_REQUEST
      THEN
         HTP.formOpen (twbkwbis.f_cgibin || 'kwlkrfnd.P_PROC_DISPLAY_RFND');
         HTP.tableopen ('CENTER',
                        cattributes   => 'align="center" width=80%  "');


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

               HTP.formSelectOpen (
                  'bank',
                  cattributes   => 'onchange=''javascript: submitform()''');
               twbkwbis.p_formselectoption ('«Œ — «·»‰ﬂ',
                                            '',
                                            'SELECTED');
            END IF;

            IF NVL (REC_NOT_REVIEWED_DATA.BANK_NAME, '~') =
                  BANK_rec.BANK_CODE
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
               || '</font>'));
         twbkfrmt.p_tabledataclose;
         --
         twbkfrmt.p_tabledataopen;
         twbkfrmt.p_formtext ('ACCOUNT',
                              '40',
                              '40',
                              REC_NOT_REVIEWED_DATA.ACCOUNT_NO);
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
         twbkfrmt.p_formtext ('IBAN',
                              '40',
                              '40',
                              REC_NOT_REVIEWED_DATA.IBAN_NO);
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
         twbkfrmt.p_formtext ('NAME',
                              '40',
                              '40',
                              REC_NOT_REVIEWED_DATA.IBAN_OWNER);
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
         twbkfrmt.p_printtext (   HTF.formtextareaopen2 (
                                     'reason',
                                     5,
                                     70,
                                     cattributes   => 'ID="reason_id"')
                               || REC_NOT_REVIEWED_DATA.REFUND_REASON
                               || HTF.formTextareaClose);
         twbkfrmt.p_tabledataclose;
         twbkfrmt.p_tablerowclose;
         ---

         HTP.tableCLOSE;
         
--            IF V_ALLOW_REQUEST
--               THEN
                twbkfrmt.p_tableopen ('DATAENTRY',CATTRIBUTES=>' width=100% style="background-color:rgba(0,102,0,0.15);"'); 
                 twbkfrmt.p_tableROWOPEN;
                  twbkfrmt.p_tabledata ( '<font color="RED" face="Arial" size="5">'
                                                  ||'≈ﬁ—«—'
                                                   ||'</font>','center');
                 twbkfrmt.p_tableROWCLOSE; 
                 twbkfrmt.p_tableROWOPEN;               --,'align="center"');
                twbkfrmt.p_tabledata (HTf.FORMCHECKBOX('agreement_check','Y')||
--                 TWBKFRMT.P_PRINTTEXT(---"#008000"
                  '<font color="RED" face="Arial" size="4"> &nbsp;'
                                                      ||  ' «ﬁ— «‰« «·ÿ«·» / ' ||HTF.BOLD(F_FORMAT_NAME(PIDM,'FML' ))
                                                      || ' »’Õ… «·»Ì«‰«  «·„œŒ·… „‰ ﬁ»·Ì Ê√‰‰Ì « Õ„· ﬂ«›… «·„”ƒÊ·Ì… »‘«‰ —ﬁ„ «·Õ”«» Ê«·≈Ì»«‰ «·„œŒ· Ê⁄·Ï –·ﬂ «Êﬁ⁄ .'
                                                      ||'</font>'
                                                      );
                twbkfrmt.p_tableROWCLOSE;       
                
--                  twbkfrmt.p_tableROWOPEN;               --,'align="center"');
--                twbkfrmt.p_tabledata (
----                 TWBKFRMT.P_PRINTTEXT(---"#008000"
--                  '<font color="#008000" face="Arial" size="4">'
--                                                      ||HTF.UNDERLINE(HTF.BOLD( '„·ÕÊŸ…'))
--                                                      ||'<BR>'
--                                                      || ' ·« Ì„ﬂ‰  ⁄œÌ· —ﬁ„ «·Õ”«» «Ê «·«Ì»«‰ »⁄œ  ⁄»∆… «·‰„Ê–Ã Ê «ﬂÌœÂ .'
--                                                      ||'</font>'
--                                                      );
--                twbkfrmt.p_tableROWCLOSE;                                                  
                twbkfrmt.p_tableCLOSE;                                                      
--               END IF;
         HTP.tableopen ('CENTER',
                        cattributes   => 'align="center" width=10%  "');
         twbkfrmt.p_tablerowopen;
         twbkfrmt.p_tabledata ('&nbsp;');
         twbkfrmt.p_tablerowclose;
         twbkfrmt.p_tablerowopen;
         twbkfrmt.p_tabledataopen;
         HTP.formsubmit ('', ' ”ÃÌ· «·ÿ·»',cattributes=>'onclick="if(!this.form.agreement_check.checked){alert(''ÌÃ» «·„Ê«›ﬁ… ⁄·Ì «·«ﬁ—«— «Ê·« ﬁ»·  ”ÃÌ· «·ÿ·»'');return false}" ');
         twbkfrmt.p_tabledataclose;
         twbkfrmt.p_tablerowclose;
      ELSIF NOT V_ALLOW_REQUEST AND V_DISPLAY_REQ = 'Y'
      THEN
         HTP.tableopen ('CENTER',
                        cattributes   => 'align="center" width=80%  "');

         --------------Bank------------
         FOR BANK_rec IN GET_BANKS
         LOOP
            IF GET_BANKS%ROWCOUNT = 1
            THEN
               twbkfrmt.p_tablerowopen;
               twbkfrmt.p_tabledataopen;
               twbkfrmt.p_tabledatalabel (
                  twbkfrmt.f_formlabel (
                        '<font color="#008000" face="Arial" size="4">'
                     || ' «·»‰ﬂ:'
                     || twbkfrmt.f_printrequired
                     || '</font>'));
               twbkfrmt.p_tabledataclose;
            END IF;


            IF NVL (REC_NOT_REVIEWED_DATA.BANK_NAME, '~') =
                  BANK_rec.BANK_CODE
            THEN
               twbkfrmt.p_tabledataopen;
               Twbkfrmt.p_tabledata (BANK_rec.BANK_DESC);
               twbkfrmt.p_tabledataclose;
               twbkfrmt.p_tablerowclose;
            END IF;
         END LOOP;



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
         twbkfrmt.p_tabledata (REC_NOT_REVIEWED_DATA.ACCOUNT_NO);
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
         twbkfrmt.p_tabledata (REC_NOT_REVIEWED_DATA.IBAN_NO);
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
         twbkfrmt.p_tabledata (REC_NOT_REVIEWED_DATA.IBAN_OWNER);
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
         twbkfrmt.p_tabledata (REC_NOT_REVIEWED_DATA.REFUND_REASON);
         twbkfrmt.p_tabledataclose;
         twbkfrmt.p_tablerowclose;
         ---

         HTP.tableCLOSE;
         HTP.tableopen ('CENTER',
                        cattributes   => 'align="center" width=10%  "');
         twbkfrmt.p_tablerowopen;
         twbkfrmt.p_tabledata ('&nbsp;');
         twbkfrmt.p_tablerowclose;
      --         twbkfrmt.p_tablerowopen;
      --         twbkfrmt.p_tabledataopen;
      --         HTP.formsubmit ('', ' ”ÃÌ· «·ÿ·»');
      --         twbkfrmt.p_tabledataclose;
      --         twbkfrmt.p_tablerowclose;

      END IF;

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
                                  reason     VARCHAR2 DEFAULT NULL,
                                  AGREEMENT_CHECK VARCHAR2 DEFAULT NULL)
   IS
   BEGIN
      /* Check for valid user */
      IF NOT twbkwbis.f_validuser (pidm)
      THEN
         RETURN;
      END IF;
      IF AGREEMENT_CHECK IS NULL
      THEN
               ERR_MSG :=
               'Œÿ√'
            || HTF.BR
            || 'ÌÃ» «·„Ê«›ﬁ… ⁄·Ì «·«ﬁ—«— ﬁ»·  ﬁœÌ„ «·ÿ·»';
         P_DISPLAY_RFND;
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