package Webservice::Shipment::Carrier::FedEx;

use Mojo::Base 'Webservice::Shipment::Carrier';

use constant DEBUG =>  $ENV{MOJO_SHIPMENT_DEBUG};

use Mojo::Template;
use Mojo::URL;
use Mojo::IOLoop;
use Time::Piece;
use Cpanel::JSON::XS;

has api_url => sub { Mojo::URL->new('https://www.fedex.com/trackingCal/track') };
has carrier_description => sub { 'FedEx' };
has validation_regex => sub {    qr/(\b96\d{20}\b)|(\b\d{15}\b)|(\b\d{12}\b)/ };

has template => <<'TEMPLATE';
% my ($self, $id) = @_;
<?xml version="1.0" ?>
<AccessRequest xml:lang='en-US'>
  <AccessLicenseNumber><%== $self->api_key %></AccessLicenseNumber>
  <UserId><%== $self->username %></UserId>
  <Password><%== $self->password %></Password>
</AccessRequest>
<?xml version="1.0" ?>
<TrackRequest>
  <Request>
    <TransactionReference>
      <CustomerContext><%== $id %></CustomerContext>
    </TransactionReference>
    <RequestAction>Track</RequestAction>
  </Request>
  <TrackingNumber><%== $id %></TrackingNumber>
</TrackRequest>
TEMPLATE

sub human_url {
  my ($self, $id, $dom) = @_;
  return Mojo::URL->new('https://www.fedex.com/apps/fedextrack/')->query(action => 'track', locale => 'en_US', cntry_code => 'us', language => 'english', tracknumbers => $id);
}

sub extract_destination {
  my ($self, $id, $dom, $target) = @_;

  my %targets = (
    postal_code => 'destZip',
    state => 'destStateCD',
    city => 'destCity',
    country => 'destCntryCD',
  );

  my $t = $targets{$target} or return;
  my $addr = $dom->{$t} or return;
  return $addr;
}

sub extract_service {
  my ($self, $id, $dom) = @_;
  my $class = $dom->{'serviceDesc'};
  my $service =  $class =~m/fedex/i ? $class : 'FedEx ' . $class;
  return $service;
}

sub extract_status {
  my ($self, $id, $dom) = @_;

  my $summary = $dom->{'scanEventList'}->[0];
  return unless $summary;

  my $delivered = $dom->{isDelivered} ? 1 : 0;

  my $desc = $dom->{statusWithDetails};
  unless ($summary->{date}) {
    $desc = 'No information found for <a href="' . human_url($id) . '">' . $id . '</a>';
    return ($desc, undef, $delivered);
  }
  my $timestamp = join(' ', $summary->{date}, $summary->{time});
  eval{
    $timestamp = Time::Piece->strptime($summary->{date} . ' T ' . $summary->{time}, '%Y-%m-%d T %H:%M:%S');
  };

  $desc = $summary->{date} ? join(' ', $desc , $summary->{date}, $summary->{time}) : $desc;
  $desc ||= Cpanel::JSON::XS->new->pretty(1)->encode($dom->{'scanEventList'});
  return ($desc, $timestamp, $delivered);
}

sub extract_weight { '' }

sub request {
  my ($self, $id, $cb) = @_;

  my $tx = $self->ua->build_tx(
    POST => $self->api_url.
    {Accept => '*/*'},
    form => {
      action => 'trackpackages',
      locale => 'en_US',
      version => '1',
      format => 'json',
      data => Cpanel::JSON::XS->new->encode({
        TrackPackagesRequest => {
          appType => 'WTRK',
          uniqueKey => '',
          processingParameters => {},
          trackingInfoList => [
            {
              trackNumberInfo => {
                trackingNumber => $id,
                trackingQualifier => '',
                trackingCarrier => '',
              }
            }
          ]
        }
      })
    }
  );

  unless ($cb) {
    $self->ua->start($tx);
    return _handle_response($tx);
  }

  Mojo::IOLoop->delay(
    sub { $self->ua->start($tx, shift->begin) },
    sub {
      my ($ua, $tx) = @_;
      die $tx->error->{message} unless $tx->success;
      my $json = _handle_response($tx);
      $self->$cb(undef, $json);
    },
  )->catch(sub { $self->$cb(pop, undef) })->wait;
}

sub _handle_response {
  my $tx = shift;
  my $json = $tx->res->json;
  warn "Response:\n" . $tx->res->body . "\n" if DEBUG;
  return $json->{TrackPackagesResponse}{packageList}[0];
}

1;

=head1 NAME

Webservice::Shipment::Carrier::FedEx - FedEx handling for Webservice::Shipment

=head1 DESCRIPTION

Implements FedEx handling for L<Webservice::Shipment>.
It is a subclass of L<Webservice::Shipment::Carrier> which implements all the necessary methods.

=head1 ATTRIBUTES

L<Webservice::Shipment::Carrier::FedEx> implements all of the attributes from L<Webservice::Shipment::Carrier> and implements the following new ones

=head2 template

The string template used with L<Mojo::Template> to format the request.

=head1 NOTES

The service does not provide weight information, so C<extract_weight> will always return an empty string.
