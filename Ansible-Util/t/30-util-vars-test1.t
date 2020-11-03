use Test::More;
use Modern::Perl;
use Data::Printer alias => 'pdump';
use Ansible::Util;

use lib 't/';
use Local::Ansible::Test1;

#########################################

use_ok('Ansible::Util::Run');

my $util = Ansible::Util->new;
ok($util);

my $vars = $util->select('Vars');
isa_ok( $vars, 'Ansible::Util::Vars' );

my $test1 = Local::Ansible::Test1->new;

SKIP: {
    skip "ansible-playbook executable not found" unless $test1->ansiblePlaybookExeExists;

    $test1->chdir;

    my $href = $vars->getVars(['states']);
    ok(exists $href->{states}->{iowa});
    ok(exists $href->{states}->{texas});
 
    $href = $vars->getVar('states.iowa');
    my @keys = keys %{ $href->{states} };
    ok(@keys == 1);
   
    $href = $vars->getVar('states.iowa.cities');
    ok(ref($href->{states}->{iowa}->{cities}) eq 'ARRAY');
  
    $href = $vars->getVar('states.iowa.cities.0');
    ok(ref($href->{states}->{iowa}->{cities}->[0]) eq 'HASH');

    $href = $vars->getVar('states.iowa.cities.0.zip_codes.0');
    ok($href->{states}->{iowa}->{cities}->[0]->{zip_codes}->[0] eq '52001');
    
    my $val = $vars->getValue('states.iowa.cities.0.zip_codes.0');
    ok($val eq '52001');
};

done_testing();
