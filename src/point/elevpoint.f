
        PROGRAM ELEVPOINT

C***********************************************************************
C  program body starts at line 
C
C  DESCRIPTION:
C       Identifies sources as elevated (major or plume-in-grid) or minor.
C       Major sources will get plume rise and minor sources will not, however,
C       the major/minor distinction is not required because SMOKE will compute
C       layer fractions for all sources efficiently when needed.  If desired,
C       the program can use an analytical computation (the PLUMRIS routine)
C       along with a cutoff height to determine the major sources.
C
C       NOTE - The initial version uses input files to identify the sources
C       or can use the PLUMERIS and cutoff height.  Future versions will
C       permit more flexible run-time identification of major and plume-in-grid
C       sources based on source characteristics and hourly emissions.
C       
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C       Copied from elevpoint.F 4.2 by M Houyoux
C
C************************************************************************
C  
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C  
C COPYRIGHT (C) 1999, MCNC--North Carolina Supercomputing Center
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
C Last updated: %G 
C  
C***********************************************************************

C...........   MODULES for public variables
C...........   This module is the source inventory arrays
        USE MODSOURC

C.........  This module contains arrays for plume-in-grid and major sources
        USE MODELEV

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES:
        
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters
        INCLUDE 'CONST3.EXT'    !  physical and mathematical constants
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptions:

        CHARACTER*2     CRLF
        LOGICAL         DSCM3GRD
        INTEGER         ENVINT
        LOGICAL         ENVYN
        INTEGER         FIND1
        INTEGER         FINDC
        INTEGER         GETFLINE
        REAL            PLUMRIS
        INTEGER         PROMPTFFILE
        CHARACTER*16    PROMPTMFILE

        EXTERNAL        CRLF, DSCM3GRD, ENVINT, ENVYN, FIND1, FINDC, 
     &                  GETFLINE, PLUMRIS, PROMPTFFILE, PROMPTMFILE

C...........  LOCAL PARAMETERS and their descriptions:
        CHARACTER*50, PARAMETER :: SCCSW = '@(#)$Id$'

C...........   Indicator for which public inventory arrays need to be read
        INTEGER               , PARAMETER :: NINVARR = 9
        CHARACTER(LEN=IOVLEN3), PARAMETER :: IVARNAMS( NINVARR ) = 
     &                                 ( / 'IFIP           '
     &                                   , 'XLOCA          '
     &                                   , 'YLOCA          '
     &                                   , 'STKHT          '
     &                                   , 'STKDM          '
     &                                   , 'STKTK          '
     &                                   , 'STKVE          '
     &                                   , 'CSCC           '
     &                                   , 'CSOURC         ' / )

C...........   Allocateable arrays for using GENPTCEL routine to get grid-cell
C              numbers based on current projection
        INTEGER, ALLOCATABLE :: INDX ( : )  ! sorting index (unused)
        INTEGER, ALLOCATABLE :: GN   ( : )  ! cell numbers
        INTEGER, ALLOCATABLE :: SN   ( : )  ! stack group pos in list (unused)
        INTEGER, ALLOCATABLE :: NX   ( : )  ! no. stack groups per cell (unused)

C...........   Allocatable arrays for reading in stack splits def'n file
        INTEGER, ALLOCATABLE :: SPTINDX ( : )  ! sorting index
        INTEGER, ALLOCATABLE :: SPTGIDA( : )  ! unsorted stack group ID

        LOGICAL, ALLOCATABLE :: SPTMMSA( : )  ! true: Major stack (unsorted)
        LOGICAL, ALLOCATABLE :: SPTMPSA( : )  ! true: PinG stack (unsorted)
        LOGICAL, ALLOCATABLE :: FOUND  ( : )  ! true: entry found in inven

        CHARACTER(LEN=ALLLEN3), ALLOCATABLE :: SPTCSRCA( : ) ! src info (unsrt)
        CHARACTER(LEN=ALLLEN3), ALLOCATABLE :: SPTCSRC ( : ) ! src info (sorted)

C...........   File units and logical/physical names
        INTEGER         GDEV    !  stack groups file
        INTEGER         LDEV    !  log-device
        INTEGER         PDEV    !  for output major/mepse src ID file
        INTEGER         SDEV    !  ASCII part of inventory unit no.
        INTEGER         TDEV    !  stack splits file

        CHARACTER*16    ANAME   !  logical name for ASCII inventory input file
        CHARACTER*16    ENAME   !  logical name for i/o api inventory input file
        CHARACTER*16    MNAME   !  plume-in-grid srcs stack groups output file

C...........   Other local variables
        INTEGER         I, J, K, S, L, L2      ! indices and counters

        INTEGER         COID          ! tmp country ID
        INTEGER         COL           ! tmp column number
        INTEGER         CYID          ! tmp county ID
        INTEGER         ENLEN         ! inventory file name length
        INTEGER         FIP           ! tmp FIPS code
        INTEGER         GID           ! tmp group ID
        INTEGER         IOS           ! i/o status
        INTEGER         IOSCUT        ! i/o status for cutoff E.V.
        INTEGER         IREC          ! record counter
        INTEGER         NCOLS         ! no. grid column
        INTEGER         NEXCLD        ! no. stack groups exlcuded from the grid
        INTEGER         NGRID         ! no. grid cells
        INTEGER         NROWS         ! no. grid rows
        INTEGER         NGLINES       ! no. lines in stack group file
        INTEGER      :: NMAJOR = 0    ! no. major sources
        INTEGER         NPG           ! tmp number per group
        INTEGER      :: NPING  = 0    ! no. plume-in-grid sources
        INTEGER         NSLINES       ! no. lines in stack splits file
        INTEGER         NSTEPS        ! no. time steps
        INTEGER         MS            ! tmp src ID for major sources
        INTEGER         PS            ! tmp src ID for plume in grid sources
        INTEGER         ROW           ! tmp row number
        INTEGER         STID          ! tmp state ID
        INTEGER         SDATE         ! Julian start date
        INTEGER         STIME         ! start time
        INTEGER         TZONE         ! output time zone

        REAL            CUTOFF        ! plume rise cutoff for elev pts
        REAL            DM            ! tmp inside stack diameter [m]
        REAL            FL            ! tmp stack exit flow rate [m^3/s]
        REAL            HT            ! tmp inside stack diameter [m]
        REAL            LAT           ! tmp latitude [degrees]
        REAL            LON           ! tmp longitude [degrees]
        REAL            RISE          ! calculated plume rise
        REAL            TK            ! tmp stack exit temperature [K]
        REAL            VE            ! tmp stack exit velocity diameter [m/s]

        LOGICAL :: CFLAG    = .FALSE. ! true: convert from English to metric
        LOGICAL :: EFLAG    = .FALSE. ! true: error detected
        LOGICAL :: MAJRFLAG = .FALSE. ! true: use major/minor specifier
        LOGICAL :: PINGFLAG = .FALSE. ! true: output for plume-in-grid
        LOGICAL :: WFLAG    = .FALSE. ! true: convert lon to western

        CHARACTER*1     CSWITCH1  ! major/minor (TDEV) or PinG switch (GDEV)
        CHARACTER*1     CSWITCH2  ! PinG switch       
        CHARACTER*8     FMTFIP    ! format for writing co/st/cy code
        CHARACTER*80    GDESC               !  grid description
        CHARACTER*300   BUFFER
        CHARACTER*300   MESG

        CHARACTER(LEN=FIPLEN3) CFIP     !  char FIPS code
        CHARACTER(LEN=IOVLEN3) COORD3D  !  coordinate system name
        CHARACTER(LEN=IOVLEN3) COORUN3D !  coordinate system units 
        CHARACTER(LEN=ALLLEN3) CSRC     !  buffer for source char, incl pol/act
        CHARACTER(LEN=CHRLEN3) CHAR1    !  tmp plant characteristic 1
        CHARACTER(LEN=CHRLEN3) CHAR2    !  tmp plant charactersitic 2
        CHARACTER(LEN=PLTLEN3) PLT      !  tmp plant ID

        CHARACTER*16 :: PROGNAME = 'ELEVPOINT'   !  program name

C***********************************************************************
C   begin body of program ELEVPOINT

        LDEV = INIT3()

C.........  Write out copywrite, version, web address, header info, and prompt
C           to continue running the program.
        CALL INITEM( LDEV, SCCSW, PROGNAME )

C.........  Get environment variables that control this program
        MESG = 'Plume height elevated source cutoff [m]'
        CUTOFF = ENVINT( 'SMK_CUTOFF_HT', MESG, 75., IOSCUT )

        MESG = 'Indicator for create plume-in-grid outputs'
        PINGFLAG = ENVYN( 'SMK_PING_YN', MESG, .FALSE., IOS )

        MESG = 'Indicator for defining major/minor sources'
        MAJRFLAG = ENVYN( 'SMK_SPECELEV_YN', MESG, .FALSE., IOS )

        MESG = 'Indicator for converting all longitudes to Western'
        WFLAG = ENVYN( 'WEST_HSPHERE', MESG, .TRUE., IOS )

        MESG = 'Indicator for English to metric units conversion'
        CFLAG = ENVYN( 'SMK_ENG2METRIC_YN', MESG, .FALSE., IOS )

C.........  Resolve e.v. setting dependencies
        IF( PINGFLAG ) MAJRFLAG = .TRUE.

C.........  Set source category based on environment variable setting
        CALL GETCTGRY

C.........  Get inventory file names given source category
        CALL GETINAME( CATEGORY, ENAME, ANAME )

C.........  Make sure only run for point sources
        IF( CATEGORY .NE. 'POINT' ) THEN
            MESG = 'ERROR: ' // PROGNAME( 1:LEN_TRIM( PROGNAME ) ) //
     &             ' is not valid for ' // CATEGORY( 1:CATLEN ) // 
     &             ' sources'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Create format for country/state/county code
        WRITE( FMTFIP, 94300 ) '(I', FIPLEN3, '.', FIPLEN3, ')'

C.......   Get file name; open input point source and output
C.......   elevated points files; get plume-rise cutoff for
C.......   elevated points file

C.........   Get file names and open inventory files
        ENAME = PROMPTMFILE( 
     &          'Enter logical name for the I/O API INVENTORY file',
     &          FSREAD3, ENAME, PROGNAME )
        ENLEN = LEN_TRIM( ENAME )

        SDEV = PROMPTFFILE( 
     &         'Enter logical name for the ASCII INVENTORY file',
     &         .TRUE., .TRUE., ANAME, PROGNAME )

C.........  For plume-in-grid inputs, get input file
        IF( PINGFLAG ) THEN
            GDEV = PROMPTFFILE( 
     &         'Enter logical name for the STACK SPLIT GROUPS file',
     &         .TRUE., .TRUE., CRL // 'GROUP', PROGNAME )
        END IF

C.........  For plume-in-grid or major/minor inputs, get input file
        IF( MAJRFLAG ) THEN
            TDEV = PROMPTFFILE( 
     &         'Enter logical name for the STACK SPLIT DEFINITION file',
     &         .TRUE., .TRUE., CRL // 'SPLIT', PROGNAME )
        END IF

C.........  Get header description of inventory file, error if problem
        IF( .NOT. DESC3( ENAME ) ) THEN
            MESG = 'Could not get description of file "' //
     &             ENAME( 1:ENLEN ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Otherwise, store source-category-specific header information, 
C           including the inventory pollutants in the file (if any).  Note that 
C           the I/O API head info is passed by include file and the
C           results are stored in module MODINFO.
        ELSE

            CALL GETSINFO

        END IF

C.........  Get episode information for setting date and time of STACK_PING file
        MESG = 'NOTE: Getting date/time information for use in ' //
     &         'STACK_PING file'
        CALL M3MSG2( MESG )

        CALL GETM3EPI( -9, SDATE, STIME, -9 )

C.........  Allocate memory for and read in required inventory characteristics
        CALL RDINVCHR( CATEGORY, ENAME, SDEV, NSRC, NINVARR, IVARNAMS )

C.........  Allocate memory for source status arrays and group numbers
        ALLOCATE( LMAJOR( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LMAJOR', PROGNAME )
        ALLOCATE( LPING( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LPING', PROGNAME )
        ALLOCATE( GROUPID( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GROUPID', PROGNAME )

C.........  Initialize source status and group number arrays
        LMAJOR  = .FALSE.   ! array
        LPING   = .FALSE.   ! array
        GROUPID = 0         ! array

C.........  If using plume-and-grid inputs, allocate memory and read in 
C           stack groups file
        IF( PINGFLAG ) THEN

C.............  Get grid description for converting the stack group coordinates
            IF( .NOT. DSCM3GRD( 
     &                GDNAM3D, GDESC, COORD3D, GDTYP3D, COORUN3D,
     &                P_ALP3D, P_BET3D, P_GAM3D, XCENT3D, YCENT3D,
     &                XORIG3D, YORIG3D, XCELL3D, YCELL3D,
     &                NCOLS3D, NROWS3D, NTHIK3D ) ) THEN

        	MESG = 'Could not get Models-3 grid description.'
        	CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

            ELSE
                NCOLS = NCOLS3D
                NROWS = NROWS3D
                NGRID = NCOLS * NROWS

            END IF            

C.............  Get the number of lines in the stack groups file
            NGLINES = GETFLINE( GDEV, 'Stack groups' )

C.............  Scan the groups file to determine the number of PinG groups
            DO I = 1, NGLINES

                READ( GDEV, 93500, IOSTAT=IOS, END=999 ) 
     &                GID, CSWITCH1
                IREC = IREC + 1

C.................  Check read error status
        	IF( IOS .GT. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'I/O error', IOS, 
     &                 'reading stack groups file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
        	END IF

                IF( CSWITCH1 .NE. ' ' ) NGROUP = NGROUP + 1

            END DO

            REWIND( GDEV )

C.............  Allocate memory for stack groups and splits files based on the
C               number of lines
            ALLOCATE( GRPIDX( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPIDX', PROGNAME )
            ALLOCATE( GRPGIDA( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPGIDA', PROGNAME )
            ALLOCATE( GRPGID( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPGID', PROGNAME )
            ALLOCATE( GRPLAT( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPLAT', PROGNAME )
            ALLOCATE( GRPLON( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPLON', PROGNAME )
            ALLOCATE( GRPDM( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPDM', PROGNAME )
            ALLOCATE( GRPHT( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPHT', PROGNAME )
            ALLOCATE( GRPTK ( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPTK', PROGNAME )
            ALLOCATE( GRPVE( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPVE', PROGNAME )
            ALLOCATE( GRPFL( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPFL', PROGNAME )
            ALLOCATE( GRPCNT( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPCNT', PROGNAME )
            ALLOCATE( GRPCOL( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPCOL', PROGNAME )
            ALLOCATE( GRPROW( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPROW', PROGNAME )
            ALLOCATE( GRPXL( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPXL', PROGNAME )
            ALLOCATE( GRPYL( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GRPYL', PROGNAME )
            ALLOCATE( INDX( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'INDX', PROGNAME )
            ALLOCATE( GN( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'GN', PROGNAME )
            ALLOCATE( SN( NGROUP ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SN', PROGNAME )

C.............  Allocate memory so that we can use the GENPTCEL
            ALLOCATE( NX( NGRID ), STAT=IOS )
            CALL CHECKMEM( IOS, 'NX', PROGNAME )

            MESG = 'Reading stack split groups file...'
            CALL M3MSG2( MESG )

            IF( CFLAG ) THEN
                MESG = 'NOTE: Converting stack parameters from ' //
     &                 'English to metric units'
        	CALL M3MSG2( MESG )
            END IF

C.............  Read stack groups file
            IREC = 0
            J    = 0
            DO I = 1, NGLINES

                READ( GDEV, 93500, IOSTAT=IOS, END=999 ) 
     &                GID, CSWITCH1, NPG, LON, LAT, DM, HT, TK, VE, FL
                IREC = IREC + 1

C.................  Check read error status
        	IF( IOS .GT. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'I/O error', IOS, 
     &                 'reading stack groups file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
        	END IF

C.................  Skip entry if not a plume-in-grid source
                IF( CSWITCH1 .EQ. ' ' ) CYCLE

C.................  Convert longitude to western hemisphere if needed
                IF( WFLAG .AND. LON .GT. 0 ) LON = -LON

C.................  Convert from English to metric, if needed...
                IF( CFLAG ) THEN
                    DM = DM * FT2M
                    HT = HT * FT2M
                    TK = ( TK - 32. ) * FTOC + CTOK
                    VE = VE * FT2M
                    FL = FL * FLWE2M
                END IF

C.................  When flow is not defined, set it with the vel & diam
                IF( FL .LE. 0. .AND. VE .GT. 0. ) THEN
                   FL = VE * PI * ( 0.25 * DM * DM )
                END IF

C.................  Store data
                J = J + 1
                IF( J .LE. NGROUP ) THEN
                    GRPIDX ( J ) = J
                    GRPGIDA( J ) = GID
                    GRPCNT ( J ) = NPG 
                    GRPLON ( J ) = LON
                    GRPXL  ( J ) = LON
                    GRPLAT ( J ) = LAT
                    GRPYL  ( J ) = LAT
                    GRPDM  ( J ) = DM
                    GRPHT  ( J ) = HT
                    GRPTK  ( J ) = TK
                    GRPVE  ( J ) = VE
                    GRPFL  ( J ) = FL
                END IF

            END DO    ! End loop on input file lines

C.............  Abort if overflow
            IF( J .GT. NGROUP ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &                  'INTERNAL ERROR: Number of stack groups ' //
     &                  'J=', J, 
     &                  'exceeds dimension NGROUP=', NGROUP
                CALL M3MSG2( MESG ) 

C.............  Otherwise, process the stack group coordinates for the
C               current grid
            ELSE

C.................  Convert x,y location to coordinates of the projected grid
                CALL CONVRTXY( NGROUP, GDTYP3D, P_ALP3D, P_BET3D, 
     &                         P_GAM3D, XCENT3D, YCENT3D, GRPXL, GRPYL )

C.................  Determine grid cells for these coordinate locations
                CALL GENPTCEL( NGROUP, NGRID, GRPXL, GRPYL, NEXCLD, NX, 
     &                         INDX, GN, SN )

C.................  Convert grid cells to row and columns numbers
                DO I = 1, NGROUP

                   ROW = 0
                   COL = 0

                   IF( GN( I ) .GT. 0 ) THEN
                       ROW = ( GN( I ) / NCOLS ) + 1      ! note: integer math
                       COL = GN( I ) - ( ROW-1 ) * NCOLS
                   END IF

                   GRPROW( I ) = ROW
                   GRPCOL( I ) = COL

                END DO

            END IF

C.............  Give warning if any plume-in-grid stack groups are outside the
C               grid
            IF( NEXCLD .GT. 0 ) THEN
                WRITE( MESG,94010 ) 'WARNING: ', NEXCLD, 'stack ' //
     &                 'groups are outside of grid "' // 
     &                 GDNAM3D( 1:LEN_TRIM( GDNAM3D ) )
                CALL M3MSG2( MESG )
            END IF

C.............  Sort stack group information
            CALL SORTI1( NGROUP, GRPIDX, GRPGIDA )

C.............  Store sorted stack groups for lookups in reading stack splits 
C               file
            DO I = 1, NGROUP
                GRPGID( I ) = GRPGIDA( GRPIDX( I ) )
            END DO

        END IF   ! End if plume-in-grid

C.........  If major/minor definitions are to be used...
        IF( MAJRFLAG ) THEN

C.............  Allocate memory for reading stack splits file
            NSLINES = GETFLINE( TDEV, 'Stack splits' )

            ALLOCATE( SPTINDX( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTINDX', PROGNAME )
            ALLOCATE( SPTGIDA( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTGIDA', PROGNAME )
            ALLOCATE( SPTMMSA( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTMMSA', PROGNAME )
            ALLOCATE( SPTMPSA( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTMPSA', PROGNAME )
            ALLOCATE( SPTCSRCA( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTCSRCA', PROGNAME )
            ALLOCATE( SPTCSRC( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'SPTCSRC', PROGNAME )
            ALLOCATE( FOUND  ( NSLINES ), STAT=IOS )
            CALL CHECKMEM( IOS, 'FOUND', PROGNAME )

C.............  Initialize status of PSPLIT entries found in inventory
            FOUND = .FALSE.    ! array 
        
            MESG = 'Reading stack splits file...'
            CALL M3MSG2( MESG )

C.............  Read stack splits file
            IREC = 0
            DO I = 1, NSLINES

                READ( TDEV, 93550, IOSTAT=IOS, END=999 ) 
     &                GID, CSWITCH1, CSWITCH2, COID, STID, CYID, PLT,
     &                CHAR1, CHAR2
                IREC = IREC + 1

C.................  Check read error status
        	IF( IOS .GT. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 'I/O error', IOS, 
     &                 'reading stack splits file at line', IREC
                    CALL M3MESG( MESG )
                    CYCLE
        	END IF

C.................  Store contents of splits file entry
                SPTGIDA( I ) = GID
                SPTMMSA( I ) = ( CSWITCH1 .NE. ' ' )
                SPTMPSA( I ) = ( CSWITCH2 .NE. ' ' )

                FIP = COID * 100000 + STID * 1000 + CYID
                WRITE( CFIP, FMTFIP ) FIP

                CSRC = ' '
                CALL BLDCSRC( CFIP, PLT, CHAR1, CHAR2, CHRBLNK3,
     &                        CHRBLNK3, CHRBLNK3, POLBLNK3, CSRC )

                SPTCSRCA( I ) = CSRC
                SPTINDX  ( I ) = I

            END DO    ! End loop on input file lines

            MESG = 'Processing splits data with inventory...'
            CALL M3MSG2( MESG )

C.............  Sort splits file source characteristics
            CALL SORTIC( NSLINES, SPTINDX, SPTCSRCA ) 

C.............  Store sorted splits file source characteristics for searching
            DO I = 1, NSLINES
                J = SPTINDX( I )
                SPTCSRC( I ) = SPTCSRCA( J )
            END DO

C.............  Loop through sources and match with records in splits file.
C.............  Flag and sources as major or plume-in-grid, and store group 
C               number for plume-in-grid sources
            DO S = 1, NSRC

                CSRC = CSOURC( S )( 1:PTENDL3( 4 ) )
                I = FINDC( CSRC, NSLINES, SPTCSRC )

                IF( I .LE. 0 ) THEN
                    CSRC = CSOURC( S )( 1:PTENDL3( 3 ) )
                    I = FINDC( CSRC, NSLINES, SPTCSRC )
                END IF

                IF( I .GT. 0 ) THEN
                    J = SPTINDX( I )
                    FOUND  ( I ) = .TRUE.
                    GROUPID( S ) = SPTGIDA( J )

C.....................  Find group ID in stack groups file to make sure that
C                       output is desired for this group
                    GID = SPTGIDA( J )
                    K = FIND1( GID, NGROUP, GRPGID )

C.....................  Skip source if stack group is not in stack group file
                    IF( K .LE. 0 ) CYCLE

C.....................  Store per-source major and PinG source info
                    LMAJOR ( S ) = SPTMMSA( J )
                    LPING  ( S ) = ( PINGFLAG .AND. SPTMPSA( J ) )

                    IF( LPING( S ) ) THEN
                        NPING  = NPING  + 1
                    ELSE IF( LMAJOR( S ) ) THEN
                        NMAJOR = NMAJOR + 1
                    END IF

                END IF

            END DO

C.............  Give warnings if any entries in the SPLITS file are not in the
C               inventory
            DO I = 1, NSLINES

                IF( .NOT. FOUND( I ) ) THEN

                    CSRC = SPTCSRCA( I )
                    CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                    MESG = 'WARNING: Entry from PSPLIT not found ' //
     &                     'in inventory:' // CRLF() // BLANK10 // 
     &                     BUFFER( 1:L2 )              
                    CALL M3MESG( MESG )

                END IF

            END DO

        END IF  ! End of section for major/minor split file input

C.........  If there are no stack groups or stack splits files...
        IF( .NOT. MAJRFLAG ) THEN

C.............  Write note indicating what cutoff is being used and whether
C               this is a default value
            MESG = 'Computing plume rise and comparing to cutoff...'
            CALL M3MSG2( MESG )

            IF( IOSCUT .LT. 0 ) THEN
                WRITE( MESG,94020 ) 'Using default cutoff of', 
     &                              CUTOFF, '[m]'
            ELSE
                WRITE( MESG,94020 ) 'Using user-defined cutoff of', 
     &                              CUTOFF, '[m]'
            END IF
            CALL M3MSG2( MESG )

C.............  Process the stacks to determine elevated sources
            EFLAG = .FALSE.
            DO S = 1, NSRC

C.................  Check stack parameters so PLUMRIS doesn't blow up
C.................  If parameters are bad, skip plume rise calculation
                IF( STKHT( S ) .LT. 0. .OR. 
     &              STKTK( S ) .LE. 0. .OR.
     &              STKVE( S ) .LE. 0. .OR.
     &              STKDM( S ) .LE. 0.      ) THEN

                    EFLAG = .TRUE.
                    CALL FMTCSRC( CSRC, NCHARS, BUFFER, L2 )

                    WRITE( MESG,94030 ) STKHT( S ), STKDM( S ),
     &                                  STKTK( S ), STKVE( S )
                    L = LEN_TRIM( MESG )
                    MESG = 'ERROR: Invalid stack parameters for:' //
     &                     CRLF() // BLANK10 // 
     &                     BUFFER( 1:L2 )// ' with'// CRLF()// BLANK10//
     &                     MESG( 1:L )                
                    CALL M3MESG( MESG )

C.................  When stack parameters are okay...
                ELSE

C.....................  Calculate estimated plume rise
                    RISE = PLUMRIS( STKHT( S ), STKTK( S ), 
     &                              STKVE( S ), STKDM( S ) )

C.....................  Identify sources as major when the plume rise is
C                       greater than the cutoff
                    IF( RISE .GT. CUTOFF ) THEN

                	NMAJOR = NMAJOR + 1
                	LMAJOR ( S ) = .TRUE.

                    END IF    ! if rise > cutoff

                END IF        ! end bad stack parms or not
            END DO            ! end loop on sources S
        END IF                ! end groups/splits file or not

C.........  Abort if an error occurred
        IF( EFLAG ) THEN
            MESG = 'Problem selecting major/plume-in-grid sources'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.........  Write status of processing
        IF( NGROUP .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of plume-in-grid source ' //
     &             '(MEPSE) groups:', NGROUP
            CALL M3MSG2( MESG )
        END IF

        IF( NMAJOR .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of major sources:', NMAJOR
            CALL M3MSG2( MESG )
        END IF

        IF( NPING .GT. 0 ) THEN
            WRITE( MESG,94010 ) 'Number of plume-in-grid sources:',NPING
            CALL M3MSG2( MESG )
        END IF

C.........  Open output files
        CALL OPENEOUT( NGROUP, SDATE, STIME, ENAME, PDEV, MNAME )

C.........  Write ASCII file
        MESG = 'Writing ELEVATED POINT SOURCE output file'
        CALL M3MSG2( MESG )

        DO S = 1, NSRC

            IF( LMAJOR( S ) .OR. LPING( S ) ) THEN
 
                MS  = 0
                PS  = 0
                GID = 0
                IF( LMAJOR( S ) ) MS = S
                IF( LPING ( S ) ) THEN
                    MS = 0
                    PS = S
                    GID = GROUPID( S )
                END IF

                WRITE( PDEV, 93620 ) MS, PS, GID

            END IF

        END DO  

C.........  If needed, sort and write plume-in-grid output file
        IF( PINGFLAG ) THEN

            MESG='Writing PLUME-IN-GRID STACK PARAMETERS output file...'
            CALL M3MSG2( MESG )

            CALL WPINGSTK( MNAME, SDATE, STIME )

        END IF

C.........  Normal completion of program
        CALL M3EXIT( PROGNAME, 0, 0, ' ', 0 )

999     MESG = 'End of file reached unexpectedly'
        CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93500   FORMAT( I6, A1, 21X, I5, F9.0, F9.0, 3X, F8.0, F7.0, F7.0, 
     &          F7.0, F10.0 )

93550   FORMAT( 6X, I6, A1, A1, I1, I2, I3, A15, A15, A11 )

93620   FORMAT( 3(I8,1X) )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10 ( A, :, I8, :, 2X  ) )

94020   FORMAT( A, 1X, F8.2, 1X, A )

94030   FORMAT( 'H[m]:', 1X, F6.2, 1X, 'D[m]:'  , 1X, F4.2, 1X,
     &          'T[K]:', 1X, F7.1, 1X, 'V[m/s]:', 1X, F10.1 )

94300   FORMAT( A, I2.2, A, I2.2, A )

        END PROGRAM ELEVPOINT

