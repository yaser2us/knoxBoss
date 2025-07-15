# Test Helper for AuthService
ExUnit.start()

# Start the application for testing
Application.ensure_all_started(:auth_service)

# Configure Ecto to use sandbox mode
Ecto.Adapters.SQL.Sandbox.mode(AuthService.Repo, :manual)

# Configure ExUnit for performance tests
ExUnit.configure(
  exclude: [:performance, :stress],
  timeout: 60_000,
  max_failures: 10
)

# Performance test configuration
if System.get_env("PERFORMANCE_TESTS") == "true" do
  ExUnit.configure(
    include: [:performance, :stress],
    exclude: [],
    timeout: 600_000,  # 10 minutes for performance tests
    max_failures: 1
  )
  
  # Optimize system for performance testing
  System.put_env("PERFORMANCE_MODE", "true")
  
  # Set high limits
  :erlang.system_flag(:max_ports, 65536)
  :erlang.system_flag(:max_processes, 2_000_000)
  
  IO.puts("🚀 Performance test mode enabled")
  IO.puts("⚡ System optimized for high throughput testing")
  IO.puts("🔧 Max processes: 2,000,000")
  IO.puts("🔌 Max ports: 65,536")
end

# Helper functions for tests
defmodule TestHelpers do
  @moduledoc """
  Helper functions for testing.
  """
  
  def setup_performance_test do
    # Clear any existing data
    AuthService.Repo.delete_all(AuthService.Accounts.User)
    
    # Optimize configurations for performance
    Application.put_env(:auth_service, :rate_limit_max_requests, 100_000)
    Application.put_env(:auth_service, :max_login_attempts, 100)
    
    # Set logger to warning level to reduce noise
    Logger.configure(level: :warning)
    
    :ok
  end
  
  def cleanup_performance_test do
    # Reset configurations
    Logger.configure(level: :info)
    
    # Clear test data
    AuthService.Repo.delete_all(AuthService.Accounts.User)
    
    # Force garbage collection
    :erlang.garbage_collect()
    
    :ok
  end
  
  def create_test_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      password: "testpassword123",
      first_name: "Test",
      last_name: "User",
      role: "user",
      is_active: true,
      email_verified: true
    }
    
    attrs = Map.merge(default_attrs, attrs)
    
    AuthService.Accounts.create_user(attrs)
  end
  
  def authenticate_user(email, password) do
    AuthService.Accounts.authenticate_user(email, password)
  end
  
  def create_jwt_token(user) do
    AuthService.Guardian.encode_and_sign(user)
  end
  
  def validate_jwt_token(token) do
    AuthService.Guardian.resource_from_token(token)
  end
  
  def measure_time(fun) do
    start_time = System.monotonic_time(:microsecond)
    result = fun.()
    end_time = System.monotonic_time(:microsecond)
    
    duration_ms = (end_time - start_time) / 1000
    {result, duration_ms}
  end
  
  def memory_usage do
    :erlang.memory(:total)
  end
  
  def process_count do
    :erlang.system_info(:process_count)
  end
  
  def system_metrics do
    %{
      memory_total: :erlang.memory(:total),
      memory_processes: :erlang.memory(:processes),
      memory_system: :erlang.memory(:system),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count),
      schedulers: :erlang.system_info(:schedulers_online)
    }
  end
end

# Make TestHelpers available globally
import TestHelpers

# Print test configuration
IO.puts("✅ Test environment initialized")
IO.puts("🗄️  Database: #{Application.get_env(:auth_service, AuthService.Repo)[:database]}")
IO.puts("🏃 ExUnit timeout: #{ExUnit.configuration()[:timeout]}ms")

if System.get_env("PERFORMANCE_MODE") == "true" do
  IO.puts("⚡ Performance testing mode active")
  IO.puts("🎯 Ready for high-throughput benchmarks")
end