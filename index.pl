#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.020;
use Encode qw(decode);
use File::Slurp qw(read_file write_file);

my $re_place_declaration = qr{
	^
	(?<place> \S+ )
	\s* := \s*
	(?<description> .* )
	$
}x;

my $re_part = qr{
	^
	(?<place> \S+ )
	\s* [|] \s*
	(?<amount> \S+ )
	\s* [|] \s*
	(?<description> [^|]+ )
	(?:
		\s* [|] (?<tags> .* )
	)?
	$
}x;

sub read_parts {
	my @parts;

	for my $line (read_file('/home/derf/packages/hardware/var/db')) {
		$line = decode('UTF-8', $line);
		if ($line =~ $re_place_declaration) {
		}
		elsif ($line =~ $re_part) {
			my %part = (
				location => $+{place},
				amount => $+{amount},
				description => $+{description}
			);
			push(@parts, \%part);
		}
	}
	return @parts;
}

get '/' => sub {
	my ($self) = @_;

	my @parts = read_parts();

	$self->render(
		'index',
		parts => \@parts,
	);
};

app->config(
	hypnotoad => {
		listen => [ $ENV{LISTEN} // 'http://*:8098' ],
		pid_file => '/tmp/minipart.pid',
		workers => $ENV{WORKERS} // 1,
	},
);

app->defaults( layout => 'default' );

app->start;
