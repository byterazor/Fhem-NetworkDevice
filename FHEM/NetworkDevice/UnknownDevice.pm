# class representing a unknown Network Device in FHEM
package NetworkDevice::UnknownDevice;
use Moose;
use SNMP::Info;
use Data::Dumper;

with 'NetworkDevice::NetworkDevice';


sub isDevice
{
  my $self=shift;
  my $snmp=shift;
  my $debug = shift;

  return 1;
}


sub BUILD {
  my $self = shift;


}

sub setupHash
{
  my $self = shift;
  my $hash = shift;

}

sub update
{

}

sub cmd
{
  
}

1;
