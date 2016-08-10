#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.020;
use Encode qw(decode encode);
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
	my $id = 0;

	for my $line ( read_file('/home/derf/packages/hardware/var/db') ) {
		$line = decode( 'UTF-8', $line );
		chomp($line);
		if ( $line =~ $re_part ) {
			my %part = (
				amount      => $+{amount},
				description => $+{description},
				id          => $id,
				location    => $+{place},
			);
			if ( $part{amount} =~ m{ \d+ }x ) {
				$part{amount}      = int( $part{amount} );
				$part{amountIsInt} = 1;
			}
			if ( $+{tags} ) {
				$part{tags} = $+{tags};
			}
			push( @parts, \%part );
			$id++;
		}
	}
	return @parts;
}

sub write_parts {
	my (@parts) = @_;

	my $buffer = q{};

	for my $part (@parts) {
		$buffer .= "$part->{location} | $part->{amount} | $part->{description}";
		if ( $part->{tags} ) {
			$buffer .= " | $part->{tags}";
		}
		$buffer .= "\n";
	}

	write_file( '/home/derf/packages/hardware/var/db',
		encode( 'UTF-8', $buffer ) );
}

get '/' => sub {
	my ($self) = @_;

	my @parts = read_parts();

	$self->render(
		'index',
		parts => \@parts,
	);
};

post '/ajax/edit' => sub {
	my ($self) = @_;

	my $data = $self->req->params->to_hash;
	my ( $id, $amount ) = @{$data}{qw{id amount}};

	my @parts = read_parts();

	$parts[$id]{amount} = int($amount);

	write_parts(@parts);

	$self->render( json => $parts[$id] );
};

helper 'jsonify' => sub {
	my ( $self, $arg ) = @_;

	return $self->render_to_string( json => $arg );
};

app->config(
	hypnotoad => {
		listen => [ $ENV{LISTEN} // 'http://*:8098' ],
		pid_file => '/tmp/minipart.pid',
		workers  => $ENV{WORKERS} // 1,
	},
);

app->defaults( layout => 'default' );

app->start;
