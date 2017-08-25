# class representing a Switch in FHEM
package NetworkDevice::Switch;
use Moose;
use SNMP::Info;
use Data::Dumper;

with 'NetworkDevice::NetworkDevice';

has 'ethernet_ports' => (is => 'rw', default=>undef);

# check if the given SNMP::Info structure is a switch
#
# returns 1 for true, 0 for false
sub isDevice
{
  my $self=shift;
  my $snmp=shift;
  my $debug = shift;

  # how do we identify a switch by SNMP ?
  #  -layer2 or layer3 device
  #  -at least two ethernet ports
  #  -no ipForwarding

  #get number of ethernet interfaces
  my $nr_ethernet=0;
  my $nr_lag=0;
  my $type=$snmp->i_type();
  for my $i (keys %{$type}) {
    if ($type->{$i} =~ /ethernet/)
    {
      $nr_ethernet++;
    }
    elsif ($type->{$i} =~ /lag/)
    {
      $nr_lag++;
    }
  }

  if ( ($snmp->has_layer(2) || $snmp->has_layer(3)) && $snmp->ipForwarding() ne "forwarding" )
  {
    return 1;
  }
  else
  {
    return 0;
  }

}

sub nr_ethernet_ports
{
  my $self = shift;
  my $nr=0;
  my $type=$self->snmp->i_type();

  for my $i (keys %{$type}) {
    if ($type->{$i} =~ /ethernet/)
    {
      $nr++;
    }
  }

  return $nr;
}

sub nr_lag_ports
{
  my $self = shift;
  my $nr=0;
  my $type=$self->snmp->i_type();

  for my $i (keys %{$type}) {
    if ($type->{$i} =~ /Lag/)
    {
      $nr++;
    }
  }

  return $nr;
}

sub get_ethernet_ports
{
  my $self  = shift;
  my @ports;

  my $type=$self->snmp->i_type();

  for my $i (keys %{$type}) {
    if ($type->{$i} =~ /ethernet/)
    {
      push(@ports, $i);
    }
  }

  return \@ports;
}

sub BUILD {
  my $self = shift;

}

sub setupHash
{
  my $self = shift;
  my $hash = shift;

  $hash->{ethernet_ports}=$self->nr_ethernet_ports();
  $hash->{lag_ports}=$self->nr_lag_ports;

  $hash->{support_layer2}=$self->snmp->has_layer(2) ? "true" : "false";
  $hash->{support_layer3}=$self->snmp->has_layer(3) ? "true" : "false";
  $hash->{support_link_aggregation}=$self->nr_lag_ports > 0 ? "true" : "false";
}

sub cmd
{

}

sub update {
  my $self        = shift;
  my $hash        = shift;
  my $update_ref  = shift;
  my $debug       = shift;

  $self->snmp->update();

  # create the ethernet port names
  if (!defined($self->ethernet_ports())){
    my %ether_ports;
    my $nr = 0;
    my @ports=sort @{$self->get_ethernet_ports()};
    my $names=$self->snmp->i_name();

    for my $p (@ports)
    {
      $ether_ports{$p}->{id}=$nr;
      $ether_ports{$p}->{name}=$names->{$p};
      $update_ref->($hash, "ethernet_port_" . $nr . "_name", $ether_ports{$p}->{name}, 1);
      $nr++;
    }
    $self->ethernet_ports(\%ether_ports);
  }

  my $ethernet_ports=$self->ethernet_ports();

  for my $p (keys %{$ethernet_ports})
  {

    #check for user description
    if ( !defined($ethernet_ports->{$p}->{alias}) ||
         $ethernet_ports->{$p}->{alias} ne $self->snmp->i_alias()->{$p}
       )
    {
      $ethernet_ports->{$p}->{alias} = $self->snmp->i_alias()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_alias", $ethernet_ports->{$p}->{alias} , 1);
    }

    #check for enable status
    if ( !defined($ethernet_ports->{$p}->{enabled}) ||
         $ethernet_ports->{$p}->{enabled} ne $self->snmp->i_up_admin()->{$p}
       )
    {
      $ethernet_ports->{$p}->{enabled} = $self->snmp->i_up_admin()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_enabled", $ethernet_ports->{$p}->{enabled} , 1);
    }

    #check for online status
    if ( !defined($ethernet_ports->{$p}->{status}) ||
         $ethernet_ports->{$p}->{status} ne $self->snmp->i_up()->{$p}
       )
    {
      $ethernet_ports->{$p}->{status} = $self->snmp->i_up()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_status", $ethernet_ports->{$p}->{status} , 1);
    }

    #check for last changed status
    if ( !defined($ethernet_ports->{$p}->{lastChanged}) ||
         $ethernet_ports->{$p}->{lastChanged} ne $self->snmp->i_lastchange()->{$p}
       )
    {
      $ethernet_ports->{$p}->{lastChanged} = $self->snmp->i_lastchange()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_lastChanged", $ethernet_ports->{$p}->{lastChanged} , 1);
    }

    #check for raw speed status
    if ( !defined($ethernet_ports->{$p}->{speed_raw}) ||
         $ethernet_ports->{$p}->{speed_raw} ne $self->snmp->i_speed_raw()->{$p}
       )
    {
      $ethernet_ports->{$p}->{speed_raw} = $self->snmp->i_speed_raw()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_speed_raw", $ethernet_ports->{$p}->{speed_raw} , 1);
    }

    #check for human readable speed status
    if ( !defined($ethernet_ports->{$p}->{speed}) ||
         $ethernet_ports->{$p}->{speed} ne $self->snmp->i_speed()->{$p}
       )
    {
      $ethernet_ports->{$p}->{speed} = $self->snmp->i_speed()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_speed", $ethernet_ports->{$p}->{speed} , 1);
    }

    #check for duplex status if available
    if (defined($self->snmp->i_duplex())) {
      if ( !defined($ethernet_ports->{$p}->{duplex}) ||
           $ethernet_ports->{$p}->{duplex} ne $self->snmp->i_duplex()->{$p}
         )
      {
        $ethernet_ports->{$p}->{duplex} = $self->snmp->i_duplex()->{$p};
        $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_duplex", $ethernet_ports->{$p}->{duplex} , 1);
      }
    }

    #check for incoming error stats
    if ( !defined($ethernet_ports->{$p}->{errors_in}) ||
         $ethernet_ports->{$p}->{errors_in} ne $self->snmp->i_errors_in()->{$p}
       )
    {
      $ethernet_ports->{$p}->{errors_in} = $self->snmp->i_errors_in()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_errors_in", $ethernet_ports->{$p}->{errors_in} , 1);
    }

    #check for outgoing error stats
    if ( !defined($ethernet_ports->{$p}->{errors_out}) ||
         $ethernet_ports->{$p}->{errors_out} ne $self->snmp->i_errors_out()->{$p}
       )
    {
      $ethernet_ports->{$p}->{errors_out} = $self->snmp->i_errors_out()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_errors_out", $ethernet_ports->{$p}->{errors_out} , 1);
    }

    #check for incoming unicast packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_unicast_in}) ||
         $ethernet_ports->{$p}->{packets_unicast_in} ne $self->snmp->i_pkts_ucast_in()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_unicast_in} = $self->snmp->i_pkts_ucast_in()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_unicast_packets_in", $ethernet_ports->{$p}->{packets_unicast_in} , 1);
    }

    #check for outgoing unicast packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_unicast_out}) ||
         $ethernet_ports->{$p}->{packets_unicast_out} ne $self->snmp->i_pkts_ucast_out()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_unicast_out} = $self->snmp->i_pkts_ucast_out()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_unicast_packets_out", $ethernet_ports->{$p}->{packets_unicast_out} , 1);
    }

    #check for incoming broadcast packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_broadcast_in}) ||
         $ethernet_ports->{$p}->{packets_broadcast_in} ne $self->snmp->i_pkts_bcast_in()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_broadcast_in} = $self->snmp->i_pkts_bcast_in()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_broadcast_packets_in", $ethernet_ports->{$p}->{packets_broadcast_in} , 1);
    }

    #check for outgoing broadcast packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_broadcast_out}) ||
         $ethernet_ports->{$p}->{packets_broadcast_out} ne $self->snmp->i_pkts_bcast_out()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_broadcast_out} = $self->snmp->i_pkts_bcast_out()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_broadcast_packets_out", $ethernet_ports->{$p}->{packets_broadcast_out} , 1);
    }


    #check for incoming discarded packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_discarded_in}) ||
         $ethernet_ports->{$p}->{packets_discarded_in} ne $self->snmp->i_discards_in()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_discarded_in} = $self->snmp->i_discards_in()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_discarded_packets_in", $ethernet_ports->{$p}->{packets_discarded_in} , 1);
    }

    #check for outgoing discarded packet stats
    if ( !defined($ethernet_ports->{$p}->{packets_discarded_out}) ||
         $ethernet_ports->{$p}->{packets_discarded_out} ne $self->snmp->i_discards_out()->{$p}
       )
    {
      $ethernet_ports->{$p}->{packets_discarded_out} = $self->snmp->i_discards_out()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_discarded_packets_out", $ethernet_ports->{$p}->{packets_discarded_out} , 1);
    }

    #check for incoming bytes stats
    if ( !defined($ethernet_ports->{$p}->{bytes_in}) ||
         $ethernet_ports->{$p}->{bytes_in} ne $self->snmp->i_octet_in()->{$p}
       )
    {
      $ethernet_ports->{$p}->{bytes_in} = $self->snmp->i_octet_in()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_bytes_in", $ethernet_ports->{$p}->{bytes_in} , 1);
    }

    #check for outgoing bytes stats
    if ( !defined($ethernet_ports->{$p}->{bytes_out}) ||
         $ethernet_ports->{$p}->{bytes_out} ne $self->snmp->i_octet_out()->{$p}
       )
    {
      $ethernet_ports->{$p}->{bytes_out} = $self->snmp->i_octet_out()->{$p};
      $update_ref->($hash, "ethernet_port_" . $ethernet_ports->{$p}->{id} . "_bytes_out", $ethernet_ports->{$p}->{bytes_out} , 1);
    }

  }

  $self->ethernet_ports($ethernet_ports);

}

1;
