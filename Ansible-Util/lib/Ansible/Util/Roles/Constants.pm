package Ansible::Util::Roles::Constants;

use Modern::Perl;
use Moose::Role;

=head1 NAME

Ansible::Util::Roles::Constants

=cut

use constant {
	ARGS_VAULT_PASS_FILE      => '--vault-password-file',
	CACHE_NS_VARS             => 'ansible-vars',
	CACHE_KEY                 => 'default',
	CMD_ANSIBLE_PLAYBOOK      => 'ansible-playbook',
	DEFAULT_CACHE_EXPIRE_SECS => 60 * 10, # 10 mins
};

1;
