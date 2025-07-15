defmodule AuthService.Application do
  @moduledoc """
  The AuthService Application with distributed OTP supervision tree.
  
  This application provides a distributed authentication service with:
  - Token management across multiple nodes
  - Session clustering with Horde
  - Redis-backed token blacklisting
  - Telemetry monitoring
  - Fault-tolerant supervision
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    # Ensure distributed Erlang is started
    ensure_distributed()
    
    children = [
      # Database
      AuthService.Repo,
      
      # Distributed state management
      {Horde.Registry, [name: AuthService.TokenRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: AuthService.TokenSupervisor, strategy: :one_for_one]},
      
      # Redis connection pool
      {Redix, [host: "localhost", port: 6379, name: :redis_auth]},
      
      # Token management cluster
      {AuthService.TokenCluster, []},
      
      # Session management
      {AuthService.SessionManager, []},
      
      # Cache for rate limiting and temporary data
      {Cachex, name: :auth_cache, options: [
        expiration: [
          default: :timer.minutes(15),
          interval: :timer.minutes(5)
        ]
      ]},
      
      # Telemetry supervisor
      AuthService.Telemetry,
      
      # Phoenix endpoint (if enabled)
      maybe_phoenix_endpoint()
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    
    opts = [strategy: :one_for_one, name: AuthService.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AuthService.Endpoint.config_change(changed, removed)
    :ok
  end
  
  # Ensure distributed Erlang is running
  defp ensure_distributed do
    unless Node.alive?() do
      System.cmd("epmd", ["-daemon"])
      {:ok, _} = Node.start(:"auth_service@127.0.0.1")
    end
  end
  
  # Conditionally start Phoenix endpoint
  defp maybe_phoenix_endpoint do
    if Application.get_env(:auth_service, :enable_phoenix, false) do
      AuthService.Endpoint
    end
  end
end