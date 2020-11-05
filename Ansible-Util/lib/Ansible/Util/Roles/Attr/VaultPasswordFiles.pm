package Ansible::Util::Roles::Attr::VaultPasswordFiles;

=head1 NAME

Ansible::Util::Roles::VaultPasswordFiles - Utilities for working with Ansible.

=cut

use Modern::Perl;
use Moose::Role;

has vaultPasswordFiles => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);


1;
