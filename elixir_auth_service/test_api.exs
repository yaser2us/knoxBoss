#!/usr/bin/env elixir

Mix.install([
  {:req, "~> 0.3.0"},
  {:jason, "~> 1.2"}
])

# Test the API endpoints directly
defmodule APITest do
  def test_registration do
    IO.puts("🧪 Testing Registration API...")
    
    # Test data
    registration_data = %{
      "user" => %{
        "email" => "testapi@example.com",
        "password" => "Test123!@#",
        "first_name" => "API",
        "last_name" => "Test"
      }
    }
    
    # Start the server in the background
    server_task = Task.async(fn ->
      System.cmd("mix", ["phx.server"], env: [{"MIX_ENV", "dev"}])
    end)
    
    # Wait for server to start
    Process.sleep(5000)
    
    # Test registration
    case Req.post("http://localhost:4000/api/auth/register", json: registration_data) do
      {:ok, %{status: 201, body: body}} ->
        IO.puts("✅ Registration successful!")
        IO.puts("   Response: #{inspect(body)}")
        
        # Test login
        test_login(registration_data["user"]["email"], registration_data["user"]["password"])
        
      {:ok, %{status: status, body: body}} ->
        IO.puts("❌ Registration failed with status #{status}")
        IO.puts("   Response: #{inspect(body)}")
        
      {:error, reason} ->
        IO.puts("❌ Registration request failed: #{inspect(reason)}")
    end
    
    # Clean up
    Task.shutdown(server_task, :brutal_kill)
  end
  
  def test_login(email, password) do
    IO.puts("\n🔑 Testing Login API...")
    
    login_data = %{
      "email" => email,
      "password" => password
    }
    
    case Req.post("http://localhost:4000/api/auth/login", json: login_data) do
      {:ok, %{status: 200, body: body}} ->
        IO.puts("✅ Login successful!")
        IO.puts("   Response: #{inspect(body)}")
        
      {:ok, %{status: status, body: body}} ->
        IO.puts("❌ Login failed with status #{status}")
        IO.puts("   Response: #{inspect(body)}")
        
      {:error, reason} ->
        IO.puts("❌ Login request failed: #{inspect(reason)}")
    end
  end
end

# Run the test
APITest.test_registration()
IO.puts("\n🎉 API test completed!")