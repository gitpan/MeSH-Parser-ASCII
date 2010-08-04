#!/usr/bin/perl

=head1 NAME

MeSH::Parser::ASCII - parser for the MeSH ASCII format

=head1 SYNOPSIS

	use MeSH::Parser::ASCII;
	
	# instantiate the parser
	my $parser = MeSH::Parser::ASCII->new( meshfile => 'd2010.bin' );
	
	# parse the file
	$parser->parse();
	
	# loop through all the headings
	while (my ($id, $heading)  = each %{$parser->heading} ){
		print $id . ' - ' . $heading->{label} . "\n";
		for my $synonym (@{$heading->{synonyms}}){
			print "\t$synonym\n";
		}
	}

=head1 DESCRIPTION

Parser for the MeSH ASCII format.

=over

=item  meshfile

MeSH file in ASCII format

=back

=head2 METHODS

=over

=item parse()

Parses the MeSH file and loads it into a hash ref.

=item heading

Returns a hash ref collection of all the parsed headings. Each consists of a label, 
and id and synonyms if any were available. 

Label is extracted from I<Mesh Heading> field in Descriptor Data Elements,
or I<Name of substance> in Supplementary Concept Records,
or I<Subheading> in Qualifier Data Elements.

Synonyms are only parsed for Descriptor Data Elements (I<PRINT ENTRY> and I<ENTRY> entries)

=back

=head1 AUTHOR

Tomasz Adamusiak <tomasz@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010 European Bioinformatics Institute. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it 
under GPLv3.

This software is provided "as is" without warranty of any kind.

=cut

package MeSH::Parser::ASCII;

use Moose 0.89;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $INFO, layout => '%-5p - %m%n' } );

our $VERSION = 0.01;

has 'meshfile' => ( is => 'rw', isa => 'Str', required => 1 );
has 'heading' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

sub parse() {
	my $self = shift;

	INFO 'Parsing file ' . $self->meshfile . ' ...';

	# open file
	open my $fh, '<', $self->meshfile;

	my ( $label, $id, $synonyms, $count );
	$count->{syns} = 0;

	while (<$fh>) {
		chomp;

		# initialise
		if (/^\*NEWRECORD/) {
			$synonyms = undef;
			$label    = undef;
			$id       = undef;
		}

		# save on new line
		if (/^$/) {
			LOGDIE 'Something went wrong. Could not parse heading\'s label.'
			  unless defined $label;
			$count->{headings}++;
			WARN "Duplicate heading found for $id"
			  if defined $self->heading->{$id};
			$self->heading->{$id}->{label}    = $label;
			$self->heading->{$id}->{synonyms} = $synonyms
			  if defined $synonyms;
			DEBUG $label . ' ' . $id . "\n";
			for my $syn (@$synonyms) {
				DEBUG "\t" . $syn;
				$count->{syns}++;
			}
		}

		# Mesh Heading in Descriptor Data Elements
		$label = ( split(/ = /) )[1] if /^MH = /;

		# Name of substance in Supplementary Concept Records
		$label = ( split(/ = /) )[1] if /^NM = /;

		# Subheading in Qualifier Data Elements
		$label = ( split(/ = /) )[1] if /^SH = /;

		$id = ( split(/ = /) )[1] if /^UI = /;

		# PRINT ENTRY and ENTRY are synonyms in Descriptor Data Elements
		# splits on ENTRY = , and then disregards anything after pipe |
		push @$synonyms, ( split( /\|/, ( split(/ = /) )[1] ) )[0]
		  if /^ENTRY = /;
		push @$synonyms, ( split( /\|/, ( split(/ = /) )[1] ) )[0]
		  if /^PRINT ENTRY = /;

	}
	close $fh;

	INFO "Loaded "
	  . $count->{headings}
	  . " headings and "
	  . $count->{syns}
	  . " synonyms";
	  
	  1;
}

1;
