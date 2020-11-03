use Test::More;
use Modern::Perl;
use Data::Printer alias => 'pdump';

use_ok('Ansible::Util');
use_ok('Ansible::Util::Run');
use_ok('Ansible::Util::Vars');

done_testing();