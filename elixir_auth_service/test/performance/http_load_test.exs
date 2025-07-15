defmodule AuthService.Performance.HTTPLoadTest do
  @moduledoc """
  HTTP-based load test for the authentication service.
  
  This test simulates real HTTP requests to the authentication endpoints.
  """
  
  use ExUnit.Case
  
  alias AuthService.{Accounts, Repo}
  
  import AuthService.Factory
  
  @endpoint_url "http://localhost:4000"
  @concurrent_users 100
  @requests_per_user 1000
  @test_duration_seconds 180  # 3 minutes
  
  @tag timeout: 300_000  # 5 minutes
  @tag :http_load
  test "HTTP login load test" do
    IO.puts("\n🌐 Starting HTTP Login Load Test")
    IO.puts("Endpoint: #{@endpoint_url}")
    IO.puts("Concurrent users: #{@concurrent_users}")
    IO.puts("Requests per user: #{@requests_per_user}")
    IO.puts("Test duration: #{@test_duration_seconds} seconds")
    
    # Setup test users
    users = setup_http_test_users(50)
    
    # Start HTTP server if not running
    ensure_server_running()
    
    # Initialize metrics
    metrics = %{
      start_time: System.monotonic_time(:millisecond),
      requests_completed: 0,
      requests_successful: 0,
      requests_failed: 0,
      total_response_time: 0,
      response_times: [],
      status_codes: %{},
      errors: %{}
    }
    
    # Start metrics collector
    metrics_pid = start_http_metrics_collector(metrics)
    
    IO.puts("🚀 Starting HTTP load test...")
    
    # Create HTTPoison pool
    :httpoison.start()
    
    # Spawn concurrent HTTP workers
    tasks = for i <- 1..@concurrent_users do
      Task.async(fn ->
        user = Enum.random(users)
        run_http_login_worker(i, user, @requests_per_user, metrics_pid)
      end)
    end
    
    # Wait for completion or timeout
    start_time = System.monotonic_time(:millisecond)
    results = Task.await_many(tasks, @test_duration_seconds * 1000 + 30_000)
    end_time = System.monotonic_time(:millisecond)
    
    total_duration = end_time - start_time
    
    # Get final metrics
    final_metrics = get_http_final_metrics(metrics_pid)
    send(metrics_pid, :stop)
    
    # Calculate performance metrics
    actual_rps = final_metrics.requests_completed / (total_duration / 1000)
    avg_response_time = if final_metrics.requests_completed > 0 do
      final_metrics.total_response_time / final_metrics.requests_completed
    else
      0
    end
    
    success_rate = if final_metrics.requests_completed > 0 do
      (final_metrics.requests_successful / final_metrics.requests_completed) * 100
    else
      0
    end
    
    # Generate report
    generate_http_load_report(%{
      total_duration: total_duration / 1000,
      total_requests: final_metrics.requests_completed,
      successful_requests: final_metrics.requests_successful,
      failed_requests: final_metrics.requests_failed,
      actual_rps: actual_rps,
      success_rate: success_rate,
      avg_response_time: avg_response_time,
      response_times: final_metrics.response_times,
      status_codes: final_metrics.status_codes,
      errors: final_metrics.errors,
      concurrent_users: @concurrent_users,
      requests_per_user: @requests_per_user
    })
    
    # Assertions
    expected_total_requests = @concurrent_users * @requests_per_user
    assert final_metrics.requests_completed >= expected_total_requests * 0.8,
           "Completed #{final_metrics.requests_completed} out of #{expected_total_requests} requests"
    
    assert success_rate >= 90.0,
           "Success rate #{success_rate}% is below 90%"
    
    assert actual_rps >= 50,
           "RPS #{actual_rps} is below minimum threshold of 50"
    
    assert avg_response_time <= 1000,
           "Average response time #{avg_response_time}ms exceeds 1000ms"
  end
  
  defp setup_http_test_users(count) do
    for i <- 1..count do
      email = "http_user_#{i}@example.com"
      password = "http_password_#{i}"
      
      # Create user in database
      user = insert(:user, email: email, password: password)
      
      %{
        email: email,
        password: password,
        user_id: user.id
      }
    end
  end
  
  defp ensure_server_running do
    case :httpoison.get("#{@endpoint_url}/health") do
      {:ok, %{status_code: 200}} ->
        IO.puts("✅ Server is running")
      
      {:error, %{reason: :econnrefused}} ->
        IO.puts("❌ Server not running - please start the server first")
        IO.puts("Run: mix run --no-halt")
        exit(:server_not_running)
      
      {:error, reason} ->
        IO.puts("⚠️  Server health check failed: #{inspect(reason)}")
    end
  end
  
  defp run_http_login_worker(worker_id, user, request_count, metrics_pid) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
    
    login_payload = Jason.encode!(%{
      email: user.email,
      password: user.password
    })
    
    for i <- 1..request_count do
      request_start = System.monotonic_time(:microsecond)
      
      result = case :httpoison.post("#{@endpoint_url}/api/v1/auth/login", login_payload, headers, [timeout: 5000]) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"token" => _token}} -> {:success, 200}
            _ -> {:error, :invalid_response}
          end
        
        {:ok, %{status_code: status_code}} ->
          {:error, {:http_error, status_code}}
        
        {:error, %{reason: reason}} ->
          {:error, {:connection_error, reason}}
        
        {:error, reason} ->
          {:error, {:unknown_error, reason}}
      end
      
      request_end = System.monotonic_time(:microsecond)
      response_time = (request_end - request_start) / 1000  # Convert to ms
      
      # Report metrics
      send(metrics_pid, {:http_request_completed, result, response_time})
      
      # Brief pause every 50 requests to prevent overwhelming
      if rem(i, 50) == 0 do
        :timer.sleep(1)
      end
    end
    
    {:worker_completed, worker_id}
  end
  
  defp start_http_metrics_collector(initial_metrics) do
    spawn(fn ->
      http_metrics_collector_loop(initial_metrics)
    end)
  end
  
  defp http_metrics_collector_loop(metrics) do
    receive do
      {:http_request_completed, {:success, status_code}, response_time} ->
        status_count = Map.get(metrics.status_codes, status_code, 0) + 1
        new_status_codes = Map.put(metrics.status_codes, status_code, status_count)
        
        new_metrics = %{
          metrics |
          requests_completed: metrics.requests_completed + 1,
          requests_successful: metrics.requests_successful + 1,
          total_response_time: metrics.total_response_time + response_time,
          response_times: [response_time | metrics.response_times],
          status_codes: new_status_codes
        }
        
        # Progress reporting
        if rem(new_metrics.requests_completed, 1000) == 0 do
          elapsed = (System.monotonic_time(:millisecond) - metrics.start_time) / 1000
          current_rps = new_metrics.requests_completed / elapsed
          IO.puts("Progress: #{new_metrics.requests_completed} requests, #{Float.round(current_rps, 2)} RPS")
        end
        
        http_metrics_collector_loop(new_metrics)
      
      {:http_request_completed, {:error, reason}, response_time} ->
        error_count = Map.get(metrics.errors, reason, 0) + 1
        new_errors = Map.put(metrics.errors, reason, error_count)
        
        new_metrics = %{
          metrics |
          requests_completed: metrics.requests_completed + 1,
          requests_failed: metrics.requests_failed + 1,
          total_response_time: metrics.total_response_time + response_time,
          response_times: [response_time | metrics.response_times],
          errors: new_errors
        }
        
        http_metrics_collector_loop(new_metrics)
      
      {:get_metrics, pid} ->
        send(pid, {:metrics, metrics})
        http_metrics_collector_loop(metrics)
      
      :stop ->
        :ok
    end
  end
  
  defp get_http_final_metrics(metrics_pid) do
    send(metrics_pid, {:get_metrics, self()})
    receive do
      {:metrics, metrics} -> metrics
    after 5000 ->
      %{requests_completed: 0, requests_successful: 0, requests_failed: 0}
    end
  end
  
  defp generate_http_load_report(results) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🌐 HTTP LOGIN LOAD TEST REPORT")
    IO.puts(String.duplicate("=", 80))
    
    IO.puts("\n📊 PERFORMANCE METRICS:")
    IO.puts("Total Duration:      #{Float.round(results.total_duration, 2)}s")
    IO.puts("Total Requests:      #{results.total_requests}")
    IO.puts("Successful Requests: #{results.successful_requests}")
    IO.puts("Failed Requests:     #{results.failed_requests}")
    IO.puts("Requests per Second: #{Float.round(results.actual_rps, 2)}")
    IO.puts("Success Rate:        #{Float.round(results.success_rate, 2)}%")
    
    IO.puts("\n⏱️  RESPONSE TIME METRICS:")
    IO.puts("Average Response:    #{Float.round(results.avg_response_time, 2)}ms")
    
    if length(results.response_times) > 0 do
      sorted_times = Enum.sort(results.response_times)
      p50 = Enum.at(sorted_times, round(length(sorted_times) * 0.5))
      p95 = Enum.at(sorted_times, round(length(sorted_times) * 0.95))
      p99 = Enum.at(sorted_times, round(length(sorted_times) * 0.99))
      min_time = Enum.min(sorted_times)
      max_time = Enum.max(sorted_times)
      
      IO.puts("Min Response:        #{Float.round(min_time, 2)}ms")
      IO.puts("Max Response:        #{Float.round(max_time, 2)}ms")
      IO.puts("P50 Response:        #{Float.round(p50, 2)}ms")
      IO.puts("P95 Response:        #{Float.round(p95, 2)}ms")
      IO.puts("P99 Response:        #{Float.round(p99, 2)}ms")
    end
    
    IO.puts("\n🔧 TEST CONFIGURATION:")
    IO.puts("Concurrent Users:    #{results.concurrent_users}")
    IO.puts("Requests per User:   #{results.requests_per_user}")
    IO.puts("Target Total:        #{results.concurrent_users * results.requests_per_user}")
    
    if map_size(results.status_codes) > 0 do
      IO.puts("\n📈 HTTP STATUS CODES:")
      for {status_code, count} <- results.status_codes do
        IO.puts("#{status_code}: #{count}")
      end
    end
    
    if map_size(results.errors) > 0 do
      IO.puts("\n❌ ERRORS:")
      for {error, count} <- results.errors do
        IO.puts("#{inspect(error)}: #{count}")
      end
    end
    
    IO.puts("\n" <> String.duplicate("=", 80))
    
    # Save report to file
    save_http_load_report(results)
  end
  
  defp save_http_load_report(results) do
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")
    filename = "http_load_test_#{timestamp}.json"
    filepath = Path.join(["test", "performance", "reports", filename])
    
    File.mkdir_p!(Path.dirname(filepath))
    
    report_data = %{
      test_name: "http_load_test",
      timestamp: DateTime.utc_now(),
      results: results,
      environment: %{
        endpoint_url: @endpoint_url,
        erlang_version: :erlang.system_info(:version),
        elixir_version: System.version()
      }
    }
    
    File.write!(filepath, Jason.encode!(report_data, pretty: true))
    IO.puts("📄 HTTP load test report saved to: #{filepath}")
  end
end