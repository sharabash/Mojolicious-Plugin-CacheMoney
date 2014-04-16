package Mojolicious::Plugin::CacheMoney;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util 'decamelize';
use CHI;

sub register {
    my ( $self, $app, $opts ) = @_;
    $opts->{ '-chi' } //= {
        driver => 'Memcached::Fast'
        , servers => [ "127.0.0.1:11211" ]
        , compress_threshold => 16 * 1024
        , namespace => decamelize( ref $app ) .':'. $app->mode
        , serializer => { serializer => 'JSON::XS', compress => 1 }
    };
    $app->attr( __chi => sub {
        return new CHI ( %{ $opts->{ '-chi' } } );
    } );
    $app->helper( chi => sub { shift->app->__chi } );
    $app->attr( __started_on => time );
    $app->helper( started_on => sub {
        my $app = shift;
        return $app->app->__started_on;
    } );
    $app->helper( cache => sub {
        my ( $self, $get, $set, %args ) = @_;
        my ( $code );

        return $self->chi unless $get;

        my $shared = delete $args{shared};
        my $key = $shared ? 'shared:'. $get : ref( $self ) .':'. $get;

        return $self->chi->get( $key ) unless defined $set;

        # Set default expire_if param unless we explicitly pass in
        # expire_if => undef to override.
        $args{expire_if} = sub {
            my ( $created_at, $started_on, $expire_if ) = ( $_[0]->created_at, $self->started_on );
            # it's expired by default if it was created before the app was started/restarted
            # i.e. cache keys effectively cleared on app restart
            $expire_if = $created_at < $started_on;

            return $expire_if;
        } unless exists $args{expire_if};

        for ( keys %args ) {
            delete $args{ $_ } unless defined $args{ $_ };
        }

        $code = ref $set && ref $set eq 'CODE' ? $set : sub { $set };
        return $self->chi->compute( $key, ( %args ? \%args : undef ), $code );
    } );

}

# ABSTRACT: Bling bling
1;

=head1 USAGE

    package App;
    use Mojo::Base 'Mojolicious';

    sub startup {
        my $self = shift;
        # ...
        $self->plugin( 'Mojolicious::Plugin::CacheMoney' );
    }
    sub startup {
        my $self = shift;
        # ...or fine-tuned (below are the defaults if no options are passed):
        $self->plugin( 'Mojolicious::Plugin::CacheMoney', {
            -chi => {
                driver => 'Memcached::Fast'
                , servers => [ "127.0.0.1:11211" ]
                , compress_threshold => 16 * 1024
                , namespace => decamelize( ref $self ) .':'. $self->mode
                , serializer => { serializer => 'JSON::XS', compress => 1 }
            }
        } );
    }

then

    package App::Example;
    use Mojo::Base 'Mojolicious::Controller';

    sub test {
        my $self = shift;
        my $res1 = $self->cache( 'aprettycachekey' => sub {
            my $res = $self->do_some_database_calls_get_some_results;
            return $res;
        } );
        my $res2 = $self->cache( 'anothercachekey' => sub {
            my $res = $self->do_some_database_calls_get_some_results;
            return $res;
        }, expires_at => time + 600 );
        my $also_res1 = $self->cache( 'aprettycachekey' );
        my $res3 = $self->cache( 't minus 60 seconds until kaboom' => sub {
            my $res = $self->do_some_database_calls_get_some_results;
            return $res;
        }, expires_in => 60 );
        return $self->render( json => { res1 => $res1, res3 => $res3, also_res1 => $also_res1, res2 => $res2 } );
    }

See L<CHI> for parameters you can pass after the code ref, especially parameters around get and set (particularly see L<CHI/"Removing and expiring">).

=cut
