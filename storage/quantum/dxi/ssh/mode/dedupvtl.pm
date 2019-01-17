  #
  # Copyright 2019 Centreon (http://www.centreon.com/)
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

  package storage::quantum::dxi::ssh::mode::dedupvtl;

  use base qw(centreon::plugins::templates::counter);

  use strict;
  use warnings;
  use DateTime;

  my $instance_mode;

  sub custom_status_threshold {
      my ($self, %options) = @_;
      my $status = 'ok';
      my $message;

      eval {
          local $SIG{__WARN__} = sub { $message = $_[0]; };
          local $SIG{__DIE__} = sub { $message = $_[0]; };

          if (defined($instance_mode->{option_results}->{critical_status}) && $instance_mode->{option_results}->{critical_status} ne '' &&
              eval "$instance_mode->{option_results}->{critical_status}") {
              $status = 'critical';
          } elsif (defined($instance_mode->{option_results}->{warning_status}) && $instance_mode->{option_results}->{warning_status} ne '' &&
              eval "$instance_mode->{option_results}->{warning_status}") {
              $status = 'warning';
          }
      };
      if (defined($message)) {
          $self->{output}->output_add(long_msg => 'filter status issue: ' . $message);
      }

      return $status;
  }

  sub custom_status_output {
      my ($self, %options) = @_;

      my $msg = sprintf("Status is '%s' [State: %s], Duration: %s, Percent complete: %s%%",
          $self->{result_values}->{status}, $self->{result_values}->{state},
          centreon::plugins::misc::change_seconds(value => $self->{result_values}->{duration}),
          $self->{result_values}->{percent_complete});
      return $msg;
  }

  sub custom_status_calc {
      my ($self, %options) = @_;

      $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_status'};
      $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
      $self->{result_values}->{start_time} = $options{new_datas}->{$self->{instance} . '_start_time'};
      $self->{result_values}->{completion_time} = $options{new_datas}->{$self->{instance} . '_completion_time'};
      $self->{result_values}->{percent_complete} = $options{new_datas}->{$self->{instance} . '_percent_complete'};

      my ($start, $end);
      my %months = ("Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12);
      if (defined($self->{result_values}->{start_time}) && $self->{result_values}->{start_time} =~ /^(\w+)\s(\w+)\s(\d+)\s(\d+):(\d+):(\d+)\s(\d+)$/) { # Mon Jan 01 13:01:23 2018
          $start = DateTime->new(year => $7, month => $months{$2}, day => $3, hour => $4, minute => $5, second => $6);
      }
      if (defined($self->{result_values}->{completion_time}) && $self->{result_values}->{completion_time} =~ /^(\w+)\s(\w+)\s(\d+)\s(\d+):(\d+):(\d+)\s(\d+)$/) {
          $end = DateTime->new(year => $7, month => $months{$2}, day => $3, hour => $4, minute => $5, second => $6);
      }

      $self->{result_values}->{duration} = 0;
      $self->{result_values}->{duration} = $end->epoch() - $start->epoch() if (defined($end));
      $self->{result_values}->{duration} = time() - $start->epoch() if (defined($start) && !defined($end));

      return 0;
  }

  sub prefix_output {
      my ($self, %options) = @_;
      return "VTL deduplication '" . $options{instance_value}->{name} . "' ";
  }

  sub set_counters {
      my ($self, %options) = @_;

      $self->{maps_counters_type} = [
          { name => 'global', type => 1, cb_prefix_output => 'prefix_output', message_multiple => 'All VTL deduplication are ok', message_separator => ' - ' },
      ];

      $self->{maps_counters}->{global} = [
          { label => 'status', threshold => 0, set => {
                  key_values => [ { name => 'status' }, { name => 'state' }, { name => 'start_time' },
                      { name => 'completion_time' }, { name => 'percent_complete' }, { name => 'name' } ],
                  closure_custom_calc => $self->can('custom_status_calc'),
                  closure_custom_output => $self->can('custom_status_output'),
                  closure_custom_perfdata => sub { return 0; },
                  closure_custom_threshold_check => $self->can('custom_status_threshold'),
              }
          },
          { label => 'original-data-size', set => {
                  key_values => [ { name => 'original_size' }, { name => 'name' }  ],
                  output_template => 'Original data size: %s %s',
                  output_change_bytes => 1,
                  perfdatas => [
                      { label => 'original_data_size', value => 'original_size_absolute', template => '%d',
                        unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'name_absolute' },
                  ],
              }
          },
          { label => 'sent-data-size', set => {
                  key_values => [ { name => 'sent_size' }, { name => 'name' }  ],
                  output_template => 'Sent data size: %s %s',
                  output_change_bytes => 1,
                  perfdatas => [
                      { label => 'sent_data_size', value => 'sent_size_absolute', template => '%d',
                        unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'name_absolute' },
                  ],
              }
          },
      ];
  }

  sub new {
      my ($class, %options) = @_;
      my $self = $class->SUPER::new(package => __PACKAGE__, %options);
      bless $self, $class;

      $self->{version} = '1.0';
      $options{options}->add_options(arguments =>
                                  {
                                    "hostname:s"          => { name => 'hostname' },
                                    "ssh-option:s@"       => { name => 'ssh_option' },
                                    "ssh-path:s"          => { name => 'ssh_path' },
                                    "ssh-command:s"       => { name => 'ssh_command', default => 'ssh' },
                                    "timeout:s"           => { name => 'timeout', default => 30 },
                                    "sudo"                => { name => 'sudo' },
                                    "command:s"           => { name => 'command', default => 'syscli' },
                                    "command-path:s"      => { name => 'command_path' },
                                    "command-options:s"   => { name => 'command_options', default => '--list dedupvtl' },
                                    "warning-status:s"    => { name => 'warning_status', default => '%{state} !~ /Enabled/i' },
                                    "critical-status:s"   => { name => 'critical_status', default => '' },
                                  });

      return $self;
  }

  sub check_options {
      my ($self, %options) = @_;
      $self->SUPER::check_options(%options);

      if (defined($self->{option_results}->{hostname}) && $self->{option_results}->{hostname} ne '') {
          $self->{option_results}->{remote} = 1;
      }

      $instance_mode = $self;
      $self->change_macros();
  }

  sub change_macros {
      my ($self, %options) = @_;

      foreach (('warning_status', 'critical_status')) {
          if (defined($self->{option_results}->{$_})) {
              $self->{option_results}->{$_} =~ s/%\{(.*?)\}/\$self->{result_values}->{$1}/g;
          }
      }
  }

  sub manage_selection {
      my ($self, %options) = @_;

      $self->{global} = {};

      my ($stdout, $exit_code) = centreon::plugins::misc::execute(output => $self->{output},
                                                                  options => $self->{option_results},
                                                                  sudo => $self->{option_results}->{sudo},
                                                                  command => $self->{option_results}->{command},
                                                                  command_path => $self->{option_results}->{command_path},
                                                                  command_options => $self->{option_results}->{command_options},
                                                                  );
      # Output data:
      # List of all deduped VTL on source:
      # Total count = 2
      # [dedupvtl = 1]
      #     VTL name = Library_DC1
      #     Replication type  = SYNCHRONIZATION
      #     Replication state = Enabled
      #     Replication sync id = Library_DC1
      #     Replication target = 1.2.3.5
      #     Replication start = Tue Jun 12 11:00:36 2018
      #     Replication completion = Wed Jun 13 09:22:14 2018
      #     Replication status = SUCCESS
      #     Percent complete = 0
      #     Estimated completion time = No time remaining.
      #     Original data size = 159591544529360
      #     Actual data sent = 653312931536
      #     Average data sent = 8.63815e+06
      # [dedupvtl = 2]
      #     VTL name = vtl_dc1_plat
      #     Replication type  = SYNCHRONIZATION
      #     Replication state = Enabled
      #     Replication sync id = vtl_dc1_plat
      #     Replication target = 1.2.3.4
      #     Replication start = Tue Jun 12 10:38:01 2018
      #     Replication completion = Tue Jun 12 11:06:36 2018
      #     Replication status = SUCCESS
      #     Percent complete = 2
      #     Estimated completion time = No time remaining.
      #     Original data size = 162997086504
      #     Actual data sent = 4352486416
      #     Average data sent = 1.9672e+07

      my $id;
      foreach (split(/\n/, $stdout)) {
          $id = $1 if ($_ =~ /.*\[dedupvtl\s=\s(.*)\]$/i);
          $self->{global}->{$id}->{name} = $1 if ($_ =~ /.*VTL\sname\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{state} = $1 if ($_ =~ /.*Replication\sstate\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{start_time} = $1 if ($_ =~ /.*Replication\sstart\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{completion_time} = $1 if ($_ =~ /.*Replication\scompletion\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{status} = $1 if ($_ =~ /.*Replication\sstatus\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{percent_complete} = $1 if ($_ =~ /.*Percent\scomplete\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{original_size} = $1 if ($_ =~ /.*Original\sdata\ssize\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{sent_size} = $1 if ($_ =~ /.*Actual\sdata\ssent\s=\s(.*)$/i && defined($id) && $id ne '');
          $self->{global}->{$id}->{status} = "-" if (defined($id) && $id ne '' && !defined($self->{global}->{$id}->{status}));
          $self->{global}->{$id}->{start_time} = "-" if (defined($id) && !defined($self->{global}->{$id}->{start_time}));
          $self->{global}->{$id}->{completion_time} = "-" if (defined($id) && !defined($self->{global}->{$id}->{completion_time}));
      }
  }

  1;


  =head1 MODE

  Check deduped VTL on source.

  =over 8

  =item B<--hostname>

  Hostname to query.

  =item B<--filter-counters>

  Only display some counters (regexp can be used).
  Example: --filter-counters='status'

  =item B<--warning-status>

  Set warning threshold for status (Default: '%{state} !~ /Enabled/i').
  Can used special variables like: %{status}, %{state}, %{duration}, %{percent_complete}.

  =item B<--critical-status>

  Set critical threshold for status (Default: '').
  Can used special variables like: %{status}, %{state}, %{duration}, %{percent_complete}.

  =item B<--warning-*>

  Threshold warning.
  Can be: 'original-data-size', 'sent-data-size'.

  =item B<--critical-*>

  Threshold critical.
  Can be: 'original-data-size', 'sent-data-size'.

  =item B<--ssh-option>

  Specify multiple options like the user (example: --ssh-option='-l=centreon-engine' --ssh-option='-p=52').

  =item B<--ssh-path>

  Specify ssh command path (default: none)

  =item B<--ssh-command>

  Specify ssh command (default: 'ssh'). Useful to use 'plink'.

  =item B<--timeout>

  Timeout in seconds for the command (Default: 30).

  =item B<--sudo>

  Use 'sudo' to execute the command.

  =item B<--command>

  Command to get information (Default: 'syscli').

  =item B<--command-path>

  Command path.

  =item B<--command-options>

  Command options (Default: '--list dedupvtl').

  =back

  =cut
