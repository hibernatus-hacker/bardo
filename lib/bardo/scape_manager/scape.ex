defmodule Bardo.ScapeManager.Scape do
  @moduledoc """
  Scapes are self-contained simulated worlds or virtual environments.
  
  They can be thought of as a way of interfacing with the problem in question. Scapes are composed
  of two parts: a simulation of an environment or a problem we are applying the neural network to,
  and a function that can keep track of the neural network's performance.
  
  Scapes run outside the neural network systems, as independent processes with which the neural networks
  interact using their sensors and actuators. There are two types of scapes:
  
  1. Private scapes are spawned for each neural network during creation, and destroyed when
     that neural network is taken offline.
  2. Public scapes are persistent - they exist regardless of the neural networks, and allow 
     multiple neural networks to interact with them at the same time, enabling those networks
     to interact with each other.
     
  This module defines the public scape.
  """
  
  use GenServer
  
  alias Bardo.{Utils, LogR}
  alias Bardo.ScapeManager.{Sector, SectorSupervisor}
  alias Bardo.Models

  # Define the records as structs
  defmodule State do
    @moduledoc false
    defstruct mod_name: nil
  end
  
  defmodule XYPoint do
    @moduledoc false
    defstruct x: nil, y: nil, point: nil, agent_id: nil
  end
  
  defmodule BoundingBox do
    @moduledoc false
    defstruct x: nil, y: nil, width: nil, height: nil, min_x: nil, min_y: nil, max_x: nil, max_y: nil
  end
  
  defmodule QuadNode do
    @moduledoc false
    defstruct uid: nil, bb: nil, points: [], height: nil, 
              north_west: nil, north_east: nil, south_west: nil, south_east: nil, 
              mod_name: nil
  end

  # QT Configuration
  @max_capacity 50 # Max number of children before sub-dividing

  @doc """
  Starts the Scape process.
  """
  @spec start_link(float(), float(), float(), float(), atom()) :: {:ok, pid()}
  def start_link(x, y, width, height, mod_name) do
    GenServer.start_link(__MODULE__, {x, y, width, height, mod_name}, name: __MODULE__)
  end

  @doc """
  Enter public scape.
  """
  @spec enter(Models.agent_id(), any()) :: :ok
  def enter(agent_id, params) do
    GenServer.cast(__MODULE__, {:enter, agent_id, params})
  end

  @doc """
  Gather sensory inputs from the environment (Public Scape).
  """
  @spec sense(Models.agent_id(), pid(), any()) :: :ok
  def sense(agent_id, sensor_pid, params) do
    GenServer.cast(__MODULE__, {:sense, agent_id, sensor_pid, params})
  end

  @doc """
  Perform various scape functions e.g. move, push, etc. The scape
  API is problem dependent. This function provides an interface
  to call various functions defined by the scape in question.
  """
  @spec actuate(Models.agent_id(), pid(), atom(), any()) :: :ok
  def actuate(agent_id, actuator_pid, function, params) do
    GenServer.cast(__MODULE__, {:actuate, agent_id, actuator_pid, function, params})
  end

  @doc """
  Leave public scape.
  """
  @spec leave(Models.agent_id(), any()) :: :ok
  def leave(agent_id, params) do
    GenServer.cast(__MODULE__, {:leave, agent_id, params})
  end

  @doc """
  Query a specific area within the scape.
  """
  @spec query_area(float(), float(), float(), float()) :: list()
  def query_area(x, y, w, h) do
    GenServer.call(__MODULE__, {:query_area, x, y, w, h})
  end

  @doc """
  Insert point at X,Y into tree.
  """
  @spec insert(float(), float(), Models.agent_id()) :: boolean()
  def insert(x, y, agent_id) do
    GenServer.call(__MODULE__, {:insert, x, y, agent_id})
  end

  @doc """
  Move the agent to a different point in the tree.
  """
  @spec move(float(), float(), Models.agent_id()) :: boolean()
  def move(x, y, agent_id) do
    GenServer.call(__MODULE__, {:move, x, y, agent_id})
  end

  @doc """
  Lookup agent in tree.
  """
  @spec whereis(Models.agent_id()) :: {float(), float()} | :not_found
  def whereis(agent_id) do
    GenServer.call(__MODULE__, {:whereis, agent_id})
  end

  @impl GenServer
  def init({x, y, width, height, mod_name}) do
    Process.flag(:trap_exit, true)
    Utils.random_seed()
    
    new(x, y, width, height, mod_name)
    LogR.debug({:scape, :init, :ok, nil, [mod_name]})
    
    {:ok, %State{mod_name: mod_name}}
  end

  @impl GenServer
  def handle_call({:query_area, x, y, w, h}, _from, state) do
    results = query_range(x, y, w, h)
    {:reply, results, state}
  end

  @impl GenServer
  def handle_call({:insert, x, y, agent_id}, _from, state) do
    xy_p = build_xy_point(x, y, agent_id)
    root_node = get_root()
    result = do_insert(xy_p, root_node)
    
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:move, x, y, agent_id}, _from, state) do
    result = do_move(x, y, agent_id)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:whereis, agent_id}, _from, state) do
    result = do_whereis(agent_id)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(request, from, state) do
    LogR.warning({:scape, :msg, :error, "unexpected handle_call", [request, from]})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:enter, agent_id, params}, state) do
    do_enter(agent_id, params, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:sense, agent_id, sensor_pid, params}, state) do
    do_sense(agent_id, params, sensor_pid, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:actuate, agent_id, actuator_pid, function, params}, state) do
    do_actuate(agent_id, function, actuator_pid, params, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:leave, agent_id, params}, state) do
    do_leave(agent_id, params, state)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    LogR.debug({:scape, :terminate, :ok, nil, [reason]})
    
    case reason do
      :shutdown ->
        stop_sectors()
        try do
          :ets.delete_all_objects(:ids_sids_loc)
          :ets.delete_all_objects(:xy_pts)
          :ets.delete_all_objects(:qt)
        catch
          :error, :badarg -> :ok
        end
      _ -> :ok
    end
  end

  # Internal functions
  
  defp do_enter(agent_id, params, _state) do
    true = join(agent_id)
    sector_uid = fetch_sector(agent_id)
    Sector.enter(sector_uid, agent_id, params)
  end

  defp do_sense(agent_id, params, sensor_pid, _state) do
    sector_uid = fetch_sector(agent_id)
    Sector.sense(sector_uid, agent_id, sensor_pid, params)
  end

  defp do_actuate(agent_id, function, actuator_pid, params, _state) do
    sector_uid = fetch_sector(agent_id)
    Sector.actuate(sector_uid, agent_id, function, actuator_pid, params)
  end

  defp do_leave(agent_id, params, _state) do
    sector_uid = fetch_sector(agent_id)
    true = remove(agent_id)
    Sector.leave(sector_uid, agent_id, params)
  end

  # QuadTree implementation
  
  defp new(x, y, width, height, mod_name) do
    xy_p = build_xy_point(x, y)
    bb = build_bounding_box(xy_p, width, height)
    root_node = build_root_quad_node(bb, mod_name)
    :ets.insert(:qt, {root_node.uid, root_node})
  end

  defp get_root do
    [{:root, root_node}] = :ets.lookup(:qt, :root)
    root_node
  end

  defp join(agent_id) do
    root_node = get_root()
    bb = root_node.bb
    {x, y} = generate_xy(bb.width, bb.height)
    xy_p = build_xy_point(x, y, agent_id)
    do_insert(xy_p, root_node)
  end

  defp remove(agent_id) do
    [{agent_id, {_pid, {x, y}}}] = :ets.lookup(:ids_sids_loc, agent_id)
    remove(x, y, agent_id)
  end

  defp remove(x, y, agent_id) do
    xy_p = build_xy_point(x, y, agent_id)
    root_node = get_root()
    do_remove(xy_p, root_node)
  end

  defp query_range(x, y, width, height) do
    xy_p = build_xy_point(x, y)
    root_node = get_root()
    range = build_bounding_box(xy_p, width, height)
    do_query_range(range, root_node)
  end

  defp fetch_sector(agent_id) do
    [{agent_id, {sector_uid, _loc}}] = :ets.lookup(:ids_sids_loc, agent_id)
    sector_uid
  end

  defp stop_sectors do
    :ets.foldl(fn {_id, {uid, _loc}}, :ok -> 
      Process.exit(uid, :terminate)
      :ok
    end, :ok, :ids_sids_loc)
  end

  # QuadTree internal functions
  
  defp do_insert(xy_p, qn) do
    # Ignore objects which do not belong in this quad node
    if bounding_box_contains_point(xy_p, qn.bb) do
      cond do
        is_leaf(qn) and Enum.member?(qn.points, xy_p) ->
          false
          
        is_leaf(qn) and length(qn.points) < @max_capacity ->
          # If there is space in this quad node, add the object here
          u_qn = %{qn | points: [xy_p | qn.points]}
          true = :ets.insert(:ids_sids_loc, {xy_p.agent_id, {u_qn.uid, xy_p.point}})
          true = :ets.insert(:xy_pts, {xy_p.point, xy_p})
          true = :ets.insert(:qt, {u_qn.uid, u_qn})
          true
          
        is_leaf(qn) and length(qn.points) >= @max_capacity ->
          # We need to subdivide then add the point to whichever node will accept it
          u_qn = subdivide(qn)
          insert_into_children([xy_p], u_qn)
          
        true ->
          # Not a leaf, insert into children
          insert_into_children([xy_p], qn)
      end
    else
      false
    end
  end

  defp do_remove(xy_p, qn) do
    if bounding_box_contains_point(xy_p, qn.bb) do
      # If in this BB and in this node
      if Enum.member?(qn.points, xy_p) do
        u_qn = %{qn | points: List.delete(qn.points, xy_p)}
        true = :ets.delete(:ids_sids_loc, xy_p.agent_id)
        true = :ets.delete(:xy_pts, xy_p.point)
        true = :ets.insert(:qt, {u_qn.uid, u_qn})
        true
      else
        # If this node has children
        if is_leaf(qn) do
          false
        else
          # If in this BB but in a child branch
          if remove_from_children(xy_p, qn) do
            merge(qn)
            true
          else
            false
          end
        end
      end
    else
      # If not in this BB, don't do anything
      false
    end
  end

  defp do_query_range(range, qn) do
    # Automatically abort if the range does not collide with this quad
    if intersects_box(qn.bb, range) do
      # If leaf, check objects at this level
      if is_leaf(qn) do
        Enum.filter(qn.points, fn p -> bounding_box_contains_point(p, range) end)
      else
        # Otherwise, add the points from the children
        [{_nw_uid, nw}] = :ets.lookup(:qt, qn.north_west)
        [{_ne_uid, ne}] = :ets.lookup(:qt, qn.north_east)
        [{_sw_uid, sw}] = :ets.lookup(:qt, qn.south_west)
        [{_se_uid, se}] = :ets.lookup(:qt, qn.south_east)
        
        Enum.map([nw, ne, sw, se], fn child -> do_query_range(range, child) end)
      end
    else
      nil
    end
  end

  defp do_move(x, y, agent_id) do
    xy_p = build_xy_point(x, y, agent_id)
    root_node = get_root()
    do_remove(xy_p, root_node)
    do_insert(xy_p, root_node)
  end

  defp do_whereis(agent_id) do
    case :ets.lookup(:ids_sids_loc, agent_id) do
      [] ->
        :not_found
      [{^agent_id, {_pid, {x, y}}}] ->
        {x, y}
    end
  end

  defp subdivide(qn) do
    bb = qn.bb
    mod_name = qn.mod_name
    xy_points = qn.points
    h = qn.bb.height / 2
    w = qn.bb.width / 2
    
    # NW
    xy_nw = build_xy_point(bb.x, bb.y)
    bb_nw = build_bounding_box(xy_nw, w, h)
    nw = build_quad_node(bb_nw, mod_name)
    
    # NE
    xy_ne = build_xy_point(bb.x + w, bb.y)
    bb_ne = build_bounding_box(xy_ne, w, h)
    ne = build_quad_node(bb_ne, mod_name)
    
    # SW
    xy_sw = build_xy_point(bb.x, bb.y + h)
    bb_sw = build_bounding_box(xy_sw, w, h)
    sw = build_quad_node(bb_sw, mod_name)
    
    # SE
    xy_se = build_xy_point(bb.x + w, bb.y + h)
    bb_se = build_bounding_box(xy_se, w, h)
    se = build_quad_node(bb_se, mod_name)
    
    # Points live in leaf nodes, so distribute
    u_qn = %{qn | 
      north_west: nw.uid,
      north_east: ne.uid,
      south_west: sw.uid,
      south_east: se.uid,
      height: qn.height + 4,
      points: []
    }
    
    true = :ets.insert(:qt, [
      {nw.uid, nw},
      {ne.uid, ne},
      {sw.uid, sw},
      {se.uid, se},
      {u_qn.uid, u_qn}
    ])
    
    insert_into_children(xy_points, u_qn)
    u_qn
  end

  defp insert_into_children([], _qn), do: true
  
  defp insert_into_children([xy_p | xy_points], qn) do
    [{_nw_uid, nw}] = :ets.lookup(:qt, qn.north_west)
    [{_ne_uid, ne}] = :ets.lookup(:qt, qn.north_east)
    [{_sw_uid, sw}] = :ets.lookup(:qt, qn.south_west)
    [{_se_uid, se}] = :ets.lookup(:qt, qn.south_east)
    
    # A point can only live in one child
    cond do
      do_insert(xy_p, nw) ->
        redistribute([xy_p], qn.uid, nw.uid)
        insert_into_children(xy_points, qn)
        
      do_insert(xy_p, ne) ->
        redistribute([xy_p], qn.uid, ne.uid)
        insert_into_children(xy_points, qn)
        
      do_insert(xy_p, sw) ->
        redistribute([xy_p], qn.uid, sw.uid)
        insert_into_children(xy_points, qn)
        
      do_insert(xy_p, se) ->
        redistribute([xy_p], qn.uid, se.uid)
        insert_into_children(xy_points, qn)
        
      true ->
        false
    end
  end

  defp redistribute([], _old_uid, _new_uid), do: true
  
  defp redistribute([xy_p | xy_points], old_uid, new_uid) do
    agent = Sector.remove(old_uid, xy_p.agent_id)
    Sector.insert(new_uid, xy_p.agent_id, agent)
    redistribute(xy_points, old_uid, new_uid)
  end

  defp remove_from_children(xy_p, qn) do
    [{_nw_uid, nw}] = :ets.lookup(:qt, qn.north_west)
    [{_ne_uid, ne}] = :ets.lookup(:qt, qn.north_east)
    [{_sw_uid, sw}] = :ets.lookup(:qt, qn.south_west)
    [{_se_uid, se}] = :ets.lookup(:qt, qn.south_east)
    
    # A point can only live in one child
    cond do
      do_remove(xy_p, nw) -> true
      do_remove(xy_p, ne) -> true
      do_remove(xy_p, sw) -> true
      do_remove(xy_p, se) -> true
      true -> false
    end
  end

  defp merge(qn) do
    [{_nw_uid, nw}] = :ets.lookup(:qt, qn.north_west)
    [{_ne_uid, ne}] = :ets.lookup(:qt, qn.north_east)
    [{_sw_uid, sw}] = :ets.lookup(:qt, qn.south_west)
    [{_se_uid, se}] = :ets.lookup(:qt, qn.south_east)
    
    # If the children aren't leafs, you cannot merge
    if is_leaf(nw) and is_leaf(ne) and is_leaf(sw) and is_leaf(se) do
      # Children are leafs, see if you can remove point and merge into this node
      total_size_children = length(nw.points) + length(ne.points) + length(sw.points) + length(se.points)
      total_size_parent = length(qn.points)
      
      # If all the children's points can be merged into this node
      if (total_size_parent + total_size_children) < @max_capacity do
        list_of_lists = [
          Enum.sort(qn.points),
          Enum.sort(nw.points),
          Enum.sort(ne.points),
          Enum.sort(sw.points),
          Enum.sort(se.points)
        ]
        
        u_qn = %{qn |
          north_west: nil,
          north_east: nil,
          south_west: nil,
          south_east: nil,
          points: Enum.sort(list_of_lists) |> Enum.concat()
        }
        
        true = :ets.insert(:qt, {u_qn.uid, u_qn})
        
        true = :ets.delete(:qt, {nw.uid, nw})
        redistribute(nw.points, qn.uid, nw.uid)
        true = :ets.delete(:qt, {ne.uid, ne})
        redistribute(ne.points, qn.uid, ne.uid)
        true = :ets.delete(:qt, {sw.uid, sw})
        redistribute(sw.points, qn.uid, sw.uid)
        true = :ets.delete(:qt, {se.uid, se})
        redistribute(se.points, qn.uid, se.uid)
        true
      else
        false
      end
    else
      false
    end
  end

  # Helper functions
  
  defp build_xy_point(x, y) do
    %XYPoint{
      x: x,
      y: y,
      point: {x, y}
    }
  end

  defp build_xy_point(x, y, agent_id) do
    %XYPoint{
      x: x,
      y: y,
      point: {x, y},
      agent_id: agent_id
    }
  end

  defp build_bounding_box(upper_left, width, height) do
    %BoundingBox{
      x: upper_left.x,
      y: upper_left.y,
      width: width,
      height: height,
      min_x: upper_left.x,
      min_y: upper_left.y,
      max_x: upper_left.x + width,
      max_y: upper_left.y + height
    }
  end

  defp build_quad_node(bb, mod_name) do
    uid = System.unique_integer([:positive, :monotonic])
    {:ok, _pid} = SectorSupervisor.start_sector(mod_name, uid)
    
    %QuadNode{
      uid: uid,
      bb: bb,
      height: 1,
      mod_name: mod_name
    }
  end

  defp build_root_quad_node(bb, mod_name) do
    uid = :root
    {:ok, _pid} = SectorSupervisor.start_sector(mod_name, uid)
    
    %QuadNode{
      uid: uid,
      bb: bb,
      height: 1,
      mod_name: mod_name
    }
  end

  defp is_leaf(qn) do
    qn.north_west == nil and
    qn.north_east == nil and
    qn.south_west == nil and
    qn.south_east == nil
  end

  defp bounding_box_contains_point(p, b) do
    cond do
      p.x >= b.max_x -> false
      p.x < b.min_x -> false
      p.y >= b.max_y -> false
      p.y < b.min_y -> false
      true -> true
    end
  end

  defp inside_this_box(box, other_box) do
    other_box.min_x >= box.min_x and
    other_box.max_x <= box.max_x and
    other_box.min_y >= box.min_y and
    other_box.max_y <= box.max_y
  end

  defp intersects_box(box, other_box) do
    cond do
      inside_this_box(box, other_box) or inside_this_box(other_box, box) ->
        true
        
      box.max_x < other_box.min_x or box.min_x > other_box.max_x ->
        false
        
      box.max_y < other_box.min_y or box.min_y > other_box.max_y ->
        false
        
      true ->
        true
    end
  end

  defp generate_xy(x, y) do
    {xx, yy} = {:rand.uniform(round(x)) / 1, :rand.uniform(round(y)) / 1}
    
    if :ets.member(:xy_pts, {xx, yy}) do
      generate_xy(x, y)
    else
      {xx, yy}
    end
  end
end