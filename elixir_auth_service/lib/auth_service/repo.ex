defmodule AuthService.Repo do
  @moduledoc """
  The repository module for AuthService.
  
  This module provides database access for the authentication service,
  including support for:
  - PostgreSQL database connections
  - Connection pooling
  - Query logging and telemetry
  - Migration support
  """
  
  use Ecto.Repo,
    otp_app: :auth_service,
    adapter: Ecto.Adapters.Postgres
  
  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    opts =
      case System.get_env("DATABASE_URL") do
        nil -> opts
        url -> Keyword.put(opts, :url, url)
      end
    
    {:ok, opts}
  end
  
  @doc """
  A small wrapper around `Repo.transaction/2` that logs transaction rollbacks.
  """
  def transaction_with_logging(fun_or_multi, opts \\ []) do
    result = transaction(fun_or_multi, opts)
    
    case result do
      {:error, reason} ->
        require Logger
        Logger.error("Transaction rolled back: #{inspect(reason)}")
        result
      _ ->
        result
    end
  end
  
  @doc """
  Checks if the database connection is healthy.
  """
  def health_check do
    try do
      query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end
end