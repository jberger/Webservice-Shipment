use Mojo::Base -strict;

use Test::More;

use Mojo::Shipment;

my $ship = Mojo::Shipment->new;
$ship->add_carrier('UPS');
isa_ok $ship->carriers->[0], 'Mojo::Shipment::Carrier::UPS';
$ship->add_carrier('USPS');
isa_ok $ship->carriers->[1], 'Mojo::Shipment::Carrier::USPS';

isa_ok $ship->detect('9400115901396094290000'), 'Mojo::Shipment::Carrier::USPS';
like $ship->human_url('9400115901396094290000'), qr/usps/i, 'correct delegation';

isa_ok $ship->detect('1Z584856NT65700000'), 'Mojo::Shipment::Carrier::UPS';
like $ship->human_url('1Z584856NT65700000'), qr/ups/i, 'correct delegation';

done_testing;


