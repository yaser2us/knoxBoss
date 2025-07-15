#!/usr/bin/env elixir

# Test the registration fix directly by calling the controller function
Mix.install([
  {:req, "~> 0.3.0"},
  {:jason, "~> 1.2"}
])

defmodule RegistrationTest do
  def test_registration_api do
    IO.puts("🧪 Testing Fixed Registration API...")
    
    # Test data
    registration_data = %{
      "user" => %{
        "email" => "fixtest@example.com",
        "password" => "Test123!@#",
        "first_name" => "Fix",
        "last_name" => "Test"
      }
    }
    
    # Wait a moment to ensure server is ready
    Process.sleep(1000)
    
    # Test registration
    IO.puts("📝 Sending registration request...")
    
    case Req.post("http://localhost:4000/api/auth/register", 
                  json: registration_data,
                  headers: [{"content-type", "application/json"}]) do
      {:ok, %{status: 201, body: body}} ->
        IO.puts("✅ Registration successful!")
        IO.puts("   Status: 201")
        IO.puts("   Response: #{inspect(body)}")
        
        # Now test login with the same credentials
        test_login(registration_data["user"]["email"], registration_data["user"]["password"])
        
      {:ok, %{status: status, body: body}} ->
        IO.puts("❌ Registration failed with status #{status}")
        IO.puts("   Response: #{inspect(body)}")
        
      {:error, %{reason: :econnrefused}} ->
        IO.puts("❌ Server not running. Please start with: mix phx.server")
        
      {:error, reason} ->
        IO.puts("❌ Registration request failed: #{inspect(reason)}")
    end
  end
  
  def test_login(email, password) do
    IO.puts("\n🔑 Testing Login with registered user...")
    
    login_data = %{
      "email" => email,
      "password" => password
    }
    
    case Req.post("http://localhost:4000/api/auth/login", 
                  json: login_data,
                  headers: [{"content-type", "application/json"}]) do
      {:ok, %{status: 200, body: body}} ->
        IO.puts("✅ Login successful!")
        IO.puts("   Status: 200")
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
RegistrationTest.test_registration_api()
IO.puts("\n🎉 Registration fix test completed!")