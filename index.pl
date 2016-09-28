#!/usr/bin/env perl
use Mojolicious::Lite;
use 5.020;
use Encode qw(decode encode);
use File::Slurp qw(read_file write_file);
use List::Util qw(uniq);

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
	\s*
	(
		[|] \s* (?<tags> .* )
	)?
	$
}x;

my $dbfile = $ENV{MINIPART_DB};

if ( not defined $dbfile ) {
	say STDERR "Usage: MINIPART_DB=/path/to/db hypnotoad $0";
	exit 1;
}

sub read_parts {
	my @parts;
	my $id = 0;

	if ( not -e $dbfile ) {
		return ();
	}

	for my $line ( read_file($dbfile) ) {
		$line = decode( 'UTF-8', $line );
		chomp($line);
		if ( $line =~ $re_part ) {
			my %part = (
				amount      => $+{amount},
				description => $+{description},
				id          => $id,
				location    => $+{place},
			);
			if ( $+{tags} ) {
				$part{tags} = $+{tags};
			}
			if ( $part{amount} =~ m{ \d+ }x ) {
				$part{amount}      = int( $part{amount} );
				$part{amountIsInt} = 1;
			}
			$part{description} =~ s{ \s+ $ }{}x;
			push( @parts, \%part );
			$id++;
		}
	}
	return @parts;
}

sub write_parts {
	my (@parts) = @_;

	@parts = map { $_->[0] }
	  sort { $a->[1] cmp $b->[1] }
	  map { [ $_, "$_->{location}.$_->{description}" ] } @parts;

	my $buffer = q{};

	for my $part (@parts) {
		$buffer .= "$part->{location} | $part->{amount} | $part->{description}";
		if ( $part->{tags} ) {
			$buffer .= " | $part->{tags}";
		}
		$buffer .= "\n";
	}

	write_file( $dbfile, encode( 'UTF-8', $buffer ) );
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

get '/ajax/locations' => sub {
	my ($self) = @_;

	my %locations
	  = map { $_ => undef } uniq map { $_->{location} } read_parts();

	$self->render( json => \%locations );
};

get '/add' => sub {
	my ($self) = @_;

	$self->render(
		'edit',
		submit_text => 'Add',
	);
};

post '/edit' => sub {
	my ($self) = @_;

	my $data = $self->req->params->to_hash;

	if (    exists $data->{id}
		and exists $data->{action}
		and $data->{action} eq 'delete' )
	{
		# delete an existing part
		my @parts = read_parts();
		splice( @parts, $data->{id}, 1 );
		write_parts(@parts);
		$self->flash(
			'status_message' => "$data->{description} deleted successfully" );
		$self->redirect_to('/');
	}
	elsif ( exists $data->{id} and not exists $data->{location} ) {

		# fill out form to edit an existing part
		my @parts = read_parts();
		my $part  = $parts[ $data->{id} ];
		$self->param( id          => $part->{id} );
		$self->param( location    => $part->{location} );
		$self->param( amount      => $part->{amount} );
		$self->param( description => $part->{description} );
		if ( exists $part->{tags} ) {
			$self->param( tags => $part->{tags} );
		}
	}
	elsif ( exists $data->{id} and exists $data->{location} ) {

		# edit an existing part
		my @parts = read_parts();
		$parts[ $data->{id} ] = {
			amount      => $data->{amount},
			description => $data->{description},
			location    => $data->{location},
			tags        => $data->{tags},
		};
		write_parts(@parts);
		$self->flash(
			'status_message' => "$data->{description} edited successfully" );
		$self->redirect_to("/#p$data->{id}");
	}
	elsif ( exists $data->{location} and exists $data->{description} ) {

		# add a new part
		my @parts = read_parts();
		my $id    = $#parts + 1;
		push(
			@parts,
			{
				amount      => $data->{amount},
				description => $data->{description},
				id          => $id,
				location    => $data->{location},
				tags        => $data->{tags},
			}
		);
		write_parts(@parts);
		$self->flash(
			'status_message' => "$data->{description} added successfully" );
		$self->redirect_to('add');
	}
	else {
		# derp
		$self->flash( 'status_message' => 'Missing data' );
	}

	$self->render( 'edit', );
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
