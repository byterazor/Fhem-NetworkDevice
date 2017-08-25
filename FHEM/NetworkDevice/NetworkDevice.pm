#
# abstract class for a Network Device in FHEM
#
package NetworkDevice::NetworkDevice;
use Moose::Role;
use strict;
use warnings;
use utf8;
use SNMP::Info;
use Data::Dumper;

requires 'isDevice';
requires 'setupHash';
requires 'update';
requires 'cmd';


has 'snmp'      => (is => 'rw', isa => 'SNMP::Info', required=>1);
has 'model'     => (is => 'rw', isa => 'Str', default => "unknown");
has 'vendor'    => (is => 'rw', isa => 'Str', default => "unknown");
has 'ip'        => (is => 'rw', isa => 'Str', default => "unknown");
has 'proto'     => (is => 'rw', isa => 'Str', default => "udp");
has 'cmds'      => (is => 'rw', isa => 'Str', default => "SNMP_COMMUNITY update:noArg");
has 'cmds_read' => (is => 'rw', isa => 'Str', default => "SNMP_COMMUNITY update:noArg");
has 'cmds_write'=> (is => 'rw', isa => 'Str', default => "sysName sysContact sysLocation");
has 'cmd_processed' => (is => 'rw', isa => 'Int', default => 0);
has 'cmd_error' =>  (is => 'rw', isa => 'Str');
has 'debug'     => (is => 'ro', required=>1);


before 'BUILD' => sub {
    my $self = shift;

    $self->model($self->snmp->model);
    $self->vendor($self->snmp->vendor);
};

before 'setupHash' => sub {
    my $self = shift;
    my $hash = shift;

    $hash->{SNMP_ACCESS}=$self->check_write() ? "readwrite" : "readonly";
    if ($hash->{SNMP_ACCESS} eq "readwrite")
    {
      $self->cmds($self->cmds_read() . " " . $self->cmds_write());
    }
    else
    {
      $self->cmds($self->cmds_read());
    }
    $hash->{model}=$self->model();
    $hash->{vendor}=$self->vendor();
    $hash->{type}=ref($self);
    $hash->{sysName}=$self->snmp->name();
    $hash->{sysContact}=$self->snmp->contact();
    $hash->{sysLocation}=$self->snmp->location();
};

before 'cmd' => sub {
  my $self = shift;
  my ( $hash, $name, $cmd, @args ) = @_;

  $self->cmd_processed(0);
  $self->cmd_error("");


  #
  # check for networkdevice common commands
  #
  if($cmd eq "SNMP_COMMUNITY")  # set community name
	{
    $self->debug()->("SNMP_COMMUNITY");
    #first test if we can connect with the community to the host
    my $err=0;
    my $info = new SNMP::Info(
                              AutoSpecify => 1,
                              Debug       => 0,
                              DestHost    => "udp:" . $hash->{SNMP_HOST},
                              Community   => $args[0],
                              Version     => 2
                            );

    if (!defined($info))
    {
      $self->cmd_error("can not connect to host with community " . $args[0]);
    }
    else
    {
      $hash->{SNMP_COMMUNITY}=$args[0];
      $self->snmp($info);
      $hash->{SNMP_ACCESS}=$self->check_write() ? "readwrite" : "readonly";
      if ($hash->{SNMP_ACCESS} eq "readwrite")
      {
        $self->cmds($self->cmds_read() . " " . $self->cmds_write());
      }
      else
      {
        $self->cmds($self->cmds_read());
      }
    }
    $self->cmd_processed(1);
  }
  elsif ($cmd eq "sysName")         # set remote snmp systemName
  {
    $self->snmp->set_name($args[0]);
    $self->snmp->update();
    $self->setupHash($hash);
    $self->cmd_processed(1);
  }
  elsif ($cmd eq "sysContact")      # set remote snmp systemContact
  {
    $self->snmp->set_contact($args[0]);
    $self->snmp->update();
    $self->setupHash($hash);
    $self->cmd_processed(1);
  }
  elsif ($cmd eq "sysLocation")     # set remote snmp systemLocation
  {
    $self->snmp->set_location($args[0]);
    $self->snmp->update();
    $self->setupHash($hash);
    $self->cmd_processed(1);
  }
  elsif ($cmd eq "update")          # update the internal snmp structure
  {
    $self->snmp->update();
    $self->setupHash($hash);
    $self->cmd_processed(1);
  }
};

before 'update' => sub {
    my $self = shift;
    my $hash = shift;
    my $update_ref = shift;

    my $uptime = $self->snmp->uptime();

    $update_ref->($hash, "uptime", $uptime, 1);

};

# check_write
#
# check if write access is available by snmp
sub check_write
{
  my $self = shift;

  my $location=$self->snmp->location();
  my $ret=$self->snmp->set_location($location);

  if (defined($ret))
  {
    return 1;
  }
  else
  {
    return 0;
  }


}

1;
