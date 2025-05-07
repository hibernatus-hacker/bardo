defmodule Bardo.Repo do
  @moduledoc """
  Bardo's Ecto repository for database access.
  
  This module provides the Ecto repository for Bardo, enabling
  the application to interact with the database using Ecto.
  """
  
  use Ecto.Repo,
    otp_app: :bardo,
    adapter: Ecto.Adapters.Postgres
end