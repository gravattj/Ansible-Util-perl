package Ansible::Util::Roles::Attr::VaultPasswordFiles;

use Modern::Perl;
use Moose::Role;

=head1 NAME

Ansible::Util::Roles::VaultPasswordFiles

=cut

has vaultPasswordFiles => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);


1;
