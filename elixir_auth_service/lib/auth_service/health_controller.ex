defmodule AuthService.HealthController do
  @moduledoc """
  Health check controller for monitoring and load balancers.
  """
  
  use Phoenix.Controller, namespace: AuthService
  
  alias AuthService.{Repo, SessionManager, TokenCluster}
  
  @doc """
  Basic health check endpoint.
  
  Returns 200 OK if the service is running and healthy.
  """
  def check(conn, _params) do
    health_status = %{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:auth_service, :vsn) |> to_string(),
      uptime: uptime(),
      checks: %{
        database: check_database(),
        redis: check_redis(),
        session_manager: check_session_manager(),
        token_cluster: check_token_cluster()
      }
    }
    
    overall_status = if all_checks_healthy?(health_status.checks) do
      "healthy"
    else
      "unhealthy"
    end
    
    status_code = if overall_status == "healthy", do: 200, else: 503
    
    conn
    |> put_status(status_code)
    |> json(Map.put(health_status, :status, overall_status))
  end
  
  # Check database connectivity
  defp check_database do
    case Repo.health_check() do
      :ok -> %{status: "healthy", message: "Database connection successful"}
      :error -> %{status: "unhealthy", message: "Database connection failed"}
    end
  rescue
    _ -> %{status: "unhealthy", message: "Database check failed"}
  end
  
  # Check Redis connectivity
  defp check_redis do
    case Redix.command(:redis_auth, ["PING"]) do
      {:ok, "PONG"} -> %{status: "healthy", message: "Redis connection successful"}
      _ -> %{status: "unhealthy", message: "Redis connection failed"}
    end
  rescue
    _ -> %{status: "unhealthy", message: "Redis check failed"}
  end
  
  # Check session manager
  defp check_session_manager do
    case Process.whereis(SessionManager) do
      nil -> %{status: "unhealthy", message: "Session manager not running"}
      _pid -> %{status: "healthy", message: "Session manager running"}
    end
  rescue
    _ -> %{status: "unhealthy", message: "Session manager check failed"}
  end
  
  # Check token cluster
  defp check_token_cluster do
    case Process.whereis(TokenCluster) do
      nil -> %{status: "unhealthy", message: "Token cluster not running"}
      _pid -> %{status: "healthy", message: "Token cluster running"}
    end
  rescue
    _ -> %{status: "unhealthy", message: "Token cluster check failed"}
  end
  
  # Check if all health checks are healthy
  defp all_checks_healthy?(checks) do
    Enum.all?(checks, fn {_name, check} -> check.status == "healthy" end)
  end
  
  # Calculate uptime
  defp uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms / 1000
  end
end