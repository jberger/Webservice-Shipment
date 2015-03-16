package Mojo::Shipment::Carrier;

use Mojo::Base -base;

use Mojo::URL;
use Mojo::UserAgent;

use Carp;

has api_url => sub { Mojo::URL->new };
has password => sub { croak 'password is required' };
has ua => sub { Mojo::UserAgent->new };
has username => sub { croak 'username is required' };
has [qw/date_format validation_regex/];

sub extract_destination { '' }
sub extract_service     { '' }
sub extract_status      { return ('', '', 0) }
sub extract_weight      { '' }

sub human_url { Mojo::URL->new }

sub parse {
  my ($self, $id, $res) = @_;
  my $ret = {};

  my @targets = (qw/postal_code state city country address1 address2/);
  for my $target (@targets) {
    $ret->{destination}{$target} = $self->extract_destination($id, $res, $target) || '';
  }

  $ret->{weight} = $self->extract_weight($id, $res);

  @{$ret->{status}}{qw/description date delivered/} = $self->extract_status($id, $res);
  $ret->{status}{date} ||= '';
  if ($ret->{status}{date} and my $fmt = $self->date_format) {
    $ret->{status}{date} = $ret->{status}{date}->strftime($fmt);
  }
  $ret->{status}{delivered} = $ret->{status}{delivered} ? 1 : 0;

  $ret->{service} = $self->extract_service($id, $res);

  $ret->{human_url} = $self->human_url($id, $res)->to_string;

  return $ret;
}

sub request { die 'to be overloaded by subclass' }

sub track {
  my ($self, $id) = @_;
  my $res = $self->request($id) or return undef;
  return $self->parse($id, $res);
}

sub validate {
  my ($self, $id) = @_;
  return undef unless my $re = $self->validation_regex;
  return !!($id =~ $re);
}

1;

=head1 NAME

Mojo::Shipment::Carrier - A base class for carrier objects used by Mojo::Shipment

=head1 SYNOPSIS

=head1 DESCRIPTION

L<Mojo::Shipment::Carrier> is an abstract base class used to defined carrier objects which interact with external APIs.
For security, L<Mojo::Shipment/add_carrier> requires that added carriers be a subclass of this one.

=head1 ATTRIBUTES

L<Mojo::Shipment::Carrier> inherits all of the attributes from L<Mojo::Base> and implements the following new ones.

=head2 api_url

A L<Mojo::URL> instance for specifying the base url of the api.
It is expected that this attribute will be overloaded in a subclass.

=head2 date_format

If specified, this format string is used to convert L<Time::Piece> objects to string representations.

=head2 password

Password for the external api call.
The default implementation dies if used without being specified.

=head2 ua

An instance of L<Mojo::UserAgent>, presumably used to make the L</request>.
This is provided as a convenience for subclass implementations.

=head2 usename

Username for the external api call.
The default implementation dies if used without being specified.

=head2 validation_regex

A regexp (C<qr>) applied to a tracking id to determine if the carrier can handle the request.
Currently, this is the only mechanism by which L</validate> determines this ability.
It is expected that this attribute will be overloaded in a subclass.
The default value is C<undef> which L</validate> interprets as false.

=head1 METHODS

=head2 extract_destination

  my $dest = $carrier->extract_destination($id, $res, $type);

Returns a string of the response's destination field of a given type.
Currently those types are

=over

=item address1

=item address2

=item city

=item state

=item postal_code

=item country

=back

An implementation should return an empty string if the type is not understood or if no information is available.

=head2 extract_service

  my $service = $carrier->extract_service($id, $res);

Returns a string representing the level of service the shipment as transported with.
By convention this string also should included the carrier name.
An example might be C<USPS First Class Mail>.

An implementation should return an empty string at the minimum if the information is unavailable.
That said, to follow the convention, most implementations should at least return the carrier name in any case.

=head2 extract_status

  my ($description, $date, $delievered) = $carrier->extract_status($id, $res);

Extract either the final or current status of the shipment.
Returns three values, the textual description of the current status, a L<Time::Piece> object, and a boolean C<1/0> representing whether the shipment has been delivered.
It is likely that if the shipment has been delivered that the description and date will correspond to that even, but it is not specifically guaranteed.

=head2 extract_weight

  my $weight = $carrier->extract_weight($id, $res);

Extract the shipping weight of the parcel.
An implementation should return an empty string if the information is not available.

=head2 human_url

  my $url = $carrier->human_url($id, $res);

Returns an instance of L<Mojo::URL> which represents a url for to human interaction rather than API interaction.
An implementation should return a L<Mojo::URL> object (presumably empty) even if information is not available.

Note that though a response parameter is accepted, an implementation is likely able to generate a human_url from an id alone.

=head2 parse

  my $info = $carrier->parse($id, $res);

Returns a hash reference of data obtained from the id and the result obtained from L</request>.
It contains the following structure with results obtained from many of the other methods.

=head2 request

  my $res = $carrier->request($id);

Given a valid id, this methods should return some native result for which other methods may extract or generate information.
The actual response will be carrier dependent and should not be relied upon other than the fact that it should be able to be passed to the extraction methods and function correctly.
Must be overridden by subclass, the default implementation throws an exception.

=head2 track

  my $info = $carrier->track($id);

A shortcut for calling L</request> and then L</parse>.

=head2 validate

  $bool = $carrier->validate($id);

Given an id, check that the class can handle it.
The default implementation tests against the L</validation_regex>.

