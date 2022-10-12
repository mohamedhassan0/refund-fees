create TABLE KAUCUST.SYRVLDP(SYRVLDP_PIDM NUMBER,
                                                SYRVLDP_SQENO NUMBER,
                                                SYRVLDP_PIN NUMBER,
                                                SYRVLDP_ACTIVITY_DATE DATE,
                                                 SYRVLDP_USER VARCHAR2(30) ,
                                                 SYRVLDP_DATA_ORIGIN VARCHAR2(30),
                                                 CONSTRAINT SYRVLDP_PK PRIMARY KEY(SYRVLDP_PIDM,SYRVLDP_SQENO) );

GRANT INSERT,SELECT ON KAUCUST.SYRVLDP TO public;

CREATE PUBLIC SYNONYM SYRVLDP FOR KAUCUST.SYRVLDP ;                                      