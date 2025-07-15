defmodule AuthService.MetricsController do
  @moduledoc """
  Metrics controller for monitoring and observability.
  """
  
  use Phoenix.Controller, namespace: AuthService
  
  alias AuthService.{Repo, Telemetry}
  
  @doc """
  Main metrics endpoint.
  
  Returns application metrics in JSON format.
  """
  def index(conn, _params) do
    metrics = %{
      timestamp: DateTime.utc_now(),
      application: %{
        name: "auth_service",
        version: Application.spec(:auth_service, :vsn) |> to_string(),
        environment: Mix.env()
      },
      system: system_metrics(),
      database: database_metrics(),
      authentication: auth_metrics(),
      performance: performance_metrics()
    }
    
    json(conn, metrics)
  end
  
  @doc """
  Health check endpoint for monitoring systems.
  """
  def health(conn, _params) do
    json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})
  end
  
  @doc """
  Readiness check endpoint for Kubernetes.
  """
  def ready(conn, _params) do
    ready = database_ready?() && redis_ready?()
    
    status = if ready, do: "ready", else: "not_ready"
    status_code = if ready, do: 200, else: 503
    
    conn
    |> put_status(status_code)
    |> json(%{status: status, timestamp: DateTime.utc_now()})
  end
  
  # System metrics
  defp system_metrics do
    {total_memory, _} = :erlang.memory(:total)
    {process_count, _} = :erlang.system_info(:process_count)
    {port_count, _} = :erlang.system_info(:port_count)
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    
    %{
      memory_total: total_memory,
      process_count: process_count,
      port_count: port_count,
      uptime_seconds: uptime_ms / 1000,
      node_name: Node.self(),
      vm_version: :erlang.system_info(:version) |> to_string()
    }
  end
  
  # Database metrics
  defp database_metrics do
    try do
      %{
        pool_size: get_pool_size(),
        active_connections: get_active_connections(),
        status: "connected"
      }
    rescue
      _ -> %{status: "error"}
    end
  end
  
  # Authentication metrics
  defp auth_metrics do
    try do
      %{
        total_users: get_total_users(),
        active_sessions: get_active_sessions(),
        recent_logins: get_recent_logins(),
        failed_attempts: get_failed_attempts()
      }
    rescue
      _ -> %{status: "error"}
    end
  end
  
  # Performance metrics
  defp performance_metrics do
    %{
      gc_count: :erlang.statistics(:garbage_collection),
      reductions: :erlang.statistics(:reductions),
      run_queue: :erlang.statistics(:run_queue),
      context_switches: :erlang.statistics(:context_switches)
    }
  end
  
  # Helper functions
  defp database_ready? do
    case Repo.health_check() do
      :ok -> true
      _ -> false
    end
  end
  
  defp redis_ready? do
    case Redix.command(:redis_auth, ["PING"]) do
      {:ok, "PONG"} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
  
  defp get_pool_size do
    Application.get_env(:auth_service, AuthService.Repo)[:pool_size] || 10
  end
  
  defp get_active_connections do
    # This would need to be implemented based on your connection pool
    0
  end
  
  defp get_total_users do
    case Repo.aggregate(AuthService.Accounts.User, :count, :id) do
      count when is_integer(count) -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp get_active_sessions do
    # This would query your sessions table
    0
  end
  
  defp get_recent_logins do
    # This would query recent login attempts
    0
  end
  
  defp get_failed_attempts do
    # This would query failed login attempts
    0
  end
end