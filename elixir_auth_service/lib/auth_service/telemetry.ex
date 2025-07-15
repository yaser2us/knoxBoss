defmodule AuthService.Telemetry do
  @moduledoc """
  Telemetry configuration for monitoring authentication service performance.
  
  This module provides:
  - Authentication metrics (success/failure rates)
  - Token generation and validation metrics
  - Session management metrics
  - Database query metrics
  - Custom business metrics
  """
  
  use Supervisor
  import Telemetry.Metrics
  
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end
  
  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_join.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        unit: {:native, :millisecond}
      ),
      
      # Database Metrics
      summary("auth_service.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("auth_service.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("auth_service.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("auth_service.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("auth_service.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "The time the connection spent waiting before being checked out for the query"
      ),
      
      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      
      # Authentication Metrics
      counter("auth_service.authentication.attempts.total",
        tags: [:result, :method],
        description: "Total authentication attempts"
      ),
      counter("auth_service.authentication.success.total",
        tags: [:method],
        description: "Successful authentication attempts"
      ),
      counter("auth_service.authentication.failure.total",
        tags: [:method, :reason],
        description: "Failed authentication attempts"
      ),
      summary("auth_service.authentication.duration",
        unit: {:native, :millisecond},
        tags: [:method],
        description: "Authentication request duration"
      ),
      
      # Token Metrics
      counter("auth_service.token.generated.total",
        tags: [:type],
        description: "Total tokens generated"
      ),
      counter("auth_service.token.validated.total",
        tags: [:result],
        description: "Token validation attempts"
      ),
      counter("auth_service.token.blacklisted.total",
        tags: [:reason],
        description: "Tokens blacklisted"
      ),
      summary("auth_service.token.generation_time",
        unit: {:native, :millisecond},
        description: "Token generation duration"
      ),
      summary("auth_service.token.validation_time",
        unit: {:native, :millisecond},
        description: "Token validation duration"
      ),
      
      # Session Metrics
      counter("auth_service.session.created.total",
        description: "Total sessions created"
      ),
      counter("auth_service.session.terminated.total",
        tags: [:reason],
        description: "Sessions terminated"
      ),
      summary("auth_service.session.duration",
        unit: {:native, :second},
        description: "Session duration"
      ),
      last_value("auth_service.session.active.count",
        description: "Number of active sessions"
      ),
      
      # Rate Limiting Metrics
      counter("auth_service.rate_limit.exceeded.total",
        tags: [:endpoint, :ip],
        description: "Rate limit exceeded events"
      ),
      
      # Security Metrics
      counter("auth_service.security.invalid_token.total",
        tags: [:reason],
        description: "Invalid token attempts"
      ),
      counter("auth_service.security.suspicious_activity.total",
        tags: [:type],
        description: "Suspicious activity detected"
      ),
      counter("auth_service.security.account_locked.total",
        description: "Accounts locked due to failed attempts"
      ),
      
      # Cache Metrics
      counter("auth_service.cache.hit.total",
        tags: [:cache_name],
        description: "Cache hits"
      ),
      counter("auth_service.cache.miss.total",
        tags: [:cache_name],
        description: "Cache misses"
      ),
      
      # Cluster Metrics
      last_value("auth_service.cluster.nodes.count",
        description: "Number of nodes in cluster"
      ),
      counter("auth_service.cluster.node_up.total",
        description: "Node up events"
      ),
      counter("auth_service.cluster.node_down.total",
        description: "Node down events"
      ),
      
      # Custom Business Metrics
      counter("auth_service.user.registered.total",
        description: "Total users registered"
      ),
      counter("auth_service.user.login.total",
        tags: [:success],
        description: "User login attempts"
      ),
      summary("auth_service.user.session_duration",
        unit: {:native, :second},
        description: "Average user session duration"
      )
    ]
  end
  
  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {__MODULE__, :dispatch_active_sessions, []},
      {__MODULE__, :dispatch_cluster_info, []},
      {__MODULE__, :dispatch_cache_stats, []}
    ]
  end
  
  def dispatch_active_sessions do
    active_sessions = 0  # TODO: Implement get_active_session_count()
    
    :telemetry.execute(
      [:auth_service, :session, :active],
      %{count: active_sessions},
      %{}
    )
  end
  
  def dispatch_cluster_info do
    nodes_count = length([Node.self() | Node.list()])
    
    :telemetry.execute(
      [:auth_service, :cluster, :nodes],
      %{count: nodes_count},
      %{}
    )
  end
  
  def dispatch_cache_stats do
    # Get cache statistics from Cachex
    case Cachex.stats(:auth_cache) do
      {:ok, stats} ->
        :telemetry.execute(
          [:auth_service, :cache, :stats],
          %{
            hit_rate: stats.hit_rate || 0,
            miss_rate: stats.miss_rate || 0,
            size: stats.size || 0
          },
          %{cache_name: :auth_cache}
        )
      
      _ ->
        :ok
    end
  end
  
  # Helper functions to emit telemetry events
  
  def emit_authentication_attempt(method, result, duration) do
    :telemetry.execute(
      [:auth_service, :authentication, :attempts],
      %{duration: duration},
      %{method: method, result: result}
    )
  end
  
  def emit_token_generated(type, duration) do
    :telemetry.execute(
      [:auth_service, :token, :generated],
      %{duration: duration},
      %{type: type}
    )
  end
  
  def emit_token_validated(result, duration) do
    :telemetry.execute(
      [:auth_service, :token, :validated],
      %{duration: duration},
      %{result: result}
    )
  end
  
  def emit_session_created(duration) do
    :telemetry.execute(
      [:auth_service, :session, :created],
      %{duration: duration},
      %{}
    )
  end
  
  def emit_session_terminated(reason, duration) do
    :telemetry.execute(
      [:auth_service, :session, :terminated],
      %{duration: duration},
      %{reason: reason}
    )
  end
  
  def emit_rate_limit_exceeded(endpoint, ip) do
    :telemetry.execute(
      [:auth_service, :rate_limit, :exceeded],
      %{count: 1},
      %{endpoint: endpoint, ip: ip}
    )
  end
  
  def emit_security_event(type, metadata \\ %{}) do
    :telemetry.execute(
      [:auth_service, :security, :event],
      %{count: 1},
      Map.put(metadata, :type, type)
    )
  end
  
  def emit_cache_operation(operation, cache_name, duration) do
    :telemetry.execute(
      [:auth_service, :cache, operation],
      %{duration: duration},
      %{cache_name: cache_name}
    )
  end
  
  def emit_cluster_event(event, node_name) do
    :telemetry.execute(
      [:auth_service, :cluster, event],
      %{count: 1},
      %{node: node_name}
    )
  end
  
  def emit_user_event(event, user_id) do
    :telemetry.execute(
      [:auth_service, :user, event],
      %{count: 1},
      %{user_id: user_id}
    )
  end
end