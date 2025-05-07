defmodule Bardo.Examples.Applications.Flatland.FlatlandUtils do
  @moduledoc """
  Utility functions for the Flatland simulation.
  
  This module provides utility functions for calculating intersections
  between rays and objects in the Flatland environment.
  """
  
  @doc """
  Calculates the shortest intersection line between a ray and a circular object.
  
  Parameters:
  - ray_origin: {x, y} coordinates of ray origin
  - ray_dir: {dx, dy} ray direction vector
  - object: {x, y, r} object position and radius
  
  Returns:
  - :no_intersection if there is no intersection
  - distance to the intersection point
  
  This function is a direct port of the Erlang implementation, which uses
  vector math to calculate ray-circle intersections.
  """
  @spec shortest_intr_line({float(), float()}, {float(), float()}, {float(), float(), float()}) ::
    float() | :no_intersection
  def shortest_intr_line(ray_origin, ray_dir, object) do
    {x1, y1} = ray_origin
    {dx, dy} = normalize_vector(ray_dir)
    {x2, y2, r} = object
    
    # Vector from ray origin to object center
    v = {x2 - x1, y2 - y1}
    
    # Project v onto the ray direction
    {vx, vy} = v
    dot_product = vx * dx + vy * dy
    
    # Closest point on the ray to the object center
    closest_point = {x1 + dot_product * dx, y1 + dot_product * dy}
    
    # Distance from closest point to object center
    {cx, cy} = closest_point
    dist_squared = (cx - x2) * (cx - x2) + (cy - y2) * (cy - y2)
    
    # Check if the ray intersects with the object
    if dist_squared > r * r do
      # No intersection
      :no_intersection
    else
      # Intersection exists
      # Calculate the distance from ray origin to intersection point
      back_dist = :math.sqrt(r * r - dist_squared)
      dist_to_closest = :math.sqrt((cx - x1) * (cx - x1) + (cy - y1) * (cy - y1))
      
      intr_dist = dist_to_closest - back_dist
      
      # If intersection is behind the ray origin, return no intersection
      if intr_dist < 0 or dot_product < 0 do
        :no_intersection
      else
        # Return the normalized intersection distance (0 to 1)
        intr_dist
      end
    end
  end
  
  @doc """
  Normalizes a vector to a unit vector.
  """
  @spec normalize_vector({float(), float()}) :: {float(), float()}
  def normalize_vector({dx, dy}) do
    len = :math.sqrt(dx * dx + dy * dy)
    if len > 0 do
      {dx / len, dy / len}
    else
      {0.0, 0.0}
    end
  end
  
  @doc """
  Maps object type to color value.
  
  Returns:
  - -0.5 for plants (green)
  - 0.0 for prey (blue)
  - 0.5 for predators (red)
  """
  @spec object_color_value(atom()) :: float()
  def object_color_value(type) do
    case type do
      :plant -> -0.5    # Green
      :prey -> 0.0      # Blue
      :predator -> 0.5  # Red
      _ -> 1.0          # White (nothing)
    end
  end
  
  @doc """
  Calculates the intersection of a ray with the boundary of a rectangular world.
  
  This is useful for determining how far a ray can travel before hitting a wall,
  which is important for sensors that need to detect world boundaries.
  """
  @spec world_boundary_intersection({float(), float()}, {float(), float()}, float(), float()) ::
    {float(), float(), float()} | :no_intersection
  def world_boundary_intersection(ray_origin, ray_dir, width, height) do
    {x, y} = ray_origin
    {dx, dy} = normalize_vector(ray_dir)
    
    # Calculate intersection distances with the four boundaries
    t_left = if dx != 0, do: (0 - x) / dx, else: :infinity
    t_right = if dx != 0, do: (width - x) / dx, else: :infinity
    t_top = if dy != 0, do: (0 - y) / dy, else: :infinity
    t_bottom = if dy != 0, do: (height - y) / dy, else: :infinity
    
    # Find the smallest positive distance (first intersection)
    t = Enum.min_by([t_left, t_right, t_top, t_bottom], fn t ->
      if is_number(t) and t >= 0, do: t, else: :infinity
    end, fn -> :infinity end)
    
    if t == :infinity do
      :no_intersection
    else
      # Calculate intersection point
      ix = x + t * dx
      iy = y + t * dy
      {ix, iy, t}
    end
  end
end