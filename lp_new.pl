#!/usr/bin/perl
use strict;
use Data::Dumper;
use POSIX;
use feature qw(switch);
use Log::Message::Simple;
use File::Basename;

## Globals Configuration parameters
my $INPUT_PATH  = "./import";
my $OUTPUT_PATH = "files/intermediate/";    ## Path where the intermediate files are created. These files will be read by the generate_xml.pl
my %INPUT_FILES = (
	"patron"  => "PATRON.TXT",
	"student" => "UTD_R0008_02_AMSFEEDA.txt",
	"course"  => "UTD_R0008_03_COURSES.txt",
	"barcode" => "BARCODE.TXT"
);

## Get the logging things done here.
my $LOGPATH = "files/logs/";
my $logfile = $LOGPATH . File::Basename::basename($0) . "_" . strftime ("%Y%m%d", localtime) . ".log";
open my $log, ">>", $logfile or warn "Cannot open log file $logfile";
local $Log::Message::Simple::MSG_FH = $log;
my $verbose = 1;    ## Assign 0 to turn this off.

## Contant used to define if a user is present in just one file, two files or all 3 files.
use constant {
	SR     => 1,
	HR     => 2,
	SRHR   => 3,
	AR     => 4,
	SRAR   => 5,
	HRAR   => 6,
	SRHRAR => 7,
};

## Handlers functions for each output field. These functions are responsible to get each field in the output record. All the ugly priorities go into the helper functions.
my %consolidated_data_fields = (
	f_name     => \&get_f_name,
	l_name     => \&get_l_name,
	m_name     => \&get_m_name,
	gender     => \&get_gender,
	birth_date => \&get_birth_date,
	barcode    => \&get_barcode,
	ad1ln1     => \&get_ad1ln1,
	ad1ln2     => \&get_ad1ln2,
	ad1ln3     => \&get_ad1ln3,
	ad1city    => \&get_ad1city,
	ad1state   => \&get_ad1state,
	ad1zip     => \&get_ad1zip,
	ad1country => \&get_ad1country,
	ad2ln1     => \&get_ad2ln1,
	ad2ln2     => \&get_ad2ln2,
	ad2ln3     => \&get_ad2ln3,
	ad2city    => \&get_ad2city,
	ad2state   => \&get_ad2state,
	ad2zip     => \&get_ad2zip,
	ad2country => \&get_ad2country,
	email      => \&get_email,
	phoneno    => \&get_phoneno,
	jobcode    => \&get_jobcode,
);

## Each of these globals will contains the data from respective files after loadData.
my $patron_data;
my $student_data;
my $course_data;
my $barcode_data;
my $consolidated_data;

msg( "BEGIN", $verbose );
## Main code starts


&load_patron_data();         ## This does the loading of the patron data from the patron feed.
&map_patron_data();          ## This does the mapping/generating additional fields from the patron data.


&load_student_data();
&map_student_data();

&load_course_data();
&map_course_data();

&load_barcode_data();
&map_barcode_data();

&consolidate_data();
&output_data();


## Main code ends
msg( "END", $verbose );
## Helper functions

sub load_student_data() {
	msg( "LOADING STUDENT DATA", $verbose );
	## Loads the data from $INPUT_FILES{student} into $student_data.

	## The position and offsets of the input data file. All the crazy input specifications go here. This is just where we find each of the field in the input file.
	my $utdid_location = 325;
	my $utdid_length   = 10;
	my %input_fields   = (
		"name" => {
			start  => 18,
			length => 32
		},
		"job_code1" => {
			start  => 50,
			length => 3
		},
		"birth_date" => {
			start  => 63,
			length => 8
		},
		"job_code2" => {
			start  => 71,
			length => 4
		},
		"term" => {
			start  => 76,
			length => 5
		},
		"withdrawal_code" => {
			start  => 81,
			length => 8
		},
		"address_line1" => {
			start  => 89,
			length => 32
		},
		"address_line2" => {
			start  => 121,
			length => 32
		},
		"address_city" => {
			start  => 153,
			length => 20
		},
		"address_state" => {
			start  => 173,
			length => 2
		},
		"address_country" => {
			start  => 175,
			length => 2
		},
		"address_zip" => {
			start  => 187,
			length => 5
		},
		"gender" => {
			start  => 200,
			length => 1
		},
		"email" => {
			start  => 231,
			length => 25
		},
	);

	open( FH, "<", $INPUT_PATH . "/" . $INPUT_FILES{"student"} ) or die "Unable to open $!";
	while (<FH>) {
		my $utdid = substr( $_, $utdid_location, $utdid_length );
		for my $field ( keys %input_fields ) {
			$student_data->{$utdid}{$field} = trim( substr( $_, $input_fields{$field}{start}, $input_fields{$field}{length} ) );
		}
	}
	msg( "Read $. student records", $verbose );
	close(FH);
}

sub load_patron_data() {
	msg( "LOADING PATRON DATA", $verbose );
	## Loads the data from $INPUT_FILES{patron} into $patron_data.

	## The position and offsets of the input data file. All the crazy input specifications go here. This is just where we find each of the field in the input file.
	my $utdid_location = 197;
	my $utdid_length   = 10;
	my %input_fields   = (
		"l_name" => {
			start  => 9,
			length => 18
		},
		"f_name" => {
			start  => 27,
			length => 12
		},
		"m_name" => {
			start  => 39,
			length => 1
		},
		"job_code" => {
			start  => 40,
			length => 6
		},
		"address_line1" => {
			start  => 65,
			length => 39
		},
		"address_city" => {
			start  => 105,
			length => 13
		},
		"address_state" => {
			start  => 118,
			length => 2
		},
		"address_zip" => {
			start  => 120,
			length => 5
		},
		"birth_date" => {
			start  => 130,
			length => 8
		},
		"gender" => {
			start  => 138,
			length => 1
		},
		"mail_station" => {
			start  => 139,
			length => 4
		},
		"room_no" => {
			start  => 143,
			length => 8
		},
		"extension" => {
			start  => 152,
			length => 5
		},
		"email" => {
			start  => 167,
			length => 30
		}
	);

	open( FH, "<", $INPUT_PATH . "/" . $INPUT_FILES{"patron"} ) or die "Unable to open $!";
	while (<FH>) {
		my $utdid = substr( $_, $utdid_location, $utdid_length );
		for my $field ( keys %input_fields ) {
			$patron_data->{$utdid}{$field} = trim( substr( $_, $input_fields{$field}{start}, $input_fields{$field}{length} ) );
		}

	}
	msg( "Read $. patron records", $verbose );
	close(FH);
}

sub load_course_data() {
	msg( "LOADING COURSE DATA", $verbose );
	## Loads the data from $INPUT_FILES{course} into $course_data.

	## This input file is even complex. One line rerepsents upto 3 different data.
	my @utdid_location = ( 213, 223, 233 );
	my $utdid_length   = 10;
	my @name_location  = ( 81, 113, 145 );
	my $name_length    = 32;
	my %input_fields   = (
		"term" => {
			start  => 0,
			length => 3
		}
	);

	open( FH, "<", $INPUT_PATH . "/" . $INPUT_FILES{"course"} ) or die "Unable to open $!";
	while (<FH>) {
		chomp;
		my $len = length($_);

		# This is the logic that give the number of people each line has, i.e. the lenght of the line !!
		my $count = 0;
		if ( $len > 243 ) {
			$count = 3;
		}
		elsif ( $len > 233 ) {
			$count = 2;
		}
		elsif ( $len > 223 ) {
			$count = 1;
		}
		for ( my $i = 0 ; $i < $count ; $i++ ) {
			my $utdid = substr( $_, $utdid_location[$i], $utdid_length );
			if ( $utdid !~ /^\s*$/ ) {    ## If there is a UTDID then load both name/utdid
				$course_data->{$utdid}{name} = trim( substr( $_, $name_location[$i], $name_length ) );
				for my $field ( keys %input_fields ) {
					$course_data->{$utdid}{$field} = trim( substr( $_, $input_fields{$field}{start}, $input_fields{$field}{length} ) );
				}
			}
		}
	}
	msg( "Read $. course records", $verbose );
	close(FH);
}

sub load_barcode_data() {
	msg( "LOADING BARCODE DATA", $verbose );
	## Loads the data from $INPUT_FILES{barcode} into $barcode_data.

	## The position and offsets of the input data file. All the crazy input specifications go here. This is just where we find each of the field in the input file.
	my $utdid_location = 0;
	my $utdid_length   = 10;
	my %input_fields   = (
		"bar_code" => {
			start  => 11,
			length => 16
		}
	);

	open( FH, "<", $INPUT_PATH . "/" . $INPUT_FILES{"barcode"} )
	  or die "Unable to open $!";
	while (<FH>) {
		my $utdid = substr( $_, $utdid_location, $utdid_length );
		for my $field ( keys %input_fields ) {
			$barcode_data->{$utdid}{$field} = trim( substr( $_, $input_fields{$field}{start}, $input_fields{$field}{length} ) );
		}

	}
	msg( "Read $. barcode records", $verbose );
	close(FH);
}

sub map_patron_data {
	## Does below :
	# 1) Maps the incoming job codes to our job codes. Tranforms job_code and adds a "role".
	# 2) Converts gender from M to Male, F to Female.
	# 3) Converts the format of birthdate to YYYYMMDD

	## This variable stores all the mapping codes. Maps from our jobcode to the incoming code.
	## Ourjobcode => (Possible incoming codes)
	my $defaul_role = "staf";    ## We do not store anything. This is the role by default if it does not match any of the below.
	my %roles       = (
		vips => "A00101?A00105?A00106?A00107?A00109?A00117?A00119?A00130?A00131?A00132?A00133?A00200?A00201?A00202?A00203?A00204?A00206?A00207?A00212?A00213?A00217?A00297?A00300?A00302?A00401?A00403?A00901?",
		utdf => "F00001?F00002?F00003?F00004?F00005?F00008?F00009?F00010?F00011?F00012?F00013?F00014?F00015?F00016?F00017?F00018?F00019?F00020?F00021?F00022?F00025?F00026?F00029?F00030?F00032?F00033?F00034?F00035?F00047?F00048?F00049?A00232?A00233?A00234?A00235?A00236?A00314?A00612?A00702?F00905?A00906?F00907?F00908?A00183?A00184?F00900?A00219?A00222?F00942?F00961?F00962?",
		libp => "A00504?A00502?A00513?A00523?A00598?A00599?A00528?A00529?A00503?A00505?",
		rsci => "F00036?F00039?F00046?A00185?A00186?A00611?A00614?A0616?A00618?A00619?A00631?A00632?A00633?A00634?A00640?A00670?A00672?A00684?A00704?A00708?A00712?A00715?A00730?A00732?A00733?A00734?A00735?A00736?A00738?A00742?A00744?A00745?A00746?A00748?A00750?A00751?A00752?C04206?C04207?C04208?C04209?C04210?C04211?C04222?C04412?C04413?C04415?C04416?A00680?",
		rets => "A00930?",
		emri => "A00928?A00929?",
		lect => "F00040?F00041?F00042?F00043?F00044?F00050?F00051?F00071?F00072?F00076?F00080?C03086?",
	);

	foreach my $utdid ( keys %$patron_data ) {
		##1) Maps the incoming job codes to our job codes. Tranforms job_code and adds a "role".
		my $patron_job_code = $patron_data->{$utdid}{job_code} . '\?';
		$patron_data->{$utdid}{role} = $defaul_role;    ## Default role.
		foreach my $role ( keys %roles ) {
			if ( $roles{$role} =~ /$patron_job_code/ ) {
				$patron_data->{$utdid}{role} = $role;
				last;
			}
		}

		##2) Converts gender from M to Male, F to Female.
		$patron_data->{$utdid}{gender} = "None" if ( $patron_data->{$utdid}{gender} ne "F" && $patron_data->{$utdid}{gender} ne "M" );
		$patron_data->{$utdid}{gender} = "Male"   if ( $patron_data->{$utdid}{gender} eq "M" );
		$patron_data->{$utdid}{gender} = "Female" if ( $patron_data->{$utdid}{gender} eq "F" );


		##3) Convert format of birthdate.
		$patron_data->{$utdid}{birth_date} =~ s/(\d\d)(\d\d)(\d\d\d\d)/$3$1$2/;

	}

}

sub map_student_data {
	## Does below :
	## 1) Adds a field called "job_code" that takes a union from job_code1 and job_code2
	## 2) Maps the incoming job codes to our job codes. Tranforms job_code and adds a "role".
	## 3) Splits the name into fname mname and lname.
	## 4) Converts gender from M to Male, F to Female.
	## 5) Converts the format of birthdate to YYYYMMDD

	my $default_role = "utdu";    ## This is by default.
	my %roles        = (
		utdd => "PHD?PHX?PHN?PSCI?PHM?PHQ?PHU?AUD?",
		utdm => "GM ?GX ?GRS?GPM?GPD?CEU?MT ?MITM?CRT?MA ?MFA?MAT?MS ?MPA?MPP?MSCS?MSEE?MSTE?MBA?MAT?",
		elss => "ELSS?",
		elsf => "ELSF?",
		utde => "FR?",
		utdp => "SO?",
		utdj => "JR?",
		utds => "SR?",

	);

	foreach my $utdid ( keys %$student_data ) {
		## 1) Adds a field called "job_code" that takes a union from job_code1 and job_code2
		$student_data->{$utdid}{job_code} = $student_data->{$utdid}{job_code1};
		$student_data->{$utdid}{job_code} = $student_data->{$utdid}{job_code2} if ( $student_data->{$utdid}{job_code} =~ /^\s*$/ );    ## If the job_code is still empty add the job_code2 as the job code.

		## 2) Maps the incoming job codes to our job codes. Tranforms job_code and adds a "role".
		my $student_job_code = $student_data->{$utdid}{job_code} . '\?';
		$student_data->{$utdid}{role} = $default_role;    ## Default role.
		foreach my $role ( keys %roles ) {
			if ( $roles{$role} =~ /$student_job_code/ ) {
				$student_data->{$utdid}{role} = $role;
				last;
			}
		}

		## 3) Splits the name into fname mname and lname.
		$student_data->{$utdid}{f_name} = "";
		$student_data->{$utdid}{l_name} = "";
		$student_data->{$utdid}{m_name} = "";
		my ( $last, $rest ) = split( /,/, $student_data->{$utdid}{name} );
		print $student_data->{$utdid}{name} if ( !defined $rest );
		my ( $first, $middle ) = split( / /, trim($rest) );
		$student_data->{$utdid}{f_name} = $first  if ( defined $first );
		$student_data->{$utdid}{l_name} = $last   if ( defined $last );
		$student_data->{$utdid}{m_name} = $middle if ( defined $middle );

		## 4)
		$student_data->{$utdid}{gender} = "None" if ( $student_data->{$utdid}{gender} ne "F" && $student_data->{$utdid}{gender} ne "M" );
		$student_data->{$utdid}{gender} = "Male"   if ( $student_data->{$utdid}{gender} eq "M" );
		$student_data->{$utdid}{gender} = "Female" if ( $student_data->{$utdid}{gender} eq "F" );

		## 5) Converts the format of birthdate to YYYYMMDD
		$student_data->{$utdid}{birth_date} =~ s/(\d\d\d\d)(\d\d)(\d\d)/$1$3$2/;

	}
}

sub map_course_data {
	## What this does?
	## 1) Sets the role of every one to lect.
	## 2) Splits the name in fname, lname, mname.
	my $default_role = "lect";
	foreach my $utdid ( keys %$course_data ) {
		## 1) Default role.
		$course_data->{$utdid}{role} = $default_role;

		## 2) Splits the name into fname mname and lname.
		$course_data->{$utdid}{f_name} = "";
		$course_data->{$utdid}{l_name} = "";
		$course_data->{$utdid}{m_name} = "";
		my ( $last, $rest ) = split( /,/, $course_data->{$utdid}{name} );
		print $course_data->{$utdid}{name} if ( !defined $rest );
		my ( $first, $middle ) = split( / /, trim($rest) );
		$course_data->{$utdid}{f_name} = $first  if ( defined $first );
		$course_data->{$utdid}{l_name} = $last   if ( defined $last );
		$course_data->{$utdid}{m_name} = $middle if ( defined $middle );

	}
}

sub map_barcode_data {
	## Does below:
	#  Foreach of the person in barcode file finds how many files the person occurs in.
	foreach my $utdid ( keys %$barcode_data ) {
		$barcode_data->{$utdid}{present_in} = 0;
		$barcode_data->{$utdid}{present_in} += 1 if ( exists $student_data->{$utdid} );
		$barcode_data->{$utdid}{present_in} += 2 if ( exists $patron_data->{$utdid} );
		$barcode_data->{$utdid}{present_in} += 4 if ( exists $course_data->{$utdid} );
	}
}

sub trim($) {
	## Perl trim function to remove whitespace from the start and end of the string
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub consolidate_data {
	## What this does?
	# Gets the data for only the people in barcode files from the 3 input files. The priorities are taken care by appropriate handler functions.
	#	my @test = (2010022852);

	#foreach my $utdid (@test) {
	foreach my $utdid ( keys %$barcode_data ) {
		foreach my $field ( keys %consolidated_data_fields ) {
			$consolidated_data->{$utdid}{$field} = $consolidated_data_fields{$field}->($utdid) if ( $barcode_data->{$utdid}{present_in} != 0 );
		}
	}
}

sub output_data {
	my $today    = strftime( "%Y%m%d", localtime(time) );
	my $fdelim   = "\x1F";
	my $rdelim   = "\n";
	my $filename = $OUTPUT_PATH . "lp_data.$today";

	open( FH, ">", $filename ) or die "Cannot open file $filename";
	foreach my $utdid ( keys $consolidated_data ) {
		print FH "$utdid$fdelim";
		foreach my $field ( sort keys $consolidated_data->{$utdid} ) {
			if ( defined $consolidated_data->{$utdid}{$field} ) {
				print FH "$consolidated_data->{$utdid}{$field}$fdelim";
			}
			else {
				print FH $fdelim;
			}
		}
		print FH $rdelim;
	}
	msg( "WROTE ".scalar(keys $consolidated_data)." records to $filename.", $verbose );
	close(FH);
}

### Below are the subroutines to get each field for consolidated data.
sub get_f_name {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{f_name} when (SR);
		return $patron_data->{$utdid}{f_name} when (HR);
		return $course_data->{$utdid}{f_name} when (AR);
		return $student_data->{$utdid}{f_name} when (SRHR);
		return $patron_data->{$utdid}{f_name} when (HRAR);
		return $student_data->{$utdid}{f_name} when (SRAR);
		return $student_data->{$utdid}{f_name} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_m_name {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{m_name} when (SR);
		return $patron_data->{$utdid}{m_name} when (HR);
		return $course_data->{$utdid}{m_name} when (AR);
		return $student_data->{$utdid}{m_name} when (SRHR);
		return $patron_data->{$utdid}{m_name} when (HRAR);
		return $student_data->{$utdid}{m_name} when (SRAR);
		return $student_data->{$utdid}{m_name} when (SRHRAR);
		default {};    ## Should not happen

	}
}

sub get_l_name {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{l_name} when (SR);
		return $patron_data->{$utdid}{l_name} when (HR);
		return $course_data->{$utdid}{l_name} when (AR);
		return $student_data->{$utdid}{l_name} when (SRHR);
		return $patron_data->{$utdid}{l_name} when (HRAR);
		return $student_data->{$utdid}{l_name} when (SRAR);
		return $student_data->{$utdid}{l_name} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_gender {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{gender} when (SR);
		return $patron_data->{$utdid}{gender} when (HR);
		return "None" when (AR);
		return $student_data->{$utdid}{gender} when (SRHR);
		return $patron_data->{$utdid}{gender} when (HRAR);
		return $student_data->{$utdid}{gender} when (SRAR);
		return $student_data->{$utdid}{gender} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_birth_date {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{birth_date} when (SR);
		return $patron_data->{$utdid}{birth_date} when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{birth_date} when (SRHR);
		return $patron_data->{$utdid}{birth_date} when (HRAR);
		return $student_data->{$utdid}{birth_date} when (SRAR);
		return $student_data->{$utdid}{birth_date} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_barcode {
	my $utdid = shift;
	return $barcode_data->{$utdid}{bar_code};
}

sub get_ad1ln1 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_line1} when (SR);
		return "CAMPUS MAIL" when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_line1} when (SRHR);
		return "CAMPUS MAIL" when (HRAR);
		return $student_data->{$utdid}{address_line1} when (SRAR);
		return $student_data->{$utdid}{ad1ln1} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1ln2 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_line2} when (SR);
		return "MAIL STATION: " . $patron_data->{$utdid}{mail_station} when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_line2} when (SRHR);
		return "MAIL STATION: " . $patron_data->{$utdid}{mail_station} when (HRAR);
		return $student_data->{$utdid}{address_line2} when (SRAR);
		return $student_data->{$utdid}{address_line2} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1ln3 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return "ROOM NUMBER: " . $patron_data->{$utdid}{room_no} when (HR);
		return "" when (AR);
		return "" when (SRHR);
		return "ROOM NUMBER: " . $patron_data->{$utdid}{room_no} when (HRAR);
		return "" when (SRAR);
		return "" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1city {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_city} when (SR);
		return "RICHARDSON" when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_city} when (SRHR);
		return "RICHARDSON" when (HRAR);
		return $student_data->{$utdid}{address_city} when (SRAR);
		return $student_data->{$utdid}{address_city} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1state {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_state} when (SR);
		return "TX" when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_state} when (SRHR);
		return "TX" when (HRAR);
		return $student_data->{$utdid}{address_state} when (SRAR);
		return $student_data->{$utdid}{address_state} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1zip {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_zip} when (SR);
		return "75080" when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_zip} when (SRHR);
		return "75080" when (HRAR);
		return $student_data->{$utdid}{address_zip} when (SRAR);
		return $student_data->{$utdid}{address_zip} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad1country {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{address_country} when (SR);
		return "USA" when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{address_country} when (SRHR);
		return "USA" when (HRAR);
		return $student_data->{$utdid}{address_country} when (SRAR);
		return $student_data->{$utdid}{address_country} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2ln1 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return $patron_data->{$utdid}{address_line1} when (HR);
		return "" when (AR);
		return "CAMPUS MAIL" when (SRHR);
		return $patron_data->{$utdid}{address_line1} when (HRAR);
		return "" when (SRAR);
		return "CAMPUS MAIL" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2ln2 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return "" when (HR);
		return "" when (AR);
		return "MAIL STATION: " . $patron_data->{$utdid}{mail_station} when (SRHR);
		return "" when (HRAR);
		return "" when (SRAR);
		return "MAIL STATION: " . $patron_data->{$utdid}{mail_station} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2ln3 {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return "" when (HR);
		return "" when (AR);
		return "ROOM NUMBER: " . $patron_data->{$utdid}{room_no} when (SRHR);
		return "" when (HRAR);
		return "" when (SRAR);
		return "ROOM NUMBER: " . $patron_data->{$utdid}{room_no} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2city {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return $patron_data->{$utdid}{address_city} when (HR);
		return "" when (AR);
		return "RICHARDSON" when (SRHR);
		return $patron_data->{$utdid}{address_city} when (HRAR);
		return "" when (SRAR);
		return "RICHARDSON" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2state {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return $patron_data->{$utdid}{address_state} when (HR);
		return "" when (AR);
		return "TX" when (SRHR);
		return $patron_data->{$utdid}{address_state} when (HRAR);
		return "" when (SRAR);
		return "TX" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2zip {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return $patron_data->{$utdid}{address_zip} when (HR);
		return "" when (AR);
		return "75080" when (SRHR);
		return $patron_data->{$utdid}{address_zip} when (HRAR);
		return "" when (SRAR);
		return "75080" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_ad2country {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return "USA" when (HR);
		return "" when (AR);
		return "USA" when (SRHR);
		return "USA" when (HRAR);
		return "" when (SRAR);
		return "USA" when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_email {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return $student_data->{$utdid}{email} when (SR);
		return $patron_data->{$utdid}{email} when (HR);
		return "" when (AR);
		return $student_data->{$utdid}{email} when (SRHR);
		return $patron_data->{$utdid}{email} when (HRAR);
		return $student_data->{$utdid}{email} when (SRAR);
		return $student_data->{$utdid}{email} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_phoneno {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		return "" when (SR);
		return $patron_data->{$utdid}{extension} when (HR);
		return "" when (AR);
		return $patron_data->{$utdid}{extension} when (SRHR);
		return $patron_data->{$utdid}{extension} when (HRAR);
		return "" when (SRAR);
		return $patron_data->{$utdid}{extension} when (SRHRAR);
		default {};    ## Should not happen
	}
}

sub get_jobcode {
	my $utdid = shift;
	given ( $barcode_data->{$utdid}{present_in} ) {
		when (SR) {
			return $student_data->{$utdid}{role};
		}
		when (HR) {
			return $patron_data->{$utdid}{role};
		}
		when (AR) {
			return $course_data->{$utdid}{role};
		}
		when (SRHR) {
			my $student_role = $student_data->{$utdid}{role};
			my $patron_role  = $patron_data->{$utdid}{role};
			return $patron_role if ( $patron_role eq "vips" || $patron_role eq "utdf" || $patron_role eq "lect" );
			return $student_role if ( $student_role eq "utdd" || $student_role eq "utdm" );
			return $patron_role  if ( $patron_role  eq "libp" || $student_role eq "rsci" || $student_role eq "rets" || $student_role eq "emri" );
			return $student_role if ( $student_role eq "utdp" || $student_role eq "utdj" || $student_role eq "utds" || $student_role eq "utdu" );
			return $patron_role;    ## This will be staf.
		}
		when (HRAR) {
			my $lecture_role = $course_data->{$utdid}{role};
			my $patron_role  = $patron_data->{$utdid}{role};
			return $patron_role if ( $patron_role eq "vips" || $patron_role eq "utdf" || $patron_role eq "lect" );
			return $lecture_role;
		}
		when (SRAR) {
			my $lecture_role = $course_data->{$utdid}{role};
			return $lecture_role;
		}
		when (SRHRAR) {
			my $lecture_role = $course_data->{$utdid}{role};
			my $student_role = $student_data->{$utdid}{role};    ## We dont need this.
			my $patron_role  = $patron_data->{$utdid}{role};
			return $patron_role if ( $patron_role eq "vips" || $patron_role eq "utdf" || $patron_role eq "lect" );
			return $lecture_role;
		}
		default {
		};    ## Should not happen
	}
}

