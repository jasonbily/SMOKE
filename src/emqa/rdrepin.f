
        SUBROUTINE RDREPIN( NSLIN, NSSIN, RDEV, SDEV, GDEV, PDEV, TDEV,
     &                      EDEV, YDEV, NDEV, ENAME, CUNAME, GNAME, 
     &                      LNAME, PRNAME, SLNAME, SSNAME, NX, IX, CX, 
     &                      SSMAT, SLMAT )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      The RDREPIN routine reads in the SMOKE intermediate files and other
C      files needed for generating the reports.
C
C  PRECONDITIONS REQUIRED:
C    REPCONFIG file is opened
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     Created 7/2000 by M Houyoux
C
C***********************************************************************
C  
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C  
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C  
C Pathname: $Source$
C Last updated: $Date$ 
C  
C***********************************************************************

C...........   MODULES for public variables
C...........   This module is the inventory arrays
        USE MODSOURC

C.........  This module contains Smkreport-specific settings
        USE MODREPRT

C.........  This module contains report arrays for each output bin
        USE MODREPBN

C.........  This module contains the control packet data and control matrices
        USE MODCNTRL

C.........  This module contains arrays for plume-in-grid and major sources
        USE MODELEV

C.........  This module contains the lists of unique source characteristics
        USE MODLISTS

C.........  This module contains the global variables for the 3-d grid
        USE MODGRID

C.........  This module contains the information about the source category
        USE MODINFO

C.........  This module is required for the FileSetAPI
        USE MODFILESET
        
        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'SETDECL.EXT'   !  FileSetAPI function declarations

C...........  EXTERNAL FUNCTIONS and their descriptions:
        LOGICAL     CHKINT
        LOGICAL     CHKREAL 
        CHARACTER*2 CRLF
        INTEGER     FINDC
        INTEGER     GETFLINE
        INTEGER     GETNLIST
        INTEGER     INDEX1
        REAL        STR2REAL

        EXTERNAL    CHKINT, CHKREAL, CRLF, FINDC, GETFLINE, GETNLIST, 
     &              INDEX1, STR2REAL

C...........   SUBROUTINE ARGUMENTS
        INTEGER     , INTENT (IN) :: NSLIN  ! no. mass spec input vars
        INTEGER     , INTENT (IN) :: NSSIN  ! no. mass spec input vars
        INTEGER     , INTENT (IN) :: RDEV(3)! control report files
        INTEGER     , INTENT (IN) :: SDEV   ! unit no.: ASCII inven file
        INTEGER     , INTENT (IN) :: GDEV   ! unit no.: gridding supplemental
        INTEGER     , INTENT (IN) :: PDEV   ! unit no.: speciation supplemental
        INTEGER     , INTENT (IN) :: TDEV   ! unit no.: temporal supplemental
        INTEGER     , INTENT (IN) :: EDEV   ! unit no.: elevated ID file (PELV)
        INTEGER     , INTENT (IN) :: YDEV   ! unit no.: cy/st/co file
        INTEGER     , INTENT (IN) :: NDEV   ! unit no.: SCC descriptions
        CHARACTER(*), INTENT (IN) :: ENAME  ! name for I/O API inven input
	CHARACTER(*), INTENT (IN) :: CUNAME ! mulitplicative control matrix name
        CHARACTER(*), INTENT (IN) :: GNAME  ! gridding matrix name
        CHARACTER(*), INTENT (IN) :: LNAME  ! layer fractions file name
        CHARACTER(*), INTENT (IN) :: PRNAME ! projection matrix name
        CHARACTER(*), INTENT (IN) :: SLNAME ! speciation matrix name
        CHARACTER(*), INTENT (IN) :: SSNAME ! speciation matrix name
        INTEGER     , INTENT(OUT) :: NX( NGRID ) ! no. srcs per cell
        INTEGER     , INTENT(OUT) :: IX( NMATX ) ! src IDs
        REAL        , INTENT(OUT) :: CX( NMATX ) ! gridding coefficients
        REAL        , INTENT(OUT) :: SLMAT( NSRC, NSLIN ) ! mole spec coefs
        REAL        , INTENT(OUT) :: SSMAT( NSRC, NSSIN ) ! mass spec coefs
 
C.........  Local allocatable arrays
        INTEGER, ALLOCATABLE :: IBUF   ( : )  ! tmp var for temporal profiles
        REAL   , ALLOCATABLE :: LFRAC1L( : )  ! 1st-layer fraction

C.........  Array that contains the names of the inventory variables needed for
C           this program
        CHARACTER(LEN=IOVLEN3) IVARNAMS( MXINVARR )

C.........  For parsing lines
        CHARACTER*64              SEGMENT( 10 )
        CHARACTER(LEN=CHRLEN3) :: CHARS  ( 5 )   ! tmp plant characteristics

C...........   Local variables that depend on module variables
        INTEGER    SWIDTH( NCHARS )

C...........   Other local variables
        INTEGER          I, J, K, L, L1, L2, N, V, S, T ! counters and indices

        INTEGER          DIU                ! tmp diurnal profile number
        INTEGER          IOS                ! i/o status
        INTEGER          IREC               ! tmp record number
        INTEGER       :: JDATE = 0          ! Julian date
        INTEGER       :: JTIME = 0          ! time (HHMMSS)
        INTEGER          MON                ! tmp monthly profile number
        INTEGER       :: NINVARR = 0        ! no. actual inventory inputs
        INTEGER          NREPLIN            ! no. lines in input report
        INTEGER          NS                 ! tmp no. strings on line
        INTEGER          NV                 ! tmp no. variables in temporal suplm
        INTEGER       :: SRGID1             ! tmp primary surrogate IDs
        INTEGER       :: SRGID2             ! tmp fallback surrogate IDs
        INTEGER          WEK                ! tmp weekly profile number

        LOGICAL       :: LRDREGN = .FALSE.  !  true: read region code
        LOGICAL       :: EFLAG   = .FALSE.  !  true: error found
        LOGICAL       :: MSGFLAG = .FALSE.  !  true: don't repeat message
        LOGICAL       :: LTMP    = .FALSE.  !  true: temporary logical

        CHARACTER*1            TTYP         !  temporal profile entry type
        CHARACTER*16  ::       BNAME = ' '  !  name buffer
        CHARACTER*50           BUFFER       !  string buffer
        CHARACTER*256          LINE         !  input line
        CHARACTER*256          MESG         !  message buffer
        CHARACTER(LEN=IOVLEN3) CBUF         !  tmp pollutant name
        CHARACTER(LEN=IODLEN3) DBUF         !  tmp variable name
        CHARACTER(LEN=FIPLEN3) CFIP         !  tmp ASCII FIPS code
        CHARACTER(LEN=LNKLEN3) CLNK         !  tmp link code
        CHARACTER(LEN=SRCLEN3) CSRC         !  tmp source chars
        CHARACTER(LEN=PLTLEN3) PLT          !  tmp plant code
        CHARACTER(LEN=SRCLEN3) SRCBUF       !  tmp source chars
        CHARACTER(LEN=SCCLEN3) TSCC         !  tmp SCC code

        CHARACTER*16 :: PROGNAME = 'RDREPIN' ! program name

C***********************************************************************
C   begin body of subroutine RDREPIN

C.........  Set local variables for determining input inventory variables
        LRDREGN = ( ANY_TRUE( NREPORT, ALLRPT%BYCNRY ) .OR.
     &              ANY_TRUE( NREPORT, ALLRPT%BYSTAT ) .OR.
     &              ANY_TRUE( NREPORT, ALLRPT%BYCNTY ) .OR.
     &              ANY_TRUE( NREPORT, ALLRPT%BYPLANT ) .OR.
     &              ANY_CVAL( NREPORT, ALLRPT%REGNNAM )     )

C.........  Build array of inventory variable names based on report settings
C.........  Region code
        IF( LRDREGN ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'IFIP'
        END IF

C.........  Road class code
        IF( ANY_TRUE( NREPORT, ALLRPT%BYRCL ) ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'IRCLAS'
        END IF

C.........  SCC code
        IF( ANY_TRUE( NREPORT, ALLRPT%BYSCC ) ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'CSCC'
        END IF

C.........  Source description
        IF( ANY_TRUE( NREPORT, ALLRPT%BYSRC ) .OR.
     &      ANY_TRUE( NREPORT, ALLRPT%BYPLANT )    ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'CSOURC'
        END IF

C.........  Stack parameters
        IF( ANY_TRUE( NREPORT, ALLRPT%STKPARM ) ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'STKHT'
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'STKDM'
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'STKTK'
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'STKVE'
        END IF

C.........  Plant name
        IF( ANY_TRUE( NREPORT, ALLRPT%SRCNAM ) ) THEN
            NINVARR = NINVARR + 1
            IVARNAMS( NINVARR ) = 'CPDESC'
        END IF

C.........  Allocate memory for and read in required inventory characteristics
        CALL RDINVCHR( CATEGORY, ENAME, SDEV, NSRC, NINVARR, IVARNAMS )

C.........  Create unique source characteristic lists
        CALL GENUSLST

C.........  If needed, read in gridding matrix
C.........  Initialize all to 1 for point sources
        IF( GFLAG ) THEN

            MESG = 'Reading gridding matrix...'
            CALL M3MSG2( MESG )

            CALL RDGMAT( GNAME, NGRID, NMATX, NMATX, NX, IX, CX )

C.............  Initialize part of gridding matrix array for point sources
            IF( CATEGORY .EQ. 'POINT' ) THEN
                CX = 1   ! array            
            END IF

        END IF

C.........  If needed, read in gridding supplementation fike
        IF( GSFLAG ) THEN

            MESG = 'Reading supplemental gridding file...'
            CALL M3MSG2( MESG )

            ALLOCATE( SRGID( NSRC,2 ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SRGID', PROGNAME )
            SRGID = -9

            MESG = 'Supplemental gridding file'
            N = GETFLINE( GDEV, MESG )

            IREC = 0
            DO I = 1, N

                READ( GDEV, *, END=999, IOSTAT=IOS ) S, SRGID1, SRGID2
                IREC = IREC + 1

                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &                'I/O error', IOS, 
     &                'reading supplemental gridding file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

                SRGID( S,1 ) = SRGID1
                SRGID( S,2 ) = SRGID2
                
            END DO            

        END IF

C........  Allocate memory for projection factors
C........  Ensure that NVPROJ = 1 if no controls are being run,
C          because genrprt.f will still use array. First column
C          will always be an array of ones.
        I = NVPROJ
        IF( PRRPTFLG ) I = 2 * I
        ALLOCATE( PRMAT( NSRC,1+I ), STAT=IOS )
        CALL CHECKMEM( IOS, 'PRMAT', PROGNAME )
        PRMAT = 1.

C........  If needed, read in projection matrix
        IF( PRFLAG ) THEN

            MESG = 'Reading projection matrix...'
            CALL M3MSG2( MESG )

C...........  Read in projection factors for each projection variable
C...........  Note that openrepin.f contrains the no. of vars to 1,
C             since that is how Cntlmat currently works. 
            DO V = 1, NVPROJ
                IF( .NOT. READSET( PRNAME, PNAMPROJ( V ), ALLAYS3, 
     &                           ALLFILES, 0, 0, PRMAT( 1,1+V ) ) ) THEN

                    MESG = 'ERROR: Could not read "' //
     &                     TRIM( PNAMPROJ( V ) ) //'" from file "' // 
     &                     TRIM( PRNAME ) // '"'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF           
            END DO
        END IF

C........  Read projection factors report...
        IF( PRRPTFLG ) THEN

            MESG = 'Reading projection report...'
            CALL M3MSG2( MESG )

C............  Get the number of lines in the file
            MESG = 'projection report'
            NREPLIN = GETFLINE( RDEV( 1 ), MESG )

C............  Loop through all lines in the file
            DO I = 1, NREPLIN

C...............  Read line 
                READ( RDEV( 1 ), '(A)', END = 9001 ) LINE

C...............  Skip header lines (not very robust way)
                IF( I .LE. 6 ) CYCLE

                L = LEN_TRIM( LINE )
                NS = GETNLIST( L, LINE )

C...............  Parse line into parts
                SEGMENT = ' '  ! array
                CALL PARSLINE( LINE, NS, SEGMENT )
                CFIP = SEGMENT( 1 )( 1:FIPLEN3 )

C...............  Build source string
                SELECT CASE( CATEGORY )
                CASE ( 'AREA' )
                    TSCC = SEGMENT( 2 )( 1:SCCLEN3 )
                    CALL BLDCSRC( CFIP, TSCC, CHRBLNK3, CHRBLNK3,
     &                            CHRBLNK3, CHRBLNK3, CHRBLNK3,
     &                            POLBLNK3, CSRC )

                CASE ( 'MOBILE' )
                    TSCC = SEGMENT( 2 )( 1:SCCLEN3 )
                    CLNK = SEGMENT( 3 )( 1:LNKLEN3 )
                    CALL BLDCSRC( CFIP, TSCC, CLNK, CHRBLNK3,
     &                            CHRBLNK3, CHRBLNK3, CHRBLNK3,
     &                            POLBLNK3, CSRC )

                CASE ( 'POINT' )
                    PLT = SEGMENT( 2 )( 1:PLTLEN3 )
                    DO J = 3, MAX( 8,NS-1 )
                        CHARS( J-2 ) = SEGMENT( J )( 1:CHRLEN3 )
                    END DO
                    
                    IF( JSCC .GT. 0 ) THEN 
                        TSCC = SEGMENT( JSCC )
                    ELSE
                        TSCC = SEGMENT( NS-1 )
                    END IF

                    CALL BLDCSRC( CFIP, PLT, CHARS( 1 ), CHARS( 2 ),
     &                            CHARS( 3 ), CHARS( 4 ), CHARS( 5 ),
     &                            POLBLNK3, SRCBUF )
                    CSRC = SRCBUF( 1:SRCLEN3 ) // TSCC

                END SELECT

C...............  Search for source string in source list
                S = FINDC( CSRC, NSRC, CSOURC )

C...............  If not found, give error
                IF( S .LE. 0 ) THEN

C...................  Check if the first segment is an integer, and
C                     if not, then there is garbage at the end of
C                     the report (or an old report with multiple
C                     reports in one file).  If so, end read loop.
                    IF( .NOT. CHKINT( SEGMENT( 1 ) ) ) THEN
                        EXIT
                    END IF

C..................  Otherwise, there is an error because the report
C                    file is not for the inventory used in this run.
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'ERROR: Projection report ' //
     &                     'entry at line', I, 'could not' //
     &                     CRLF() // BLANK10 // 'be matched to the ' //
     &                     'inventory.'
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C...............  If found store factor
                MSGFLAG = .FALSE.
                J = NS - NVPROJ
                DO V = 1, NVPROJ
                    J = J + 1

C..................  Check to ensure that segment is a real first.
                    IF( .NOT. CHKREAL( SEGMENT( J ) ) ) THEN
                        EFLAG = .TRUE.

C......................  If message hasn't been written for this line...
                        IF( .NOT. MSGFLAG ) THEN
                            WRITE( MESG,94010 ) 'ERROR: Bad format ' //
     &                      'or value at line', IREC, 'of projection '//
     &                      'report.'
                            CALL M3MSG2( MESG )
                        END IF
                        MSGFLAG = .TRUE.
                        CYCLE

C..................  If field is a real, store it
                    ELSE
                        PRMAT( S,1+NVPROJ+V ) = STR2REAL( SEGMENT( J ) )
                    END IF

                END DO

            END DO
        END IF     ! end if projection report or not

C........  Allocate memory for multiplicative control factors
C........  Ensure that NVCMULT = 1 if no controls are being run,
C          because genrprt.f will still use array.  First column
C          will always be an array of ones.
        ALLOCATE( ACUMATX( NSRC,1+NVCMULT ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ACUMATX', PROGNAME )
        ACUMATX = 1.

C.........  If needed, read in multiplicative control matrix
        IF( CUFLAG ) THEN

            MESG = 'Reading multiplicative control matrix...'
            CALL M3MSG2( MESG )

            DO V = 1, NVCMULT
                IF( .NOT. READSET( CUNAME, PNAMMULT( V ), ALLAYS3, 
     &                          ALLFILES, 0, 0, ACUMATX( 1,1+V ) )) THEN

                    MESG = 'ERROR: Could not read "' //
     &                     TRIM( PNAMMULT( V ) ) //'" from file "' // 
     &                     TRIM( CUNAME ) // '"'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

                END IF
            END DO
        END IF

C.........  If needed, read in speciation matrices
C.........  NOTE that only the variables that are needed are read in 
        IF( SLFLAG .OR. SSFLAG ) THEN

            MESG = 'Reading speciation matrices...'
            CALL M3MSG2( MESG )

            IF( SLNAME .NE. ' ' ) BNAME = SLNAME
            IF( SSNAME .NE. ' ' ) BNAME = SSNAME

C.............  Get file header for variable names
            IF ( .NOT. DESCSET( BNAME, ALLFILES ) ) THEN

                MESG = 'Could not get description of file "' //
     &                 BNAME( 1:LEN_TRIM( BNAME ) ) // '"'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

            END IF

            K = 0
            DO V = 1, NSVARS

                IF( SPCOUT( V ) ) THEN

                    K = K + 1
                    DBUF = VDESCSET( V )
                    IF( SLFLAG ) THEN
                        CALL RDSMAT( SLNAME, DBUF, SLMAT( 1,K ) )
                    END IF

                    IF( SSFLAG ) THEN
                        CALL RDSMAT( SSNAME, DBUF, SSMAT( 1,K ) )
                    END IF

                END IF

            END DO

        END IF

C.........  If needed, read in speciation supplementation file
        IF( PSFLAG ) THEN

            MESG = 'Reading supplemental speciation file...'
            CALL M3MSG2( MESG )

            ALLOCATE( SPPROF( NSRC,NSPCPOL ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPPROF', PROGNAME )
            SPPROF = ' '

            MESG = 'supplemental speciation file'
            N = GETFLINE( PDEV, MESG )

            IREC = 0
            
            DO I = 1, N

                READ( PDEV, '(A)', END=1001, IOSTAT=IOS ) BUFFER
                IREC = IREC + 1

                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &                'I/O error', IOS, 'reading supplemental ' //
     &                'speciation file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C.................  See if this line is a pollutant name
                L1 = INDEX( BUFFER, '"' )        ! Find start quote

C.................  If pollutant name, figure out which pollutant index and
C                   reset source counter to 0.
                IF ( L1 .GT. 0 ) THEN

                    L2 = LEN_TRIM( BUFFER )     ! Find end quote
                    CBUF = BUFFER( L1+1:L2-1 )  

C.....................  Check if this pollutant is one selected for reporting 
                    V = INDEX1( CBUF, NSPCPOL, SPCPOL )
                    IF ( V .GT. 0 ) THEN
                        LSPCPOL( V ) = .TRUE.
                        S = 0
                    END IF
                        
C.................  If not pollutant name, then continue to read in the 
C                   pollutant codes and store them by source
                ELSE IF ( V .GT. 0 ) THEN
                    S = S + 1

                    BUFFER = ADJUSTL( BUFFER )
                    SPPROF( S,V ) = ADJUSTR( BUFFER( 1:SPNLEN3 ) )

C.....................  Handle case where spaces have been added to file.
                    IF ( S .EQ. NSRC ) V = 0

                END IF
                
            END DO            

        END IF

C.........  If needed, read in temporal supplementation matrix
        IF( TSFLAG ) THEN

            MESG = 'Reading supplemental temporal file...'
            CALL M3MSG2( MESG )

            ALLOCATE( IDIU( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IDIU', PROGNAME )
            ALLOCATE( IWEK( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IWEK', PROGNAME )
            ALLOCATE( IMON( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IMON', PROGNAME )
            ALLOCATE( IBUF( NIPPA ), STAT=IOS )
            CALL CHECKMEM( IOS, 'IBUF', PROGNAME )
            IDIU = 0
            IWEK = 0
            IMON = 0
            IBUF = 0

            MESG = 'Supplemental temporal file'
            N = GETFLINE( TDEV, MESG )

C.............  Check file format, assuming that pollutants weren't processed
C               in > 1 groups.  (this routine doesn't handle grouped processing)
            IF ( ( (N-1)/3 ) .NE. NSRC ) THEN
                MESG = 'INTERNAL ERROR: ' // CRL// 'TSUP file has '//
     &                 'inconsistent number of lines with NSRC'
                CALL M3MSG2( MESG )
                CALL M3EXIT( PROGNAME, 0, 0, ' ', 2 )
            END IF

C.............  Skip file header
            READ( TDEV, * )

            IREC = 1
            DO I = 2, N

                READ( TDEV, *, END=1003, IOSTAT=IOS ) 
     &              TTYP, NV, ( IBUF( V ), V=1, NV )
                IREC = IREC + 1

                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &                'I/O error', IOS, 
     &                'reading supplemental temporal file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
                END IF

C.................  NV > 1 is not supported
                IF ( NV .GT. 1 ) THEN
                    MESG = 'Number of variables in ' // CRL //
     &                     'TSUP file is not supported.'
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                S = INT( ( I-2 ) / 3 ) + 1
                SELECT CASE( TTYP )
                CASE ( 'M' )
                    IF ( NV .EQ. 1 ) THEN
                        IMON( S ) = IBUF( 1 )
                    ELSE
c                   note: this is not supported yet in Temporal
                    ENDIF

                CASE ( 'W' )
                    IF ( NV .EQ. 1 ) THEN
                        IWEK( S ) = IBUF( 1 )
                    ELSE
c                   note: this is not supported yet in Temporal
                    ENDIF

                CASE ( 'H' )
                    IF ( NV .EQ. 1 ) THEN
                        IDIU( S ) = IBUF( 1 )
                    ELSE
c                   note: this is not supported yet in Temporal
                    ENDIF

                END SELECT
              
            END DO            

        END IF

C.........  If needed, read in country, state, county file
        IF( YFLAG ) THEN
            CALL RDSTCY( YDEV, NINVIFIP, INVIFIP )
        END IF

C.........  If needed, read in elevated source indentification file
        IF( VFLAG ) THEN
            LTMP = ( .NOT. LFLAG )
            CALL RDPELV( EDEV, NSRC, LTMP, NMAJOR, NPING )
        END IF

C.........  If needed, read in SCC descriptions file
        IF( NFLAG ) CALL RDSCCDSC( NDEV )

C.........  If needed, read in layer fractions file to identify elevated
C           sources
        IF( LFLAG ) THEN

            IF( .NOT. ALLOCATED( LMAJOR ) ) THEN
                ALLOCATE( LMAJOR( NSRC ), STAT=IOS )
                CALL CHECKMEM( IOS, 'LMAJOR', PROGNAME )
                LMAJOR = .FALSE.   ! array
            END IF

            IF( .NOT. ALLOCATED( LPING ) ) THEN
                ALLOCATE( LPING( NSRC ), STAT=IOS )
                CALL CHECKMEM( IOS, 'LPING', PROGNAME )
                LPING  = .FALSE.   ! array
            END IF

            ALLOCATE( LFRAC1L( NSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'LFRAC1L', PROGNAME )

            MESG = 'Reading layer fractions...'
            CALL M3MSG2( MESG )

            JDATE = SDATE
            JTIME = STIME
            DO T = 1, NSTEPS

                IF( READ3( LNAME, 'LFRAC', 1,
     &                     JDATE, JTIME, LFRAC1L ) ) THEN
                    DO S = 1, NSRC
                        IF( LFRAC1L( S ) .LT. 1. ) LMAJOR( S ) = .TRUE.
                    END DO

                ELSE  !  Read failed
                    MESG = 'Could not read "LFRAC" from '// LNAME
                    CALL M3EXIT( PROGNAME, JDATE, JTIME, MESG, 2 )

                END IF

                CALL NEXTIME( JDATE, JTIME, TSTEP )

            END DO

        END IF

C.........  Reformat source characteristics and set widths.  Do this once
C           for the entire run of the program, so that it doesn't have to be
C           done for each report (it is slow)

        IF( ANY_TRUE( NREPORT, ALLRPT%BYSRC  ) .OR.
     &      ANY_TRUE( NREPORT, ALLRPT%BYPLANT )    ) THEN

C.............  Determine width of source chararactistic columns over the
C               whole inventory
            SWIDTH = 0   ! initialize array
            DO S = 1, NSRC

                K = 0
                DO J = MINC, NCHARS

                    K  = K + 1
                    L1 = SC_BEGP( J )
                    L2 = SC_ENDP( J )
                    BUFFER = ADJUSTL( CSOURC( S )( L1:L2 ) )
                    SWIDTH( K ) = MAX( SWIDTH( K ), LEN_TRIM( BUFFER ) )

                END DO

            END DO

C.............  Reset CSOURC based on these widths
C.............  Also remove SCC from the source characteristics
            DO S = 1, NSRC

                CSRC = CSOURC( S )

                L = SC_ENDP( MINC-1 ) 
                K  = 0
                DO J = MINC, NCHARS

                    K = K + 1
                    IF( J .NE. JSCC ) THEN
                        L1 = SC_BEGP( J )
                        L2 = SC_ENDP( J )
                        CSOURC( S ) = CSOURC( S )( 1:L ) //
     &                                ADJUSTL( CSRC( L1:L2 ) )
                        L = L + SWIDTH( K )
                    END IF

                END DO

            END DO

C.............  Allocate and initialize arrays for storing new field lengths
            ALLOCATE( LOC_BEGP( NCHARS ), STAT=IOS )
            CALL CHECKMEM( IOS, 'LOC_BEGP', PROGNAME )
            ALLOCATE( LOC_ENDP( NCHARS ), STAT=IOS )
            CALL CHECKMEM( IOS, 'LOC_ENDP', PROGNAME )
            LOC_BEGP = SC_BEGP   ! array
            LOC_ENDP = SC_ENDP   ! array

C.............  Set local start and end fields based on new widths
            K = 0
            DO J = MINC, NCHARS
                K = K + 1
                IF( J .EQ. JSCC ) CYCLE
                LOC_BEGP( J ) = LOC_ENDP( J-1 ) + 1
                LOC_ENDP( J ) = LOC_BEGP( J ) + SWIDTH( K ) - 1
            END DO

            IF( JSCC .GT. 0 ) NCHARS = NCHARS - 1

        END IF

C.........  Exit if any errors encountered
        IF( EFLAG ) THEN
            MESG = 'Problem(s) reading input files.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Deallocate local memory
        IF( ALLOCATED( LFRAC1L ) ) DEALLOCATE( LFRAC1L )

        RETURN

999     MESG = 'Unexpected end of file reached while reading ' //
     &         'supplementary gridding file.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 ) 

1001    MESG = 'Unexpected end of file reached while reading ' //
     &         'supplementary speciation file.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 ) 

1003    MESG = 'Unexpected end of file reached while reading ' //
     &         'supplementary temporal file.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 ) 

9001    MESG = 'Unexpected end of file reached while reading ' //
     &         'projection report file.'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 ) 

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I10, :, 1X ) )

C******************  INTERNAL SUBPROGRAMS  *****************************
 
        CONTAINS
 
C.............  This internal function scans a logical array for any
C               true values, and if it finds one, returns true.
            LOGICAL FUNCTION ANY_TRUE( NDIM, LOGARR )

C.............  Subprogram arguments
            INTEGER, INTENT (IN) :: NDIM
            LOGICAL, INTENT (IN) :: LOGARR( NDIM )

C.............  Local variables
            INTEGER   I

C----------------------------------------------------------------------

            ANY_TRUE = .FALSE.

            DO I = 1, NDIM

                IF( LOGARR( I ) ) THEN
                    ANY_TRUE = .TRUE.
                    RETURN
                END IF

            END DO

            RETURN
 
            END FUNCTION ANY_TRUE

C----------------------------------------------------------------------
C----------------------------------------------------------------------

C.............  This internal function scans a character array for any
C               non-blank values, and if it finds one, returns true.
            LOGICAL FUNCTION ANY_CVAL( NDIM, CHARARR )

C.............  Subprogram arguments
            INTEGER     , INTENT (IN) :: NDIM
            CHARACTER(*), INTENT (IN) :: CHARARR( NDIM )

C.............  Local variables
            INTEGER   I

C----------------------------------------------------------------------

            ANY_CVAL = .FALSE.

            DO I = 1, NDIM

                IF( CHARARR( I ) .NE. ' ' ) THEN
                    ANY_CVAL = .TRUE.
                    RETURN
                END IF

            END DO

            RETURN
 
            END FUNCTION ANY_CVAL

        END SUBROUTINE RDREPIN

