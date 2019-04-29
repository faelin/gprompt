my $name_text = <<EO_NAME;
gprompt -- customizable git status in your command prompt!
EO_NAME

my $vers_text = <<EO_VERS;
gprompt $gprompt_version
EO_VERS

my $uses_text = <<EO_USES;
gprompt  [help [command]]  [load [name]] [off]  [reset [--hard]] 
[save [-f] [name]]  [update [--list] [--available] [version|commit]]  [version] 
[-diopRrv] [-a boolean]  [-b [num] ['all']]  [-C path] [-f format]  [-h [topic]] 
[-I num]  [-l name]  [-p [xvar]]  [-U <ask|background|never|supress>]  [-u num] 
[--get-<def>]  [--set-<def>=value]  [--<def>[=value]]  [<def> [-l|-s] [value]] 
EO_USES

my $para_text = <<EO_PARA;
 ... more to come ...
EO_PARA

my $help_text = <<EO_HELP;
See `gprompt help` for the full documentation of gprompt, or

See `gprompt help <command>` for a detailed description of the command.
EO_HELP

my $syno_text = "$uses_text\n$para_text\n$help_text";

my $conf_text = <<EO_CONF;
The gprompt configuration file location defaults to:

    ~/.gprompt/.gprompt_conf
    
To instruct gprompt to look in another location for a configuration file,
add the following line to the top of your existing gprompt config:

    GPROMPT_CONF='</path/to/new/config>'

This value will cause gprompt to load the indicated '*.gprompt_conf' file,
or to look for a '.gprompt_conf' if the provided path is a directory.

Note that this redirection is recursive, meaning that gprompt will always
check for a 'GPROMPT_CONF' value (and will redirect if one is found) before
attempting to load any further configuration values.

NOTE: although it is recommended that a 'GPROMPT_CONF' redirection only be
placed on the TOP line of the '.gprompt_conf' file, gprompt will redirect to
the first 'GPROMPT_CONF' value that it finds, no matter when that value
appears in the config.

// PLEASE SEE THE 'CONFIGURATION OPTIONS' SECTION TO LEARN ABOUT THE AVAILABLE SETTINGS //
EO_CONF

my $form_text = <<EO_FORM;
The format of your prompt will determine what appears in you shell prompt.
Please see below for more information on what you can include in your gprompt
format string.

After setting your prompt, consider saving via the 'gprompt save' command, which
will save all of your current gprompt settings to your gprompt config file.
Alternatively, you can turn on autosave to immediately save changes whenever you
update any gprompt definition.

NOTE: saving will overwrite your previously saved settings. Turn on automatic
backups to keep a backup of your current configuration settings when you save:

    gprompt --backup=<n|all>
    

The gprompt format consists of a series of 'printf-esque' formatting codes,
which will be populated with real values whenever you generate a new prompt.
These values are updated from git periodically, as indicated by your refresh
interval setting.

              FORMAT CODES
    =========================================
      SHORT        FULL           ALTS
    -----------------------------------------

           ## ANSI Color Escapes:
       \\c<integer>
       \\c{<integer>[;...]}
       
           ## TPUT Color Escapes:
       \\t<integer>
       \\t{<integer>[;...]}

           ## DIRECTORY INFO
        %p      %path
        %d      %directory      %dir, %local
        %f      %full_path      %full

           ## REPO INFO
        %r      %repo
        %b      %branch
        %c      %commit         %com, %hash, %sha

           ## BRANCH STATE
        %+      %ahead
        %-      %behind
        %~      %parent
        %^      %merged
        
           ## FILE STATUS MODES
        %s      %staged
        %u      %unstaged

           ## FILE STATUS COUNTS
        %mod    %modified
        %add    %added
        %del    %deleted
        %rem    %removed
        %cop    %copied         %copy
        %re     %renamed
        %up     %updated
        %un     %unmerged
        %?      %untracked
        %!      %ignored


Curly brace groups can be used to add additional control to your prompt,
such as by creating conditional statements: 

              CONDITIONALS
    =====================================
      STRUCTURE         DESCRIPTION
    -------------------------------------

        { A }      --  Basic Braced Group: anything inside of this
                       construct will be hidden when the CWD is not a
                       git repo.
                       [ A if A ]
                       
       { A B }     --  Combining Group: output will be the content
                       at A followed by the content at B, as long
                       as either A or B is not falsey.
                       [ A and/or B ]
                       
      { A & B }    --  Conjunction Group: 
                       [ both A and B ]

      { A | B }    --  Alternating Group: output will be the content
                       at position A unless it looks falsey, in which
                       case output will be the content at position B.
                       [ B unless A ]

      { A ? B }    --  Conditional Group: output will be the content
                       at position B unless A looks falsey, and blank
                       otherwise.
                       [ if A then B ]  -  equivalent to  { A ? B | }
                       
      { A ! B }    --  Negating Group: output will be the content at
                       position B if the content at position A looks
                       falsey.
                       [ if not A then B ]  -  equivalent to  { A ? | B }

    { A ? B | C }  --  Conditional Group with Alternative: as above,
                       but output will be the content at position C in
                       the case that A looks falsey.
                       [ if A then B else C ]
                       
                   
              USAGE EXAMPLES
    =====================================
      PROMPT FORMAT
         RENDERED EXAMPLE
    -------------------------------------

    {%path[%repo:%branch{-%-}{+%+} <%staged>(%unstaged)]}%p $> 
        ~/git[my_stuff:master-5 <1>(5)] $> 

    {[%repo:%branch{-%-}{+%+}{ (%commit)} <%staged>(%unstaged)] Git://%repo/}%path $> 
        [my_stuff:master-5 (a3db7f0) <1>(5)] Git://my_stuff/sub/directory/path/ $> 

    {branch: %branch{ %behind ? {: pull required!}} | %full_path}$> 
        branch: master (pull required!) $> 
EO_FORM

my $exit_text=<<EO_EXIT;
0    successfully generated a new prompt line
1    failed to load config
-1   a runtime error occured during prompt generation
EO_EXIT

my $exam_text=<<EO_EXAM;
To initiate gprompt in a new bash session:

    \$ gprompt init
    
To set the gprompt format:

    \$ gprompt format='{%dir[%repo:%branch%~%+ <%staged>(%unstaged)]}%p $>'

To set the gprompt format and then save it for use in future sessions:

    \$ gprompt -fs '%directory {[%branch: {%behind ? (pull required!)}]}'

To reload the gprompt settings from your configuration file

    \$ gprompt load

To reset gprompt to its default values:

    \$ gprompt reset
EO_EXAM


my %optn_sect;
$optn_sect{autosave}=<<EO_AUTO;
# AUTOSAVE  -  Automatically save your settings whenever they are updated.
EO_AUTO
$optn_sect{backup}=<<EO_BACK;
# BACKUP  -  Maintain copies of your previous gprompt settings when saving.
EO_BACK
$optn_sect{config}=<<EO_CONF;
# CONFIG  -   Path to the config file you want gprompt to use.
EO_CONF
$optn_sect{format}=<<EO_FORM;
# FORMAT  -  Format string used to generate your command prompt.
EO_FORM
$optn_sect{pathtype}=<<EO_PATH;
# PATHTYPE  -  Determines whether rendered paths are relative or absolute.
EO_PATH
$optn_sect{refresh}=<<EO_INTR;
# REFRESH  -  Frequency with which gprompt checks the status of your git repo.
EO_INTR
$optn_sect{update}=<<EO_UPDT;
# UPDATE  -  Frequency with which gprompt checks for available updates.
EO_UPDT
$optn_sect{updater}=<<EO_MODE;
# UPDATER  -  Determines whether gprompt will ask you before updating. 
EO_MODE
$optn_sect{vanilla}=<<EO_VANL;
# VANILLA  -  Non-formatted prompt that will be used when gprompt is turned off.
EO_VANL
my $optn_text = join( "\n", map { $optn_sect{$_} } sort keys %optn_sect );


my %coms_sect;
$coms_sect{disable} = <<EO_disable;
# DISABLE  -  Permanently disables gprompt until manually enabled.    

usage: gprompt disable

This command will cause the `gprompt generate` command to return the 'vanilla'
prompt definition stored in your configuration file for your current shell type,
or from the 'DEFAULT' section if no configuration section can be found for your
current shell.

To re-enable the gprompt utility, simply use the command:

    gprompt init 

Once the gprompt utility is disabled, any gprompt command other than
`gprompt init` will immediately return a non-zero exit code.
EO_disable
$coms_sect{help} = <<EO_HELP;
# HELP  -  Provides helpful information about gprompt.

usage: gprompt help [command ...] [section ...]  [definition ...]

The 'help' command by itself will the gprompt documentation into your shell.

If provided with any arguments, the printed output will only contain
information about the specified commands, defintions, or help text sections.
EO_HELP
$coms_sect{init} = <<EO_INIT;
# INIT  -  Used to initiate gprompt before using it for the first time.

usage: gprompt init

The 'init' command should be used anytime a user wants to run gprompt for the
first time, or to enable gprompt after using the `gprompt disable` command.

This command will create a default gprompt configuration file if one does not
already exist under the path '~/.gprompt/.gprompt_conf'.
EO_INIT
$coms_sect{load} = <<EO_RELOAD;
# LOAD  -  Loads your saved gprompt settings in the current shell.

usage: gprompt load [--list] [name]

Reloads gprompt's configuration settings from your stored gprompt config file.
This will only update the gprompt environment within your current shell.

This command should be run anytime that you want to import a new gprompt
definition (or any other gprompt configuration value), such as if you want to
port format-defitions between sessions, or if you manually edit the config file.

NOTE: it is not recommended to run this command after setting a new
format-definition unless you have already saved your new definition (or if you
have autosave turned on), as this command will overwrite your local settings.

If no [name] is provided, gprompt will first look for any config values
previously saved for your current shell session. If no save can be found for
your current session, gprompt will default to the saved values for your current
shell type. Finally, if no other relevant saves are found, then the stored
'DEFAULT' values will be used.

CAUTION: Failure to load successfully or failure to find a valid default
configuration will cause gprompt to overwrite the entire configuration file
(indicated by your current 'config-path') with a clean "default" configuration!
EO_RELOAD
$coms_sect{off} = <<EO_OFF;
# OFF  -  Temporarily disable gprompt in the current shell.

usage: gprompt off

Running this command will cause your command prompt to be set to the 'vanilla'
config value, which is typically defined when you run gprompt the first time.
EO_OFF
$coms_sect{reload} = <<EO_RELOAD;
# RESET  -  Resets the gprompt config file to default values.

usage: gprompt reload

Resets the gprompt environment (in the current shell session) to the values
described in your config file's 'DEFAULTS' section.

NOTE: this will overwrite existing gprompt environment values! Consider backing
up your configuration settings before resetting gprompt, or use the 'backup'
command to set up automatic backups:

    gprompt --set-backup all
EO_RELOAD
$coms_sect{reset} = <<EO_RESET;
# RESET  -  Resets the gprompt config file to default values.

usage: gprompt reset

Resets the entire gprompt configuration file (indicated by your current
'config' setting) will be overwritten with a clean "default" configuration.

Use at your own risk!
EO_RESET
$coms_sect{save} = <<EO_SAVE;
# SAVE  -  Stores your current settings in the gprompt config file.

usage: gprompt save [-f] [name]

This command will save your current gprompt configuration settings to disk. If a
[name] is provided, gprompt will append your configuration file with a new
section, indicated using the name you provided. If a section already exists
under that name, gprompt will ask you whether or not to overwrite that section.
By invoking the [-f] option, gprompt will overwrite the section without asking.
All names are upcased when saving/loading, and are case insensitive.

CAUTION: saving under the name 'DEFAULT' will overwrite the "default"
configuration settings used by the `gprompt reset` command. These defaults will
be used by any new gprompt session unless specified.

When no name is provided, your settings will be saved under a section named
after your current shell (i.e. 'BASH', 'ZSH', etc.), creating or overwriting the
section as necessary.

NOTE: when saving with no specified name, you will not be prompted for
permission to overwrite the existing configuration section.

If the 'autosave' setting is enabled, then the name of your STORED settings
section will be automatically appended with a pattern described in the autosave
options help text, after which the settings for your current session will be
written to disk.
EO_SAVE
$coms_sect{update} = <<EO_UPDATE;
# UPDATE  -  Updates the gprompt source files to the latest stable build.

usage: gprompt update [--list] [--available] [version] [commit]

The "update" command forces gprompt to immediately search for any available
updates. The version ID of the newest update will be listed, along with a prompt
asking the user if gprompt should be updated.

Specifying a version number or short-form git commit hash will upgrade/downgrade
to that specific gprompt version.

Adding the option '--available' will print out a list of all gprompt versions
that are newer than the version that is currently installed.

The option '--list' will print out a list of every version released to date,
ordered from newest to older.
EO_UPDATE
$coms_sect{version} = <<EO_VERSION;
# VERSION  -  Shows the current gprompt version.

usage: gprompt version
    
Shows the current version of your active gprompt installation.

    Your current gprompt version is '$gprompt_version'.
EO_VERSION
my $coms_text = join( "\n", map { $coms_sect{$_} } sort keys %coms_sect );