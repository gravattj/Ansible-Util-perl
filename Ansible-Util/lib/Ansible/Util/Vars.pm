package Ansible::Util::Vars;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use File::Temp;
use Hash::DotPath;
use JSON;
use YAML ();

extends 'Ansible::Util';

with 
    'Ansible::Util::Roles::Constants',
    'Util::Medley::Roles::Attributes::Cache',
    'Util::Medley::Roles::Attributes::File';

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has keepTempFiles => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has cacheExpireSecs => (
	is      => 'rw',
	isa     => 'Int',
	default => sub { DEFAULT_CACHE_EXPIRE_SECS() },
);

has cacheEnabled => (
	is      => 'rw',
	isa     => 'Bool',
	default => 1,
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

has _tempFiles => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub {[]},
);

##############################################################################
# CONSTRUCTOR
##############################################################################

method BUILD {

	$self->Cache->ns( CACHE_NS_VARS() );
	$self->Cache->expireSecs( $self->cacheExpireSecs );
	$self->Cache->enabled( $self->cacheEnabled );
}

method DEMOLISH {

    if (!$self->keepTempFiles) {
    
        foreach my $tempFile (@{ $self->_tempFiles }) {	
            $self->File->unlink($tempFile);
        }
    }	
}

##############################################################################
# PUBLIC METHODS
##############################################################################

method clearCache {

	$self->Cache->clear;
}

method getValue (Str $path!) {

    my $href = $self->getVar(@_);
    my $dotResp = Hash::DotPath->new($href);
   
    # --> Any (value @ hash key)
    return $dotResp->get($path);  
}

method getVar (Str $path!) {

	return $self->getVars( [$path] ); # --> HashRef
}

=pod

method getVars (ArrayRef $paths!) {

	my $dotCached = $self->_cacheGet;
	
	my @missingVars;
	foreach my $dotPath (@$paths) {
		if ( !$dotCached->exists($dotPath)) {
			push @missingVars, $dotPath;
		}
	}
	
	my $dotMissing = $self->_getVars(\@missingVars);
	my $dotMerged = $dotCached->merge($dotMissing);

	if (@missingVars) {
		# only update cache if we had to fetch something
	   $self->_cacheSet($dotMerged);
	}

    my $dotResp = Hash::DotPath->new;
    
	foreach my $dotPath (@$paths) {
		if ( $dotMerged->exists( $dotPath ) ) {
		    my $value =  $dotMerged->get($dotPath);	
			$dotResp->set($dotPath, $value);
		}
	}

    # --> HashRef	
	return $dotResp->toHashRef;
}

=cut

method getVars (ArrayRef $paths!) {

    return $self->_getVars($paths);
}


##############################################################################
# PRIVATE METHODS
##############################################################################

method _cacheAdd (HashRef $newVars) {

	my $cachedVars = $self->_cacheGet;

	my $merge      = Hash::Merge->new('LEFT_PRECEDENT');
	my $mergedVars = $merge->merge( $newVars, $cachedVars );

	$self->_setCache(
		key  => CACHE_KEY(),
		data => $mergedVars
	);
}

method _getTempFile (Str $dir? = '.',
                     Str $suffix?) {
    
    my ( $tempFh, $tempFilename ) =
      File::Temp::tempfile( dir => $dir, SUFFIX => $suffix);
    close($tempFh);
    
    push @{ $self->_tempFiles }, $tempFilename;   

    return $tempFilename;	
}

method _getVars (ArrayRef $vars) {
	
	#
	# save template j2 file
	#
	#my ( $templateFh, $templateFilename ) =
	#  File::Temp::tempfile( dir => '.', SUFFIX => '-template.j2' );
	#close($templateFh);
    my $templateFilename = $self->_getTempFile('.', '-template.j2');
   
    my @content; 
	foreach my $var (@$vars) {
		push @content, "{{ my_vars | to_nice_json }} ";
	}
	
    $self->File->write( $templateFilename, join("\n", @content));

	#
	# create a placeholder for the template output
	#
#	my ( $outputFh, $outputFilename ) =
#	  File::Temp::tempfile( dir => '.', SUFFIX => '-output.json' );
#	close($outputFh);
    my $outputFilename = $self->_getTempFile('.', '-output.json');

	#
	# create the playbook
	#
#	my ( $pbFh, $pbFilename ) =
#	  File::Temp::tempfile( dir => '.', SUFFIX => '-playbook.yml' );
#	close($pbFh);
    my $pbFilename = $self->_getTempFile('.', '-playbook.yml');
    
	my $content = $self->_buildPlaybook(
		 $vars,
		 $templateFilename,
		 $outputFilename
	);

	$self->File->write( $pbFilename, $content );

	#
	# execute
	#
	my $run = $self->select('Run');
	my ( $stdout, $stderr, $exit ) =
	  $run->ansiblePlaybook( playbook => $pbFilename );
	confess $stderr if $exit;

	#
	# read the output json and put into perl var
	#
	my $json_text = $self->File->read($outputFilename);
	my $json      = JSON->new;
	my $answer    = $json->decode($json_text);

	#
	# cleanup
	#
#	if ( !$keepTempFiles ) {
#		$self->File->unlink($templateFilename);
#		$self->File->unlink($outputFilename);
#		$self->File->unlink($pbFileName);
#	}

	# return answer
	return $answer;
}

=pod

method _buildPlaybookVars (ArrayRef $vars) {

    my $dot = Hash::DotPath->new;
   
    my $href = {};
    foreach my $var (@$vars) {

        my @keys = split /\./, $var;
        my $tail = pop @keys;
        my $ptr  = $href;

        foreach my $key (@keys) {
            if ( !exists $ptr->{$key} ) {
                $ptr->{$key} = {};
            }

            $ptr = $ptr->{$key};
        }
        
        $ptr->{$tail} = sprintf '{{ %s }}', $var;
    }
    
    my $my_vars_yaml = YAML::Dump($href);

    my @indented;
    foreach my $line ( split /\n/, $my_vars_yaml ) {
        next if $line eq '---';    # remove new document syntax
        push @indented, sprintf '%s%s', ' ' x 6, $line;
    }

    
    $my_vars_yaml = join "\n", @indented;    # overwrite
   
    return $my_vars_yaml; 	
}

=cut

method _buildPlaybookVars (ArrayRef $vars) {

    my $dot = Hash::DotPath->new;
   
    foreach my $var (@$vars) {
        $dot->set($var, sprintf '{{ %s }}', $var);
    }
    
    my $my_vars_yaml = YAML::Dump($dot->toHashRef);

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

method _cacheGet {

	my $vars = $self->Cache->get( key => CACHE_KEY() );
	if ( !$vars ) {
		return Hash::DotPath->new({});
	}

    return $vars;	
}

method _cacheSet (Hash::DotHash $dot) {

    my $href = $dot->toHashRef;
    
	$self->Cache->set(
		key  => CACHE_KEY(),
		data => $href,
	);

	return $href;
}

1;
