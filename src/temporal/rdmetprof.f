
        SUBROUTINE RDMETPROF( PNAME ) 

C***********************************************************************
C  function body starts at line 
C
C  DESCRIPTION:
C      Reads the input temporal profiles generated by Gentpro utility program
C
C  PRECONDITIONS REQUIRED:
C       this segment of the input file sorted
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C       
C
C  REVISION  HISTORY:
C       Created by B.H. Baek   7/2011
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C****************************************************************************

C.........  MODULES for public variables
C.........  For temporal profiles
        USE MODTMPRL, ONLY: METFACS, NMETPROF, METPROF, METPRFFLAG, METPRFTYPE

        IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'PARMS3.EXT'    !  i/o api parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C..........  EXTERNAL FUNCTIONS
        LOGICAL         BLKORCMT
        CHARACTER(2)    CRLF
        INTEGER         STR2INT, FINDC, GETFLINE, PROMPTFFILE
        REAL            STR2REAL
        CHARACTER(16)   PROMPTMFILE

        EXTERNAL        BLKORCMT, CRLF, STR2INT, FINDC, GETFLINE,
     &                  PROMPTFFILE, PROMPTMFILE, STR2REAL

C.........  SUBROUTINE ARGUMENTS
        CHARACTER(*), INTENT   (OUT) :: PNAME ! hour-spec file

C...........   Local parameters
        INTEGER, PARAMETER :: MXCOL = 35
        
C.........  Local, sorted temporal profile codes
        CHARACTER( 15 )         SEGMENT( MXCOL )

C...........   SCRATCH LOCAL VARIABLES and their descriptions:
        INTEGER         I, J, K, L, N    !  counters and indices

        INTEGER         IOS           ! i/o status
        INTEGER         IREC          ! no of records
        INTEGER         NFAC          ! tmp number of factors per profile
        INTEGER         NPROF         ! actual number of profiles
        INTEGER         NLINES        ! number of lines of input file
        INTEGER      :: DDEV = 0      ! temporary profile file open
        
        LOGICAL      :: EFLAG  = .FALSE.  !  input error flag

        CHARACTER(525)     LINE        !  line buffer
        CHARACTER(300)     MESG        !  message buffer
        CHARACTER(8)       PROFTYPE    !  'MONTHLY', 'DAILY', 'HOURLY'

        CHARACTER(16) :: PROGNAME = 'RDMETPROF' ! program name

C***********************************************************************
C   begin body of subroutine  RDTPROF

C.........  Determine Met-based temporal profile resolution
        PROFTYPE = METPRFTYPE 

C.........  If profile type is monthly,
        IF( PROFTYPE .EQ. 'MONTHLY' ) THEN

C.............  Open and read Met-based Temporal profiles
            DDEV = PROMPTFFILE(
     &           'Enter logical name for Met-based MONTHLY temporal profile file',
     &           .TRUE., .TRUE., 'TPRO_MON', PROGNAME )

C.........  If profile type is Daily
        ELSE IF( PROFTYPE .EQ. 'DAILY' ) THEN

C.............  Open and read Met-based Temporal profiles
            DDEV = PROMPTFFILE(
     &           'Enter logical name for Met-based DAILY temporal profile file',
     &           .TRUE., .TRUE., 'TPRO_DAY', PROGNAME )

C.........  If profile type is HOURLY, return
        ELSE IF( PROFTYPE .EQ. 'HOURLY' ) THEN
  
C.............  Open and read met-based hourly temporal profiles
            PNAME = PROMPTMFILE(
     &               'Enter logical name for Met-based HOURLY temporal profile file',
     &               FSREAD3, 'TPRO_HOUR', PROGNAME )

C.............  Get header description of hour-specific temporal profile input file
            IF( .NOT. DESC3( PNAME ) ) THEN
                CALL M3EXIT( PROGNAME, 0, 0,
     &                       'Could not get description of file "'
     &                       // PNAME( 1:LEN_TRIM( PNAME ) ) // '"', 2 )
            END IF

C.............  Allocate memory for temporal profile ID and values
C               NROWS3D contains no of sources in Hourly profiles created by Gentpro program
C               No need to allocate 3d memory but 2d memory since HOUR NCF file contains
C               FIPS,hr of month, hr of year and hr of day factors.
C               METPROF will hold FIPS variable
            NMETPROF = NROWS3D

            ALLOCATE( METPROF( NMETPROF ), STAT=IOS )
            CALL CHECKMEM( IOS, 'METPROF', PROGNAME )
            ALLOCATE( METFACS( NMETPROF, 1, 1 ), STAT=IOS )
            CALL CHECKMEM( IOS, 'METFACS', PROGNAME )

            METPROF = 0
            METFACS = 0.0

            RETURN
        ELSE

C............. Skip processing of Met-based Temporal Profiles file..
            RETURN

        END IF

C.........  Write status message
        MESG = 'Reading Met-based Temporal Profiles file...'
        CALL M3MSG2( MESG )

C.........  Get the number of lines in the file
        NLINES = GETFLINE( DDEV, 'Met-based temporal profiles file' )

C.........  Read and store temporal profiles
C           Process monthly or daily temporal profiles

C.........  Initialize character strings
        SEGMENT = ' '  ! array

C.........  Read lines and store unsorted data for the source category of
C           interest
        IREC   = 0
        J = 0
        N = 0
        DO I = 1, NLINES

            READ( DDEV, 93000, IOSTAT=IOS ) LINE
            IREC = IREC + 1

            IF ( IOS .NE. 0 ) THEN
                 WRITE( MESG,94010 )
     &             'I/O error', IOS,'reading tagging file at line', IREC
                 CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Determine no of profiles
C.............  Allocate local array to store temporal profiles
            IF( INDEX( LINE,'NUM_PROFILES' ) > 0 ) THEN
                L = INDEX( LINE,'=' )
                NPROF =  STR2INT( LINE( L+1: ) )

                NMETPROF = NPROF

                ALLOCATE( METPROF( NPROF ), STAT=IOS )
                CALL CHECKMEM( IOS, 'METPROF', PROGNAME )
                ALLOCATE( METFACS( NPROF, 12, 31 ), STAT=IOS )
                CALL CHECKMEM( IOS, 'METFACS', PROGNAME )

                METPROF = 0
                METFACS = 0.0
                    
            END IF    

C.............  Skip blank lines or comments
            IF( BLKORCMT( LINE ) ) CYCLE

C.............  Parse line
            CALL PARSLINE( LINE, MXCOL, SEGMENT )

C.............  Check header line to determine no of profiles in file
            IF( NPROF <= 0 ) THEN
                MESG = 'ERROR: Missing #NUM_PROFILES header line '//
     &                 ' in the '// PROFTYPE // ' temporal input file'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C.............  Count no of profiles
            N = N + 1
        
C.............  Define no of profiles based on profile type
            IF( PROFTYPE == 'MONTHLY' ) THEN

                J = N
C.....................  Store monthly temporal profiles
                DO K = 1, 12
                    METPROF( J ) = STR2INT( SEGMENT( 1 ) )
                    METFACS( J,K,: ) = STR2REAL ( SEGMENT( K+1 ) )
                END DO

            ELSE   ! if it is DAILY profiles

                J = MOD( N , NPROF )
                K = INT( N / NPROF ) + 1

                IF( J == 0 ) THEN
                    J = NPROF
                    K = INT( N / NPROF )
                END IF

                DO L = 1, 31
                    METPROF( J ) = STR2INT( SEGMENT( 1 ) )
                    METFACS( J,K,L ) = STR2REAL ( SEGMENT( L+2 ) )
                END DO

            END IF

        END DO

        RETURN

C******************  FORMAT  STATEMENTS   ******************************
C...........   Formatted file I/O formats............ 93xxx
93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx
94010   FORMAT( 10 ( A, :, I8, :, 1X ) )

        END SUBROUTINE RDMETPROF

