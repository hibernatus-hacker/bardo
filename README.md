# Bardo

A powerful and friendly neuroevolution library for Elixir, based on a topology 
and parameter evolving universal learning network originally created by Gene Sher.

## Requirements

  - [Elixir](https://elixir-lang.org/install.html) (>= 1.13)
  - [CMake](https://cmake.org/)

## Introduction

`Bardo` is a distributed topology and weight evolving artificial neural
network originally created by Gene Sher. This Elixir port includes significant changes such as a deeper
integration of the OTP application structure, replacement of the single scape
process with a quad tree, converting the sensor -> scape and actuator -> scape
processes to be asynchronous, dropping Mnesia in favour of RocksDB.

## Project Status

This project is currently in active development as a port from the original Erlang
implementation. The following components have been converted:

✅ Core project structure and configuration  
✅ Utility modules (Functions, Models, Utils)  
✅ Agent manager core modules (Neuron, SignalAggregator)  
✅ Plasticity functionality  
✅ Tests for core functionality  
⏳ Population manager modules (pending)  
⏳ Experiment manager modules (pending)  
⏳ Scape manager modules (pending)  
⏳ Example applications (pending)  
⏳ Benchmark applications (pending)  

The goal is to provide a complete, well-tested, and user-friendly neuroevolution
library for Elixir that maintains compatibility with the original system while
leveraging Elixir's strengths.

## Architecture

Bardo uses a distributed, message-passing architecture for neural network simulation:

1. **Neuron** - The core processing element that accepts inputs, applies weights and an activation function, and sends output to connected elements.

2. **Cortex** - Coordinates neurons, sensors, and actuators to form a complete neural network.

3. **ExoSelf** - The outer control process that manages a neural network's lifecycle.

4. **Population Manager** - Handles evolution of neural networks.

5. **Experiment Manager** - Conducts experiments by running multiple evolutionary runs.

All these components communicate using Elixir processes and message passing, making the system highly concurrent and scalable.

## How to:

### 1. Build

```bash
mix deps.get
mix compile
```

### 2. Run Static Analysis

```bash
mix credo
mix dialyzer
```

### 3. Run Tests

```bash
mix test
mix coveralls
```

### 4. Run

```bash
iex -S mix
iex(1)> Bardo.ExperimentManager.run()
```

### 5. Generate release

```bash
MIX_ENV=prod mix release
```

### 6. Run release

```bash
_build/prod/rel/bardo/bin/bardo start
```

### 7. Observe

From an IEx session:

```elixir
:observer.start()
```

or

```elixir
:observer_cli.start()
```

### 8. Conduct an experiment

The experiment manager process composes experiments by performing N evolutionary
runs, and then produces statistical data and chart-ready files of the various
evolutionary dynamics and averages.

All these files can be found under the `/experiments` directory.

## Configuration

Every application of the system needs a corresponding configuration file. The
`/config` directory contains examples that can be used to get
started.

Remember, we do not need to force the system to use any one particular approach.
We can set it in the constraints to use all available functionality and the
system will evolve it all.

## Benchmarks

Three benchmarks are included:
- Double pole balancing without damping
- Double pole balancing with damping
- Discrete T-maze

See the `/docs/examples/benchmarks` directory for more information.

## Applications

Two applications are included:
- Flatland
- FX

See the `/docs/examples/applications` directory for more information.

## Documentation

### Developers
The most useful resource for developers working on this project will be the
inline documentation and the ExDocs.

### General
For a more general introduction, see the `/docs` directory for a quick
introduction to neuroevolution and related topics.

For a more thorough introduction, the book "Handbook of Neuroevolution Through
Erlang" by Gene Sher is highly recommended. Indeed, much of the content in the
Docs section is taken from this book as is the majority of the inline
documentation found in the source code. So, credit for the good stuff goes to
him.

## Related publications

1. [Handbook of Neuroevolution Through Erlang](http://www.amazon.com/Handbook-Neuroevolution-Through-Erlang-Gene/dp/1461444624) _by Gene Sher_.
2. [Agent-Based Modeling Using Erlang](https://pdfs.semanticscholar.org/239e/e207f97233f3e28852fe43341aaaaf4bb2e7.pdf) _by Gene Sher_.

## License

Copyright (c) 2023

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.