
        SUBROUTINE ALOCTTBL( NIPOL, ICSIZE )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine allocates memory for the portion of the temporal 
C      cross-reference tables that contain the temporal profile numbers, and it
C      initializes these to missing.  The subroutine arguments are the number
C      of inventory pollutants and an array that contains the dimensions for 
C      each of the different groups of the cross-reference.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     Created 3/99 by M. Houyoux
C
C****************************************************************************/
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
C***************************************************************************

C...........   This module is for cross reference tables
        USE MODXREF

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'PARMS3.EXT'    !  i/o api parameters

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT(IN) :: NIPOL        ! number of inventory pols
        INTEGER     , INTENT(IN) :: ICSIZE( * )  ! size of x-ref groups

C...........   Other local variables
        INTEGER       J     ! counter and indices

        INTEGER       IOS              ! i/o status

        CHARACTER*16 :: PROGNAME = 'ALOCTTBL' ! program name

C***********************************************************************
C   begin body of subroutine ALOCTTBL

        ALLOCATE( MPRT01( NIPOL ), STAT=IOS )
        CALL CHECKMEM( IOS, 'MPRT01', PROGNAME )
        ALLOCATE( WPRT01( NIPOL ), STAT=IOS )
        CALL CHECKMEM( IOS, 'WPRT01', PROGNAME )
        ALLOCATE( DPRT01( NIPOL ), STAT=IOS )
        CALL CHECKMEM( IOS, 'DPRT01', PROGNAME )
        MPRT01 = IMISS3 ! arrays
        WPRT01 = IMISS3
        DPRT01 = IMISS3

        J = ICSIZE( 2 )                                       ! SCC=left, FIP=0
        IF( J .GT. 0 ) THEN
            ALLOCATE( MPRT02( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT02', PROGNAME )
            ALLOCATE( WPRT02( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT02', PROGNAME )
            ALLOCATE( DPRT02( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT02', PROGNAME )
            MPRT02 = IMISS3 ! arrays
            WPRT02 = IMISS3
            DPRT02 = IMISS3
        ENDIF

        J = ICSIZE( 3 )                                   ! SCC=all, FIP=0
        IF( J .GT. 0 ) THEN
            ALLOCATE( MPRT03( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT03', PROGNAME )
            ALLOCATE( WPRT03( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT03', PROGNAME )
            ALLOCATE( DPRT03( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT03', PROGNAME )
            MPRT03 = IMISS3 ! arrays
            WPRT03 = IMISS3
            DPRT03 = IMISS3
        ENDIF
                
        J = ICSIZE( 4 )                                 ! SCC=0, FIP=state
        IF( J .GT. 0 ) THEN
            ALLOCATE( MPRT04( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT04', PROGNAME )
            ALLOCATE( WPRT04( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT04', PROGNAME )
            ALLOCATE( DPRT04( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT04', PROGNAME )
            MPRT04 = IMISS3 ! arrays
            WPRT04 = IMISS3
            DPRT04 = IMISS3
        ENDIF
            
        J = ICSIZE( 5 )                                 ! SCC=left, FIP=state
        IF( J .GT. 0 ) THEN
            ALLOCATE( MPRT05( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT05', PROGNAME )
            ALLOCATE( WPRT05( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT05', PROGNAME )
            ALLOCATE( DPRT05( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT05', PROGNAME )
            MPRT05 = IMISS3 ! arrays
            WPRT05 = IMISS3
            DPRT05 = IMISS3
        ENDIF
            
        J = ICSIZE( 6 )  
        IF( J .GT. 0 ) THEN                        ! SCC=all, FIP=state
            ALLOCATE( MPRT06( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT06', PROGNAME )
            ALLOCATE( WPRT06( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT06', PROGNAME )
            ALLOCATE( DPRT06( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT06', PROGNAME )
            MPRT06 = IMISS3 ! arrays
            WPRT06 = IMISS3
            DPRT06 = IMISS3
        ENDIF
                        
        J = ICSIZE( 7 )   
        IF( J .GT. 0 ) THEN                          ! SCC=0, FIP=all
            ALLOCATE( MPRT07( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT07', PROGNAME )
            ALLOCATE( WPRT07( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT07', PROGNAME )
            ALLOCATE( DPRT07( J ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT07', PROGNAME )
            MPRT07 = IMISS3 ! arrays
            WPRT07 = IMISS3
            DPRT07 = IMISS3
        ENDIF
            
        J = ICSIZE( 8 )
        IF( J .GT. 0 ) THEN                         ! SCC=left, FIP=all
            ALLOCATE( MPRT08( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT08', PROGNAME )
            ALLOCATE( WPRT08( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT08', PROGNAME )
            ALLOCATE( DPRT08( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT08', PROGNAME )
            MPRT08 = IMISS3 ! arrays
            WPRT08 = IMISS3
            DPRT08 = IMISS3
        ENDIF
                        
        J = ICSIZE( 9 )
        IF( J .GT. 0 ) THEN                          ! SCC=all, FIP=all
            ALLOCATE( MPRT09( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT09', PROGNAME )
            ALLOCATE( WPRT09( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT09', PROGNAME )
            ALLOCATE( DPRT09( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT09', PROGNAME )
            MPRT09 = IMISS3 ! arrays
            WPRT09 = IMISS3
            DPRT09 = IMISS3
        ENDIF
            
        J = ICSIZE( 10 )
        IF( J .GT. 0 ) THEN                       ! PLANT=non-blank, SCC=0
            ALLOCATE( MPRT10( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT10', PROGNAME )
            ALLOCATE( WPRT10( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT10', PROGNAME )
            ALLOCATE( DPRT10( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT10', PROGNAME )

            MPRT10 = IMISS3 ! arrays
            WPRT10 = IMISS3
            DPRT10 = IMISS3
        ENDIF
            
        J = ICSIZE( 11 )         
        IF( J .GT. 0 ) THEN                      ! PLANT=non-blank, SCC=all
            ALLOCATE( MPRT11( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT11', PROGNAME )
            ALLOCATE( WPRT11( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT11', PROGNAME )
            ALLOCATE( DPRT11( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT11', PROGNAME )
            MPRT11 = IMISS3 ! arrays
            WPRT11 = IMISS3
            DPRT11 = IMISS3
        ENDIF
            
        J = ICSIZE( 12 )        
        IF( J .GT. 0 ) THEN                      ! CHAR1=non-blank, SCC=all
            ALLOCATE( MPRT12( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT12', PROGNAME )
            ALLOCATE( WPRT12( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT12', PROGNAME )
            ALLOCATE( DPRT12( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT12', PROGNAME )
            MPRT12 = IMISS3 ! arrays
            WPRT12 = IMISS3
            DPRT12 = IMISS3
        ENDIF
            
        J = ICSIZE( 13 )  
        IF( J .GT. 0 ) THEN                      ! CHAR2=non-blank, SCC=all
            ALLOCATE( MPRT13( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT13', PROGNAME )
            ALLOCATE( WPRT13( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT13', PROGNAME )
            ALLOCATE( DPRT13( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT13', PROGNAME )
            MPRT13 = IMISS3 ! arrays
            WPRT13 = IMISS3
            DPRT13 = IMISS3
        ENDIF
            
        J = ICSIZE( 14 )
        IF( J .GT. 0 ) THEN                      ! CHAR3=non-blank, SCC=all
            ALLOCATE( MPRT14( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT14', PROGNAME )
            ALLOCATE( WPRT14( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT14', PROGNAME )
            ALLOCATE( DPRT14( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT14', PROGNAME )
            MPRT14 = IMISS3 ! arrays
            WPRT14 = IMISS3
            DPRT14 = IMISS3
        ENDIF
            
        J = ICSIZE( 15 )
        IF( J .GT. 0 ) THEN                      ! CHAR4=non-blank, SCC=all
            ALLOCATE( MPRT15( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT15', PROGNAME )
            ALLOCATE( WPRT15( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT15', PROGNAME )
            ALLOCATE( DPRT15( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT15', PROGNAME )
            MPRT15 = IMISS3 ! arrays
            WPRT15 = IMISS3
            DPRT15 = IMISS3
        ENDIF
            
        J = ICSIZE( 16 )
        IF( J .GT. 0 ) THEN                      ! CHAR5=non-blank, SCC=all
            ALLOCATE( MPRT16( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MPRT16', PROGNAME )
            ALLOCATE( WPRT16( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'WPRT16', PROGNAME )
            ALLOCATE( DPRT16( J,NIPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'DPRT16', PROGNAME )
            MPRT16 = IMISS3 ! arrays
            WPRT16 = IMISS3
            DPRT16 = IMISS3
        ENDIF
            
        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

        END SUBROUTINE ALOCTTBL
