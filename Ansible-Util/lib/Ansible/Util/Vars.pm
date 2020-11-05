package Ansible::Util::Vars;

=head1 NAME

Ansible::Util::Vars - Read Ansible runtime vars into Perl

=cut

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use File::Temp;
use Hash::DotPath;
use JSON;
use YAML ();
use Ansible::Util::Run;

with 'Ansible::Util::Roles::Constants';

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

with
  'Ansible::Util::Roles::Attr::VaultPasswordFiles',
  'Util::Medley::Roles::Attributes::Cache',
  'Util::Medley::Roles::Attributes::File';

has cacheEnabled => (
	is      => 'rw',
	isa     => 'Bool',
	default => 1,
);

has cacheExpireSecs => (
	is      => 'rw',
	isa     => 'Int',
	default => sub { DEFAULT_CACHE_EXPIRE_SECS() },
);

has keepTempFiles => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

has tempDir => (
	is      => 'rw',
	isa     => 'Str',
	default => '.',
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

has _tempFiles => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

##############################################################################
# CONSTRUCTOR
##############################################################################

# uncoverable branch false count:1
method BUILD {

	$self->Cache->ns( CACHE_NS_VARS() );
	$self->Cache->expireSecs( $self->cacheExpireSecs );
	$self->Cache->enabled( $self->cacheEnabled );
}

##############################################################################
# DESTRUCTOR
##############################################################################

# uncoverable branch false count:1
method DEMOLISH {

	if ( !$self->keepTempFiles ) {
		foreach my $tempFile ( @{ $self->_tempFiles } ) {
			$self->File->unlink($tempFile);
		}
	}
}

##############################################################################
# PUBLIC METHODS
##############################################################################

# uncoverable branch false count:1
method clearCache {

	$self->Cache->clear;

	return 1;
}

# uncoverable branch false count:1
method disableCache {

	my $orig = $self->cacheEnabled;

	$self->cacheEnabled(0);
	$self->Cache->enabled( $self->cacheEnabled );

	return $orig;
}

# uncoverable branch false count:1
method enableCache {

	my $orig = $self->cacheEnabled;

	$self->cacheEnabled(1);
	$self->Cache->enabled( $self->cacheEnabled );

	return $orig;
}

method getValue (Str $path!) {

	my $href    = $self->getVar(@_);
	my $dotResp = Hash::DotPath->new($href);

	# --> Any (value @ path)
	return $dotResp->get($path);
}

method getVar (Str $path!) {

	return $self->getVars( [$path] );
}

method getVars (ArrayRef $paths!) {

	my @missing;
	my $cached = Hash::DotPath->new( $self->_getCache );

	foreach my $path (@$paths) {
		if ( !$cached->exists($path) ) {
			push @missing, $path;
		}
	}

	my $href   = $self->_getVars( \@missing );
	my $merged = $cached->merge($href);
	$self->_setCache( $merged->toHashRef );

	#
	# now extract just the requested paths because the cache might
	# have a superset of what was requested.
	#
	my $result = Hash::DotPath->new;
	foreach my $path (@$paths) {
		$result->set( $path, $merged->get($path) );
	}

	return $result->toHashRef;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

method _getTempFile (Str $suffix!) {

	my $dir = $self->tempDir;
	$self->File->mkdir($dir);

	my ( $tempFh, $tempFilename ) =
	  File::Temp::tempfile( DIR => $dir, SUFFIX => $suffix );
	close($tempFh);

	$tempFilename = sprintf '%s/%s', $dir, $self->File->basename($tempFilename);
	push @{ $self->_tempFiles }, $tempFilename;

	return $tempFilename;
}

method _getVars (ArrayRef $vars!) {

	return {} if @$vars < 1;

	#
	# save template j2 file
	#
	my $templateFilename = $self->_getTempFile('-template.j2');

	my @content;
	foreach my $var (@$vars) {
		push @content, "{{ my_vars | to_nice_json }} ";
	}

	$self->File->write( $templateFilename, join( "\n", @content ) );

	#
	# create a placeholder for the template output
	#
	my $outputFilename = $self->_getTempFile('-output.json');

	#
	# create the playbook
	#
	my $pbFilename = $self->_getTempFile('-playbook.yml');

	my $content =
	  $self->_buildPlaybook( $vars, $templateFilename, $outputFilename );

	$self->File->write( $pbFilename, $content );

	#
	# execute
	#
	my $run = Ansible::Util::Run->new(
		vaultPasswordFiles => $self->vaultPasswordFiles );

	my ( $stdout, $stderr, $exit ) =
	  $run->ansiblePlaybook( playbook => $pbFilename );
	confess $stderr if $exit;

	#
	# read the output json and put into perl var
	#
	my $json_text = $self->File->read($outputFilename);
	my $json      = JSON->new;
	my $answer    = $json->decode($json_text);

	# return answer
	return $answer;
}

method _buildPlaybookVars (ArrayRef $vars!) {

	my $dot = Hash::DotPath->new;

	foreach my $var (@$vars) {
		$dot->set( $var, sprintf '{{ %s }}', $var );
	}

	my $my_vars_yaml = YAML::Dump( $dot->toHashRef );

	my @indented;
	foreach my $line ( split /\n/, $my_vars_yaml ) {
		next if $line eq '---';    # remove new document syntax
		push @indented, sprintf '%s%s', ' ' x 6, $line;
	}

	$my_vars_yaml = join "\n", @indented;    # overwrite

	return $my_vars_yaml;
}

method _buildPlaybook (ArrayRef $vars!,
                       Str      $template_src!,
                       Str      $template_dest!) {

	my $my_vars_yaml = $self->_buildPlaybookVars($vars);

	my $content = qq{
- hosts: localhost
  connection: local
  gather_facts: yes
  
  vars:
    my_vars:
$my_vars_yaml    
  
  tasks:
    - template:
        src:  $template_src
        dest: $template_dest
        
};

	return $content;
}

method _getCache {

	my $vars = $self->Cache->get( key => CACHE_KEY() );
	if ( !$vars ) {
		return {};
	}

	return $vars;
}

method _setCache (HashRef $href!) {

	$self->Cache->set(
		key  => CACHE_KEY(),
		data => $href,
	);

	return $href;
}

1;
