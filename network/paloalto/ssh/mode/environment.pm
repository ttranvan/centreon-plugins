#
# Copyright 2020 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package network::paloalto::ssh::mode::environment;

use base qw(centreon::plugins::templates::hardware);

use strict;
use warnings;

sub set_system {
    my ($self, %options) = @_;

    $self->{regexp_threshold_numeric_check_section_option} = '^(?:temperature|voltage)$';

    $self->{cb_hook2} = 'ssh_execute';

    $self->{thresholds} = {
        default => [
            ['false', 'OK'],
            ['.*', 'CRITICAL']
        ]
    };

    $self->{components_exec_load} = 0;

    $self->{components_path} = 'network::paloalto::ssh::mode::components';
    $self->{components_module} = ['temperature', 'voltage', 'psu'];
}

sub ssh_execute {
    my ($self, %options) = @_;

    ($self->{results}, $self->{exit_code}) = $options{custom}->execute_command(
        command => 'show system environmentals',
        ForceArray => ['entry']
    );
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, no_absent => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

1;

__END__

=head1 MODE

Check components.

=over 8

=item B<--component>

Which component to check (Default: '.*').
Can be: 'psu', 'temperature', 'voltage'.

=item B<--filter>

Exclude some parts (comma seperated list) (Example: --filter=temperature)
Can also exclude specific instance: --filter='temperature,Temperature @ U48'

=item B<--no-component>

Return an error if no compenents are checked.
If total (with skipped) is 0. (Default: 'critical' returns).

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,[instance,]status,regexp)
It used before default thresholds (order stays).
Example: --threshold-overload='temperture,OK,true'

=item B<--warning>

Set warning threshold for 'temperature', 'voltage' (syntax: type,regexp,threshold)
Example: --warning='temperature,.*,30'

=item B<--critical>

Set critical threshold for 'temperature', 'voltage' (syntax: type,regexp,threshold)
Example: --critical='temperature,.*,50'

=back

=cut
