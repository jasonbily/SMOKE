
        SUBROUTINE WRPDEMIS( JDATE, JTIME, TIDX, NPDSRC, NVAR, NVSP, 
     &                       FNAME, PFLAG, EAIDX, SPIDX, PDIDX, PDDATA, 
     &                       EFLAG )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: I/O API subroutine
C
C  REVISION  HISTORY:
C      Created 12/99 by M. Houyoux
C
C**************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2001, MCNC--North Carolina Supercomputing Center
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

C.........  MODULES for public variables
C...........   This module is the inventory arrays
        USE MODSOURC

C.........  This module contains the information about the source category
        USE MODINFO

C.........  This module contains data for day- and hour-specific data
        USE MODDAYHR

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C.........  EXTERNAL FUNCTIONS
        CHARACTER*2  CRLF
        LOGICAL      ENVYN


C.........  SUBROUTINE ARGUMENTS
        INTEGER,      INTENT  (IN) :: JDATE                ! Julian date
        INTEGER     , INTENT  (IN) :: JTIME                ! time HHMMSS
        INTEGER     , INTENT  (IN) :: TIDX                 ! time index
        INTEGER     , INTENT  (IN) :: NPDSRC               ! no. part-day srcs
        INTEGER     , INTENT  (IN) :: NVAR                 ! no. pol/act vars
        INTEGER     , INTENT  (IN) :: NVSP                 ! no. pol/act/special
        CHARACTER(*), INTENT  (IN) :: FNAME                ! output file name
        LOGICAL     , INTENT  (IN) :: PFLAG                ! true: gen profiles
        INTEGER     , INTENT  (IN) :: EAIDX( NVAR )        ! pol/act index
        INTEGER     , INTENT  (IN) :: SPIDX( MXSPDAT )     ! special var index
        INTEGER     , INTENT (OUT) :: PDIDX ( NPDSRC )     ! sparse src index
        REAL        , INTENT (OUT) :: PDDATA( NPDSRC,NVSP )! sparse data storage
        LOGICAL     , INTENT (OUT) :: EFLAG                ! true: error found

C...........   Local allocatable arrays
        LOGICAL, ALLOCATABLE, SAVE :: NOMISS( :,: )

C...........   Local arrays
        INTEGER          SPIDX2( MXSPDAT )

C...........   Other local variables
        INTEGER          I, J, K, L2, LS, S, V, V2

        INTEGER          IOS                  ! i/o status
        INTEGER          NOUT                 ! tmp no. sources per time step

        LOGICAL, SAVE :: DFLAG    = .FALSE.  ! true: error on duplicates
        LOGICAL, SAVE :: FIRSTIME = .TRUE.   ! true: first time routine called
        LOGICAL, SAVE :: SFLAG    = .FALSE.  ! true: error on missing species
        LOGICAL, SAVE :: LFLAG    = .FALSE.  ! true: iteration on special var

        CHARACTER*100    BUFFER           ! src description buffer
        CHARACTER*300    MESG             ! message buffer

        CHARACTER*16 :: PROGNAME = 'WRPDEMIS' !  program name

C***********************************************************************
C   begin body of program WRPDEMIS

C.........  For the first time the routine is called...
        IF( FIRSTIME ) THEN

C.............  Get settings from the environment.
            DFLAG = ENVYN( 'RAW_DUP_CHECK',
     &                     'Error if duplicate inventory records',
     &                     .FALSE., IOS )

            SFLAG = ENVYN( 'RAW_SRC_CHECK',
     &                     'Error if missing species-records',
     &                     .FALSE., IOS )

C.............  Allocate memory for flag for writing missing-data messages
            ALLOCATE( NOMISS( NSRC,NVSP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'NOMISS', PROGNAME )
            NOMISS = .TRUE.  ! Array

            FIRSTIME = .FALSE.

        END IF

        PDIDX  = 0        ! array (index)
        PDDATA = BADVAL3  ! array (emissions/activities)
        PDTOTL = BADVAL3  ! array (total daily emissions/activities)

C.........  Create reverse index for special variables
        DO V = 1, MXSPDAT
            K = SPIDX( V )
            IF( K .GT. 0 ) SPIDX2( K ) = V       
        END DO

C.........  Sort sources for current time step
        CALL SORTI1( NPDPT( TIDX ), IDXSRC( 1,TIDX ), SPDIDA( 1,TIDX ) )

C.........  Store sorted records for this hour
        LS = 0  ! previous source
        K  = 0
        DO I = 1, NPDPT( TIDX )

            J = IDXSRC( I,TIDX )
            S = SPDIDA( J,TIDX )
            V = CODEA ( J,TIDX )

C.............  Intialize as not a special data variable (e.g., not flow rate)
            LFLAG = .FALSE.

C.............  Check for bad index
            IF( V .LE. 0 ) THEN
                MESG = 'INTERNAL ERROR: problem indexing input '//
     &                 'pollutants to output pollutants.'
                CALL M3EXIT( PROGNAME, JDATE, JTIME, MESG, 2 )

C.............  Check for index for special variables and set V to be consistent
C               with the output structure of the file
            ELSE IF ( V .GT. CODFLAG3 ) THEN
                V2 = V - CODFLAG3      ! remove flag on index
                V = NVAR + SPIDX( V2 ) ! reset to condensed order from master
                LFLAG = .TRUE.         ! flag as a special data variable

            END IF

C.............  If current source is not equal to previous source
            IF( S .NE. LS ) THEN
                K = K + 1
                PDIDX( K ) = S
                LS         = S
            END IF

C.............  If emissions are not yet set for current source and variable
            IF( PDDATA( K,V ) .LT. AMISS3 ) THEN  ! PDDATA is blank

                PDDATA( K,V ) = EMISVA( J,TIDX )
                PDTOTL( K,V ) = DYTOTA( J,TIDX )

C.............  Otherwise, sum emissions, report, and set error if needed
            ELSE 

                IF( .NOT. LFLAG .AND. EMISVA( J,TIDX ) .GE. 0. )
     &              PDDATA( K,V )  = PDDATA( K,V ) + EMISVA( J,TIDX )

                IF( .NOT. LFLAG .AND. DYTOTA( J,TIDX ) .GE. 0. )
     &              PDTOTL( K,V )  = PDTOTL( K,V ) + DYTOTA( J,TIDX )

                CALL FMTCSRC( CSOURC( S ), NCHARS, BUFFER, L2 )
                
                IF( DFLAG ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Duplicate source in inventory:'//
     &                     CRLF() // BLANK10 // BUFFER( 1:L2 )
                    CALL M3MESG( MESG )
                    CYCLE
                ELSE IF ( LFLAG ) THEN
                    MESG = 'WARNING: Duplicate source in ' //
     &                     'inventory. Will store only one value '//
     &                     'for '// CRLF()// BLANK10// SPDATDSC( V2 )//
     &                     ':' // CRLF() // BLANK10 // BUFFER( 1:L2 )
                    
                ELSE
                    MESG = 'WARNING: Duplicate source in ' //
     &                     'inventory will haved summed emissions:' 
     &                     //CRLF() // BLANK10 // BUFFER( 1:L2 )
                    CALL M3MESG( MESG )
                END IF
            END IF

        END DO

C.........  Set tmp variable for loops
        NOUT = K
        
C.........  Check if there are missing values and output errors, if the
C           flag is set to treat these as errors
C.........  Also use loop to create diurnal profiles from emission values,
C           if needed.
        DO V = 1, NVSP
            DO I = 1, NOUT

                S = PDIDX( I )

C.................  Format source information
                CALL FMTCSRC( CSOURC( S ), NCHARS, BUFFER, L2 )

C.................  Check for missing values
                IF ( PDDATA( I,V ) .LT. AMISS3 ) THEN
                    IF( SFLAG ) THEN
                	EFLAG = .TRUE.
                        IF( NOMISS( S,V ) ) THEN
                            IF ( V .LE. NVAR ) THEN
                	        MESG = 'ERROR: Data missing for:' //
     &                                 CRLF()//BLANK10//BUFFER( 1:L2 )//
     &                                ' VAR: '// EANAM( EAIDX( V ) )
                            ELSE
                                K = V - NVAR
                	        MESG = 'ERROR: Data missing for:' //
     &                                 CRLF()//BLANK10//BUFFER( 1:L2 )//
     &                                 ' VAR: '//SPDATNAM( SPIDX2( K ) )
                            END IF

                            CALL M3MESG( MESG )
                            NOMISS( S,V ) = .FALSE.
                        END IF
                        CYCLE

                    ELSE
                        IF( NOMISS( S,V ) ) THEN
                            IF ( V .LE. NVAR ) THEN
               	                MESG = 'WARNING: Data missing for: ' //
     &                                 CRLF()//BLANK10//BUFFER( 1:L2 )//
     &                                 ' VAR: '// EANAM( EAIDX( V ) )
                            ELSE
                                K = V - NVAR
               	                MESG = 'WARNING: Data missing for: ' //
     &                                 CRLF()//BLANK10//BUFFER( 1:L2 )//
     &                                 ' VAR: '//SPDATNAM( SPIDX2( K ) )
                            END IF

                            CALL M3MESG( MESG )
                            NOMISS( S,V ) = .FALSE.
                        END IF

                    END IF
                END IF

C.................  Skip next section if special data variable
                IF ( V .GT. NVAR ) CYCLE

C.................  If profiles need to be created instead of hourly emissions
C.................  Make sure totals data are available!
                IF ( PFLAG .AND. PDTOTL( I,V ) .LT. AMISS3 ) THEN
                    EFLAG = .TRUE.
                    MESG = 'ERROR: Cannot create profiles ' //
     &                     'because daily total data missing for:' //
     &                     CRLF() // BLANK10 // BUFFER( 1:L2 ) //
     &                     ' VAR: ' // EANAM( EAIDX( V ) )
                    CALL M3MESG( MESG )
                    CYCLE

C.................  Prevent divide by zero
C.................  If totals are zero, then profile values should be zero
                ELSE IF( PFLAG .AND. PDTOTL( I,V ) .GT. 0 ) THEN

                    PDDATA( I,V ) = PDDATA( I,V ) / PDTOTL( I,V )

                END IF

            END DO
        END DO
  
C.........  Write emissions for this time step

        IF ( .NOT. WRITE3( FNAME, ALLVAR3, JDATE, JTIME, PDIDX ) ) THEN

            L2   = LEN_TRIM( FNAME )
            MESG= 'Error writing output file "' // FNAME(1:L2) // '"'
            CALL M3EXIT( PROGNAME, JDATE, JTIME, MESG, 2 )

        END IF
 
        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

C******************  INTERNAL SUBPROGRAMS  *****************************

        END SUBROUTINE WRPDEMIS
