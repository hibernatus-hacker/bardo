defmodule Bardo.Examples.Benchmarks.Dpb.Dpb do
  @moduledoc """
  Double Pole Balancing (DPB) simulation environment.
  
  This module implements the physics simulation for the cart-pole system
  with two poles of different lengths. It is a common benchmark in
  neuroevolution and reinforcement learning.
  """
  
  alias Bardo.AgentManager.PrivateScape
  
  @behaviour PrivateScape
  
  # Constants for the simulation
  @gravity 9.8           # Gravitational acceleration (m/s^2)
  @max_pos 2.4           # Maximum cart position (m)
  @max_steps 100000      # Maximum simulation steps for success
  @time_step 0.01        # Time step for physics simulation (s)
  @mass_cart 1.0         # Mass of the cart (kg)
  @mass_pole1 0.1        # Mass of the first pole (kg)
  @length_pole1 0.5      # Half-length of the first pole (m)
  @mass_pole2 0.01       # Mass of the second pole (kg)
  @length_pole2 0.05     # Half-length of the second pole (m)
  @mu_cart 0.0005        # Friction coefficient of the cart
  @mu_pole1 0.000002     # Friction coefficient of the first pole
  @mu_pole2 0.000002     # Friction coefficient of the second pole
  
  # Define the pole balancing state struct
  defstruct [
    :scape_pid,          # PID of the scape
    :x,                  # Cart position
    :x_dot,              # Cart velocity
    :theta1,             # First pole angle
    :theta1_dot,         # First pole angular velocity
    :theta2,             # Second pole angle
    :theta2_dot,         # Second pole angular velocity
    :steps,              # Number of steps elapsed
    :max_steps,          # Maximum number of steps
    :jiggle_total        # Sum of movement (used for fitness with damping)
  ]
  
  @doc """
  Initialize the private scape for DPB simulation.
  
  Parameters:
  - scape_pid: PID of the scape
  - params: Additional parameters (e.g., max_steps)
  """
  @impl PrivateScape
  def init(params) do
    # Extract parameters or use defaults
    max_steps = Map.get(params, :max_steps, @max_steps)
    
    # Initialize the simulation state
    state = %__MODULE__{
      scape_pid: nil,          # Will be set later
      x: 0.0,                  # Start cart at center
      x_dot: 0.0,              # No initial velocity
      theta1: 0.07,            # Slight angle for first pole
      theta1_dot: 0.0,         # No initial angular velocity
      theta2: 0.0,             # No angle for second pole
      theta2_dot: 0.0,         # No initial angular velocity
      steps: 0,                # No steps elapsed
      max_steps: max_steps,    # Maximum simulation steps
      jiggle_total: 0.0        # Initial movement sum
    }
    
    {:ok, state}
  end
  
  # Legacy init function for compatibility
  def init(scape_pid, params) do
    max_steps = Map.get(params, :max_steps, @max_steps)
    
    state = %__MODULE__{
      scape_pid: scape_pid,
      x: 0.0,
      x_dot: 0.0,
      theta1: 0.07,
      theta1_dot: 0.0,
      theta2: 0.0,
      theta2_dot: 0.0,
      steps: 0,
      max_steps: max_steps,
      jiggle_total: 0.0
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle an agent entering the private scape.
  
  For DPB, we just return success with the current state.
  """
  # Not part of PrivateScape behaviour, but provided for compatibility
  def enter(_agent_id, _params, state) do
    {:ok, state}
  end
  
  @doc """
  Handle an agent leaving the private scape.
  
  For DPB, we just return success with the current state.
  """
  # Not part of PrivateScape behaviour, but provided for compatibility
  def leave(_agent_id, _params, state) do
    {:ok, state}
  end
  
  @doc """
  Handle a sensor request from an agent.
  
  Returns the requested state variable (cart position, pole angles, etc.)
  """
  @impl PrivateScape
  def sense(params, state) do
    # Get the appropriate state variable based on sensor type
    sensor_type = Map.get(params, :sensor_type, :cart_position)
    
    value = case sensor_type do
      :cart_position -> state.x
      :pole1_angle -> state.theta1
      :pole2_angle -> state.theta2
      :cart_velocity -> state.x_dot
      :pole1_angular_velocity -> state.theta1_dot
      :pole2_angular_velocity -> state.theta2_dot
      _ -> 0.0
    end
    
    # Return value and unchanged state
    {value, state}
  end
  
  # Legacy sense function for compatibility
  def sense(_agent_id, params, state) do
    %{sensor_type: sensor_type} = params
    
    # Get the appropriate state variable based on sensor type
    value = case sensor_type do
      :cart_position -> state.x
      :pole1_angle -> state.theta1
      :pole2_angle -> state.theta2
      :cart_velocity -> state.x_dot
      :pole1_angular_velocity -> state.theta1_dot
      :pole2_angular_velocity -> state.theta2_dot
      _ -> 0.0
    end
    
    {:ok, value, state}
  end
  
  @doc """
  Handle an actuator request from an agent.
  
  Applies the force to the cart and simulates physics for one step.
  """
  @impl PrivateScape
  def actuate(_function, params, _agent_id, state) do
    # Get force and damping parameters
    force = Map.get(params, :force, 0.0)
    damping_type = Map.get(params, :parameters, :without_damping)
    
    # Run one step of physics simulation
    case simulate_step(state, force) do
      # Simulation failed (poles fell or cart out of bounds)
      {:failed, new_state} ->
        # Calculate fitness based on damping type
        fitness = calculate_fitness(new_state, damping_type)
        response = {{%{status: :failed, fitness: fitness}}, fitness}
        {response, new_state}
        
      # Simulation completed successfully (max steps reached)
      {:completed, new_state} ->
        fitness = calculate_fitness(new_state, damping_type)
        response = {{%{status: :completed, fitness: fitness}}, fitness}
        {response, new_state}
        
      # Simulation continues
      {:continue, new_state} ->
        response = {{%{status: :continue}}, 0.0}
        {response, new_state}
    end
  end
  
  # Legacy actuate function for compatibility
  def actuate(_agent_id, params, state) do
    %{force: force, parameters: damping_type} = params
    
    # Run one step of physics simulation
    case simulate_step(state, force) do
      # Simulation failed (poles fell or cart out of bounds)
      {:failed, new_state} ->
        # Calculate fitness based on damping type
        fitness = calculate_fitness(new_state, damping_type)
        response = %{status: :failed, fitness: fitness}
        {:ok, response, new_state}
        
      # Simulation completed successfully (max steps reached)
      {:completed, new_state} ->
        fitness = calculate_fitness(new_state, damping_type)
        response = %{status: :completed, fitness: fitness}
        {:ok, response, new_state}
        
      # Simulation continues
      {:continue, new_state} ->
        response = %{status: :continue}
        {:ok, response, new_state}
    end
  end
  
  @doc """
  Advance the simulation by one step.
  
  This is not used in DPB since the simulation advances via actuate/3,
  but we implement it for PrivateScape behaviour compliance.
  """
  # Not part of PrivateScape behaviour, but provided for compatibility
  def step(_params, state) do
    {:ok, state}
  end
  
  # Private functions
  
  # Calculate fitness based on damping type
  defp calculate_fitness(state, damping_type) do
    case damping_type do
      :with_damping ->
        # Damping fitness is a combination of steps and stability
        basic_fitness = state.steps / @max_steps
        jiggle_penalty = min(state.jiggle_total / 1000.0, 0.5)
        %{
          steps: state.steps,
          jiggle: state.jiggle_total,
          fitness: basic_fitness - jiggle_penalty
        }
        
      _ ->
        # Without damping, fitness is binary: 0 for failure, 1 for success
        if state.steps >= state.max_steps do
          1.0
        else
          # Partial credit based on how long it balanced
          state.steps / state.max_steps
        end
    end
  end
  
  # Simulate one step of the physics
  defp simulate_step(state, force) do
    # Increment step counter
    new_steps = state.steps + 1
    
    # Check if we've reached maximum steps (success)
    if new_steps >= state.max_steps do
      # Return success state
      {:completed, %{state | steps: new_steps}}
    else
      # Simulate physics for one time step
      {new_x, new_x_dot, new_theta1, new_theta1_dot, new_theta2, new_theta2_dot} =
        sm_double_pole(state.x, state.x_dot, state.theta1, state.theta1_dot, 
                       state.theta2, state.theta2_dot, force)
        
      # Calculate jiggle (stability metric)
      jiggle = abs(new_x_dot) + abs(new_theta1_dot) + abs(new_theta2_dot)
      new_jiggle_total = state.jiggle_total + jiggle
      
      # Create updated state
      new_state = %{state |
        x: new_x,
        x_dot: new_x_dot,
        theta1: new_theta1,
        theta1_dot: new_theta1_dot,
        theta2: new_theta2,
        theta2_dot: new_theta2_dot,
        steps: new_steps,
        jiggle_total: new_jiggle_total
      }
      
      # Check if simulation has failed
      if failed?(new_state) do
        {:failed, new_state}
      else
        {:continue, new_state}
      end
    end
  end
  
  # Check if the simulation has failed
  defp failed?(state) do
    # Failure conditions:
    # 1. Cart position exceeds bounds
    # 2. Pole angles exceed bounds (poles have fallen)
    abs(state.x) > @max_pos or 
    abs(state.theta1) > :math.pi() / 2 or 
    abs(state.theta2) > :math.pi() / 2
  end
  
  # Physics simulation for the double pole balancing problem
  # This is a direct port of the Erlang implementation
  defp sm_double_pole(x, x_dot, theta1, theta1_dot, theta2, theta2_dot, force) do
    # Constants based on the physical properties
    ml1 = @mass_pole1 * @length_pole1
    ml2 = @mass_pole2 * @length_pole2
    fi1 = (@mu_pole1 * theta1_dot) / ml1
    fi2 = (@mu_pole2 * theta2_dot) / ml2
    mi1 = @mass_pole1 / @mass_cart
    mi2 = @mass_pole2 / @mass_cart
    
    # Calculate the physics equations for the first pole
    s1 = :math.sin(theta1)
    c1 = :math.cos(theta1)
    _sin_c1 = s1 * c1
    sin_2_1 = s1 * s1
    num1 = (@gravity * s1) + (c1 * ((fi1 * ml1) + (force + @mu_cart * (if x_dot < 0, do: -1, else: 1)) / @mass_cart))
    den1 = @length_pole1 * (4.0/3.0 - (mi1 * c1 * c1))
    accel1 = num1 / den1
    
    # Calculate the physics equations for the second pole
    s2 = :math.sin(theta2)
    c2 = :math.cos(theta2)
    _sin_c2 = s2 * c2
    sin_2_2 = s2 * s2
    num2 = (@gravity * s2) + (c2 * ((fi2 * ml2) + (force + @mu_cart * (if x_dot < 0, do: -1, else: 1)) / @mass_cart))
    den2 = @length_pole2 * (4.0/3.0 - (mi2 * c2 * c2))
    accel2 = num2 / den2
    
    # Calculate the acceleration of the cart
    num3 = force + @mu_cart * (if x_dot < 0, do: -1, else: 1) + @mass_pole1 * @length_pole1 * sin_2_1 * theta1_dot * theta1_dot + mi1 * @length_pole1 * s1 * accel1 + @mass_pole2 * @length_pole2 * sin_2_2 * theta2_dot * theta2_dot + mi2 * @length_pole2 * s2 * accel2
    den3 = @mass_cart + @mass_pole1 * sin_2_1 + @mass_pole2 * sin_2_2
    accel3 = num3 / den3
    
    # Euler integration to update state variables
    # Clip velocities to prevent extreme values
    new_x_dot = clamp(x_dot + accel3 * @time_step, -100.0, 100.0)
    new_theta1_dot = clamp(theta1_dot + accel1 * @time_step, -100.0, 100.0)
    new_theta2_dot = clamp(theta2_dot + accel2 * @time_step, -100.0, 100.0)
    
    # Update positions
    new_x = x + new_x_dot * @time_step
    new_theta1 = theta1 + new_theta1_dot * @time_step
    new_theta2 = theta2 + new_theta2_dot * @time_step
    
    # Return updated state variables
    {new_x, new_x_dot, new_theta1, new_theta1_dot, new_theta2, new_theta2_dot}
  end
  
  # Clamp a value between min and max
  defp clamp(value, min_val, max_val) do
    min(max(value, min_val), max_val)
  end
end