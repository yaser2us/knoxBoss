defmodule AuthService.Performance.StressTest do
  @moduledoc """
  Stress tests for the authentication system.
  
  These tests validate system behavior under high load conditions.
  """
  
  use ExUnit.Case
  
  alias AuthService.{Accounts, SessionManager, TokenCluster}
  
  import AuthService.Factory
  
  @tag timeout: 120_000  # 2 minutes
  @tag :stress
  test "concurrent login stress test" do
    IO.puts("\n🔥 Starting Concurrent Login Stress Test")
    
    # Create test users
    users = setup_stress_test_users(50)
    
    # Test parameters
    concurrent_requests = 500
    requests_per_user = 20
    
    IO.puts("Users: #{length(users)}")
    IO.puts("Concurrent requests: #{concurrent_requests}")
    IO.puts("Requests per batch: #{requests_per_user}")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Run concurrent login attempts
    tasks = for i <- 1..concurrent_requests do
      Task.async(fn ->
        user = Enum.random(users)
        results = for _j <- 1..requests_per_user do
          request_start = System.monotonic_time(:microsecond)
          
          result = case Accounts.authenticate_user(user.email, user.password) do
            {:ok, _user} -> :success
            {:error, _reason} -> :failure
          end
          
          request_end = System.monotonic_time(:microsecond)
          response_time = (request_end - request_start) / 1000  # ms
          
          {result, response_time}
        end
        
        {i, results}
      end)
    end
    
    # Collect results
    all_results = Task.await_many(tasks, 120_000)
    
    end_time = System.monotonic_time(:millisecond)
    total_duration = end_time - start_time
    
    # Analyze results
    {successful, failed, response_times} = analyze_stress_results(all_results)
    total_requests = successful + failed
    
    success_rate = (successful / total_requests) * 100
    avg_response_time = Enum.sum(response_times) / length(response_times)
    rps = total_requests / (total_duration / 1000)
    
    IO.puts("\n📊 STRESS TEST RESULTS:")
    IO.puts("Total Requests:      #{total_requests}")
    IO.puts("Successful:          #{successful}")
    IO.puts("Failed:              #{failed}")
    IO.puts("Success Rate:        #{Float.round(success_rate, 2)}%")
    IO.puts("Total Duration:      #{total_duration}ms")
    IO.puts("Average RPS:         #{Float.round(rps, 2)}")
    IO.puts("Avg Response Time:   #{Float.round(avg_response_time, 2)}ms")
    
    # Assertions
    assert success_rate >= 95.0, "Success rate #{success_rate}% is below 95%"
    assert avg_response_time <= 500, "Average response time #{avg_response_time}ms exceeds 500ms"
    assert rps >= 100, "RPS #{rps} is below minimum threshold of 100"
  end
  
  @tag timeout: 60_000
  @tag :stress
  test "memory pressure test" do
    IO.puts("\n🧠 Starting Memory Pressure Test")
    
    initial_memory = :erlang.memory(:total)
    IO.puts("Initial memory: #{Float.round(initial_memory / 1_000_000, 2)} MB")
    
    # Create many sessions to test memory usage
    session_count = 10_000
    users = setup_stress_test_users(100)
    
    IO.puts("Creating #{session_count} sessions...")
    
    sessions = for i <- 1..session_count do
      user = Enum.random(users)
      device_info = %{
        user_agent: "StressTest/#{i}",
        ip_address: "127.0.0.#{rem(i, 255)}"
      }
      
      case SessionManager.create_session(user.id, device_info) do
        {:ok, session, _state} -> session
        _ -> nil
      end
    end
    
    active_sessions = Enum.count(sessions, &(&1 != nil))
    
    peak_memory = :erlang.memory(:total)
    memory_increase = peak_memory - initial_memory
    
    IO.puts("Active sessions: #{active_sessions}")
    IO.puts("Peak memory: #{Float.round(peak_memory / 1_000_000, 2)} MB")
    IO.puts("Memory increase: #{Float.round(memory_increase / 1_000_000, 2)} MB")
    IO.puts("Memory per session: #{Float.round(memory_increase / active_sessions / 1000, 2)} KB")
    
    # Cleanup sessions
    for session <- sessions, session != nil do
      SessionManager.terminate_session(session.id)
    end
    
    # Force garbage collection
    :erlang.garbage_collect()
    :timer.sleep(1000)
    
    final_memory = :erlang.memory(:total)
    IO.puts("Final memory: #{Float.round(final_memory / 1_000_000, 2)} MB")
    
    # Assertions
    assert active_sessions >= session_count * 0.95, "Only created #{active_sessions} out of #{session_count} sessions"
    assert memory_increase / active_sessions <= 10_000, "Memory per session exceeds 10KB"  # Reasonable memory usage
  end
  
  @tag timeout: 60_000
  @tag :stress
  test "token cluster stress test" do
    IO.puts("\n🎫 Starting Token Cluster Stress Test")
    
    users = setup_stress_test_users(20)
    token_count = 1000
    
    IO.puts("Generating #{token_count} tokens...")
    
    # Generate many tokens
    tokens = for i <- 1..token_count do
      user = Enum.random(users)
      case AuthService.Guardian.encode_and_sign(user) do
        {:ok, token, _claims} -> {token, user}
        _ -> nil
      end
    end
    
    valid_tokens = Enum.filter(tokens, &(&1 != nil))
    
    IO.puts("Generated #{length(valid_tokens)} valid tokens")
    
    # Validate all tokens concurrently
    validation_start = System.monotonic_time(:millisecond)
    
    validation_tasks = for {token, _user} <- valid_tokens do
      Task.async(fn ->
        case AuthService.Guardian.resource_from_token(token) do
          {:ok, _user} -> :valid
          _ -> :invalid
        end
      end)
    end
    
    validation_results = Task.await_many(validation_tasks, 30_000)
    validation_end = System.monotonic_time(:millisecond)
    validation_duration = validation_end - validation_start
    
    valid_count = Enum.count(validation_results, &(&1 == :valid))
    invalid_count = Enum.count(validation_results, &(&1 == :invalid))
    
    validation_rps = length(valid_tokens) / (validation_duration / 1000)
    
    IO.puts("Valid tokens: #{valid_count}")
    IO.puts("Invalid tokens: #{invalid_count}")
    IO.puts("Validation time: #{validation_duration}ms")
    IO.puts("Validation RPS: #{Float.round(validation_rps, 2)}")
    
    # Test token blacklisting
    blacklist_count = min(100, length(valid_tokens))
    tokens_to_blacklist = Enum.take(valid_tokens, blacklist_count)
    
    IO.puts("Blacklisting #{blacklist_count} tokens...")
    
    for {token, _user} <- tokens_to_blacklist do
      TokenCluster.blacklist_token(token, "stress_test")
    end
    
    # Verify blacklisted tokens are invalid
    blacklist_validation_tasks = for {token, _user} <- tokens_to_blacklist do
      Task.async(fn ->
        case AuthService.Guardian.resource_from_token(token) do
          {:ok, _user} -> :still_valid  # Should be invalid
          _ -> :correctly_blacklisted
        end
      end)
    end
    
    blacklist_results = Task.await_many(blacklist_validation_tasks, 10_000)
    correctly_blacklisted = Enum.count(blacklist_results, &(&1 == :correctly_blacklisted))
    
    IO.puts("Correctly blacklisted: #{correctly_blacklisted}/#{blacklist_count}")
    
    # Assertions
    assert valid_count >= length(valid_tokens) * 0.95, "Token validation success rate too low"
    assert validation_rps >= 100, "Token validation RPS #{validation_rps} below threshold"
    assert correctly_blacklisted >= blacklist_count * 0.9, "Token blacklisting not working properly"
  end
  
  defp setup_stress_test_users(count) do
    for i <- 1..count do
      %{
        id: Ecto.UUID.generate(),
        email: "stress_user_#{i}@example.com",
        password: "stress_password_#{i}"
      }
    end
  end
  
  defp analyze_stress_results(all_results) do
    Enum.reduce(all_results, {0, 0, []}, fn {_worker_id, results}, {successful, failed, response_times} ->
      {batch_successful, batch_failed, batch_times} = 
        Enum.reduce(results, {0, 0, []}, fn {result, time}, {s, f, times} ->
          case result do
            :success -> {s + 1, f, [time | times]}
            :failure -> {s, f + 1, [time | times]}
          end
        end)
      
      {successful + batch_successful, failed + batch_failed, batch_times ++ response_times}
    end)
  end
end