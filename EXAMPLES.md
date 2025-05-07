# Bardo Example Applications and Benchmarks

This document outlines the example applications and benchmarks that have been converted from Erlang to Elixir as part of the Bardo project.

## 1. Applications

### 1.1 Flatland

Flatland is a 2D simulation environment where predators and prey interact in a virtual ecosystem.

**Core modules:**
- `Bardo.Examples.Applications.Flatland.Flatland`: The main simulation environment implementing a 2D world with physics.
- `Bardo.Examples.Applications.Flatland.FlatlandUtils`: Utility functions for ray casting, collision detection, and color mapping.
- `Bardo.Examples.Applications.Flatland.FlatlandSensor`: Sensors for distance and color perception (distance scanners, color scanners).
- `Bardo.Examples.Applications.Flatland.FlatlandActuator`: Actuators for agent movement (two-wheel system).
- `Bardo.Examples.Applications.Flatland.Predator`: Morphology for predator agents.
- `Bardo.Examples.Applications.Flatland.Prey`: Morphology for prey agents.
- `Bardo.Examples.Applications.Flatland`: Main module for configuring and running Flatland experiments.

**How it works:**
1. The simulation initializes a 2D world populated with plants.
2. Predator and prey agents enter the world with neural networks that control their behavior.
3. Agents perceive the environment through distance and color sensors.
4. Agents control their movement through a two-wheel actuator system.
5. Predators attempt to find and consume prey, while prey try to find and consume plants.
6. Selection occurs based on survival and performance (energy accumulation, prey consumption).

**Usage:**
```elixir
# Configure and run a Flatland experiment
Bardo.Examples.Applications.Flatland.run(
  :flatland_experiment,  # experiment ID
  20,                    # predator population size
  20,                    # prey population size
  40,                    # plant quantity
  1000,                  # simulation steps per evaluation
  50                     # generations
)
```

### 1.2 Forex (FX) Trading

FX is a financial trading simulation where agents learn to trade currency pairs based on historical price data.

**Core modules:**
- `Bardo.Examples.Applications.Fx.Fx`: The main trading simulation environment.
- `Bardo.Examples.Applications.Fx.FxSensor`: Sensors for market data (price chart images, price lists, account state).
- `Bardo.Examples.Applications.Fx.FxActuator`: Actuators for executing trades.
- `Bardo.Examples.Applications.Fx.FxMorphology`: Morphology for trading agents.
- `Bardo.Examples.Applications.Fx`: Main module for configuring and running FX experiments.

**How it works:**
1. The simulation loads historical price data for currency pairs.
2. Trading agents observe market conditions through specialized sensors.
3. Agents make trading decisions (buy, sell, hold) using their neural networks.
4. The simulation executes trades and tracks account balance, profit/loss, etc.
5. Selection occurs based on trading performance metrics (profit, win rate, drawdown).

**Usage:**
```elixir
# Configure and run an FX trading experiment
Bardo.Examples.Applications.Fx.run(
  :fx_experiment,  # experiment ID
  50,              # population size
  5000,            # data window size
  50               # generations
)
```

## 2. Benchmarks

### 2.1 Double Pole Balancing (DPB)

DPB is a classic control theory benchmark problem where agents learn to balance two poles of different lengths on a moving cart.

**Core modules:**
- `Bardo.Examples.Benchmarks.Dpb.Dpb`: The main pole balancing physics simulation.
- `Bardo.Examples.Benchmarks.Dpb.DpbSensor`: Sensors for cart position, pole angles, and velocities.
- `Bardo.Examples.Benchmarks.Dpb.DpbActuator`: Actuator for applying force to the cart.
- `Bardo.Examples.Benchmarks.Dpb.DpbWDamping`: Morphology for agents with velocity information (damping).
- `Bardo.Examples.Benchmarks.Dpb.DpbWoDamping`: Morphology for agents without velocity information (no damping).
- `Bardo.Examples.Benchmarks.Dpb`: Main module for configuring and running DPB experiments.

**How it works:**
1. The simulation initializes a cart with two poles of different lengths.
2. Agents observe the cart and pole states through sensors.
3. Agents apply force to the cart to maintain balance using their neural networks.
4. The simulation uses real physics equations to simulate the cart-pole system.
5. Selection occurs based on how long the poles remain balanced.

**Usage:**
```elixir
# Configure and run a DPB experiment with damping
Bardo.Examples.Benchmarks.Dpb.run_with_damping(
  :dpb_experiment,  # experiment ID
  100,              # population size
  50,               # generations
  100000            # maximum steps
)

# Or without damping
Bardo.Examples.Benchmarks.Dpb.run_without_damping(
  :dpb_experiment,  # experiment ID
  100,              # population size
  50,               # generations
  100000            # maximum steps
)
```

## 3. Testing

All examples and benchmarks have comprehensive unit tests that verify their functionality:

- `flatland_utils_test.exs`: Tests collision detection and ray casting.
- `flatland_sensor_test.exs`: Tests distance and color sensors.
- `flatland_actuator_test.exs`: Tests the two-wheel movement system.
- `fx_test.exs`: Tests market data processing and trading system.
- `dpb_test.exs`: Tests pole balancing physics and control mechanisms.

To run all tests:
```bash
./run_tests.sh
```

## 4. Future Work

Future expansions to this set of examples could include:
- Additional benchmark problems like Mountain Car or Lunar Lander
- Multi-agent reinforcement learning scenarios
- Image recognition tasks using convolutional neural networks
- Natural language processing applications