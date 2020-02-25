=head1 LICENSE
Copyright [2018-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME
Bio::EnsEMBL::DataCheck::Pipeline::synchronising_conf

=head1 DESCRIPTION
A pipeline for executing datachecks.

=cut

package synchronising_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Production::Pipeline::PipeConfig::Base_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},

    pipeline_name => 'synchronising',
    mdatabase => undef,
    pattern => undef,
    dumppath => undef,
    dropbaks => 0,

    populate_controlled_tables    => 1,
    populate_analysis_description => 1,
    # DB Factory
    species      => [],
    antispecies  => [],
    taxons       => [],
    antitaxons   => [],
    division     => [],
    run_all      => 0,
    meta_filters => {},
    group        => 'core',
    #datacheck
    history_file => undef 
  };
}

# Implicit parameter propagation throughout the pipeline.
sub hive_meta_table {
  my ($self) = @_;

  return {
    %{$self->SUPER::hive_meta_table},
    'hive_use_param_stack' => 1,
  };
}

sub pipeline_wide_parameters {
 my ($self) = @_;

 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'populate_controlled_tables' => $self->o('populate_controlled_tables'),
   'populate_analysis_description' => $self->o('populate_analysis_description'),
 };
}

sub pipeline_analyses {
  my $self = shift @_;

  return [
    {
      -logic_name        => 'DbFactory',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbFactory',
      -max_retry_count   => 1,
      -input_ids         => [ {} ],
      -parameters        => {
                              species      => $self->o('species'),
                              antispecies  => $self->o('antispecies'),
                              division     => $self->o('division'),
                              registry     => $self->o('registry'),
                              run_all      => $self->o('run_all'),
                              meta_filters => $self->o('meta_filters'),
                              group        => $self->o('group'),
                            },
       -flow_into        => {
                              '2' =>
                                WHEN(
                                  '#populate_controlled_tables#' =>
                                    ['populatecontroltable'],
                                  '#populate_analysis_description#' =>
                                    ['populateanalysisdescription'],
                                )
                            }
    },
    {
      -logic_name => 'populatecontroltable',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -flow_into  => ['DbAwareSpeciesFactory_db']
    },
    {
       -logic_name => 'populateanalysisdescription',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -flow_into  => ['DbAwareSpeciesFactory_description']

    },
    {
      -logic_name        => 'DbAwareSpeciesFactory_db',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['RunDatachecksContolTables'],
                              '4' => ['RunDatachecksContolTables'],
                            },
    },
    {
      -logic_name        => 'DbAwareSpeciesFactory_description',
      -module            => 'Bio::EnsEMBL::Production::Pipeline::Common::DbAwareSpeciesFactory',
      -analysis_capacity => 10,
      -batch_size        => 100,
      -max_retry_count   => 0,
      -parameters        => {},
      -rc_name           => 'normal',
      -flow_into         => {
                              '2' => ['RunDatachecksAnalysisDescription'],
                              '4' => ['RunDatachecksAnalysisDescription'],
                            },
    },
    {
      -logic_name        => 'RunDatachecksContolTables',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters        => {
                              datacheck_names  => ['ForeignKeys', 'ControlledTablesCore' , 'ControlledTablesVariation'],
                              history_file     => $self->o('history_file'),
                              failures_fatal   => 1,
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal',
    },
    {
      -logic_name        => 'RunDatachecksAnalysisDescription',
      -module            => 'Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks',
      -parameters        => {
                              datacheck_names  => ['AnalysisDescription', 'ControlledAnalysis', 'DisplayableGenes', 'DisplayableSampleGene', 'ForeignKeys', 'FuncgenAnalysisDescription'],
                              history_file     => $self->o('history_file'),
                              failures_fatal   => 1,
                            },
      -max_retry_count   => 1,
      -analysis_capacity => 10,
      -rc_name           => 'normal',
    },


  ];
}

sub resource_classes {
  my ($self) = @_;

  return {
    'normal' => {'LSF' => '-q production-rh74 -M 1000 -R "rusage[mem=1000]"'}, 
    'default' => {LSF => '-q production-rh74 -M 500 -R "rusage[mem=500]"'},
    '2GB'     => {LSF => '-q production-rh74 -M 2000 -R "rusage[mem=2000]"'},
    '4GB'     => {LSF => '-q production-rh74 -M 4000 -R "rusage[mem=4000]"'},
  }
}

1;


