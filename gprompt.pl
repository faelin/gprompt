#!/usr/bin/env perl

use warnings;
use strict;
use feature qw/ say /;

use Digest::file qw/ digest_file_hex /;
use File::Basename;
use File::Path qw/ mkpath /;
use IO::File;
use Scalar::Util qw/ looks_like_number /;
use Storable;


## GPROMPT GLOBAL CONSTANTS
our $SESSION   = getppid;
our $PWD       = $ENV{PWD};
our $HOME      = $ENV{HOME};

our $LANG      = 'perl';
our $TAGFIX    = "stable-${LANG}_";
our $VERSION   = "2019.05.24.1";
our $DATEFORM  = 'yyyy.mm.dd.';

our $CURR_SUFF  = $VERSION;
our $CURR_DATE = substr $CURR_SUFF => 0, length $DATEFORM, '';

our $SOURCE    = fileparse(__FILE__);

our $ROOT_DIR  = "$HOME/.gprompt";
our $CACHE_DIR = "$ROOT_DIR/cache";
eval { mkpath("$ROOT_DIR", 0, 0744) };
eval { mkpath("$CACHE_DIR", 0, 0700) };
die "Critical error - gprompt requires read/write access to your gprompt storage directory ('$ROOT_DIR')!" if $@;


## GPROMPT GLOBAL VARIABLES
our %git = (
              path_full   => '',
              path_root   => '',
              path_local  => '',
              
              repo_name   => '',
              parent_hash => '',
              merged_hash => '',
              
              
              origin    => '',
              branch    => '',
              commit    => '',
              
              ahead     => 0,
              behind    => 0,
              
              ignored   => 0,
              untracked => 0,
              
              staged    => 0,
              unstaged  => 0,
              
              modified  => 0,
              added     => 0,
              deleted   => 0,
              copied    => 0,
              renamed   => 0,
              updated   => 0,
           );


## cache contains the following key shortnames:
#    conf_nm   (config name)
#    conf_cs   (config file checksum)
#    gprompt   (gprompt format string)
#    up_time   (time of last update)
#    re_time   (time of last refresh)
#    disable   (gprompt on/off state)
#
my %cache = (
                 conf_nm => undef,
                 conf_cs => undef,
                 gprompt => undef,
                 gfields => undef,
                 gformat => undef,
                 up_time => 0,
                 re_time => 0,
                 disable => 0,
             );


my %settings = (
                    autosave  =>  False,
                    backup    =>  0,
                    disabled  =>  0,
                    fetch     =>  -1,
                    format    =>  '\h:\W \u\$ ',
                    relative  =>  0,
                    refresh   =>  0,
                    update    =>  600,
                    updater   =>  'ask',
                    vanilla   =>  '\h:\W \u\$ ',
               );
my $settings_match = ( join '|' => keys %settings  );


my @settings_words = (
                           'autosave',
                           'backup',
                           'fetch',
                           'format',
                           'relative',
                           'refresh',
                           'update',
                           'updater',
                           'vanilla',
                      );
my %settings_flags = (
                           a  =>  'autosave',
                           b  =>  'backup',
                           i  =>  'fetch',
                           f  =>  'format',
                           P  =>  'relative',
                           u  =>  'updater',
                           v  =>  'vanilla',
                      );
my $settings_words = ( join '|' => @settings_words  );
my $settings_flags = ( join ''  => keys %settings_flags  );

my %commands_words = (
                           generate  =>  \&generate,
                           help      =>  \&help,
                           init      =>  \&init,
                           load      =>  \&load,
                           on        =>  \&on_off,
                           off       =>  \&on_off,
                           print     =>  \&print,
                           reload    =>  \&reload,
                           reset     =>  \&reset,
                           save      =>  \&save,
                           update    =>  \&update,
                           version   =>  \&version,
                      );
my %commands_flags = (
                           g  =>  \&generate,
                           h  =>  \&help,
                           I  =>  \&init,
                           l  =>  \&load,
                           o  =>  \&on_off,
                           p  =>  \&print,
                           r  =>  \&reload,
                           R  =>  \&reset,
                           s  =>  \&save,
                           U  =>  \&update,
                      );
my $commands_words = ( join '|' => keys %commands_words  );
my $commands_flags = ( join ''  => keys %commands_flags  );


# ##
# # my @man_pattern=(
# #                   NAME => [ $name_text ],
# #                   VERSION => [ $vers_text ],
# #                   SYNOPSIS => [ $uses_text, $help_text ],
# #                   CONFIGURATION => [ $conf_text ],
# #                   COMMANDS => [
# #                                    $coms_text{init},
# #                                    $coms_text{off},
# #                                    $coms_text{reset},
# #                                    $coms_text{load},
# #                                    $coms_text{save},
# #                                    $coms_text{update},
# #                                    $coms_text{version},
# #                                ],
# #                   OPTIONS => [ $optn_text ],
# #                   EXIT => [ $exit_text ],
# #                   EXAMPLES => [ $exam_text ],
# #               );
# #
# #
# #


my %man_sects = (
                    'NAME'           =>  1,
                    'VERSION'        =>  2,
                    'SYNOPSIS'       =>  3,
                    'CONFIGURATION'  =>  4,
                    'SETTINGS'       =>  5,
                    'COMMANDS'       =>  6,
                    'FORMATTING'     =>  7,
                    'EXIT CODES'     =>  8,
                    'EXAMPLES'       =>  9,
                );
my $help_msg = "Try 'gprompt help' to learn what you can do with gprompt!";


## ---------------- ##
##   gprompt main
## ---------------- ##


# `updater_loop &> /dev/null`
# `updater_loop_id=$!`

gprompt( @ARGV );
    

my $VERSION_patt = qr/  \d{4}\.\d{2}(\.\d{2})+  ( \(\w+\) )?  /;
my $setting_patt = qr/  @  [^\s:]+  (:[^\s:]+)*  /x;
my $command_patt = qr/^(?:
                                ## configuration settings
                           |      (?<set_word>  $settings_words   )
                           |  --  (?<set_optn>  $settings_words   )  (=(?<value>.*))?
                           |   -  (?<set_flag> [$settings_flags]  )
                           
                                ## commands
                           |      (?<com_word>  $commands_words   )
                           |   -  (?<com_flag> [$commands_flags]+ )
                        )$/x;

## argument-parser
#
sub gprompt (@) {
    my @args = @_;
    my (%actions, $errors);

    ## iterate over all args
    for (my $i = 0; $i < scalar @args; $i++) {
        
        my  ( $j, $word, $flag, $optn, $value );  # reset argument matches
        
        if ( $args[$i] =~ $command_patt ) {
            ( $j, $word, $flag )  =  ( $i, $+{com_word}, $+{com_flag} );
            
            
            if ( $word ) {
                
                if ( $word eq 'save' or $word eq 'load' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] eq '-f';
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $setting_patt $/x;
                } elsif ( $word eq 'update' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^(?:  --list  |  $VERSION_patt  )$/x;
                } elsif ( $word eq 'help' ) {
                    $j++  if  $args[$j+1];
                } elsif ( $word eq 'init' ) {
                    $j++  if  $args[$j+1];
                }
                
                if ( $i < $j ) {
                    $commands_words{ $+{com_word} }->( @args[ ++$i .. $j ] );
                    $i = $j;
                } else {
                    $commands_words{ $+{com_word} }->();
                }
                
                
            } elsif ( $flag ) {
                
                if ( $flag eq 's' or $flag eq 'l' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $setting_patt $/x;
                } elsif ( $flag eq 'u' ) {
                    $j++  if  $args[$j+1]  and  $args[$j+1] =~ /^ $VERSION_patt $/x;
                } elsif ( $flag eq 'h' ) {
                    $j++  if  $args[$j+1];
                }
                
                if ( $i < $j ) {
                    $commands_flags{ $+{com_flag} }->( @args[ ++$i .. $j ] );
                    $i = $j;
                } else {
                    $commands_flags{ $+{com_flag} }->();
                }
                
                
            } else {
                ( $j, $word, $flag, $optn, $value )  =  ( $i, $+{set_word}, $+{set_flag}, $+{set_optn}, $+{value} );
                
                if ( $word  and  $args[$i+2]  and  $args[$i + 1] eq '-s' ) {
                    $j = $i + 2;
                } elsif ( $word  and  $args[$i+1] ) {
                    $j = $i + 1;
                }
                
                if ( $word and $args[$i+1] ) {
                    __get_set_config( $word, @args[ ++$i .. $j ] );
                    $i = $j;
                } elsif ( $flag )  {
                    __get_set_config( $settings_flags{ $flag }, $args[ ++$i ] );
                } elsif ( $value ) {
                    __get_set_config( $optn, $value );
                } elsif ( $optn ) {
                    __get_set_config( $optn );
                } elsif ( $word ) {
                    __get_set_config( $word );
                }
            }
            
            
        } else {
            
            ## print error message for any gprompt argument that seems invalid.
            $errors++;
            say "\nUnrecognized argument '$args[$i]'.\n";
        }
    }
    
    exit 1 if $errors;
}



## --------------------- ##
##   gprompt utilities
## --------------------- ##


##
#
sub generate () {
    
}

## Generates a formatted help-text
#
sub help (@) {
    my @args = @_;
      
    # return say __wrap_text( \%man_sects ) unless scalar @args;
    
    # for my $query (@args) {
    #        if  ( defined $coms_sect{$query} )  {   say __wrap_text( $coms_sect{$query} )    }
    #     elsif  ( defined $optn_sect{$query} )  {   say __wrap_text( $optn_sect{$query} )    }
    #     elsif  ( defined $man_sects{$query} )  {   say __wrap_text( $man_sects{$query} )    }
    #     else   { say __wrap_text( "\nThere is no documentation availabe for '$query'.\n" )  }
    # }
}

## Prepares a new session to use gprompt
#    1. clears the session-cache namespace
#    2. loads the named config (uses the default config if no name is provided)
#
sub init (;$) {
    my $name = shift;
    $name = $name || 'default';
    
    &__clear_session_caches();
    
    ## load the named configuration-file
    &load('-f', $name);
}

## Reads the currently stored gprompt definitions from the gprompt conf file
#      • if the conf file cannot be found, gprompt will reset the existing gprompt definitions and store them to disk
#      • only the first instance of each definition will be used
#
sub load (;$$) {
    my ($option, $target) = @_;
       ($target, $option) = ($option, $target)  unless  $option eq '-f';  # swap $option and $name unless $option is valid
    
    $target = 'default' unless defined $target;
    
    my ($name, $conf, $sect) = split /@|:/ => $target;
    
    $name = ($name || $conf);
    
    my %loaded = &__load_by_name( $name, $option );
    
    if ( $sect ) {
        $settings{$sect} = $loaded{$sect};
    } else {
        $settings{$_} = $loaded{$_} for keys %loaded;
    }

    ## store the newly loaded configuration in a session cache
    &__save_cache();
}

## Activates/deactivates the named config file
#    • if no name is provided, then only the current session will be modified
#    • when deactivated, `gprompt generate` will print the 'vanilla' prompt
#
sub on_off (;$) {
  $cache{disable} = !$cache{disable};
  &__save_cache();
}

## Prints a formatted list of the current gprompt configuration settings
#
sub print (;$) {
    print for __format_print();
}

## Resets the current gprompt configuration settings back to the default configuration
#
sub reload () {
    load '-f' => 'default'
}

## Resets the gprompt 'default' configuration settings back to the hard-coded default values
#      clears all currently unused caches
#
sub reset () {
  &__prune_caches();
    
  $settings{autosave}  =  0;
  $settings{backup}    =  0;
  $settings{disabled}  =  0;
  $settings{format}    =  '{\c{1;93}[\c22{%r}:\c1{%b}{\c91-{%-}}{\c92+{%+}}{ {\c96<{%s}>}{\c95({%u})}}\c93]\c0}%d $>';
  $settings{relative}  =  0;
  $settings{vanilla}   =  '\h:\W \u\$ ';
  $settings{fetch}     =  -1;
  $settings{updater}   =  'ask';

  &save('default');
}

## Stores the current gprompt config into a save file
#    prompts user for overwrite-permission if a config file with the given $name already exists.
#
sub save ($;$) {
    my ($flag, $name) = @_;
       ($name, $flag) = ($flag, $name)  unless  $flag eq '-f';  # swap $flag and $name unless $flag is valid

    # confirm overwrite if targetted save-file already exists
    if ( $flag ne '-f'  and  -f "$ROOT_DIR/$name.conf" ) {
        print "There is already a saved config with the name '$name'. Do you want to overwrite it? [yN]: ";
        until ( <> =~ /^((?<yes>[Yy](es)?)|(?<no>([Nn]o?)?))$/x) {
            print "\tunrecognized response; do you want to overwrite the '$name' config file? [yN]: ";
        }
        return 0 if defined $+{no};
        
        if ( lc $name eq 'default' ) {
            print "This will modify the gprompt default configuration file. Are you sure you want to continue? [yN]: ";
            until ( <> =~ /^((?<yes>[Yy](es)?)|(?<no>([Nn]o?)?))$/x) {
                print "\tunrecognized response; are you sure you want to overwrite the default configuration file? [yN]: ";
            }
            return 0 if defined $+{no};
        }
    }
    
    
    # write save to file
    open( my $conf_fh, '>' => "$ROOT_DIR/$name.conf" )
        or say "Error - could not save to configuration file '$ROOT_DIR/$name.conf': $!";
    
    print $conf_fh for __format_print();

    close $conf_fh;
    
    
    # store current save-state in cache
    $cache{conf_cs} = __generate_checksum($name);
    $cache{conf_nm} = $name;
    __save_cache();
}

## Immediately attempts to update the gprompt source-files
#
sub update (;$) {
    my $request  = shift;
    
    return say join "\n" => __list_versions()  if  $request eq '--list';
    
    my $tag = $request  ||  [ __updater_check() ]->[0];
    # `git -C $SOURCE pull https://github.com/faelin/gprompt.git stable-${LANG}_$request`
    
    die "Failed to update! No such version '$VERSION'." if $!;
}

## Prints the gprompt version string
#
sub version () {
    say "gprompt release stable-${LANG}_$VERSION";
}



## ----------------------------- ##
##   gprompt private functions
## ----------------------------- ##


sub __format_print () {
    my @lines;
    
    for my $key ( keys %settings ) {
        my $param = $settings{$key};
        
        push @lines => sprintf( "%-10s %s\n" => "$key:", ($param =~ /^ -?\d+ $/x ? $param : "'$param'") );
    }
    
    return @lines;
}


sub __generate_checksum (;$) {
    my $name = shift || 'default';
    
    return digest_file_hex( "$ROOT_DIR/$name.conf" => 'SHA-1');
}

## Sorts cache-files by name and then by suffix, numerically
#
sub cache_sort {
                      my ( $a_name, undef, $a_suff ) = fileparse( $a => qr/\d+$/ );
                      my ( $b_name, undef, $b_suff ) = fileparse( $b => qr/\d+$/ );
                            # for fileparse, suffix-pattern MUST NOT include the '.', or suffixes will be compared as decimals (i.e. '.10 <=> .1' )
                      
                      my $SESSION_cmp = $a_name <=> $b_name;
                      
                      return ($SESSION_cmp or $a_suff <=> $b_suff);
                };

## Loads the latest cache for the specified session (defaults to current session)
#    loads config from the default config-file if no cache can be found
#
sub __load_cache (;$) {
    my $id = shift || $SESSION;
    my @cache_list;
    
    ## list of all caches for the current session id
    ##     (session = ppid of script process)
    @cache_list = sort cache_sort glob "$CACHE_DIR/$id.*";
    
    load() unless scalar @cache_list;
    
    ## load the highest-numbered (e.g. the most recent) cache for the current session
    %cache = %{ retrieve(  $cache_list[-1]  ) };
    
    load() if $cache{conf_cs} ne __generate_checksum( $cache{conf_nm} );
}

## Clears existing cache files for the specified session before saving a new cache file (defaults to current session)
#
sub __save_cache (;$) {
    my $id = shift || $SESSION;
    my (@cache_list, $name, $suffix);
       
    ## remove all non-locked caches for the current session before trying to save the new cache
    &__clear_session_caches();
    
    ## list of all caches for the current session id
    ##     (session = ppid of script process)
    @cache_list = sort cache_sort glob "$CACHE_DIR/$id.*";
    
    ## increment the suffix of the highest-numbered (e.g. the most recent) cache for the current session by one
    ##    then store the current session-cache under the new suffix
    ($name, undef, $suffix) = fileparse( $cache_list[-1] => qr/\d+$/ ) if scalar @cache_list;
    $suffix++;
    store \%cache => "$CACHE_DIR/$name.$suffix";
}

## Remove any cache-file whose id or 'session number' (ppid of this process) is no longer in use
#
sub __clear_session_caches (;$) {
    my $id = shift || $SESSION;
    
    unlink for glob "$CACHE_DIR/$id.*";
}

## Remove unused cache-files
#
sub __prune_caches () {
    my ($cache, $name);
    
    ## remove any cache-file whose id or 'session number' (ppid of this process) is no longer in use
    for my $cache ( glob "$CACHE_DIR/*.*" ) {
        $name = fileparse( $cache => qr/\.\d+$/ );
        
        unlink $cache unless `ps -o command= -c` =~ /  bash  |  (c|k|tc|z)? sh  /x;
    }
}

## Verify that the provided $val is a valid argument for the config option $key
#    sets $val to undef if value doesn't reflect accepted values for the current $key
#
sub __accept_parameters ($$) {
    my ($key, $val) = @_;
    
    if ( $key eq 'autosave' ) {
        $val = 1 if lc $val eq 'true';
        $val = 0 if lc $val eq 'false';
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'backup' ) {
        $val = undef unless $val =~ /^ -?\d+ $/x;
    } elsif ( $key eq 'disabled' ) {
        $val = 1 if lc $val eq 'true';
        $val = 0 if lc $val eq 'false';
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'fetch' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'format' ) {
        $val = undef unless $val;
    } elsif ( $key eq 'relative' ) {
        $val = 1 if lc $val =~ /^ rel(ative)? $/x;
        $val = 0 if lc $val =~ /^ abs(olute)? $/x;
        $val = undef unless $val =~ /^ ( 0 | 1 ) $/x;
    } elsif ( $key eq 'refresh' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'update' ) {
        $val = undef unless $val =~ /^ \d+ $/x;
    } elsif ( $key eq 'updater' ) {
        $val =  1 if lc $val =~ /^ auto(matic)? $/x;
        $val =  0 if lc $val =~ /^ ( ask | default ) $/x;
        $val = -1 if lc $val =~ /^ ( supress | ignore | never ) $/x;
        $val = undef unless $val =~ /^ ( -1 | 0 | 1 ) $/x;
    } elsif ( $key eq 'vanilla' ) {
        $val = undef unless $val;
    } else {
        return 'error';
    }
    
    return $val;
}

## Loads the config file indicated by the provided $name (loads the default config if no name is provided)
#
sub __load_by_name (@) {
    my ($name, $option) = @_;    
    $name = (lc $name or 'default');
    
    open( my $conf_fh, '<' => "$ROOT_DIR/$name.conf" )
        or say "Error - could not load configuration file '$ROOT_DIR/$name.conf': $!" and &reset();

    for (<$conf_fh>) {
        next if /^ \s* #/x;
        
        my ($key, $val) = /^ (\w+): \h+ (.*) $/x;
     
        $key = lc $key;
        $val = &__accept_parameters( $key => $val );
        
        say "Error - invalid configuration option '$key' at '$name.conf' line ${.}."
            and next
            if $val eq 'error';
            
        say "Error - configuration option '$key' requires a valid argument at '$name.conf' line ${.}."
            and next
            unless defined $val;
        
        $settings{$key} = $val;
    }
    close $conf_fh;
}

## Sets the indicated gprompt config definition
#
sub __get_set_config ($@) {
    my ($key, $opt, $val) = @_;
       ($val, $opt) = ($opt, $val)  unless  $opt eq '-s';  # swap $flag and $name unless $flag is valid
    
    return say "gprompt $key is currently set to '$settings{$key}'"  unless  $val;
     
    $key = lc $key;
    $val = &__accept_parameters( $key => $val );

    ## set $val to undef if value doesn't reflect accepted values for the current $key
    say "Warning - '$val' does not interact with git. $help_msg\n"  if  $key eq 'format' and $val !~ / (?<!\\) ( { | %[\w!?^~+-] ) /x;

    return say "Error - invalid argument for configuration option '$key'. $help_msg"  unless  $val;
    
    $settings{$key} = $val;
    &save( $cache{conf_nm} ) if $opt eq '-s';
}



# sub __wrap_text {
#     my ( $input ) = shift;
#     my $cols  = `tput cols`;
#     my ( $filler, $unwrapped;
    
#     my ( $body, $wrapped, $unwrapped )
#     if ( ref $input eq 'ARRAY' ) {
#         foreach $section ( @$input ) {
#             if ( ref $section eq 'ARRAY' ) {
#                 foreach $subsec ( @$section ) {
#                     @stack = split '\b' => ( $subsec =~ s/\n/ /r );
#                     my $level = 0;
#                     my $body = '';
#                     for (my $i; $i <= $#stack; $i++) {
#                         my $word = '';
#                         if      ( $stack[$i] eq '[' ) {
#                             $level++ or $word .= $stack[$i]
#                         } elsif ( $stack[$i] eq ']' ) {
#                             $level-- or $word .= $stack[$i]
#                         } elsif (    $level > 0     ) {
#                             $word .= $stack[$i]
#                         }
                        
#                         if ((length $word + length $body) < ($cols - 1)) {
#                             $body .= $word 
#                         } else {
#                             $body .= "\$word"
#                         }
#                     }
                    
#                     $prepped = ''
#                 }
#             else {
#                 $unwrapped = ( $section =~ s/\n/ /r );
#                 $prepped = $unwrapped;
#             }
            
#             $wrapped = $prepped;
#         }
#     } else {
#         $wrapped = ( $input =~ s/\n/ /r );
#     }

#     return $wrapped; 
# }



## runs in the background, exports a flag when an update is needed
#
sub __updater_loop () {
}


## lists the existing releases of gprompt
#
sub __list_versions () {
    my @versions = split /\n/ => `git tag -l "stable-perl_*"`;
    
    return sort {
                    my $a_suff = substr( $a => length $TAGFIX );
                    my $b_suff = substr( $b => length $TAGFIX );
                    
                    my $a_date = substr( $a_suff => 0, length $DATEFORM, '' );
                    my $b_date = substr( $b_suff => 0, length $DATEFORM, '' );
                    
                    return ($b_date cmp $a_date or $b_suff <=> $a_suff);
                } @versions;
}


## lists the available updates (updates found after the current local version)
#
sub __updater_check () {
    my @versions;

    for my $check ( __list_versions() ) {
        my $check_suff = substr $check => length $TAGFIX;
        my $check_date = substr $check_suff => 0, length $DATEFORM, '';
        
        push @versions => $check if ($CURR_DATE < $check_date or $CURR_SUFF < $check_suff)
    }
    
    return @versions;
}



## determines what to do when an update is ready (ask/auto/suppress)
#
sub __updater_mode () {
}



## -------------------------- ##
##   gprompt core functions
## -------------------------- ##

## Updates gprompt, does not provide output
#     returns 0 before git-status variables would be updated, if CWD is not a git repo
#
sub __git_status () {
    my @repo_status;

    # path_full      repo_name       origin     ahead     staged     ignored      modified
    # path_root      parent_hash     branch     behind    unstaged   untracked    added
    # path_local     merged_hash     commit                                       deleted
    #                                                                             copied
    #                                                                             renamed
    #     
    
    $git{path_full}  =  $settings{relative} ? $PWD =~ s!^ $HOME (?= $ | /)!~/!rx : $PWD;
    
    my $time = time;
    if ( $settings{refresh} and $time - $cache{re_time} > $settings{refresh} ) {
        @repo_status  =  split /\n/ => `git status --branch --untracked-files --ignored --porcelain=2 2>/dev/null`;
    }
    
    if ( scalar @repo_status ) {
        
        ## name of repo origin
        $git{repo_name}  =  fileparse `git rev-parse --show-toplevel 2>/dev/null`;
        @git{qw/path_root path_local/}  =  $git{path_full} =~ m|^ (.*) /$git{repo_name} (/.*)? $|x;

        ## looks like:
        ##   '<parent1 short-SHA> <parent2 short-SHA>'
        @git{qw/parent_hash merged_hash/}  = (`git show -s --format='%p' HEAD 2>/dev/null` || "") =~ m!^(\w+) \s* (\w*)$!x;
        
        for my $item ( @repo_status ) {
                
            ## branch-status header looks like:
            ##   '# branch.oid <commit> | (initial)'        Current commit.
            ##   '# branch.head <branch> | (detached)'      Current branch.
            ##   '# branch.upstream <upstream_branch>'      If upstream is set.
            ##   '# branch.ab +<ahead> -<behind>'           If upstream is set and the commit is present.
            my $header_pattern = qr/    ^
                                        \# \h+ branch\.  
                                        (?:
                                              (?<ab> ab )
                                            | (?<comm> oid )
                                            | (?<head> head )
                                            | (?<orig> upstream )
                                        )
                                        \h++
                                        (?:
                                            (?(<ab>) \+(?<a> \d+) \h+ \-(?<b> \d+)
                                                | (?(<comm>) (?<commit> [[:xdigit:]]{5,40})
                                                    | (?(<head>) (?<branch> .+)
                                                        | (?(<orig>) (?<stream> .+))
                                                    )
                                                )
                                            )
                                        )
                                        $
                                   /;
            
            if ( $item =~ /$header_pattern/ ) {
                
                $git{origin} = $+{stream} and next  if  $+{orig};
                $git{branch} = $+{branch} and next  if  $+{head};
                $git{commit} = $+{commit} and next  if  $+{comm};
                
                @git{qw/ahead behind/} = ( $+{a}, $+{b} ) and next  if  $+{ab};
            }
            
            
            ## file-status lines ref:
            ##   M = modified
            ##   A = added
            ##   D = deleted
            ##   C = copied
            ##   R = renamed
            ##   U = updated but unmerged
            ##   ! = ignored
            ##   ? = untracked
            my $file_pattern = qr/^[12u] \h++ (?<st> [MADCRU?!.] ) (?<un> (?&st) )/;
            
            if ( $item =~ /$file_pattern/x ) {
                $git{ignored   }++ and next  if  $+{st} eq '!';
                $git{untracked }++ and next  if  $+{st} eq '?';
                
                $git{staged   }++  if  $+{st};
                $git{unstaged }++  if  $+{un};
                
                $git{modified }++ and next  if  $+{un} eq 'M';
                $git{added    }++ and next  if  $+{un} eq 'A';
                $git{deleted  }++ and next  if  $+{un} eq 'D';
                $git{copied   }++ and next  if  $+{un} eq 'C';
                $git{renamed  }++ and next  if  $+{un} eq 'R';
                $git{updated  }++ and next  if  $+{un} eq 'U';
            }
        }

    } else {
        
        $git{path_local} = $git{path_full};
        
    }
}


## Replaces gprompt-specific escapes with printf-parsible ANSI color escape wrapped in PS1-parsible non-printing-characters brackets
#     exclamation points ('!') in  sed  substitutions are purely to increase legibility amonst a lot of backslashes
#
sub parse_format () {
    my @stack = split "\b" => $cache{gformat};

    my $parsed = '';

    $parsed =~ s/%([\w]+|[\w?!~^+-])/%{$1}/g;  # wrap all formatting codes in curly braces ('{}')
    $parsed =~ s/\\c(\d+)(?![\d;])/\\c{$1}/g;  # wrap all color codes in curly braces ('{}')
                  
    $parsed =~ s/\\\[/\x{01}/g;  # replace all opening non-printing-character escapes ('\[') with the unicode start-of-header character
    $parsed =~ s/\\\]/\x{02}/g;  # replace all closing non-printing-character escapes ('\]') with the unicode start-of-text character
    $parsed =~ s/\\e/\x{1B}/g;   # replace all ANSI escape characters ('\e') with the unicode ESC character

    #$parsed =~ s/\\t<([[:digit:]]+)>/$(tput \1)/xg;  # reformat user tput-codes into tput commands


    ## merge all parallel color format markers
    while ( $parsed =~ s/\\c  (?| (?<l>\d+) | {(?<l>[\d;]+)} )  (?<s>\h*)  \\c  (?| (?<r>\d+) | {(?<r>[\d;]+)} )/$+{s}\\c{$+{l};$+{r}}/gx ){};
    $parsed =~ s/\\c  (?| (\d+) | {([\d;]+)} )/\x{1B}\x{5B}$1m/gx;  # reformat user color-codes into ANSI valid escapes
    $parsed =~ s/(\x{1B}\x{5B}[\d;]+m)/\x{01}$1\x{02}/gx;  # wrap all ANSI color-escapes in non-printing-character escapes


    ## this chunk condenses all parallel ANSI color-escapes and redundant non-printing-character escapes
    #
    while ( $parsed =~ s/ \x{1B}\x{5B}([\d;]+)m\x{1B}\x{5B}([\d;]+)m  /  \x{1B}\x{5B}$1;$2m /gx ){}
    while ( $parsed =~ s/ \x{01} (\x{1B}\x{5B}[\d;]+m) \x{02}  /  \x{01}$1\x{02} /gx ){}
    while ( $parsed =~ s/ \x{01}\x{1B}\x{5B} ([\d;]+)m  \x{02}\x{01}\x{1B}\x{5B} ([\d;]+)m \x{02}  /  \x{01}\x{03}\x{5B}$1;$2m\x{02} /gx ){}

    return $parsed;
}


## Outputs the a populated git-prompt based on the contents of FORMAT (see the `set_format` function description for more information)
#
sub populate_prompt {
    git_status();


    # path_full     origin     parent_hash     ahead     staged      ignored      modified
    # path_root     repo       merged_hash     behind    unstaged    untracked    added
    # path_local    branch                                                        deleted
    #               commit                                                        copied
    #                                                                             renamed
    #                                                                             updated


    my $prompt = parse_format();

    # if in a git-repo, populate all format-strings
    if ( $git{repo_name} ) {
        
        ## DIRECTORY INFO
        s/%((?<b>  {  )?   ( (parent_)?p(ath)?               )   (?(<b>)  }  ))/  $git{path_root}    /gx;
        s/%((?<b>  {  )?   ( f(ull(_path)?)?                 )   (?(<b>)  }  ))/  $git{path_full}    /gx;
        s/%((?<b>  {  )?   ( d(ir(ectory)?)? | local(_path)? )   (?(<b>)  }  ))/  $git{path_local}   /gx;

        ## REPO INFO
        s/%((?<b>  {  )?      ( r(epo)?                   )      (?(<b>)  }  ))/  $git{repo}         /gx;
        s/%((?<b>  {  )?      ( b(ranch)?                 )      (?(<b>)  }  ))/  $git{branch}       /gx;
        s/%((?<b>  {  )?      ( c(om(mit)?)? | hash | sha )      (?(<b>)  }  ))/  $git{commit}       /gx;

        ## BRANCH STATE
        s/%((?<b>  {  )?            ( \+  |  ahead  )            (?(<b>)  }  ))/  $git{ahead}        /gx;
        s/%((?<b>  {  )?            ( \-  |  behind )            (?(<b>)  }  ))/  $git{behind}       /gx;
        s/%((?<b>  {  )?            ( \~  |  parent )            (?(<b>)  }  ))/  $git{parent_hash}  /gx;
        s/%((?<b>  {  )?            ( \^  |  merged )            (?(<b>)  }  ))/  $git{merged_hash}  /gx;

        ## FILE STATUS MODES
        s/%((?<b>  {  )?            ( s  | staged    )           (?(<b>)  }  ))/  $git{staged}       /gx;
        s/%((?<b>  {  )?            ( u  | unstaged  )           (?(<b>)  }  ))/  $git{unstaged}     /gx;
        s/%((?<b>  {  )?            ( \! | ignored   )           (?(<b>)  }  ))/  $git{ignored}      /gx;
        s/%((?<b>  {  )?            ( \? | untracked )           (?(<b>)  }  ))/  $git{untracked}    /gx;

        ## FILE STATUS COUNTS
        s/%((?<b>  {  )?             ( mod(ified)? )             (?(<b>)  }  ))/  $git{modified}     /gx;
        s/%((?<b>  {  )?             ( add(ed)?    )             (?(<b>)  }  ))/  $git{added}        /gx;
        s/%((?<b>  {  )?             ( del(eted)?  )             (?(<b>)  }  ))/  $git{deleted}      /gx;
        s/%((?<b>  {  )?             ( rem(oved)?  )             (?(<b>)  }  ))/  $git{deleted}      /gx;
        s/%((?<b>  {  )?             ( cop(ied)?   )             (?(<b>)  }  ))/  $git{copied}       /gx;
        s/%((?<b>  {  )?             ( re(named)?  )             (?(<b>)  }  ))/  $git{renamed}      /gx;
        s/%((?<b>  {  )?             ( up(dated)?  )             (?(<b>)  }  ))/  $git{updated}      /gx;
        s/%((?<b>  {  )?             ( un(merged)? )             (?(<b>)  }  ))/  $git{updated}      /gx;
        
    } else {
        ## if not a git-repo, strip all remaining formatting characters except for  %d
        sed -E "
                s/%{f(ull(_path)?)?}/%{full_path}/g;    s|%full_path|$full_path|g;

                s/%([[:alnum:]]+|[?!~^+-]|{[[:alnum:]]+})//g;

               " <<< "$string"

        ## strip all curly-brace wrapped content, recursively from the inside out
        while [[ $( grep -m 1 -E '(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}' <<< "$string" ) ]]
        do
            string="$( $string =~ s/(^|[^\\]){([^\\{}]+|\\[^{}]|\\[{}])*}/\1/g  )"
        done
    }
}

## Removes blank/useless values wrapped in curly-braces, then subsequently removes ALL unescaped curly-braces!
#     blank/useless is defined as any value that DOES NOT contain non-formatting alphanumeric characters
#
sub cleanup_prompt {
  local string=$1

  ## strip all blank/useless curly-brace wrapped content, recursively from the inside out
  while [[ $( grep -m 1 -E '(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}' <<< "$string" ) ]]
  do
    string="$( $string =~ s/(^|[^\\]){((\\001\\033\[[[:digit:];]+m\\002|\\c([[:digit:]]+|{[[:digit:];]+})|%[[:alpha:]~+]|[^{}[:alnum:]]*)+|[[:blank:]]+)}/\1/g  )"
  done

  ## strip all non-escaped curly braces, from left to right
  while [[ $( grep -m 1 -E '(^|[^\\])[{}]' <<< "$string" ) ]]
  do
    string="$( $string =~ s/(^|[^\\])[{}]/\1/g  )"
  done

  echo "$string"
}

## Generates a fully formatted/colored/populated git-prompt that can be fed directly into your shell prompt variable
#     intended usage is   export PS1='$( generate )'   or equivalent
#
sub generate {
    grpompt_reset unless __load(getppid);
    
  local string=`cleanup_prompt "$( populate_prompt )"`

  # this chunk formates the gprompt wrapper variables, which are used to pad the gprompt string
  #     for more info, see the   set_wrapper()   description
  local wrapper_length=${#WRAPPER}
  local wrapper_midpoint=$(($wrapper_length/2))
  local wrapper_left
  local wrapper_right

  if [ $wrapper_midpoint -gt 0 ]
  then
    wrapper_left=$( echo "${WRAPPER:0:$wrapper_midpoint}" )
    wrapper_right=$( echo "${WRAPPER:$wrapper_midpoint:$wrapper_length}" )
  else
    wrapper_left="${WRAPPER}"
    wrapper_right="${WRAPPER}"
  fi

  printf "${wrapper_left}${string}${wrapper_right}"
}



