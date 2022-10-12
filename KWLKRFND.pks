CREATE OR REPLACE PACKAGE KAUCUST.KWLKRFND
AS
PROCEDURE P_MAIN;
PROCEDURE P_DISPLAY_RFND;
PROCEDURE P_VALIDATION_PAGE(p_sent varchar2 default null);
   PROCEDURE P_PROC_VALIDATION_PAGE (send_btn      VARCHAR2 DEFAULT NULL,
                                     SUBMIT_btn    VARCHAR2 DEFAULT NULL,
                                     VALID_PIN     VARCHAR2 DEFAULT NULL);
   PROCEDURE P_PROC_DISPLAY_RFND(bank VARCHAR2 DEFAULT NULL,
                                                          ACCOUNT VARCHAR2 DEFAULT NULL,
                                                         IBAN VARCHAR2 DEFAULT NULL,
                                                         NAME VARCHAR2 DEFAULT NULL,
                                                          reason VARCHAR2 DEFAULT NULL,
                                                          AGREEMENT_CHECK VARCHAR2 DEFAULT NULL);
    PROCEDURE P_FEES_TRACKING    ;                                 
END KWLKRFND;
/