
        SUBROUTINE GETCTGRY

C***********************************************************************
C  subroutine body starts at line
C
C  DESCRIPTION: 
C     This subroutine retrieves the SMK_SOURCE environment variable to
C     determine what source category is being processed.  It returns
C     the first letter, category, and category description based on that
C     environment variable setting.
C
C  PRECONDITIONS REQUIRED:
C     
C
C  SUBROUTINES AND FUNCTIONS CALLED:  M3EXIT
C
C  REVISION  HISTORY:
C       Created 3/99 by M Houyoux
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 1998, MCNC--North Carolina Supercomputing Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Programs Group
C MCNC--North Carolina Supercomputing Center
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C env_progs@mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C****************************************************************************

C...........   MODULES for public variables
C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES:
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters

C...........   EXTERNAL FUNCTIONS:
        CHARACTER*2     CRLF
        INTEGER         INDEX1

        EXTERNAL        CRLF, INDEX1

C...........   LOCAL PARAMETER:
        INTEGER    , PARAMETER :: NLIST   = 4
        CHARACTER*1, PARAMETER :: LETLIST( NLIST ) = 
     &                                    ( / 'A', 'B', 'M', 'P' / )

        CHARACTER*6, PARAMETER :: CATLIST( NLIST ) = 
     &                                    ( / 'AREA  ', 'BIOGEN',
     &                                        'MOBILE', 'POINT ' / )

        CHARACTER*6, PARAMETER :: CATLDSC( NLIST ) = 
     &                                    ( / 'Area  ', 'Biogen',
     &                                        'Mobile', 'Point ' / )

C...........   LOCAL VARIABLES their descriptions:

        INTEGER         IOS        ! i/o status 
        INTEGER         J          ! index

        CHARACTER*300   MESG       ! Message buffer
  
        CHARACTER*16 :: PROGNAME = 'GETCTGRY'    ! Program name

C***********************************************************************
C   begin body of subroutine GETCTGRY

C.........  Retrieve environment variable that indicates the source of interest
        MESG = 'Control for which source category for controls'
        CALL ENVSTR( 'SMK_SOURCE', MESG, ' ', CRL, IOS )

        J = INDEX1( CRL, NLIST, LETLIST )

        IF( J .LE. 0 .OR. IOS .NE. 0 ) THEN

            MESG = 'Do not recognize SMK_SOURCE environment variable '//
     &             'setting "' // CRL // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ELSE

            CATEGORY = CATLIST( J )
            CATDESC  = CATLDSC( J )

            CATLEN   = LEN_TRIM( CATEGORY )

        ENDIF

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats.............94xxx
 
94010   FORMAT( 10( A, :, I6, :, 2X ) )

        END SUBROUTINE GETCTGRY
