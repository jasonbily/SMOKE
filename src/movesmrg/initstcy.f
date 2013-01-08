
        SUBROUTINE INITSTCY

C***********************************************************************
C  subroutine INITSTCY body starts at line
C
C  DESCRIPTION:
C      The purpose of this subroutine is to initialize the necessary fields
C      for performing state and county totals.  The first call sets up the
C      indices from each source to each county.
C
C  PRECONDITIONS REQUIRED:  
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C       Created 8/99 by M. Houyoux
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
C.........  This module contains the major data structure and control flags
        USE MODMERGE, ONLY: NMSRC,            ! no. of sources by category
     &                      LREPSTA,          ! output state total emissions flag
     &                      LREPCNY,          ! output county total emissions flag
     &                      LREPSCC,          ! output SCC total emissions flag
     &                      MEBSTA, ! state total speciated emissions
     &                      MEBCNY, ! county total speciated emissions
     &                      MEBSUM, ! source total speciated emissions total
     &                      MEBSRC, ! source total speciated emissions by hour
     &                      MEBSCC, ! SCC total speciated emissions
     &                      MEBSTC  ! state-SCC total speciated emissions
     
C.........  This module contains the arrays for state and county summaries
        USE MODSTCY, ONLY: MICNY, NCOUNTY, CNTYCOD

C...........   This module is the source inventory arrays
        USE MODSOURC, ONLY: IFIP, CSCC

C.........  This module contains data structures and flags specific to Movesmrg
        USE MODMVSMRG, ONLY: MISCC

C.........  This module contains the lists of unique source characteristics
        USE MODLISTS, ONLY: NINVSCC, INVSCC

        IMPLICIT NONE

C...........   INCLUDES:
        
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        
        INTEGER         FIND1  
        INTEGER         FINDC

        EXTERNAL   FIND1, FINDC

C...........   Other local variables

        INTEGER          IOS      ! i/o status
        INTEGER          J, S     ! counter
        INTEGER          FIP      ! tmp cy/st/co code
        INTEGER          PFIP     ! previous cy/st/co code
        
        LOGICAL, SAVE :: FIRSTIME = .TRUE. ! true: first time routine called

        CHARACTER(300)   MESG     ! message buffer

        CHARACTER(16) :: PROGNAME = 'INITSTCY' ! program name

C***********************************************************************
C   begin body of subroutine INITSTCY
        
        IF( FIRSTIME ) THEN

C.............  Allocate memory for indices from Co/st/cy codes to counties
            ALLOCATE( MICNY( NMSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MICNY', PROGNAME )

C.............  Allocate memory for index from master list of SCCs to source SCC
            ALLOCATE( MISCC( NMSRC ), STAT=IOS )
            CALL CHECKMEM( IOS, 'MISCC', PROGNAME )
    
C.............  Create indices to counties from Co/st/cy codes and for SCCs
            PFIP = -9
            DO S = 1, NMSRC
            
                FIP = IFIP( S )
                
                IF( FIP .NE. PFIP ) THEN
                
                    J = MAX( FIND1( FIP, NCOUNTY, CNTYCOD ), 0 )
                    PFIP = FIP
                    
                END IF
                
                MICNY( S ) = J
                
                MISCC( S ) = MAX( FINDC( CSCC( S ), NINVSCC, INVSCC ), 0 )
                
            END DO
            
            FIRSTIME = .FALSE.
        
        END IF

C.........  Initialize totals to zero...
C.........  SCC totals...
        IF( LREPSCC ) THEN
            MEBSCC = 0.
        END IF

C.........  State totals...
        IF( LREPSTA ) THEN
            MEBSTA = 0.
            IF( LREPSCC ) THEN
                MEBSTC = 0.
            END IF
        END IF

C.........  County totals...
        IF( LREPCNY ) THEN
            MEBCNY = 0.
        END IF

C.........  Source totals...
        MEBSUM = 0.

        RETURN

        END SUBROUTINE INITSTCY