# -*- cperl -*-
#
# Copyright (C) 2009 Magnus Hagander, Redpill Linpro AB
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2 dated June,
# 1991.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 USA.

# This Module is user documented inline, interspersed with code with
# perlpod.


# $Id$

=head1 NAME

Munin::Plugin::Pgsql - Base module for PostgreSQL plugins for Munin

=head1 SYNOPSIS

The Munin::Plugin::Pgsql module provides base functionality for all
PostgreSQL Munin plugins, including common configuration parameters.

=head1 CONFIGURATION

All configuration is done through environment variables.

=head1 ENVIRONMENT VARIABLES

All plugins based on Munin::Plugin::Pgsql accepts all the environment
variables that libpq does. The most common ones used are:

 PGHOST      hostname to connect to, or path to Unix socket
 PGPORT      port number to connect to
 PGUSER      username to connect as
 PGPASSWORD  password to connect with, if a password is required

The plugins will always connect to the 'template1' database, except for
wildcard per-database plugins.

=head2 Example

 [postgres_*]
    user postgres
    env.PGUSER postgres
    env.PGPORT 5433

=head1 WILDCARD MATCHING

Wildcard plugins based on this module will match on whatever type of object
specifies for a filter, usually a database. If the object name ALL is used
(for example, a symlink to postgres_connections_ALL), the filter will not be
applied, and the plugin behaves like a non-wildcard one.

=head1 REQUIREMENTS

The module requires DBD::Pg to work.

=head1 TODO

Support for using psql instead of DBD::Pg, to remove dependency.

=head1 BUGS

No known bugs at this point.

=head1 SEE ALSO

L<DBD::Pg>

=head1 AUTHOR

Magnus Hagander <magnus@hagander.net>, Redpill Linpro AB

=head1 COPYRIGHT/License.

Copyright (c) 2009 Magnus Hagander, Redpill Linpro AB

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
dated June, 1991.

=head1 API DOCUMENTATION

The following functions are available to plugins using this module.

=cut

package Munin::Plugin::Pgsql;

use strict;
use warnings;

use Munin::Plugin;

=head2 Initialization

 use Munin::Plugin::Pgsql;
 my $pg = Munin::Plugin::Pgsql->new(
    parameter=>value,
    parameter=>value
 );

=head3 Parameters

 minversion     Minimum PostgreSQL version required, formatted like 8.2. If the
                database is an older version than this, the plugin will exit
                with an error.
 title          The title for this plugin. Copied directly to the config output.
 info           The info for this plugin. Copied directly to the config output.
 vlabel         The vertical label for the graph. Copied directly to the config
                output.
 basename       For wildcard plugins, this is the base name of the plugin,
                including the trailing underscore.
 basequery      SQL query run to get the plugin values. The query should return
                two columns, one being the name of the counter and the second
                being the current value for the counter.
 pivotquery     Set to 1 to indicate that the query in basequery returns a single
                row, with one field for each counter. The name of the counter is
                taken from the returned column name, and the value from the
                first row in the result.
 configquery    SQL query run to generate the configuration information for the
                plugin. The query should return at least two columns, which are
                the name of the counter and the label of the counter. If
                a third column is present, it will be used as the info
                parameter.
 suggestquery   SQL query to run to generate the list of suggestions for a
                wildcard plugin. Don't forget to include ALL if the plugin
                supports aggregate statistics.
 graphdraw      The draw parameter for the graph. The default is LINE1.
 graphtype      The type parameter for the graph. The default is GAUGE.
 graphperiod    The period for the graph. Copied directly to the config output.
 graphmin       The min parameter for the graph. The default is no minimum.
 graphmax       The max parameter for the graph. The default is no maximum.
 stack          If set to 1, all counters except the first one will be written
                with a draw type of STACK.
 base           Used for graph_args --base. Default is 1000, set to 1024 when
                returning sizes in Kb for example.
 wildcardfilter The SQL to substitute for when a wildcard plugin is run against
                a specific entity, for example a database. All occurrances of
                the string %%FILTER%% will be replaced with this string, and
                for each occurance a parameter with the value of the filtering
                condition will be added to the DBI statement.
 paramdatabase  Makes the plugin connect to the database in the first parameter
                (wildcard plugins only) instead of 'postgres'.
 extraconfig    This string is copied directly into the configuration output
                when the plugin is run in config mode, allowing low-level
                customization.

=head3 Specifying queries

Queries specified in one of the parameters above can take one of two forms.
The easiest one is a simple string, which will then always be executed,
regardless of server version. The other form is an array, looking like this:
 [
  "SELECT 'default',... FROM ...",
  [
    "8.3", "SELECT 'query for 8.3 or earlier',... FROM ...",
    "8.1", "SELECT 'query for 8.1 or earlier',... FROM ..."
  ]
 ]
This array is parsed from top to bottom, so the entires must be in order of
version number. The *last* value found where the version specified is higher
than or equal to the version of the server will be used (yes, it counts
backwards).

=cut

sub new {
    my ($class) = shift;
    my (%args)  = @_;

    my %defaults = (
        base      => 1000,
        graphdraw => 'LINE1',
        graphtype => 'GAUGE'
    );

    my $self = {
        minversion     => $args{minversion},
        basename       => $args{basename},
        basequery      => $args{basequery},
        title          => $args{title},
        info           => $args{info},
        vlabel         => $args{vlabel},
        graphdraw      => $args{graphdraw},
        graphtype      => $args{graphtype},
        graphperiod    => $args{graphperiod},
        graphmin       => $args{graphmin},
        graphmax       => $args{graphmax},
        stack          => $args{stack},
        configquery    => $args{configquery},
        base           => $args{base},
        wildcardfilter => $args{wildcardfilter},
        suggestquery   => $args{suggestquery},
        pivotquery     => $args{pivotquery},
        paramdatabase  => $args{paramdatabase},
        extraconfig    => $args{extraconfig},
    };

    foreach my $k (keys %defaults) {
        unless (defined $self->{$k}) {
            $self->{$k} = $defaults{$k};
        }
    }
    return bless $self, $class;
}

sub Config {
    my ($self) = @_;

    $self->ensure_version();

    print "graph_title $self->{title}\n";
    print "graph_vlabel $self->{vlabel}\n";
    print "graph_category PostgreSQL\n";
    print "graph_info $self->{info}\n";
    print "graph_args --base $self->{base}";
    print " -l $self->{graphmin}" if (defined $self->{graphmin});
    print "\n";
    print "graph_period $self->{graphperiod}\n" if ($self->{graphperiod});
    print "$self->{extraconfig}\n"              if ($self->{extraconfig});

    my $firstrow = 1;
    my ($q, @p)
        = $self->replace_wildcard_parameters(
        $self->get_versioned_query($self->{configquery}));
    foreach my $row (@{$self->runquery($q, \@p)}) {
        my $l = Munin::Plugin::clean_fieldname($row->[0]);
        print "$l.label $row->[1]\n";
        print "$l.info $row->[2]\n" if (defined $row->[2]);
        print "$l.type $self->{graphtype}\n";
        if ($self->{stack} && !$firstrow) {
            print "$l.draw STACK\n";
        }
        else {
            print "$l.draw $self->{graphdraw}\n";
        }
        print "$l.min $self->{graphmin}\n" if (defined $self->{graphmin});
        print "$l.max $self->{graphmax}\n" if (defined $self->{graphmax});
        $firstrow = 0;
    }
}

sub Autoconf {
    my ($self) = @_;

    if (!$self->connect(1)) {
        print "no ($self->{connecterror})\n";
        return 1;
    }

    # Check minimum version, if it applies
    if ($self->{minversion}) {
        $self->get_version();
        if ($self->{detected_version} < $self->{minversion}) {
            print
                "no (version $self->{detected_version} is less than the required $self->{minversion})\n";
            return 1;
        }
    }

    # More magic needed?
    print "yes\n";
    return 0;
}

sub Suggest {
    my ($self) = @_;

    if (!$self->connect(1)) {
        return 0;
    }

    $self->ensure_version();
    if ($self->{suggestquery}) {
        my $r = $self->runquery($self->{suggestquery});
        foreach my $row (@$r) {
            print $row->[0] . "\n";
        }
        return 0;
    }
    die "Plugin can't do suggest, why did you try?\n";
}

sub GetData {
    my ($self) = @_;
    $self->ensure_version();
    if ($self->{basequery}) {
        my ($q, @p)
            = $self->replace_wildcard_parameters(
            $self->get_versioned_query($self->{basequery}));
        my $r = $self->runquery($q, \@p, $self->{pivotquery});
        foreach my $row (@$r) {
            my $l = Munin::Plugin::clean_fieldname($row->[0]);
            print $l . ".value " . $row->[1] . "\n";
        }
        return;
    }
    die "No query configured!";
}

=head2 Processing

 $pg->Process();

 This command executes the plugin. It will automatically parse the ARGV array
 for commands given by Munin.

=cut

sub Process {
    my ($self) = @_;

    if (defined $ARGV[0] && $ARGV[0] ne '') {
        if ($ARGV[0] eq 'autoconf') {
            return $self->Autoconf();
        }
        elsif ($ARGV[0] eq 'config') {
            return $self->Config();
        }
        elsif ($ARGV[0] eq 'suggest') {
            return $self->Suggest();
        }
        else {
            print "Unknown command: '$ARGV[0]'\n";
            return 1;
        }
    }

    return $self->GetData();
}

# Internal useful functions
sub connect() {
    my ($self, $noexit) = @_;

    my $r = $self->_connect();
    return 1 if ($r);         # connect successful
    return 0 if ($noexit);    # indicate failure but don't exit
    print "Failed to connect to database: $self->{connecterror}\n";
    exit(1);
}

sub _connect() {
    my ($self) = @_;

    return 1 if ($self->{dbh});

    if (eval "require DBI; require DBD::Pg;") {

        # Always connect to database template1, because it exists on both old
        # and new versions of PostgreSQL, unless the database should be controlled
        # by the first parameter.
        # All other connection parameters are controlled by the libpq environment
        # variables.
        my $dbname = "template1";
        $dbname = $self->wildcard_parameter(0) if ($self->{paramdatabase});
        $self->{dbh} = DBI->connect("DBI:Pg:dbname=$dbname");
        unless ($self->{dbh}) {
            $self->{connecterror} = "$DBI::errstr";
            return 0;
        }
    }
    else {
        $self->{connecterror} = "DBD::Pg not found, and cannot do psql yet";
        return 0;
    }
    return 1;
}

sub runquery {
    my ($self, $query, $params, $pivot) = @_;
    $self->connect();
    if ($self->{dbh}) {

        # Run query on DBI
        my $s = $self->{dbh}->prepare($query);
        my $r = $s->execute(@$params);
        unless ($r) {
            print "Query failed!\n";
            exit(1);
        }
        if ($pivot) {

            # Query returning a single row with one column for each counter
            # Turn this into a regular resultset
            my $r     = [];
            my @dbrow = $s->fetchrow_array();
            for (my $i = 0; $i < scalar(@dbrow); $i++) {
                push @$r, [$s->{NAME}->[$i], $dbrow[$i]];
            }
            return $r;
        }
        else {
            return $s->fetchall_arrayref();
        }
    }
    die "Don't know how to run without DBI yet!\n";
}

sub get_version {
    my ($self) = @_;

    return if (defined $self->{detected_version});

    my $r = $self->runquery("SELECT version()");
    my $v = $r->[0]->[0];
    die "Unable to detect PostgreSQL version\n"
        unless ($v =~ /^PostgreSQL (\d+)\.(\d+)\.(\d+) on/);
    $self->{detected_version} = "$1.$2";
}

sub get_versioned_query {
    my ($self, $query) = @_;
    if (ref($query) eq "ARRAY") {
        my $rq = undef;
        $self->get_version();
        foreach my $entry (@$query) {
            if (!defined($rq)) {

                # First row must always be a scalar
                die "First available query must be unconditional"
                    unless (ref($entry) eq "");
                $rq = $entry;
                next;
            }
            die "Non-first available queries must be version conditional!"
                unless (ref($entry) eq "ARRAY");
            if ($self->{detected_version} <= @$entry[0]) {

                # We are running against a server that's this version or older, so change
                # to using this query.
                $rq = @$entry[1];
            }
        }
        return $rq;
    }
    else {
        return $query;
    }
}

sub ensure_version {
    my ($self) = @_;

    if ($self->{minversion}) {
        $self->get_version();
        if ($self->{detected_version} < $self->{minversion}) {
            die
                "This plugin requires PostgreSQL $self->{minversion} or newer!\n";
        }
    }
}

sub replace_wildcard_parameters {
    my ($self, $q) = @_;
    my @p = ();

    my $w = $self->wildcard_parameter();
    if ($w) {
        while ($q =~ s/%%FILTER%%/$self->{wildcardfilter}/) {
            push @p, $self->wildcard_parameter();
        }
    }
    else {

        # Not called as a wildcard, or called with "all" - remove filter spec
        $q =~ s/%%FILTER%%//g;
    }

    # PARAM replacements are done without placeholders, so they can modify
    # the query itself.
    if ($self->wildcard_parameter(-1)) {
        my @pieces = split /:/, $self->wildcard_parameter(-1);
        for (my $i = 0; $i <= $#pieces; $i++) {
            while ($q =~ s/%%PARAM$i%%/$pieces[$i]/) {
            }
        }
    }
    return ($q, @p);
}

sub wildcard_parameter {
    my ($self, $paramnum) = @_;

    return undef unless (defined $self->{basename});

    $paramnum = 0 unless (defined $paramnum);
    if ($0 =~ /$self->{basename}(.*)$/) {

        # If asking for first parameter, and there's no filter on it,
        # return undef.
        return undef if ($1 eq "ALL" && $paramnum == 0);

        # If asking for unsplit, return that (internal use only, really)
        return $1 if ($paramnum == -1);

        # Otherwise, split the string again on colon, and return the
        # selected piece.
        my @pieces = split /:/, $1;
        if (scalar(@pieces) < $paramnum + 1) {
            die "Piece $paramnum not found in wildcard parameter.\n";
        }
        return $pieces[$paramnum];
    }
    die "Wildcard base not found in called filename!\n";
}

1;
