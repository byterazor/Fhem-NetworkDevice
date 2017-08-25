package main;
use strict;
use warnings;
use POSIX;
use SetExtensions;
use SNMP;
use SNMP::Info;
use NetworkDevice::Switch;
use NetworkDevice::UnknownDevice;
use Data::Dumper;


my $module_name="NetworkDevice";
my $VERSION    = '0.0.1';

my $network_device_hash;

sub NetworkDevice_Define;
sub NetworkDevice_Delete;
sub NetworkDevice_Set;

# not_defined_yet
#
# called by subroutines which have not been implemented yet
#
sub not_defined_yet
{
  my ($hash) = @_;
  Log3 undef, 3, "[$module_name] undefined function called";
}

# mydebug
#
# simplified debug output
#
sub mydebug
{
  my $msg=shift;

  Log3 undef, 3, "[$module_name] " . $msg;
}

# NetworkDevice_Initialize
#
#  initialize the FireTVnotify Module
#
sub NetworkDevice_Initialize
{
  my ($hash) = @_;
  $hash->{DefFn}      = 'NetworkDevice_Define';
  $hash->{UndefFn}    = 'NetworkDevice_Undef';
  $hash->{DeleteFn}   = "NetworkDevice_Delete";
  $hash->{SetFn}      = 'NetworkDevice_Set';
  $hash->{GetFn}      = 'NetworkDevice_Get';
  $hash->{AttrFn}     = 'NetworkDevice_Attr';
  $hash->{AttrList}   = "SNMP_COMMUNITY Interval " . $readingFnAttributes;

}

# NetworkDevice_Define
#
# called when the NetworkDevice instance is defined in FHEM
#
sub NetworkDevice_Define
{
  my ($hash, $def) = @_;
  my @param = split('[ \t@]+', $def);
  my $name = $param[0];
  my $community="public";
  my $host;

  # if too few arguments
  if(int(@param) < 3)
  {
    return "too few parameters: define <name> NetworkDevice <HOST | community\@HOST>";
  }

  #check if a snmp community string is given
  if ($def =~ /@/)
  {
    $community=$param[2];
    $host=$param[3];
  }
  else
  {
    $host=$param[2];
  }

  #check if host is ip or hostname
  if(defined($host) && $host !~/^[a-z0-9-.]+(:\d{1,5})?$/i)
  {
        return "Host '". $host ."' is no valid ip address or hostname";
  }

  # connect to the given host with snmp
  my $info = new SNMP::Info(
                            # Auto Discover more specific Device Class
                            AutoSpecify => 1,
                            Debug       => 0,
                            # The rest is passed to SNMP::Session
                            DestHost    => "udp:" . $host,
                            Community   => $community,
                            Version     => 2
                          ) || return "Failed to connect to host \"" . $host ."\"";

  # identify the network device
  my $device;
  if (NetworkDevice::Switch->isDevice($info,\&mydebug)) {
    $device=NetworkDevice::Switch->new(snmp=>$info,debug=>\&mydebug);
  } else {
    $device=NetworkDevice::UnknownDevice->new(snmp=>$info,debug=>\&mydebug);
  }

  # create base hash for fhem
  $hash->{NAME}           = $name;
  $hash->{SNMP_HOST}      = $host;
  $hash->{SNMP_VERSION}   = 2;
  $hash->{STATE}          = 'online';
  $attr{$name}{SNMP_COMMUNITY} = $community;
  $attr{$name}{Interval} = 60;

  # create network device specific fhem hash values
  $device->setupHash($hash);

  # save the snmp connection data in the helper hash
  $hash->{helper}->{device}=$device;

  $network_device_hash=$hash;

  # create a recurring timer to update readings
  InternalTimer(gettimeofday()+2, "NetworkDevice_Update", $hash);

  return;
}

# NetworkDevice_Undef
#
# called when a NetworkDevice instance is deleted in FHEM
#
sub NetworkDevice_Undef
{
  my ( $hash, $name) = @_;
  RemoveInternalTimer($hash);
  return;
}


# NetworkDevice_Delete
#
# called when a NetworkDevice instance is deleted in FHEM
#
sub NetworkDevice_Delete
{
  my ( $hash, $name) = @_;
  return;
}

# NetworkDevice_Get
#
# called when data is requested from the NetworkDevice
#
sub NetworkDevice_Get
{
	my ( $hash, $name, $opt, @args ) = @_;

	return;
}

# NetworkDevice_Set
#
# called when data should be set in the NetworkDevice
#
sub NetworkDevice_Set
{
	my ( $hash, $name, $cmd, @args ) = @_;

  #get device specific command list
  my $cmdList = $hash->{helper}->{device}->cmds();
  my $processed;

  $hash->{helper}->{device}->cmd(@_);
  $processed = $hash->{helper}->{device}->cmd_processed();

  if ($processed == 0)
  {
    return SetExtensions($hash, $cmdList, $name, $cmd, @args);
  }
  elsif($processed == 1 && length($hash->{helper}->{device}->cmd_error())>0)
  {
    return $hash->{helper}->{device}->cmd_error();
  }

}

sub NetworkDevice_Attr(@)
{
	my ( $cmd, $name, $attrName, $attrValue ) = @_;
  if ($cmd eq "set") {
  	if ($attrName eq "SNMP_COMMUNITY") {
        # connect to the given host with snmp
        my $info = new SNMP::Info(
                                  # Auto Discover more specific Device Class
                                  AutoSpecify => 1,
                                  Debug       => 0,
                                  # The rest is passed to SNMP::Session
                                  DestHost    => "udp:" . $network_device_hash->{SNMP_HOST},
                                  Community   => $attrValue,
                                  Version     => 2
                                ) || return "Failed to connect to host \"" .$network_device_hash->{SNMP_HOST} ."\"";
        $network_device_hash->{helper}->{device}->snmp($info);
        $network_device_hash->{helper}->{device}->setupHash($network_device_hash);
    }
    elsif ($attrName eq "Interval")          # set the update interval
    {
      if ($attrValue !~/^\d+$/)
      {
        $attrValue=60;
      }
      else
      {
        RemoveInternalTimer($network_device_hash);
        InternalTimer(gettimeofday()+$attrValue, "NetworkDevice_Update", $network_device_hash);
      }
    }
  }
  else
  {
    if ($attrName eq "SNMP_COMMUNITY") {
      return "SNMP_COMMUNITY can not be deleted ! Please change.";
    }
    elsif ($attrName eq "Interval")
    {
      RemoveInternalTimer($network_device_hash);
      InternalTimer(gettimeofday()+60, "NetworkDevice_Update", $network_device_hash);
    }
  }
  return undef;
}

sub NetworkDevice_Update
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 undef, 3, "[$module_name] update";

  my $device = $hash->{helper}->{device};

  # call device specific update function
  $device->update($hash,\&readingsSingleUpdate,\&mydebug);

  #update the hash
  $device->setupHash($hash);

  # restart the timer
  InternalTimer(gettimeofday()+AttrVal($name, "Interval", 60), "NetworkDevice_Update", $hash);
}


1;
