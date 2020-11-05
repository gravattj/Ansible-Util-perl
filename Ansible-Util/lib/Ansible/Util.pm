package Ansible::Util;

=head1 NAME

Ansible::Util - Utilities for working with Ansible.

=cut

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Module::Load;

##############################################################################
# CONSTANTS
##############################################################################

with 'Ansible::Util::Roles::Constants';

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has vaultPasswordFiles => (
	is      => 'rw',
	isa     => 'ArrayRef[Str]',
	default => sub { [] },
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

##############################################################################
# CONSTRUCTOR
##############################################################################

##############################################################################
# PUBLIC METHODS
##############################################################################

method select (Str $subClass) {

	my $class = sprintf 'Ansible::Util::%s', $subClass;
	load($class);

	my %attr = $self->_dupAttributes;

	return $class->new(%attr);
}

##############################################################################
# PRIVATE METHODS
##############################################################################

method _dupAttributes {

	my %attr;
	my $meta = $self->meta;
	foreach my $a ( $meta->get_all_attributes ) {
		my $name = $a->name;
		$attr{ $a->name } = $self->$name;
	}

	return %attr;
}

1;
