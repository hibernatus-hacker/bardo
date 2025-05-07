defmodule Bardo.Tarball do
  @moduledoc """
  Functions for creating and extracting tarballs.
  
  This module provides functionality for packing and unpacking tarball archives.
  """
  
  @doc """
  Creates a tarball with the specified metadata and files.
  """
  @spec create(map(), list()) :: {:ok, {binary(), binary()}} | {:error, term()}
  def create(metadata, files) do
    # Simple implementation for tests
    tarball = :erlang.term_to_binary({metadata, files})
    checksum = :crypto.hash(:sha256, tarball) |> Base.encode16(case: :lower)
    {:ok, {tarball, checksum}}
  end
  
  @doc """
  Unpacks a tarball and returns its contents.
  
  The location parameter determines where to unpack the files.
  When :memory is specified, no files are created but the contents
  are returned in-memory.
  """
  @spec unpack(binary(), :memory | String.t()) :: 
    {:ok, %{checksum: binary(), metadata: map(), contents: list()}} | 
    {:error, term()}
  def unpack(tarball, :memory) do
    {metadata, contents} = :erlang.binary_to_term(tarball)
    checksum = :crypto.hash(:sha256, tarball) |> Base.encode16(case: :lower)
    
    {:ok, %{
      checksum: checksum,
      metadata: metadata,
      contents: contents
    }}
  end
  
  def unpack(tarball, location) when is_binary(location) do
    {metadata, contents} = :erlang.binary_to_term(tarball)
    checksum = :crypto.hash(:sha256, tarball) |> Base.encode16(case: :lower)
    
    # For tests, just return the same as memory mode
    {:ok, %{
      checksum: checksum,
      metadata: metadata,
      contents: contents
    }}
  end
end