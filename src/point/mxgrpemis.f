
        SUBROUTINE MXGRPEMIS( NINVGRP, TSTEP, SDATE, STIME, NSTEPS, 
     &                        TNAME )

C***********************************************************************
C  subroutine body starts at line
C
C  DESCRIPTION: 
C     This routine determines the maximum daily emissions during the 
C     period being modeled.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C     Written 7/2001 by M. Houyoux
C
C***********************************************************************
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
        INCLUDE 'PARMS3.EXT'    ! I/O API constants
        INCLUDE 'FDESC3.EXT'    ! I/O API file description data structure
        INCLUDE 'IODECL3.EXT'   ! I/O API function declarations
        INCLUDE 'CONST3.EXT'    ! physical and mathematical constants

C...........   ARGUMENTS and their descriptions:
        INTEGER     , INTENT (IN) :: NINVGRP  ! no. of inventory groups
        INTEGER     , INTENT (IN) :: TSTEP    ! time step
        INTEGER  , INTENT(IN OUT) :: SDATE    ! Julian start date limit
        INTEGER  , INTENT(IN OUT) :: STIME    ! start time limit
        INTEGER  , INTENT(IN OUT) :: NSTEPS   ! number of time steps limit
        CHARACTER(*), INTENT(OUT) :: TNAME    ! temperature variable name

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2  CRLF
        INTEGER      SECSDIFF
        CHARACTER*14 MMDDYY
        CHARACTER*16 PROMPTMFILE
        INTEGER      WKDAY

        EXTERNAL    CRLF, SECSDIFF, MMDDYY, PROMPTMFILE, WKDAY

C...........   Local allocatable arrays
        INTEGER, ALLOCATABLE :: DAYBEGT( : )   ! day beginning time by source
        INTEGER, ALLOCATABLE :: DAYENDT( : )   ! day ending time by source

        LOGICAL, ALLOCATABLE :: LDAYSAV( : )   ! true: daylight savings used by source

        REAL   , ALLOCATABLE :: EMIS   ( : )   ! tmp emissions by source
        REAL   , ALLOCATABLE :: GRPSUM ( :,: ) ! emissions summing by group
        REAL   , ALLOCATABLE :: SRCSUM ( :,: ) ! emissions summing by source
        REAL   , ALLOCATABLE :: MXGRPEM( :,: ) ! emissions max for groups

C...........   Local fixed arrays
C...........   OTHER LOCAL VARIABLES and their descriptions:
        INTEGER     G, J, K, L, L2, N, S, V, T    ! indices and counters

        INTEGER         DAY           ! tmp day of week
        INTEGER         ED            ! tmp end date
        INTEGER         EDATE         ! ending date YYYYDDD
        INTEGER         ET            ! tmp end time
        INTEGER         ETIME         ! ending time HHMMSS
        INTEGER         IOS           ! i/o status
        INTEGER         ISECS         ! tmp number seconds
        INTEGER         JDATE         ! Julian date
        INTEGER         JTIME         ! time HHMMSS
        INTEGER         LDATE         ! date from previous iteration
        INTEGER         NS            ! tmp number time steps
        INTEGER         PG            ! previous G
        
        LOGICAL :: EFLAG    = .FALSE. ! true: error detected

        CHARACTER*300   MESG
        CHARACTER(LEN=IOVLEN3) CBUF   ! tmp pollutant name

        CHARACTER*16 :: PROGNAME = 'MXGRPEMIS'   !  program name

C***********************************************************************
C   begin body of subroutine MXGRPEMIS

C.........  Initialize based on subroutine arguments
        EDATE = SDATE
        ETIME = STIME
        CALL NEXTIME( EDATE, ETIME, NSTEPS*TSTEP )

C.........  Allocate arrays for maximum emission daily totals per source 
C           in local time zone for all pollutants used as a selection criteria
        ALLOCATE( MXEMIS( NSRC,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'MXEMIS', PROGNAME )
        ALLOCATE( MXEIDX( NSRC,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'MXEIDX', PROGNAME )
        ALLOCATE( MXRANK( NSRC,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'MXRANK', PROGNAME )
        ALLOCATE( SRCSUM( NSRC,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SRCSUM', PROGNAME )
        ALLOCATE( EMIS( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EMIS', PROGNAME )
        ALLOCATE( DAYBEGT( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'DAYBEGT', PROGNAME )
        ALLOCATE( DAYENDT( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'DAYENDT', PROGNAME )
        ALLOCATE( LDAYSAV( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LDAYSAV', PROGNAME )

        MXEMIS  = 0.        ! array
        MXEIDX  = 0         ! array
        SRCSUM  = 0.        ! array
        DAYBEGT = 0         ! array
        DAYENDT = 0         ! array
        LDAYSAV = .FALSE.   ! array

C.........  Initialize sorting indices
        DO S = 1, NSRC
            MXEIDX( S,1:NEVPEMV ) = S   ! array
        END DO

C.........  Allocate global and local arrays for maximum emis by stack group in
C           local time zone for all pollutants used as a selection criteria
        ALLOCATE( MXGRPEM( NINVGRP,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'MXGRPEM', PROGNAME )
        ALLOCATE( GRPSUM( NINVGRP,NEVPEMV ), STAT=IOS )
        CALL CHECKMEM( IOS, 'GRPSUM', PROGNAME )
        MXGRPEM = 0.  ! array
        GRPSUM  = 0.  ! array

C.........  Create note about why temporal file is being read in
        MESG = 'NOTE: Hourly emissions file is required to determine '//
     &         'actual daily emissions ' // CRLF() // BLANK10 //
     &         'for evaluating emissions-based criteria for elevated '//
     &         'and/or PinG ' // CRLF() // BLANK10 // 'source selection'
        CALL M3MSG2( MESG )

C.........  Open hourly emissions file
        L = LEN_TRIM( CATEGORY )
        MESG = 'Enter logical name for the ' // CATEGORY( 1:L ) // 
     &         ' HOURLY EMISSIONS file'

        TNAME = PROMPTMFILE( MESG, FSREAD3, CRL//'TMP', PROGNAME )

C.........  Get header information
        IF( .NOT. DESC3( TNAME ) ) THEN

            MESG = 'Could not get description of file "' //
     &                 TNAME( 1:LEN_TRIM( TNAME ) ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  If header was read okay...
        ELSE

C.............  Ensure time information is consistent with arguments
            ISECS = SECSDIFF( SDATE, STIME, SDATE3D, STIME3D )

            IF( ISECS .GT. 0 ) THEN  ! SDATE3D/STIME3D are later
                SDATE = SDATE3D
                STIME = STIME3D
            END IF

            ED = SDATE3D
            ET = STIME3D
            CALL NEXTIME( ED, ET, ( MXREC3D-1 ) * TSTEP3D )

            ISECS = SECSDIFF( EDATE, ETIME, ED, ET )

            IF( ISECS .LT. 0 ) THEN  ! ED/ET are earlier                
                EDATE = ED
                ETIME = ET
            END IF

            NS = 1+ SECSDIFF( SDATE, STIME, EDATE, ETIME )/ 3600

            IF( NS .LE. 0 ) THEN
                MESG = 'Because of file ' // TNAME // 
     &                 ', dates and times do not overlap at all!'
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

            ELSE IF ( NS .NE. NSTEPS ) THEN
                WRITE( MESG,94010 ) 'WARNING: The contents of the ' //
     &                 'PTMP file overlap with the requested '// 
     &                 CRLF()// BLANK10 // 'date and time for only ',
     &                 NS, 'hours.'
                CALL M3MSG2( MESG )

            END IF

            NSTEPS = NS

C.............  Check the number of sources
            CALL CHKSRCNO( CATEGORY, TNAME, NROWS3D, NSRC, EFLAG )

C.............  Check the variable number and names
            IF( NVARS3D .NE. NIPOL ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 'ERROR: The number of ' //
     &                'pollutants in the PTMP file (', NVARS3D, 
     &                CRLF() // BLANK10 // 'is inconsitent with '//
     &                'the number in the PNTS file.'
                CALL M3MSG2( MESG )

C.............  If number is okay, check names
            ELSE

                DO V = 1, NIPOL
                    IF( EINAM( V ) .NE. VNAME3D( V ) ) THEN

                        EFLAG = .TRUE.
                        L  = LEN_TRIM( EINAM( V ) )
                        L2 = LEN_TRIM( VNAME3D( V ) )
                        WRITE( MESG,94010 ) 'ERROR: Pollutant "'//
     &                        EINAM( V )(1:L)// '" is in a different '//
     &                        'order in PNTS than in PTMP.'
                        CALL M3MSG2( MESG )

                    END IF
                END DO      ! Loop on pollutants

            END IF          ! If number of pollutants the same
        END IF              ! If header was read okays

C.........  If errors found so far, then abort
        IF ( EFLAG ) THEN
            MESG = 'Problem with hourly emissions file.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

C.........  Otherwise, output status message
        ELSE
            MESG = 'Computing source and group maximum daily ' //
     &             'emissions totals...'
            CALL M3MSG2( MESG )
        END IF

C.........  Loop through hours
        JDATE = SDATE
        JTIME = STIME
        LDATE = -9
        DO T = 1, NSTEPS

C.............  When new day...
            IF ( JDATE .NE. LDATE ) THEN

C.................  Write message for day of week and date
                DAY = WKDAY( JDATE )
                MESG = 'Processing ' // DAYS( DAY ) // ' ' // 
     &                 MMDDYY( JDATE )
                CALL M3MSG2( MESG )

C.................  Create array of which sources are affected by daylight 
C                  savings
                CALL GETDYSAV( NSRC, IFIP, LDAYSAV )

C.................  Set start and end hours of day for all sources
                CALL SETSRCDY( NSRC, JDATE, TZONES, LDAYSAV, 
     &                         DAYBEGT, DAYENDT )
            END IF

C.............  Loop through pollutants that are used as selection criteria
            DO K = 1, NEVPEMV

C.................  Set global emissions variable index
                V    = EVPEMIDX( K )
                CBUF = EINAM( V )

C.................  Read emissions value
                IF ( .NOT. READ3( TNAME, CBUF, 1, 
     &                            JDATE, JTIME, EMIS ) ) THEN
                    L = LEN_TRIM( CBUF )
                    MESG = 'Could not read ' // CBUF( 1:L ) //
     &                     ' from ' // TNAME 
                    CALL M3EXIT( PROGNAME, JDATE, JTIME, MESG, 2 )

                END IF

C.................  Loop through sources and add up daily total based on 
C                   local day
                PG   = -9
                DO J = 1, NSRC

                    S = GINDEX ( J )
                    G = GROUPID( S )

C.....................  Initialize group total and source total if we are
C                       at the first hour of the day for this source
                    IF ( DAYBEGT( S ) .EQ. JTIME ) THEN

C.........................  Only initialize group total if the group is new
                        IF ( G .GT. 0 .AND. G .NE. PG ) THEN
                            GRPSUM( G,: ) = 0.
                        END IF

                        SRCSUM( S,: ) = 0.

                    END IF

C.....................  If source is in a group, add emissions
C.....................  Also store  group number for next iteration
                    IF ( G .GT. 0 ) THEN
                        GRPSUM (G,K) = GRPSUM( G,K ) + EMIS( S )
                        MXGRPEM(G,K) = MAX( MXGRPEM(G,K), GRPSUM(G,K) )
                        PG = G

C.....................  Otherwise, add emissions for this time step for source
                    ELSE
                        SRCSUM( S,K ) = SRCSUM( S,K ) + EMIS( S ) 
                        MXEMIS( S,K ) = MAX( MXEMIS(S,K), SRCSUM(S,K) )

                    END IF


                END DO   ! End loop on sources

            END DO      ! End loop on pollutants used as selection criteria

            LDATE = JDATE
            CALL NEXTIME( JDATE, JTIME, TSTEP )

        END DO       ! End loop on time steps

C.........  Replace source emissions with group emissions...
C.........  Loop through pollutants that are used as selection criteria
        DO K = 1, NEVPEMV

            DO S = 1, NSRC

                G = GROUPID( S )
                IF ( G .LE. 0 ) CYCLE  ! Skip sources without group

                MXEMIS( S,K ) = MXGRPEM( G,K )

            END DO  ! end loop on sources

        END DO      ! End loop on pollutants used as selection criteria

C.........  Loop through pollutants that are used as selection criteria
C           and sort max daily emissions in ascending order.
        IF ( LELVRNK .OR. LPNGRNK ) THEN

C.............  Write status message
            MESG = 'Ranking sources and groups by emissions values...'
            CALL M3MSG2( MESG )

            DO K = 1, NEVPEMV

C.................  Note that all sources in a group have the same group-total
C                   emissions value at this point.
                CALL SORTR2( NSRC, MXEIDX(1,K), MXEMIS(1,K), GROUPID )

C.................  Reset indices if a source is in a group, invert the
C                   order, and change the index to a ranking.
                N = 0
                PG = -9
                DO J = NSRC, 1, -1
                    
                    S = MXEIDX ( J,K )
                    G = GROUPID( S )

C.....................  If source is not a group or group has changed
                    IF ( G .LE. 0 .OR. G .NE. PG ) N = N + 1

C.....................  Reset ranked number for source such that all 
C                       members of a group will have the same rank
                    MXRANK( S,K ) = N

                    PG = G

                END DO

            END DO

        END IF

C.........  Deallocate local memory
        DEALLOCATE( DAYBEGT, DAYENDT, SRCSUM, GRPSUM, MXEIDX )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10 ( A, :, I8, :, 2X  ) )

        END SUBROUTINE MXGRPEMIS
