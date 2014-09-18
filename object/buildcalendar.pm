package nsw::object::buildcalendar;

use strict;
use Carp;

sub config {
	my $s = shift;

	return {
		public => 1,
		site_template => 'publictemplate.tt', 
		functions => {
			list => 'List',
			},
		};
}

1;
