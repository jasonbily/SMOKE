#!/usr/bin/perl
#
# Filename   : smkEFsum_v0.1.pl
# Author     : Catherine Seppanen, UNC
# Version    : 0.1
# Description: Sum emission factors in SMOKE input files to create
#            : new SMOKE input files with emission factors for
#            : consolidated emission processes EXH and EVP
#
# Usage: smkEFsum.pl [--delete] InputDBlist OutputPath\n";
#    where
#    InputDBlist - moves2smkEF_v0.1.pl input file containing existing file directory
#                  (generated by runspec_generator_v0.1.pl MOVES preprocessor)
#    OutputPath - directory where summed emission factor files will be written
#                 (directory must exist prior to running smkEFsum_v0.1.pl)
#
# Update log:
# cseppan   06 Feb 2010  v0.2  Added option to delete original MRCLIST and 
#                              emission factor files
# CSC       02 Aug 2011  v0.2  Added option to run for single mode
# CSC       30 Mar 2012  v0.21 Added support for refueling modes for MOVES2010b
# CSC       10 May 2012  v0.22 Added support for separate refueling process EF files
# CSC       14 May 2012  v0.23 Removed RPDrf and RPVrf command line options.  Made implicit to RPD and RPV options.

use strict;
use Getopt::Long;

#=================================================================================
# define mapping for expanded process names to consolidated process names
my %efMap = (
'EXR' => 'EXH',   # 1. running exhaust
'CXR' => 'EXH',   # 2. crankcase running exhaust
'EPM' => 'EPM',   # 3. & 8. evaporative permeation
'EFL' => 'EVP',   # 4. & 9. evaporative fuel leaks
'EFV' => 'EVP',   # 5. evaporative vapor venting
'EXS' => 'EXH',   # 6. start exhaust
'CXS' => 'EXH',   # 7. crankcase start exhaust
'CEI' => 'EXH',   # 10. crankcase extended idle exhaust
'EXT' => 'EXH',   # 11. extended idle exhaust
'BRK' => 'BRK',   # brake wear (no change to data)
'TIR' => 'TIR',   # tire wear (no change to data)
'EXH' => 'EXH',   # compatibility with pre-processed files
'EVP' => 'EVP',   # compatibility with older files and pre-processed files
'RFV' => 'RFL',   # 18. refueling vapor loss (added 30 Mar 2012 CSC)
'RFS' => 'RFL',   # 19. refueling spillage (added 30 Mar 2012 CSC)
'RFL' => 'RFL',   # compatibility with pre-processed files
);

# define columns of interest (process ID, start of data columns) in original files
my %modeDef = (
'rateperdistance' => {'procCol' => 5, 'dataCol' => 9},
'rateperprofile'  => {'procCol' => 7, 'dataCol' => 9},
'ratepervehicle'  => {'procCol' => 7, 'dataCol' => 9},
'rateperdistance_refueling' => {'procCol' => 5, 'dataCol' => 9},
'ratepervehicle_refueling'  => {'procCol' => 7, 'dataCol' => 9},
);

# Map three letter code to full mode name
my %modeMap = ('RPP' => 'rateperprofile', 'RPD' => 'rateperdistance', 'RPV' => 'ratepervehicle', 'RPDrf' => 'rateperdistance_refueling', 'RPVrf' => 'ratepervehicle_refueling');

#=================================================================================

# check program arguments
my $deleteOrig = 0;
my $runType = "";
my $refuel = 0;
GetOptions('delete' => \$deleteOrig, 'runtype|r:s' => \$runType, 'combine_rf|c' => \$refuel);  # CSC 10 May 2012: Added -c option to use when moves2smkEF program has RFL combined

# Check for valid run types
if ($runType ne '' && 'RPD' !~ /$runType/ && 'RPV' !~ /$runType/ && 'RPP' !~ /$runType/) 
{
	die "Please specify a valid type after '-r': RPD, RPV, or RPP.  To run all five do not use '-r' argument.\n";
}

(scalar(@ARGV) == 2) or die "Usage: $0 [--delete] [-r RPD|RPV|RPP] [-c] <InputDBList> <OutputPath>\n";
my $dbFile = $ARGV[0];
my $outDir = $ARGV[1];

# open input file containing location of files to process
my $dbFH;
open($dbFH, "<", $dbFile) or die "Unable to open input file of database names: $dbFile\n";

# ignore debug and database location lines
my $dummy = <$dbFH>;
chomp($dummy);
<$dbFH> if ($dummy =~ /^\s*debug\s*$/i);

# Directory passed at command line.  Output path same as input path rather than path in list file
my $inDir = $outDir;
# read directory from file
#my $inDir = <$dbFH>;
#chomp($inDir);
#$inDir =~ s/\\/\//g;  # convert slashes in path

close($dbFH);

#=================================================================================

my @modeList;
# Create the list of modes to process
# CSC 10 May 2012: check for the refueling combine flag along with the runType when creating the modelist
if (($runType eq "") && ($refuel ne 1)) {
	@modeList = keys(%modeDef);
} elsif (($runType eq "") && ($refuel eq 1)) {
	@modeList = ($modeMap{'RPD'}, $modeMap{'RPV'}, $modeMap{'RPP'});
} elsif (($runType eq "RPD") && ($refuel ne 1)) {  # CSC 14 May 2012: If refueling combined is off, then default to run RPD + RPDrf
	@modeList = ($modeMap{$runType}, $modeMap{"RPDrf"});
} elsif (($runType eq "RPV") && ($refuel ne 1)) {
	@modeList = ($modeMap{$runType}, $modeMap{"RPVrf"});
} else {
	@modeList = ( $modeMap{$runType} );
}

# loop through emission factor modes (distance, vehicle, and profile)
for my $mode (@modeList)
{
  print "Processing list file mrclist.$mode.lst\n";

  # open input MRCLIST file 
  my $listFile = $inDir . "mrclist." . $mode . ".lst";
  my $listFH;
  open($listFH, "<", $listFile) or die "Unable to open list file: $listFile\n";

  # open output MRCLIST file
  my $outListFile = $outDir . "mrclist." . $mode .".summed.lst";
  my $outListFH;
  open($outListFH, ">", $outListFile) or die "Unable to open output list file: $outListFile\n";

  # loop through emission factor files in MRCLIST file
  while (my $line = <$listFH>)
  {
    my ($fip, $month, $fileName) = split(" ", $line);

    # open input emission factors file
    my $efFile = $inDir . $fileName;
    my $efFH;
    open($efFH, "<", $efFile) or die "Unable to open emission factors file: $efFile\n";
    
    # open output emission factors file
    my $outEFFileName = $fileName;
    $outEFFileName =~ s/\.csv$/\.summed\.csv/;
    my $outEFFile = $outDir . $outEFFileName;
    my $outEFFH;
    open($outEFFH, ">", $outEFFile) or die "Unable to open output emission factors file: $outEFFile\n";

    # write both header lines to output file 1st is NUM_TEMP_BINS, 2nd is column labels
    my $header = <$efFH>;
    print $outEFFH $header;
    $header = <$efFH>;
    print $outEFFH $header;

    my (%sumRows, @lineOrder);

    while (my $line2 = <$efFH>)
    {
      chomp($line2);
      my @row = split(",", $line2);

      # extract process ID and check that it is recognized
      my $procID = $row[$modeDef{$mode}{'procCol'}];
      (exists $efMap{$procID}) or die "Unknown process ID \"$procID\" in emission factors file: $efFile\n";

      # replace process ID with consolidated process ID
      $row[$modeDef{$mode}{'procCol'}] = $efMap{$procID};

      # generate key to look up current row using identifying information
      # (SCC, speed bin, temperature, FIPS, month, etc.)
      my $key = join(",", splice(@row, 0, $modeDef{$mode}{'dataCol'}));

      # if new key, store data values; 
      # otherwise add this row's data to stored values
      unless (exists $sumRows{$key})
      {
        push(@lineOrder, $key);
        $sumRows{$key} = [@row];
      }
      else
      {
        for (my $i = 0; $i < scalar(@row); $i++)
        {
          $sumRows{$key}[$i] += $row[$i];
        }
      }
    }

    close ($efFH);
    
    # output summed data
    for my $key (@lineOrder)
    {
      print $outEFFH join(",", $key, @{$sumRows{$key}}) . "\n";
    }

    close ($outEFFH);
    
    # add new emission factors file name to output MRCLIST file
    print $outListFH $fip . " " . $month . " " . $outEFFileName . "\n";
    
    # delete original emission factors file if requested
    if ($deleteOrig)
    {
      unlink $efFile or warn "Could not delete $efFile: $!\n";
    }
  }

  close ($listFH);
  close ($outListFH);
  
  # delete original MRCLIST file if requested
  if ($deleteOrig)
  {
    unlink $listFile or warn "Could not delete $listFile: $!\n";
  }
}
