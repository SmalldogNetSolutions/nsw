#!/usr/bin/perl

use strict;
use Getopt::Std;
use Apache::SdnFw::lib::Core;
use Apache::SdnFw::lib::DB;
use Carp;

my %args;
getopts('vd:',\%args);

unless ($args{d}) {
	print "usage: send_calendar.pl [-v] -d database\n";
	exit;
}

my $s = Apache::SdnFw::lib::Core->new(
	uri => 'commandline',
	content_type => 'text/plain',
	env => {
		DOCUMENT_ROOT => 'commandline',
		DB_STRING => "dbname=$args{d}",
		DB_USER => 'sdnfw',
		BASE_URL => "/$args{d}",
		OBJECT_BASE => "$args{d}",
		},
	);

# we need to read the conf file to get things like CRYPT_KEY
if (-e "/usr/local/apache/conf/$args{d}.conf") {
	open F, "/usr/local/apache/conf/$args{d}.conf";
	while (my $line = <F>) {
		chomp;
		next if ($line =~ m/^#/);
		if ($line =~ m/^([^=]+)=(.+)$/) {
			$s->{env}{$1} = $2;
		}
	}
	close F;
}

$s->{dbh} = db_connect($s->{env}{DB_STRING},'sdnfw');

my %hash = $s->db_q("
	SELECT *
	FROM employees
	WHERE employee_id=1003
	",'hash');

my %site = $s->db_q("
	SELECT *
	FROM sitedata
	WHERE id=1
	",'hash');

my %content = $s->db_q("
	SELECT code, content
	FROM sitecontent
	WHERE code IN ('build_calender_email')
	",'keyval');

my @list = $s->db_q("
	SELECT ce.email, c.name as calendar_name, co.stat_date, o.order_id
	FROM calendar_orderitems co
		JOIN calendars c ON co.cal_id=c.cal_id
		JOIN order_items oi ON co.order_item_id=oi.order_item_id
		JOIN orders o ON oi.order_id=o.order_id
		JOIN customer_emails ce ON o.customer_id=ce.customer_id
	GROUP BY 1,2,3,4
	ORDER BY email, stat_date, order_id, calendar_name
	LIMIT 1
	",'arrayarrayhash',
	k => 'data',
	g => 'email',
	f => [ 'calendar_name','stat_date','order_id' ]);

foreach my $ref (@list) {
	my $body = "$content{build_calender_email}\n\n";
	
	foreach my $sref (@{$ref->{data}}) {
		$body .= "Order $sref->{order_id} - $sref->{calendar_name} - $sref->{stat_date}\n";	
	}

	$body .= "\n$hash{signature}";

	#print "$ref->{email}\n";

	$s->sendmail(to => $ref->{email},
		from => $hash{email},
		subject => $site{name},
		body => $body);

	#print $body;
}

#print <<END;
#Subject: $site{name}
#From: $hash{email}
#
#$content{build_calender_email}
#
#https://navigator.smalldognet.com/erp/buildcalendar
#
#$hash{signature}
#END
