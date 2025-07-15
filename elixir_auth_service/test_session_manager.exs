#!/usr/bin/env elixir

# Test the SessionManager.create_session return format
Mix.Task.run("app.start")

defmodule SessionManagerTest do
  def test_create_session_return_format do
    IO.puts("🧪 Testing SessionManager.create_session return format...")
    
    # Create a test user first
    user_attrs = %{
      "email" => "sessiontest@example.com",
      "password" => "Test123!@#", 
      "first_name" => "Session",
      "last_name" => "Test"
    }
    
    case AuthService.Accounts.create_user(user_attrs) do
      {:ok, user} ->
        IO.puts("✅ User created successfully")
        IO.puts("   User ID: #{user.id}")
        
        # Test create_session format
        device_info = %{
          ip_address: "127.0.0.1",
          user_agent: "test_agent",
          device_id: nil
        }
        
        IO.puts("\n🔍 Testing SessionManager.create_session...")
        
        case AuthService.SessionManager.create_session(user.id, device_info) do
          {:ok, session} ->
            IO.puts("✅ SessionManager.create_session returns: {:ok, session}")
            IO.puts("   Session ID: #{session.id}")
            IO.puts("   User ID: #{session.user_id}")
            IO.puts("   IP Address: #{session.ip_address}")
            IO.puts("   User Agent: #{session.user_agent}")
            IO.puts("   Created at: #{session.created_at}")
            IO.puts("   Expires at: #{session.expires_at}")
            
            # This is the correct format for the controller
            IO.puts("\n✅ Controller should expect: {:ok, session}")
            
          {:ok, session, state} ->
            IO.puts("❌ SessionManager.create_session returns: {:ok, session, state}")
            IO.puts("   This would cause the WithClauseError!")
            
          {:error, reason} ->
            IO.puts("❌ SessionManager.create_session failed: #{inspect(reason)}")
            
          other ->
            IO.puts("❌ SessionManager.create_session returned unexpected: #{inspect(other)}")
        end
        
      {:error, reason} ->
        IO.puts("❌ User creation failed: #{inspect(reason)}")
    end
  end
end

# Run the test
SessionManagerTest.test_create_session_return_format()
IO.puts("\n🎉 SessionManager test completed!")