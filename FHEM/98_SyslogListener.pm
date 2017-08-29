package main;
use strict;
use warnings;
use POSIX;
use SetExtensions;

my $module_name="SyslogListener";
my $VERSION    = '1.0.0';

# severity level names
my @severity_name = (
  "Emergency",
  "Alert",
  "Critical",
  "Error",
  "Warning",
  "Notice",
  "Informational",
  "Debug"
);

# facility names
my @facility_name = (
  "kernel",
  "user",
  "mail",
  "system daemons",
  "security/authorization messages",
  "messages generated internally by syslogd",
  "line printer subsystem",
  "network news subsystem",
  "UUCP subsystem",
  "clock daemon",
  "security/authorization messages",
  "FTP daemon",
  "NTP subsystem",
  "log audit",
  "log alert",
  "clock daemon",
  "local0",
  "local1",
  "local2",
  "local3",
  "local4",
  "local5",
  "local6",
  "local7"
);

# SyslogListenerDebug
#
# simplified debug output
#
sub SyslogListenerDebug
{
  my $msg=shift;

  Log3 undef, 3, "[$module_name] " . $msg;
}

# SyslogListener_Initialize
#
#  initialize the SyslogListener Module
#
sub SyslogListener_Initialize
{
  my ($hash) = @_;
  $hash->{DefFn}      = 'SyslogListener_Define';
  $hash->{ReadFn}     = 'SyslogListener_Read';
  $hash->{ReadyFn}    = undef;
  $hash->{NotifyFn}   = undef;
  $hash->{UndefFn}    = 'SyslogListener_Undef';
  $hash->{DeleteFn}   = "SyslogListener_Delete";
  $hash->{SetFn}      = 'SyslogListener_Set';
  $hash->{GetFn}      = 'SyslogListener_Get';
  $hash->{AttrFn}     = 'SyslogListener_Attr';
  $hash->{AttrList}   = "mode:include,exclude include exclude " . $readingFnAttributes;

}

# SyslogListener_Define
#
# called when the SyslogListener instance is defined in FHEM
#
sub SyslogListener_Define
{
  my ($hash, $def) = @_;
  my @param = split('[ \t]+', $def);
  my $name = $param[0];

  # if too few arguments
  if(int(@param) < 4)
  {
    return "too few parameters: define <name> SyslogListener <IP> <PORT>";
  }


  my $host = $param[2];
  my $port = $param[3];

  if (!defined($port) || $port !~ /^\d+$/)
  {
    $port = 514;
  }

  # create a listen socket for the requested local ip and port
  my $sock = IO::Socket::INET->new(   Proto     => "udp",
                                      LocalAddr => $host,
                                      LocalPort => $port)
                                  or die "Can't bind : $@\n";

  my $dev = "$host:$port";

  # create base hash for fhem
  $hash->{NAME}             = $name;
  $hash->{STATE}            = 'listening';
  $hash->{DeviceName}       = $dev;
  # we fake the DEVIO open function ;)
  $hash->{TCPDev}           = $sock;
  $hash->{FD}               = $sock->fileno();
  $selectlist{"$name.$dev"} = $hash;


  return;
}

# SyslogListener_Undef
#
# called when a SyslogListener instance is deleted in FHEM
#
sub SyslogListener_Undef
{
  my ( $hash, $name) = @_;
  return;
}


# SyslogListener_Delete
#
# called when a SyslogListener instance is deleted in FHEM
#
sub SyslogListener_Delete
{
  my ( $hash, $name) = @_;
  return;
}

# SyslogListener_Get
#
# called when data is requested from the SyslogListener
#
sub SyslogListener_Get
{
	my ( $hash, $name, $opt, @args ) = @_;

	return;
}

# SyslogListener_Set
#
# called when data should be set in the SyslogListener
#
sub SyslogListener_Set
{
	my ( $hash, $name, $cmd, @args ) = @_;
  my $cmdList="";

  return SetExtensions($hash, $cmdList, $name, $cmd, @args);
}

sub SyslogListener_Attr(@)
{
	my ( $cmd, $name, $attrName, $attrValue ) = @_;

  # check for correct attribute value
  if ($cmd eq "set")
  {
    if ($attrName eq "mode")
    {
      if ($attrValue ne "include" && $attrValue ne "exclude")
      {
        return "invalid mode: $attrValue";
      }
    }
  }

  return;
}

sub SyslogListener_Read
{
  my ( $hash ) = @_;
  my $data;
  my $flag;
  my $month;
  my $day;
  my $time;
  my $host;
  my $app;
  my $pid;
  my $msg;

  # receive one syslog line
  $hash->{TCPDev}->recv($data, 4096);

  # parse syslog data
  $data=~/^<(\d+)>(\S+)\s(\d+)\s(\d+:\d+:\d+)\s([\S\d\_\-\/]*)\s([\S\d\_\-\/]*):(.*)$/;

  $flag=$1;

  my $facility=$flag;
  $facility = $facility >> 3;
  my $severity=$flag;
  $severity = $severity & 7;
  $severity = $severity >> 5;

  $month=$2;
  $day=$3;
  $time=$4;
  $host=$5;
  $app=$6;
  my @help=split /\[/,$app;
  $app=$help[0];
  $pid=$help[1];
  $msg=$7;


  my $append=0;
  # check if readings should be updated
  if (AttrVal($hash->{NAME}, "mode", "include") eq "include")
  {
    $append=0;
    my @includes=split /,/ , AttrVal($hash->{NAME}, "include", "");
    for my $i (@includes)
    {
      my ($ihost, $iapp)=split/\:/, $i;
      if ( ($host eq $ihost || $ihost eq "*") && ( $app eq $iapp || $iapp eq "*" ) )
      {
        $append=1;
      }
    }
  }
  else
  {
    $append=1;
    my @excludes=split /,/ , AttrVal($hash->{NAME}, "exclude", "");
    for my $e (@excludes)
    {
      my ($ehost, $eapp)=split/\:/, $e;
      if ( ($host eq $ehost || $ehost eq "*") && ( $app eq $eapp || $eapp eq "*" ) )
      {
        $append=0;
      }
    }
  }

  # if required update readings
  if ($append == 1)
  {
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "msg_count", ReadingsVal($hash->{NAME}, "msg_count", 0)+1);
    readingsBulkUpdate($hash, "msg_severity", $severity);
    readingsBulkUpdate($hash, "msg_severity_name", $severity_name[$severity]);
    readingsBulkUpdate($hash, "msg_facility", $facility);
    readingsBulkUpdate($hash, "msg_facility_name", $facility_name[$facility]);
    readingsBulkUpdate($hash, "msg_date", $month . " " . $day);
    readingsBulkUpdate($hash, "msg_time", $time);
    readingsBulkUpdate($hash, "msg_host", $host);
    readingsBulkUpdate($hash, "msg_application", $app);
    readingsBulkUpdate($hash, "msg", $msg );
    readingsEndUpdate($hash, 1);
  }
}

1;
=pod
=begin html

<a name="SyslogListener"></a>
<h3>SyslogListener</h3>
<ul>
  <i>SyslogListener</i> listens for syslog messages on a configurable local IP and local port.
  The received messages can be filtered using include or exclude mode according to their
  originating host and application. The information is displayed as readings.<br/>
  This is useful if you want to transfer syslog messages from a network device like a <i>switch</i>
  or an <i>wireless access point</i> to fhem for further evaluation. It is even possible to
  configure a central syslog server running on a linux host to forward copies of its syslog messages
  to this module.
  <br><br>
  <a name="FireTVnotifydefine"></a>
    <b>Define</b><br>
    <code>define &lt;name&gt; SyslogListener &lt;LOCAL IP&gt; &lt;LOCAL PORT&gt;</code>
    <br><br>
    Example: <code>define mySyslogListener SyslogListener 0.0.0.0 6000</code><br>
    <br>
    This will listen on port 6000 on all local interfaces. If you want to listen to the normal syslog port 514
    make sure FHEM is allowed to open ports < 1024.<br/><br/>
    <a name="FireTVnotifyset"></a>
    <b>Attributes</b><br>
    <ul>
        <li> mode <br/> the default mode is include, therefor, you have to specifiy all the accepted syslog host:application combinations
        in the include attribute. In exclude mode use the exclude attribute to exclude host:application combinations.
        </li>
        <li>include|exclude <br/> append all the host:application combinations you want to include/exclude separated by a comma. <br/>
        Examble: <code>attr mySyslogListener include fhem:dhcpd,*:kern,fhem:*</code>
        </li>
    </ul>
</ul>
=end html
=cut
