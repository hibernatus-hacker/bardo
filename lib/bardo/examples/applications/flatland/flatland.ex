defmodule Bardo.Examples.Applications.Flatland.Flatland do
  @moduledoc """
  Flatland simulation environment.
  
  This module implements a 2D world where predators and prey interact.
  It behaves as a sector in the Bardo scape system.
  """
  
  alias Bardo.ScapeManager.Sector
  alias Bardo.Examples.Applications.Flatland.FlatlandUtils
  alias Bardo.Models
  
  @behaviour Sector
  
  # Define constants
  @world_width 1000
  @world_height 1000
  @plant_colour -0.5
  @prey_colour 0
  @predator_colour 0.5
  @predator_avatar_diameter 20
  @prey_avatar_diameter 15
  @plant_avatar_diameter 10
  @plant_energy 600
  @predator_hunger_degradation_rate 1
  @prey_hunger_degradation_rate 1
  @energy_degradation_rate 0.01
  @avatar_respawn_period 500
  @energy_award_per_consumption 800
  @max_energy 2000
  @max_force 90
  @max_torque 0.2
  @friction 0.06
  @weight_per_energy_unit 3
  @collision_dx 0.5
  
  # Define Flatland state struct (converted from Erlang record)
  defstruct [
    :scape_pid,
    :width,
    :height,
    :plant_quantity,
    avatars: %{},
    avatar_age: 0,
    pids: MapSet.new(),
    plant_respawn_coord_history: []
  ]
  
  # Define avatar struct (converted from Erlang record)
  defstruct [
    :id,
    :agent_id,
    :type,
    :colour,
    :x,
    :y,
    :direction,
    :energy,
    :state,
    :diameter,
    :cx,
    :cy,
    :vx,
    :vy,
    :v,
    :w,
    :fit_vec
  ]
  
  @doc """
  Initializes the Flatland sector with the given parameters.
  """
  @impl Sector
  def init(params, _state) do
    %{
      scape_pid: scape_pid,
      plant_quantity: plant_quantity
    } = params
    
    flatland_state = %__MODULE__{
      scape_pid: scape_pid,
      width: @world_width,
      height: @world_height,
      plant_quantity: plant_quantity,
      avatars: %{},
      avatar_age: 0,
      pids: MapSet.new(),
      plant_respawn_coord_history: []
    }
    
    # Create initial plants
    flatland_state = spawn_plants(flatland_state)
    
    {:ok, flatland_state}
  end
  
  @doc """
  Handles a new agent entering the Flatland environment.
  """
  @impl Sector
  def enter(agent_id, params, state) do
    type = params[:type]
    
    case type do
      :predator ->
        avatar = create_predator_avatar(state, agent_id)
        new_state = add_avatar(state, avatar)
        {:success, new_state}
        
      :prey ->
        avatar = create_prey_avatar(state, agent_id)
        new_state = add_avatar(state, avatar)
        {:success, new_state}
        
      _ ->
        {:error, state}
    end
  end
  
  @doc """
  Handles an agent leaving the Flatland environment.
  """
  @impl Sector
  def leave(agent_id, _params, state) do
    case get_avatar_by_agent_id(state, agent_id) do
      nil ->
        {:success, state}
        
      avatar ->
        new_state = remove_avatar(state, avatar.id)
        {:success, new_state}
    end
  end
  
  @doc """
  Handles the step operation for the Flatland environment.
  """
  @impl Sector
  def step(_params, state) do
    new_state = do_step(state)
    {:success, new_state}
  end
  
  @doc """
  Handles a sensor operation from an agent.
  """
  @impl Sector
  def sense(agent_id, params, state) do
    case params[:sensor_type] do
      :distance_scanner ->
        sense_distance(agent_id, params, state)
        
      :color_scanner ->
        sense_color(agent_id, params, state)
        
      _ ->
        {:error, state}
    end
  end
  
  @doc """
  Handles an actuator operation from an agent.
  """
  @impl Sector
  def actuate(agent_id, params, state) do
    case params[:actuator_type] do
      :two_wheels ->
        output_vector = params[:output_vector]
        actuate_two_wheels(agent_id, output_vector, state)
        
      _ ->
        {:error, state}
    end
  end
  
  # Private Functions
  
  # Spawn plants in the Flatland environment
  defp spawn_plants(state) do
    spawn_plants(state, state.plant_quantity)
  end
  
  defp spawn_plants(state, 0), do: state
  defp spawn_plants(state, plant_quantity) do
    avatar = create_plant_avatar(state)
    updated_state = add_avatar(state, avatar)
    spawn_plants(updated_state, plant_quantity - 1)
  end
  
  # Create a plant avatar
  defp create_plant_avatar(state) do
    avatar_id = state.avatar_age + 1
    x = :rand.uniform(state.width)
    y = :rand.uniform(state.height)
    
    %{
      id: avatar_id,
      agent_id: nil,
      type: :plant,
      colour: @plant_colour,
      x: x,
      y: y,
      direction: 0,
      energy: @plant_energy,
      state: :live,
      diameter: @plant_avatar_diameter,
      cx: x,
      cy: y,
      vx: 0,
      vy: 0,
      v: 0,
      w: 0,
      fit_vec: []
    }
  end
  
  # Create a predator avatar
  defp create_predator_avatar(state, agent_id) do
    avatar_id = state.avatar_age + 1
    x = :rand.uniform(state.width)
    y = :rand.uniform(state.height)
    
    %{
      id: avatar_id,
      agent_id: agent_id,
      type: :predator,
      colour: @predator_colour,
      x: x,
      y: y,
      direction: :rand.uniform() * 2 * :math.pi(),
      energy: @max_energy / 2,
      state: :live,
      diameter: @predator_avatar_diameter,
      cx: x,
      cy: y,
      vx: 0,
      vy: 0,
      v: 0,
      w: 0,
      fit_vec: []
    }
  end
  
  # Create a prey avatar
  defp create_prey_avatar(state, agent_id) do
    avatar_id = state.avatar_age + 1
    x = :rand.uniform(state.width)
    y = :rand.uniform(state.height)
    
    %{
      id: avatar_id,
      agent_id: agent_id,
      type: :prey,
      colour: @prey_colour,
      x: x,
      y: y,
      direction: :rand.uniform() * 2 * :math.pi(),
      energy: @max_energy / 2,
      state: :live,
      diameter: @prey_avatar_diameter,
      cx: x,
      cy: y,
      vx: 0,
      vy: 0,
      v: 0,
      w: 0,
      fit_vec: []
    }
  end
  
  # Add an avatar to the state
  defp add_avatar(state, avatar) do
    updated_avatars = Map.put(state.avatars, avatar.id, avatar)
    
    updated_pids = case avatar.agent_id do
      nil -> state.pids
      agent_id -> MapSet.put(state.pids, agent_id)
    end
    
    %{state | 
      avatars: updated_avatars, 
      avatar_age: state.avatar_age + 1,
      pids: updated_pids
    }
  end
  
  # Remove an avatar from the state
  defp remove_avatar(state, avatar_id) do
    # Get the avatar to check for agent_id
    avatar = Map.get(state.avatars, avatar_id)
    
    # Remove from avatars map
    updated_avatars = Map.delete(state.avatars, avatar_id)
    
    # Remove from pids set if it has an agent_id
    updated_pids = case avatar do
      nil -> state.pids
      %{agent_id: nil} -> state.pids
      %{agent_id: agent_id} -> MapSet.delete(state.pids, agent_id)
    end
    
    # Update the state
    %{state | avatars: updated_avatars, pids: updated_pids}
  end
  
  # Get avatar by agent_id
  defp get_avatar_by_agent_id(state, agent_id) do
    Enum.find_value(state.avatars, fn {_id, avatar} -> 
      if avatar.agent_id == agent_id, do: avatar, else: nil
    end)
  end
  
  # Main step function for updating the environment
  defp do_step(state) do
    # Apply motion to all avatars
    updated_avatars = Enum.reduce(state.avatars, %{}, fn {id, avatar}, acc ->
      case avatar.type do
        :plant -> 
          Map.put(acc, id, avatar)
          
        _ -> 
          updated_avatar = apply_motion(avatar, state.width, state.height)
          Map.put(acc, id, updated_avatar)
      end
    end)
    
    state = %{state | avatars: updated_avatars}
    
    # Handle collisions and interactions
    state = handle_interactions(state)
    
    # Respawn plants if needed
    state = respawn_plants(state)
    
    state
  end
  
  # Apply motion physics to an avatar
  defp apply_motion(avatar, world_width, world_height) do
    # Apply friction
    vx = avatar.vx * (1 - @friction)
    vy = avatar.vy * (1 - @friction)
    
    # Update position with velocity
    x = avatar.x + vx
    y = avatar.y + vy
    
    # Handle world boundaries (wrap around)
    {x, y} = wrap_position(x, y, world_width, world_height)
    
    # Update energy based on movement
    v = :math.sqrt(vx * vx + vy * vy)
    energy_cost = v * @energy_degradation_rate
    
    # Update hunger based on type
    hunger_cost = case avatar.type do
      :predator -> @predator_hunger_degradation_rate
      :prey -> @prey_hunger_degradation_rate
      _ -> 0
    end
    
    # Total energy loss
    total_energy_loss = energy_cost + hunger_cost
    new_energy = max(0, avatar.energy - total_energy_loss)
    
    # Update state if energy depleted
    state = if new_energy <= 0, do: :dead, else: avatar.state
    
    # Update avatar with new values
    %{avatar |
      x: x,
      y: y,
      cx: x,
      cy: y,
      vx: vx,
      vy: vy,
      v: v,
      energy: new_energy,
      state: state
    }
  end
  
  # Wrap position around world boundaries
  defp wrap_position(x, y, width, height) do
    x = cond do
      x < 0 -> width + x
      x > width -> x - width
      true -> x
    end
    
    y = cond do
      y < 0 -> height + y
      y > height -> y - height
      true -> y
    end
    
    {x, y}
  end
  
  # Handle collisions and interactions between avatars
  defp handle_interactions(state) do
    avatar_list = Map.values(state.avatars)
    
    # Check each avatar against all others
    Enum.reduce(avatar_list, state, fn avatar, acc_state ->
      if avatar.state == :dead do
        acc_state
      else
        # Filter out self and dead avatars
        other_avatars = Enum.filter(avatar_list, fn other ->
          other.id != avatar.id && other.state != :dead
        end)
        
        # Handle interactions with each other avatar
        Enum.reduce(other_avatars, acc_state, fn other, inner_acc_state ->
          handle_avatar_interaction(inner_acc_state, avatar, other)
        end)
      end
    end)
  end
  
  # Handle interaction between two avatars
  defp handle_avatar_interaction(state, avatar1, avatar2) do
    # Calculate distance between avatars
    distance = calculate_distance(avatar1, avatar2)
    min_distance = (avatar1.diameter + avatar2.diameter) / 2
    
    if distance < min_distance do
      case {avatar1.type, avatar2.type} do
        # Predator eats prey
        {:predator, :prey} ->
          consume(state, avatar1, avatar2)
          
        # Prey eats plant
        {:prey, :plant} ->
          consume(state, avatar1, avatar2)
          
        # Handle other collisions (push)
        _ ->
          handle_collision(state, avatar1, avatar2, distance, min_distance)
      end
    else
      state
    end
  end
  
  # Calculate Euclidean distance between two avatars
  defp calculate_distance(avatar1, avatar2) do
    dx = avatar1.x - avatar2.x
    dy = avatar1.y - avatar2.y
    :math.sqrt(dx * dx + dy * dy)
  end
  
  # Handle avatar consuming another (predator eats prey, prey eats plant)
  defp consume(state, consumer, consumed) do
    # Award energy to consumer
    updated_consumer = award_energy(consumer)
    
    # Update fitness vector for predator
    updated_consumer = if consumer.type == :predator do
      fit_vec = [consumed.agent_id | consumer.fit_vec]
      %{updated_consumer | fit_vec: fit_vec}
    else
      updated_consumer
    end
    
    # Update the state with modified consumer
    state = update_avatar(state, updated_consumer)
    
    # Handle consumed avatar (plants respawn, prey dies)
    case consumed.type do
      :plant ->
        # Remove the plant and add to respawn history
        state = remove_avatar(state, consumed.id)
        %{state | 
          plant_respawn_coord_history: [{consumed.x, consumed.y} | state.plant_respawn_coord_history]
        }
        
      _ ->
        # Mark prey as dead but keep it in the environment
        updated_consumed = %{consumed | state: :dead, energy: 0}
        update_avatar(state, updated_consumed)
    end
  end
  
  # Award energy to an avatar (when consuming another)
  defp award_energy(avatar) do
    new_energy = min(avatar.energy + @energy_award_per_consumption, @max_energy)
    %{avatar | energy: new_energy}
  end
  
  # Handle collision between avatars (pushing)
  defp handle_collision(state, avatar1, avatar2, distance, min_distance) do
    # Calculate collision vector
    dx = avatar2.x - avatar1.x
    dy = avatar2.y - avatar1.y
    
    # Normalize
    norm = :math.sqrt(dx * dx + dy * dy)
    udx = dx / norm
    udy = dy / norm
    
    # Calculate overlap
    overlap = min_distance - distance
    
    # Calculate mass based on energy
    mass1 = avatar1.energy * @weight_per_energy_unit
    mass2 = avatar2.energy * @weight_per_energy_unit
    
    # Calculate the pushing force
    push1 = @collision_dx * overlap * mass2 / (mass1 + mass2)
    push2 = @collision_dx * overlap * mass1 / (mass1 + mass2)
    
    # Update positions
    updated_avatar1 = %{avatar1 |
      x: avatar1.x - push1 * udx,
      y: avatar1.y - push1 * udy
    }
    
    updated_avatar2 = %{avatar2 |
      x: avatar2.x + push2 * udx,
      y: avatar2.y + push2 * udy
    }
    
    # Update the state with both modified avatars
    state
    |> update_avatar(updated_avatar1)
    |> update_avatar(updated_avatar2)
  end
  
  # Update an avatar in the state
  defp update_avatar(state, avatar) do
    updated_avatars = Map.put(state.avatars, avatar.id, avatar)
    %{state | avatars: updated_avatars}
  end
  
  # Respawn plants if needed
  defp respawn_plants(state) do
    current_plant_count = Enum.count(state.avatars, fn {_id, avatar} -> 
      avatar.type == :plant && avatar.state == :live
    end)
    
    plants_to_spawn = state.plant_quantity - current_plant_count
    
    if plants_to_spawn > 0 do
      spawn_plants_with_history(state, plants_to_spawn)
    else
      state
    end
  end
  
  # Spawn plants using respawn history if available
  defp spawn_plants_with_history(state, plants_to_spawn) do
    {respawn_coords, remaining_history} = Enum.split(state.plant_respawn_coord_history, plants_to_spawn)
    
    # Create new state with updated history
    state = %{state | plant_respawn_coord_history: remaining_history}
    
    # Spawn plants at historical coordinates if available, otherwise random
    Enum.reduce(1..plants_to_spawn, state, fn i, acc_state ->
      coord = Enum.at(respawn_coords, i - 1)
      
      avatar = if coord do
        {x, y} = coord
        create_plant_avatar_at(acc_state, x, y)
      else
        create_plant_avatar(acc_state)
      end
      
      add_avatar(acc_state, avatar)
    end)
  end
  
  # Create a plant avatar at specific coordinates
  defp create_plant_avatar_at(state, x, y) do
    avatar_id = state.avatar_age + 1
    
    %{
      id: avatar_id,
      agent_id: nil,
      type: :plant,
      colour: @plant_colour,
      x: x,
      y: y,
      direction: 0,
      energy: @plant_energy,
      state: :live,
      diameter: @plant_avatar_diameter,
      cx: x,
      cy: y,
      vx: 0,
      vy: 0,
      v: 0,
      w: 0,
      fit_vec: []
    }
  end
  
  # Sense distance implementation
  defp sense_distance(agent_id, params, state) do
    angles = params[:angles]
    avatar = get_avatar_by_agent_id(state, agent_id)
    
    if avatar do
      # Process each angle and find distances to other avatars
      distances = Enum.map(angles, fn angle ->
        absolute_angle = angle + avatar.direction
        
        # Find the closest intersection for this angle
        closest_distance = find_closest_intersection(state, avatar, absolute_angle)
        closest_distance
      end)
      
      {:success, distances, state}
    else
      {:error, state}
    end
  end
  
  # Find the closest intersection for a ray from an avatar at a specific angle
  defp find_closest_intersection(state, avatar, angle) do
    # Normalize angle to [0, 2π)
    angle = :math.fmod(angle, 2 * :math.pi())
    angle = if angle < 0, do: angle + 2 * :math.pi(), else: angle
    
    # Calculate ray direction
    dx = :math.cos(angle)
    dy = :math.sin(angle)
    
    # Find intersections with all other avatars
    other_avatars = Enum.filter(Map.values(state.avatars), fn other ->
      other.id != avatar.id && other.state != :dead
    end)
    
    # Find the closest intersection
    Enum.reduce(other_avatars, 1.0, fn other, closest ->
      # Calculate intersection distance
      intersection = FlatlandUtils.shortest_intr_line(
        {avatar.x, avatar.y}, 
        {dx, dy}, 
        {other.x, other.y, other.diameter / 2}
      )
      
      case intersection do
        :no_intersection -> closest
        dist when dist < closest -> dist
        _ -> closest
      end
    end)
  end
  
  # Sense color implementation
  defp sense_color(agent_id, params, state) do
    angles = params[:angles]
    avatar = get_avatar_by_agent_id(state, agent_id)
    
    if avatar do
      # Process each angle and find colors of objects
      colors = Enum.map(angles, fn angle ->
        absolute_angle = angle + avatar.direction
        
        # Find the color of the closest object for this angle
        closest_color = find_closest_object_color(state, avatar, absolute_angle)
        closest_color
      end)
      
      {:success, colors, state}
    else
      {:error, state}
    end
  end
  
  # Find the color of the closest object for a ray from an avatar
  defp find_closest_object_color(state, avatar, angle) do
    # Normalize angle to [0, 2π)
    angle = :math.fmod(angle, 2 * :math.pi())
    angle = if angle < 0, do: angle + 2 * :math.pi(), else: angle
    
    # Calculate ray direction
    dx = :math.cos(angle)
    dy = :math.sin(angle)
    
    # Find intersections with all other avatars
    other_avatars = Enum.filter(Map.values(state.avatars), fn other ->
      other.id != avatar.id && other.state != :dead
    end)
    
    # Find the closest intersection and its color
    {closest_dist, closest_color} = Enum.reduce(
      other_avatars, 
      {1.0, 1.0},
      fn other, {closest, color} ->
        # Calculate intersection distance
        intersection = FlatlandUtils.shortest_intr_line(
          {avatar.x, avatar.y}, 
          {dx, dy}, 
          {other.x, other.y, other.diameter / 2}
        )
        
        case intersection do
          :no_intersection -> {closest, color}
          dist when dist < closest -> {dist, other.colour}
          _ -> {closest, color}
        end
      end
    )
    
    closest_color
  end
  
  # Actuate two wheels implementation
  defp actuate_two_wheels(agent_id, output_vector, state) do
    avatar = get_avatar_by_agent_id(state, agent_id)
    
    if avatar && length(output_vector) >= 2 do
      [left_wheel, right_wheel] = Enum.take(output_vector, 2)
      
      # Calculate force and torque from wheel values
      force = (left_wheel + right_wheel) * @max_force
      torque = (right_wheel - left_wheel) * @max_torque
      
      # Apply force and torque to avatar
      direction = avatar.direction + torque
      
      # Compute new velocity components
      fx = force * :math.cos(direction)
      fy = force * :math.sin(direction)
      
      # Update avatar's velocity and direction
      updated_avatar = %{avatar |
        vx: avatar.vx + fx,
        vy: avatar.vy + fy,
        direction: direction,
        w: torque
      }
      
      # Update the state with the modified avatar
      updated_state = update_avatar(state, updated_avatar)
      
      response = %{
        fitness: [avatar.energy] ++ avatar.fit_vec,
        misc: %{
          energy: avatar.energy,
          state: avatar.state
        }
      }
      
      {:success, response, updated_state}
    else
      {:error, state}
    end
  end
end