package Mojolicious::Plugin::CacheMoney;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app, $opts ) = @_;
}

# ABSTRACT: Bling blind
1;

=head1 SYNOPSIS

    package App;
    use Mojo::Base 'Mojolicious';

    sub startup {
        my $self = shift;

        $self->plugin( 'Mojolicious::Plugin::CacheMoney' );
        # ...
    }

then

    package App::Example;
    use Mojo::Base 'Mojolicious::Controller';

    sub test {
        my $self = shift;
    }

=cut
