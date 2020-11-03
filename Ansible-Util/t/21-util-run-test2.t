use Test::More;
use Modern::Perl;
use Data::Printer alias => 'pdump';
use Ansible::Util;

use lib 't/';
use Local::Ansible::Test2;

#########################################

use_ok('Ansible::Util::Run');

my $util = Ansible::Util->new;
ok($util);

my $run = $util->select('Run');
isa_ok( $run, 'Ansible::Util::Run' );

my $Test2 = Local::Ansible::Test2->new;

SKIP: {
	skip "ansible-playbook executable not found"
	  unless $Test2->ansiblePlaybookExeExists;

	$Test2->chdir;

	eval {
		my ( $stdout, $stderr, $exit ) =
		  $run->ansiblePlaybook( playbook => 'dump.yml' );
	};
	ok($@);    # no vault password files found

	$run->vaultPasswordFiles( $Test2->vaultPasswordFiles );

	eval {
		my ( $stdout, $stderr, $exit ) =
		  $run->ansiblePlaybook( playbook => 'dump.yml' );
	};
	ok( !$@ );
};

done_testing();
