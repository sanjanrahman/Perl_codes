#!/usr/bin/perl
use strict;
use XML::Simple;
use POSIX;
use Log::Message::Simple;
use File::Basename;

## Configs for the file paths.
my $intermediatepath    = "files/intermediate/";    ## This is the path where the logs files are checked for past's log(created by lp_new.pl). This should ideally be same as the path from lp_new.pl
my $xmlpath    = "files/xmls/";    ## Path where the xmls are created.
my $fileprefix = "lp_data.";        ## Log file prefix.
my $filesuffix = "";               ## Log file suffix.
my $delim      = "\x1f";

## Get the logging things done here.
my $LOGPATH = "files/logs/";
my $logfile = $LOGPATH . File::Basename::basename($0) . "_" . strftime ("%Y%m%d", localtime) . ".log";
open my $log, ">>", $logfile or warn "Cannot open log file $logfile";
local $Log::Message::Simple::MSG_FH = $log;
my $verbose = 1;    ## Assign 0 to turn this off.
my $DAYS_IN_PAST = 7;

my %past;                                               ## Hash used to store past's data if yesterday file is present.
my %today;                                                   ## Hash used to store today's data.

my $xml; 							## The final xml object.

msg("BEGIN", $verbose);
&get_today_past;
&populate_additional_fields;


&create_xmls;
#&create_xml(2021075338);
msg("END", $verbose);

sub populate_additional_fields {
	## This adds the below fields for each person.
	## 1) status - inactive if he is not present today but present in past, active otherwise.
	## 2) create_date - Today's date if he is new today, else nil.
	## 3) modified_date - Today's date.
	## 4) expiry_date - Today's date + 2 years
	## 5) purge_date - Today's date + 8 years

	my @dates         = localtime time;
	my $create_date   = strftime( "%Y%m%d", @dates );
	my $modified_date = strftime( "%Y%m%d", @dates );
	$dates[5] += 2;
	my $expiry_date = strftime( "%Y%m%d", @dates );
	$dates[5] += 6;
	my $purge_date = strftime( "%Y%m%d", @dates );
	my @new_today;
	my @expired_today;

	foreach my $utdid ( keys %today ) {
		$today{$utdid}{status}        = 'Active';
		$today{$utdid}{create_date}   = "";
		$today{$utdid}{expiry_date}   = $expiry_date;
		$today{$utdid}{purge_date}    = $purge_date;
		$today{$utdid}{modified_date} = $modified_date;
		if ( !exists $past{$utdid} ) {
			## He is new today.
			$today{$utdid}{create_date} = $create_date;
			push @new_today, $utdid;
		}
	}

	foreach my $utdid ( keys %past ) {
		if ( !exists $today{$utdid} ) {
			## He has expired today.
			push @expired_today, $utdid;
			$today{$utdid}                = $past{$utdid};
			$today{$utdid}{status}        = 'Inactive';
			$today{$utdid}{create_date}   = '';
			$today{$utdid}{expiry_date}   = $expiry_date;
			$today{$utdid}{purge_date}    = $purge_date;
			$today{$utdid}{modified_date} = $modified_date;
		}
	}
	msg(scalar(@new_today). " patrons are new today", $verbose);
	msg($_, $verbose) foreach @new_today;
	msg(scalar(@expired_today). " patrons were expired today", $verbose);
	msg($_, $verbose) foreach @expired_today;
}

sub load_data{
	## This just populates the hashref with the details from the file.	
	my ($hash_ref, $filepath, $needed) = @_;
	my $filepresent = 1;	
	open FILE, "<", $filepath or $filepresent = 0; 
	die "File $filepath is missing !!" if $needed and $filepresent == 0;
	if($filepresent == 1) {
		while (<FILE>) {
			my ( $utdid, $ad1city, $ad1country, $ad1ln1, $ad1ln2, $ad1ln3, $ad1state, $ad1zip, $ad2city, $ad2country, $ad2ln1, $ad2ln2, $ad2ln3, $ad2state, $ad2zip, $barcode, $birth_date, $email, $f_name, $gender, $jobcode, $l_name, $m_name, $phoneno ) = split($delim);
			$hash_ref->{$utdid}{ad1city}    = $ad1city;
			$hash_ref->{$utdid}{ad1country} = $ad1country;
			$hash_ref->{$utdid}{ad1ln1}     = $ad1ln1;
			$hash_ref->{$utdid}{ad1ln2}     = $ad1ln2;
			$hash_ref->{$utdid}{ad1ln3}     = $ad1ln3;
			$hash_ref->{$utdid}{ad1state}   = $ad1state;
			$hash_ref->{$utdid}{ad1zip}     = $ad1zip;
			$hash_ref->{$utdid}{ad2city}    = $ad2city;
			$hash_ref->{$utdid}{ad2country} = $ad2country;
			$hash_ref->{$utdid}{ad2ln1}     = $ad2ln1;
			$hash_ref->{$utdid}{ad2ln2}     = $ad2ln2;
			$hash_ref->{$utdid}{ad2ln3}     = $ad2ln3;
			$hash_ref->{$utdid}{ad2state}   = $ad2state;
			$hash_ref->{$utdid}{ad2zip}     = $ad2zip;
			$hash_ref->{$utdid}{barcode}    = $barcode;
			$hash_ref->{$utdid}{birth_date} = $birth_date;
			$hash_ref->{$utdid}{email}      = $email;
			$hash_ref->{$utdid}{f_name}     = $f_name;
			$hash_ref->{$utdid}{gender}     = $gender;
			$hash_ref->{$utdid}{jobcode}    = $jobcode;
			$hash_ref->{$utdid}{l_name}     = $l_name;
			$hash_ref->{$utdid}{m_name}     = $m_name;
			$hash_ref->{$utdid}{phoneno}    = $phoneno;
		}
		close FILE;		
	} else {
		warn "File $filepath is missing. No patrons will be expired from this file. ";
		msg("File $filepath is missing. No patrons will be expired from this file.", $verbose);		
	}	
}

sub get_today_past {
	my $today     = strftime "%Y%m%d", localtime(time);              ## Get today's date.
	my $todayfile     = $fileprefix . $today . $filesuffix;	
	load_data(\%today, $intermediatepath . $todayfile, 1);
	
	for( my $i = $DAYS_IN_PAST; $i > 0; $i-- ) {
		my $pasttime = strftime "%Y%m%d", localtime( time - ($i * 86400) );    ## Past date. Today - 86400(n) seconds.
		my $pastfile = $fileprefix . $pasttime . $filesuffix;	
		load_data(\%past, $intermediatepath . $pastfile, 0);		
	}	
}

sub create_xmls {
	## Remove any xmls from last run.
	`rm $xmlpath/*.xml`;
	## Just call create_xml for each person.
	my $count = 0;
	my $batch = 0;
	my $perbatch = 3000;
	foreach my $utdid ( keys %today ) {
		create_xml($utdid, $count);
		$count++;
		if($count % $perbatch == 0){
			$batch++;
			$count = 0;
			open my $fh, '>', $xmlpath."upload-".$batch.".xml";
			XMLout( $xml, RootName => undef, ValueAttr => { 'test' => 'testing' }, OutputFile => $fh );
			## Write to the file and close it.
			close($fh);
			$xml = undef;
		}
	}
	$batch++;
	open my $fh, '>', $xmlpath."upload-".$batch.".xml";
	XMLout( $xml, RootName => undef, ValueAttr => { 'test' => 'testing' }, OutputFile => $fh );
	## Write to the file and close it.
	close($fh);

	msg("Created ".scalar(keys %today). " entries in xml file", $verbose);
}

sub create_xml {
	## Refer XML::Simple CPAN document for the details for this xml creation API used.
	my $utdid = shift;
	my $count = shift;

	$xml->{userRecords}{xmlns}                                    = "http://com/exlibris/digitool/repository/extsystem/xmlbeans";
	$xml->{userRecords}{'xmlns:xsi'}                              = "http://www.w3.org/2001/XMLSchema-instance";
	$xml->{userRecords}{userRecord}[$count]{matchId}                      = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{status}          = [ $today{$utdid}{status} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{expiryDate}      = [ $today{$utdid}{expiry_date} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{defaultLanguage} = ['en'];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{userName}        = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{firstName}       = [ $today{$utdid}{f_name} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{lastName}        = [ $today{$utdid}{l_name} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{middleName}      = [ $today{$utdid}{m_name} ];
	#$xml->{userRecords}{userRecord[$count]}{userDetails}{gender}          = [ $today{$utdid}{gender} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{purgeDate}       = [ $today{$utdid}{purge_date} ];
	#$xml->{userRecords}{userRecord[$count]}{userDetails}{birthDate}       = [ $today{$utdid}{birth_date} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{userType}        = ['External'];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{userGroup}       = [ $today{$utdid}{jobcode} ];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{jobDescription}  = [''];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{webSiteUrl}      = [''];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{password}        = [''];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{pinNumber}       = [''];
	$xml->{userRecords}{userRecord}[$count]{userDetails}{jobTitle}        = [''];

	#$xml->{userRecords}{userRecord}[$count]{owneredEntity}[0]{creationDate}     = [ $today{$utdid}{modified_date} ];
	$xml->{userRecords}{userRecord}[$count]{owneredEntity}[0]{modificationDate} = [ $today{$utdid}{modified_date} ];
	$xml->{userRecords}{userRecord}[$count]{owneredEntity}[0]{createdBy}        = ["SYSTEM"];
	$xml->{userRecords}{userRecord}[$count]{owneredEntity}[0]{modifiedBy}       = ["SYSTEM"];

	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{type}                            = ['BARCODE'];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{note}                            = ['Test note.'];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{value}                           = [ $today{$utdid}{barcode} ];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{matchId}                         = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{owneredEntity}{modificationDate} = [ $today{$utdid}{modified_date} ];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{owneredEntity}{createdBy}        = ['EX_LIBRIS'];
	$xml->{userRecords}{userRecord}[$count]{userIdentifiers}{userIdentifier}[0]{owneredEntity}{modifiedBy}       = ['SYSTEM'];

	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{preferred}               = "true";
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{line1}                   = [ $today{$utdid}{ad1ln1} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{line2}                   = [ $today{$utdid}{ad1ln2} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{line3}                   = [ $today{$utdid}{ad1ln3} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{line4}                   = [''];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{line5}                   = [''];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{country}                 = [ $today{$utdid}{ad1country} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{city}                    = [ $today{$utdid}{ad1city} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{stateProvince}           = [ $today{$utdid}{ad1state} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{postalCode}              = [ $today{$utdid}{ad1zip} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{note}                    = ['Mailing address'];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{startDate}               = [ $today{$utdid}{modified_date} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{endDate}                 = [ $today{$utdid}{expiry_date} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{matchId}                 = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[0]{types}{userAddressTypes} = ['home'];

	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{preferred}               = "false";
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{line1}                   = [ $today{$utdid}{ad2ln1} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{line2}                   = [ $today{$utdid}{ad2ln2} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{line3}                   = [ $today{$utdid}{ad2ln3} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{line4}                   = [''];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{line5}                   = [''];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{country}                 = [ $today{$utdid}{ad2country} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{city}                    = [ $today{$utdid}{ad2city} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{stateProvince}           = [ $today{$utdid}{ad2state} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{postalCode}              = [ $today{$utdid}{ad2zip} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{note}                    = ['Mailing address'];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{startDate}               = [ $today{$utdid}{modified_date} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{endDate}                 = [ $today{$utdid}{expiry_date} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{matchId}                 = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userAddress}[1]{types}{userAddressTypes} = ['home'];

	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userEmail}{preferred}             = "true";
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userEmail}{email}                 = [ $today{$utdid}{email} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userEmail}{matchId}               = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userEmail}{description}           = ['Email address'];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userEmail}{types}{userEmailTypes} = ['personal'];

	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userPhone}{preferred}             = "true";
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userPhone}{phone}                 = [ $today{$utdid}{phoneno} ];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userPhone}{matchId}               = [$utdid];
	$xml->{userRecords}{userRecord}[$count]{userAddressList}{userPhone}{types}{userPhoneTypes} = ['home'];

}
