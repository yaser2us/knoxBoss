defmodule AuthService.Performance.LoginBenchmarkTest do
  @moduledoc """
  High-performance login benchmark test.
  
  Target: 3 million login requests in 3 minutes
  Expected RPS: ~16,667 requests per second
  """
  
  use ExUnit.Case
  
  alias AuthService.{Accounts, Repo}
  alias AuthService.Accounts.User
  
  import AuthService.Factory
  
  @target_requests 3_000_000
  @target_duration_seconds 180  # 3 minutes
  @expected_rps round(@target_requests / @target_duration_seconds)
  @concurrent_workers 1000
  @requests_per_worker round(@target_requests / @concurrent_workers)
  
  @tag timeout: 300_000  # 5 minutes timeout
  @tag :performance
  test "3M login requests in 3 minutes benchmark" do
    IO.puts("\n🚀 Starting Login Performance Benchmark")
    IO.puts("Target: #{@target_requests} requests in #{@target_duration_seconds} seconds")
    IO.puts("Expected RPS: #{@expected_rps}")
    IO.puts("Workers: #{@concurrent_workers}")
    IO.puts("Requests per worker: #{@requests_per_worker}")
    
    # Setup test users
    IO.puts("📝 Setting up test users...")
    users = setup_test_users(100)  # Create 100 test users to distribute load
    
    # Initialize metrics
    metrics = %{
      start_time: System.monotonic_time(:millisecond),
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_response_time: 0,
      min_response_time: nil,
      max_response_time: 0,
      response_times: [],
      errors: %{}
    }
    
    # Start metrics collector
    metrics_pid = start_metrics_collector(metrics)
    
    # Start performance monitoring
    monitor_pid = start_performance_monitor()
    
    IO.puts("🔥 Starting benchmark...")
    start_time = System.monotonic_time(:millisecond)
    
    # Spawn concurrent workers
    tasks = for i <- 1..@concurrent_workers do
      Task.async(fn ->
        worker_id = i
        random_user = Enum.random(users)
        run_login_worker(worker_id, random_user, @requests_per_worker, metrics_pid)
      end)
    end
    
    # Wait for all workers to complete
    results = Task.await_many(tasks, 300_000)  # 5 minute timeout
    
    end_time = System.monotonic_time(:millisecond)
    total_duration = end_time - start_time
    
    # Collect final metrics
    final_metrics = get_final_metrics(metrics_pid)
    performance_data = get_performance_data(monitor_pid)
    
    # Stop collectors
    send(metrics_pid, :stop)
    send(monitor_pid, :stop)
    
    # Calculate results
    actual_rps = final_metrics.total_requests / (total_duration / 1000)
    avg_response_time = if final_metrics.total_requests > 0 do
      final_metrics.total_response_time / final_metrics.total_requests
    else
      0
    end
    
    success_rate = if final_metrics.total_requests > 0 do
      (final_metrics.successful_requests / final_metrics.total_requests) * 100
    else
      0
    end
    
    # Generate detailed report
    generate_performance_report(%{
      target_requests: @target_requests,
      target_duration: @target_duration_seconds,
      expected_rps: @expected_rps,
      actual_duration: total_duration / 1000,
      actual_requests: final_metrics.total_requests,
      actual_rps: actual_rps,
      successful_requests: final_metrics.successful_requests,
      failed_requests: final_metrics.failed_requests,
      success_rate: success_rate,
      avg_response_time: avg_response_time,
      min_response_time: final_metrics.min_response_time,
      max_response_time: final_metrics.max_response_time,
      response_times: final_metrics.response_times,
      errors: final_metrics.errors,
      performance_data: performance_data,
      workers: @concurrent_workers,
      requests_per_worker: @requests_per_worker
    })
    
    # Assertions for benchmark success
    assert final_metrics.total_requests >= @target_requests * 0.95, 
           "Only completed #{final_metrics.total_requests} out of #{@target_requests} requests"
    
    assert actual_rps >= @expected_rps * 0.8, 
           "RPS #{actual_rps} is below 80% of target #{@expected_rps}"
    
    assert success_rate >= 95.0, 
           "Success rate #{success_rate}% is below 95%"
    
    assert avg_response_time <= 100, 
           "Average response time #{avg_response_time}ms exceeds 100ms"
    
    IO.puts("✅ Benchmark completed successfully!")
  end
  
  defp setup_test_users(count) do
    users = for i <- 1..count do
      %{
        email: "benchmark_user_#{i}@example.com",
        password: "benchmark_password_#{i}",
        user_struct: insert(:user, 
          email: "benchmark_user_#{i}@example.com",
          password: "benchmark_password_#{i}"
        )
      }
    end
    
    IO.puts("Created #{count} test users")
    users
  end
  
  defp run_login_worker(worker_id, user, request_count, metrics_pid) do
    for i <- 1..request_count do
      start_time = System.monotonic_time(:microsecond)
      
      result = try do
        case Accounts.authenticate_user(user.email, user.password) do
          {:ok, _user} -> 
            :success
          {:error, reason} -> 
            {:error, reason}
        end
      rescue
        error -> 
          {:error, {:exception, error}}
      end
      
      end_time = System.monotonic_time(:microsecond)
      response_time = (end_time - start_time) / 1000  # Convert to milliseconds
      
      # Send metrics to collector
      send(metrics_pid, {:request_completed, result, response_time})
      
      # Brief pause to prevent overwhelming (adjust as needed)
      if rem(i, 100) == 0 do
        :timer.sleep(1)
      end
    end
    
    {:worker_completed, worker_id}
  end
  
  defp start_metrics_collector(initial_metrics) do
    spawn(fn ->
      metrics_collector_loop(initial_metrics)
    end)
  end
  
  defp metrics_collector_loop(metrics) do
    receive do
      {:request_completed, :success, response_time} ->
        new_metrics = %{
          metrics |
          total_requests: metrics.total_requests + 1,
          successful_requests: metrics.successful_requests + 1,
          total_response_time: metrics.total_response_time + response_time,
          min_response_time: if(metrics.min_response_time == nil, do: response_time, else: min(metrics.min_response_time, response_time)),
          max_response_time: max(metrics.max_response_time, response_time),
          response_times: [response_time | metrics.response_times]
        }
        
        # Print progress every 10,000 requests
        if rem(new_metrics.total_requests, 10_000) == 0 do
          current_time = System.monotonic_time(:millisecond)
          elapsed = (current_time - metrics.start_time) / 1000
          current_rps = new_metrics.total_requests / elapsed
          IO.puts("Progress: #{new_metrics.total_requests} requests, #{Float.round(current_rps, 2)} RPS")
        end
        
        metrics_collector_loop(new_metrics)
        
      {:request_completed, {:error, reason}, response_time} ->
        error_count = Map.get(metrics.errors, reason, 0) + 1
        new_errors = Map.put(metrics.errors, reason, error_count)
        
        new_metrics = %{
          metrics |
          total_requests: metrics.total_requests + 1,
          failed_requests: metrics.failed_requests + 1,
          total_response_time: metrics.total_response_time + response_time,
          errors: new_errors,
          response_times: [response_time | metrics.response_times]
        }
        
        metrics_collector_loop(new_metrics)
        
      {:get_metrics, pid} ->
        send(pid, {:metrics, metrics})
        metrics_collector_loop(metrics)
        
      :stop ->
        :ok
    end
  end
  
  defp get_final_metrics(metrics_pid) do
    send(metrics_pid, {:get_metrics, self()})
    receive do
      {:metrics, metrics} -> metrics
    after 5000 ->
      %{total_requests: 0, successful_requests: 0, failed_requests: 0}
    end
  end
  
  defp start_performance_monitor do
    spawn(fn ->
      performance_monitor_loop(%{
        cpu_samples: [],
        memory_samples: [],
        process_samples: []
      })
    end)
  end
  
  defp performance_monitor_loop(data) do
    # Collect system metrics
    {total_memory, _} = :erlang.memory(:total)
    process_count = :erlang.system_info(:process_count)
    
    new_data = %{
      data |
      memory_samples: [total_memory | data.memory_samples],
      process_samples: [process_count | data.process_samples]
    }
    
    receive do
      {:get_data, pid} ->
        send(pid, {:performance_data, new_data})
        performance_monitor_loop(new_data)
      :stop ->
        :ok
    after 1000 ->
      performance_monitor_loop(new_data)
    end
  end
  
  defp get_performance_data(monitor_pid) do
    send(monitor_pid, {:get_data, self()})
    receive do
      {:performance_data, data} -> data
    after 5000 ->
      %{memory_samples: [], process_samples: []}
    end
  end
  
  defp generate_performance_report(results) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🏆 LOGIN PERFORMANCE BENCHMARK REPORT")
    IO.puts(String.duplicate("=", 80))
    
    IO.puts("\n📊 TARGET vs ACTUAL:")
    IO.puts("Target Requests:     #{results.target_requests}")
    IO.puts("Actual Requests:     #{results.actual_requests}")
    IO.puts("Target Duration:     #{results.target_duration}s")
    IO.puts("Actual Duration:     #{Float.round(results.actual_duration, 2)}s")
    IO.puts("Target RPS:          #{results.expected_rps}")
    IO.puts("Actual RPS:          #{Float.round(results.actual_rps, 2)}")
    
    IO.puts("\n✅ SUCCESS METRICS:")
    IO.puts("Successful Requests: #{results.successful_requests}")
    IO.puts("Failed Requests:     #{results.failed_requests}")
    IO.puts("Success Rate:        #{Float.round(results.success_rate, 2)}%")
    
    IO.puts("\n⏱️  RESPONSE TIME METRICS:")
    IO.puts("Average Response:    #{Float.round(results.avg_response_time, 2)}ms")
    IO.puts("Min Response:        #{Float.round(results.min_response_time || 0, 2)}ms")
    IO.puts("Max Response:        #{Float.round(results.max_response_time, 2)}ms")
    
    if length(results.response_times) > 0 do
      sorted_times = Enum.sort(results.response_times)
      p50 = Enum.at(sorted_times, round(length(sorted_times) * 0.5))
      p95 = Enum.at(sorted_times, round(length(sorted_times) * 0.95))
      p99 = Enum.at(sorted_times, round(length(sorted_times) * 0.99))
      
      IO.puts("P50 Response:        #{Float.round(p50, 2)}ms")
      IO.puts("P95 Response:        #{Float.round(p95, 2)}ms")
      IO.puts("P99 Response:        #{Float.round(p99, 2)}ms")
    end
    
    IO.puts("\n🔧 CONFIGURATION:")
    IO.puts("Concurrent Workers:  #{results.workers}")
    IO.puts("Requests/Worker:     #{results.requests_per_worker}")
    
    if map_size(results.errors) > 0 do
      IO.puts("\n❌ ERRORS:")
      for {error, count} <- results.errors do
        IO.puts("#{error}: #{count}")
      end
    end
    
    # Performance data
    if length(results.performance_data.memory_samples) > 0 do
      avg_memory = Enum.sum(results.performance_data.memory_samples) / length(results.performance_data.memory_samples)
      max_memory = Enum.max(results.performance_data.memory_samples)
      
      IO.puts("\n💾 MEMORY USAGE:")
      IO.puts("Average Memory:      #{Float.round(avg_memory / 1_000_000, 2)} MB")
      IO.puts("Peak Memory:         #{Float.round(max_memory / 1_000_000, 2)} MB")
    end
    
    if length(results.performance_data.process_samples) > 0 do
      avg_processes = Enum.sum(results.performance_data.process_samples) / length(results.performance_data.process_samples)
      max_processes = Enum.max(results.performance_data.process_samples)
      
      IO.puts("\n🔄 PROCESS COUNT:")
      IO.puts("Average Processes:   #{round(avg_processes)}")
      IO.puts("Peak Processes:      #{max_processes}")
    end
    
    IO.puts("\n" <> String.duplicate("=", 80))
    
    # Save detailed report to file
    save_detailed_report(results)
  end
  
  defp save_detailed_report(results) do
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")
    filename = "login_benchmark_#{timestamp}.json"
    filepath = Path.join(["test", "performance", "reports", filename])
    
    File.mkdir_p!(Path.dirname(filepath))
    
    report_data = %{
      benchmark_info: %{
        test_name: "login_benchmark",
        timestamp: DateTime.utc_now(),
        target_requests: results.target_requests,
        target_duration: results.target_duration,
        expected_rps: results.expected_rps
      },
      results: results,
      system_info: %{
        erlang_version: :erlang.system_info(:version),
        elixir_version: System.version(),
        schedulers: :erlang.system_info(:schedulers_online)
      }
    }
    
    File.write!(filepath, Jason.encode!(report_data, pretty: true))
    IO.puts("📄 Detailed report saved to: #{filepath}")
  end
end