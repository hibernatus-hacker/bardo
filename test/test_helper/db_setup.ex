defmodule Bardo.TestHelper.DBSetup do
  @moduledoc """
  Helper module for setting up the DB for tests.
  
  This module ensures that each test has a clean DB instance to work with.
  """
  
  @doc """
  Sets up the DB for testing.

  This function starts the DB process and ensures it's ready for use in tests.
  It also clears any existing data to ensure tests start with a clean database.
  """
  def setup_db do
    # First, clean up any existing DB process
    cleanup_db()

    # Start DB with a fresh instance
    {:ok, _pid} = Bardo.DB.start_link([])

    # Return a cleanup function that can be used to clean up after the test
    &cleanup_db/0
  end
  
  @doc """
  Cleans up the DB after a test.
  
  This function stops the DB process, ensuring a clean slate for the next test.
  """
  def cleanup_db do
    # Clean up by stopping the DB process if it's running
    case Process.whereis(Bardo.DB) do
      nil ->
        :ok
      _pid ->
        # Try to stop gracefully, but if that fails, kill it
        try do
          GenServer.stop(Bardo.DB)
        catch
          :exit, _ ->
            # If we can't stop gracefully, forcefully kill the process
            if pid = Process.whereis(Bardo.DB) do
              Process.exit(pid, :kill)
            end
        end
    end
  end
end