# Erlang to Elixir Module Mapping

This document outlines the mapping between the original Erlang modules and the new Elixir modules in the Bardo project.

## Core Application Structure

| Erlang Module | Elixir Module |
|---------------|---------------|
| apxr_run_app.erl | Bardo.Application |
| apxr_run_sup.erl | Bardo.Supervisor |
| polis_sup.erl | Bardo.Polis.Supervisor |
| polis_mgr.erl | Bardo.Polis.Manager |
| db.erl | Bardo.DB |

## Agent Manager Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| agent_mgr/agent_mgr.erl | Bardo.AgentManager |
| agent_mgr/agent_mgr_sup.erl | Bardo.AgentManager.Supervisor |
| agent_mgr/agent_sup.erl | Bardo.AgentManager.AgentSupervisor |
| agent_mgr/agent_worker.erl | Bardo.AgentManager.AgentWorker |
| agent_mgr/actuator.erl | Bardo.AgentManager.Actuator |
| agent_mgr/cortex.erl | Bardo.AgentManager.Cortex |
| agent_mgr/exoself.erl | Bardo.AgentManager.Exoself |
| agent_mgr/neuron.erl | Bardo.AgentManager.Neuron |
| agent_mgr/private_scape.erl | Bardo.AgentManager.PrivateScape |
| agent_mgr/private_scape_sup.erl | Bardo.AgentManager.PrivateScapeSupervisor |
| agent_mgr/sensor.erl | Bardo.AgentManager.Sensor |
| agent_mgr/signal_aggregator.erl | Bardo.AgentManager.SignalAggregator |
| agent_mgr/substrate.erl | Bardo.AgentManager.Substrate |
| agent_mgr/substrate_cep.erl | Bardo.AgentManager.SubstrateCEP |
| agent_mgr/substrate_cpp.erl | Bardo.AgentManager.SubstrateCPP |
| agent_mgr/tuning_duration.erl | Bardo.AgentManager.TuningDuration |

## Population Manager Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| population_mgr/population_mgr.erl | Bardo.PopulationManager |
| population_mgr/population_mgr_sup.erl | Bardo.PopulationManager.Supervisor |
| population_mgr/population_mgr_worker.erl | Bardo.PopulationManager.Worker |
| population_mgr/genome_mutator.erl | Bardo.PopulationManager.GenomeMutator |
| population_mgr/genotype.erl | Bardo.PopulationManager.Genotype |
| population_mgr/morphology.erl | Bardo.PopulationManager.Morphology |
| population_mgr/selection_algorithm.erl | Bardo.PopulationManager.SelectionAlgorithm |
| population_mgr/specie_identifier.erl | Bardo.PopulationManager.SpecieIdentifier |
| population_mgr/tot_topological_mutations.erl | Bardo.PopulationManager.TotTopologicalMutations |

## Experiment Manager Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| experiment_mgr/experiment_mgr.erl | Bardo.ExperimentManager |
| experiment_mgr/experiment_mgr_sup.erl | Bardo.ExperimentManager.Supervisor |

## Scape Manager Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| scape_mgr/scape.erl | Bardo.ScapeManager.Scape |
| scape_mgr/scape_mgr.erl | Bardo.ScapeManager |
| scape_mgr/scape_mgr_sup.erl | Bardo.ScapeManager.Supervisor |
| scape_mgr/scape_sup.erl | Bardo.ScapeManager.ScapeSupervisor |
| scape_mgr/sector.erl | Bardo.ScapeManager.Sector |
| scape_mgr/sector_sup.erl | Bardo.ScapeManager.SectorSupervisor |

## Utility Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| lib/functions.erl | Bardo.Functions |
| lib/utils.erl | Bardo.Utils |
| lib/app_config.erl | Bardo.AppConfig |
| lib/models.erl | Bardo.Models |
| lib/logr.erl | Bardo.Logger |
| lib/flatlog.erl | Bardo.Logger.Flatlog |
| lib/plasticity.erl | Bardo.Plasticity |
| lib/tuning_selection.erl | Bardo.TuningSelection |

## Client Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| lib/agent_mgr_client.erl | Bardo.Client.AgentManager |
| lib/experiment_mgr_client.erl | Bardo.Client.ExperimentManager |
| lib/population_mgr_client.erl | Bardo.Client.PopulationManager |
| lib/scape_mgr_client.erl | Bardo.Client.ScapeManager |

## Tar Modules

| Erlang Module | Elixir Module |
|---------------|---------------|
| lib/tar/apxr_erl_tar.erl | Bardo.Tar.ErlTar |
| lib/tar/apxr_filename.erl | Bardo.Tar.Filename |
| lib/tar/apxr_tarball.erl | Bardo.Tar.Tarball |
| lib/tar/safe_erl_term.erl | Bardo.Tar.SafeErlTerm |

## Applications - Flatland

| Erlang Module | Elixir Module |
|---------------|---------------|
| examples/applications/flatland/flatland.erl | Bardo.Applications.Flatland.Flatland |
| examples/applications/flatland/flatland_actuator.erl | Bardo.Applications.Flatland.FlatlandActuator |
| examples/applications/flatland/flatland_sensor.erl | Bardo.Applications.Flatland.FlatlandSensor |
| examples/applications/flatland/flatland_utils.erl | Bardo.Applications.Flatland.FlatlandUtils |
| examples/applications/flatland/predator.erl | Bardo.Applications.Flatland.Predator |
| examples/applications/flatland/prey.erl | Bardo.Applications.Flatland.Prey |

## Applications - FX

| Erlang Module | Elixir Module |
|---------------|---------------|
| examples/applications/fx/fx.erl | Bardo.Applications.Fx.Fx |
| examples/applications/fx/fx_actuator.erl | Bardo.Applications.Fx.FxActuator |
| examples/applications/fx/fx_morphology.erl | Bardo.Applications.Fx.FxMorphology |
| examples/applications/fx/fx_sensor.erl | Bardo.Applications.Fx.FxSensor |

## Benchmarks - DPB

| Erlang Module | Elixir Module |
|---------------|---------------|
| examples/benchmarks/dpb/dpb.erl | Bardo.Benchmarks.Dpb.Dpb |
| examples/benchmarks/dpb/dpb_actuator.erl | Bardo.Benchmarks.Dpb.DpbActuator |
| examples/benchmarks/dpb/dpb_sensor.erl | Bardo.Benchmarks.Dpb.DpbSensor |
| examples/benchmarks/dpb/dpb_w_damping.erl | Bardo.Benchmarks.Dpb.DpbWDamping |
| examples/benchmarks/dpb/dpb_wo_damping.erl | Bardo.Benchmarks.Dpb.DpbWoDamping |

## Benchmarks - DTM

| Erlang Module | Elixir Module |
|---------------|---------------|
| examples/benchmarks/dtm/dtm.erl | Bardo.Benchmarks.Dtm.Dtm |
| examples/benchmarks/dtm/dtm_actuator.erl | Bardo.Benchmarks.Dtm.DtmActuator |
| examples/benchmarks/dtm/dtm_morphology.erl | Bardo.Benchmarks.Dtm.DtmMorphology |
| examples/benchmarks/dtm/dtm_sensor.erl | Bardo.Benchmarks.Dtm.DtmSensor |