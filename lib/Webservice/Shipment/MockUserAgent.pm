package Webservice::Shipment::MockUserAgent;

use Mojo::Base 'Mojo::UserAgent';

use Mojolicious;
use Mojo::URL;

has mock_blocking => 1;
has mock_response => sub { {} };

sub new {
  my $self = shift->SUPER::new(@_);

  my $app = Mojolicious->new;
  $app->routes->any('/*any' => {any => ''} => sub { shift->render(%{$self->mock_response}) });
  $self->server->app($app);

  $self->on(start => sub {
    my ($self, $tx) = @_;
    $self->emit(mock_request => $tx->req);
    my $port = $self->mock_blocking ? $self->server->url->port : $self->server->nb_url->port;
    $tx->req->url->host('')->scheme('')->port($port);
  });

  return $self;
}

1;

