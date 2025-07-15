#!/usr/bin/env elixir

defmodule BenchmarkRunner do
  @moduledoc """
  Script to run performance benchmarks for the AuthService.
  
  Usage:
    mix run test/performance/run_benchmarks.exs [test_type]
  
  Test types:
    - login_benchmark: 3M login requests in 3 minutes
    - stress: All stress tests
    - all: All performance tests
  """
  
  def run(args \\ []) do
    case args do
      [] -> run_all_benchmarks()
      ["login_benchmark"] -> run_login_benchmark()
      ["stress"] -> run_stress_tests()
      ["all"] -> run_all_benchmarks()
      _ -> print_usage()
    end
  end
  
  defp run_all_benchmarks do
    IO.puts("🚀 Running All Performance Benchmarks")
    IO.puts(String.duplicate("=", 60))
    
    # Pre-benchmark setup
    setup_environment()
    
    # Run benchmarks in order
    run_login_benchmark()
    IO.puts("\n" <> String.duplicate("-", 40) <> "\n")
    run_stress_tests()
    
    # Cleanup
    cleanup_environment()
    
    IO.puts("\n✅ All benchmarks completed!")
  end
  
  defp run_login_benchmark do
    IO.puts("🎯 Running Login Benchmark (3M requests in 3 minutes)")
    
    # Configure for high performance
    configure_for_benchmark()
    
    # Run the benchmark
    System.cmd("mix", ["test", "test/performance/login_benchmark_test.exs", "--only", "performance"], 
      into: IO.stream(:stdio, :line))
  end
  
  defp run_stress_tests do
    IO.puts("💪 Running Stress Tests")
    
    # Run all stress tests
    System.cmd("mix", ["test", "test/performance/stress_test.exs", "--only", "stress"], 
      into: IO.stream(:stdio, :line))
  end
  
  defp setup_environment do
    IO.puts("🔧 Setting up test environment...")
    
    # Start applications
    Application.ensure_all_started(:auth_service)
    
    # Clear any existing data
    AuthService.Repo.delete_all(AuthService.Accounts.User)
    
    # Optimize for performance
    configure_for_benchmark()
    
    IO.puts("✅ Environment ready")
  end
  
  defp configure_for_benchmark do
    # Set high connection pool
    Application.put_env(:auth_service, AuthService.Repo, [
      pool_size: 50,
      max_overflow: 100
    ])
    
    # Increase ETS limits
    :ets.new(:benchmark_cache, [:set, :public, :named_table])
    
    # Configure for high throughput
    Application.put_env(:auth_service, :rate_limit_max_requests, 10000)
    Application.put_env(:auth_service, :rate_limit_window, 1)
    
    # Disable some logging for performance
    Logger.configure(level: :warning)
    
    IO.puts("⚡ Optimized for high performance")
  end
  
  defp cleanup_environment do
    IO.puts("🧹 Cleaning up...")
    
    # Clear test data
    AuthService.Repo.delete_all(AuthService.Accounts.User)
    
    # Reset configurations
    Logger.configure(level: :info)
    
    IO.puts("✅ Cleanup complete")
  end
  
  defp print_usage do
    IO.puts("""
    Usage: mix run test/performance/run_benchmarks.exs [test_type]
    
    Test types:
      login_benchmark  - 3M login requests in 3 minutes
      stress          - All stress tests
      all             - All performance tests (default)
    
    Examples:
      mix run test/performance/run_benchmarks.exs
      mix run test/performance/run_benchmarks.exs login_benchmark
      mix run test/performance/run_benchmarks.exs stress
    """)
  end
end

# Run with command line arguments
BenchmarkRunner.run(System.argv())