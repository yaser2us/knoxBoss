#!/usr/bin/env elixir

# Test to verify the AuthView fix works correctly
Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"},
  {:bcrypt_elixir, "~> 3.0"},
  {:jason, "~> 1.2"},
  {:req, "~> 0.3.0"}
])

defmodule AuthViewFixTest do
  def test_registration_with_response do
    IO.puts("🧪 Testing Registration with Full Response...")
    
    # Test data
    registration_data = %{
      "user" => %{
        "email" => "authview-#{System.system_time(:millisecond)}@example.com",
        "password" => "Test123!@#",
        "first_name" => "AuthView",
        "last_name" => "Fix"
      }
    }
    
    IO.puts("📝 Sending registration request...")
    
    # Test registration
    case Req.post("http://localhost:4000/api/auth/register", 
                  json: registration_data,
                  headers: [{"content-type", "application/json"}]) do
      {:ok, %{status: 201, body: body}} ->
        IO.puts("✅ Registration successful!")
        IO.puts("   Status: 201")
        IO.puts("   Response body: #{inspect(body)}")
        
        # Verify the response structure
        if is_map(body) and Map.has_key?(body, "user") do
          user = body["user"]
          IO.puts("\n🔍 Checking user response structure...")
          
          # Check for required fields
          required_fields = ["id", "email", "first_name", "last_name", "roles", "permissions", "email_verified"]
          missing_fields = required_fields
          |> Enum.reject(fn field -> Map.has_key?(user, field) end)
          
          if Enum.empty?(missing_fields) do
            IO.puts("✅ All required user fields present!")
            IO.puts("   - ID: #{user["id"]}")
            IO.puts("   - Email: #{user["email"]}")
            IO.puts("   - Name: #{user["first_name"]} #{user["last_name"]}")
            IO.puts("   - Roles: #{inspect(user["roles"])}")
            IO.puts("   - Permissions: #{inspect(user["permissions"])}")
            IO.puts("   - Email verified: #{user["email_verified"]}")
          else
            IO.puts("❌ Missing user fields: #{inspect(missing_fields)}")
          end
          
          # Check for other response fields
          if Map.has_key?(body, "token") do
            IO.puts("✅ Token present in response")
          else
            IO.puts("❌ Token missing from response")
          end
          
          if Map.has_key?(body, "session") do
            IO.puts("✅ Session present in response")
          else
            IO.puts("❌ Session missing from response")
          end
          
        else
          IO.puts("❌ User data not found in response")
        end
        
      {:ok, %{status: status, body: body}} ->
        IO.puts("❌ Registration failed with status #{status}")
        IO.puts("   Response: #{inspect(body)}")
        
      {:error, %{reason: :econnrefused}} ->
        IO.puts("❌ Server not running. Please start with: mix phx.server")
        
      {:error, reason} ->
        IO.puts("❌ Registration request failed: #{inspect(reason)}")
    end
  end
end

# Run the test
AuthViewFixTest.test_registration_with_response()
IO.puts("\n🎉 AuthView fix test completed!")