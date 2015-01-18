package nsw::object::buildcalendar::list;

use strict;
use Carp;

sub main {
	my $s = shift;

	my @list = $s->db_q("
		SELECT co.stat_date, o.order_id, c.name, date(o.created_ts) as order_date,
			CASE WHEN c.name='Porcelain' THEN 'red' ELSE 'blue' END as color
		FROM calendar_orderitems co
			JOIN calendars c ON co.cal_id=c.cal_id
			JOIN order_items oi ON co.order_item_id=oi.order_item_id
			JOIN orders o ON oi.order_id=o.order_id
		ORDER BY stat_date, order_id
		",'arrayhash');

	my $entries = $#list;
	unless($entries) {
		$s->{content} .= 'Sorry, nothing on build calendar';
		return;
	}

	# we just need to make 2 lists
	my @red;
	my @blue;
	foreach my $ref (@list) {
		if ($ref->{color} eq 'red') {
			push @red, $ref;
		} elsif ($ref->{color} eq 'blue') {
			push @blue, $ref;
		}
	}

	my %hash = $s->db_q("
		SELECT code, content
		FROM sitecontent
		WHERE code='build_calender_header'
		",'keyval');

	$s->tt('buildcalendar/list_list.tt', { s => $s,
		hash => \%hash, 		
		red => \@red, blue => \@blue });
	
	return;

	my $start_date = $list[0]{stat_date};
	my $end_date = $list[$entries]{stat_date};
	my $months = $s->db_q("
		SELECT ((extract( year FROM date(?) ) - 
			extract( year FROM date(?) )) *12) +
			extract(MONTH FROM date(?) ) - 
			extract(MONTH FROM date(?) )
		",'scalar',
		v => [ $end_date, $start_date, $end_date, $start_date ]);

	#$s->{content} .= "$start_date $end_date $months"; return;

	my %calendar = $s->calendar($start_date,$months+1);

	# build everything into calendar
	foreach my $week (@{$calendar{weeks}}) {
		for my $d ( 0 .. 6 ) {
			next unless(defined($week->{days}{$d}));

			my $day = $week->{days}{$d}{date};

			my $n = 0;
			foreach my $ref (@list) {
				if ($ref->{stat_date} eq $day) {
					push @{$week->{days}{$d}{orderitem}}, $ref;
				}
				$n++;
			}
		}
	}

	$s->tt('buildcalendar/list.tt', { s => $s,
		hash => \%hash,
		calendar => \%calendar });
}

1;
