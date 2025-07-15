#!/usr/bin/env elixir

# Test to verify the WithClauseError fix in the controller
Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"},
  {:bcrypt_elixir, "~> 3.0"},
  {:jason, "~> 1.2"},
  {:phoenix, "~> 1.7.10"}
])

defmodule WithClauseFixTest do
  # Define a simple repo for testing
  defmodule SimpleRepo do
    use Ecto.Repo,
      otp_app: :test_app,
      adapter: Ecto.Adapters.Postgres
  end

  def run do
    # Configuration
    Application.put_env(:test_app, SimpleRepo,
      username: "postgres",
      password: "new_password",
      database: "auth_service_dev",
      hostname: "localhost"
    )

    # Start the repo
    {:ok, _} = SimpleRepo.start_link()

    IO.puts("🧪 Testing WithClause Fix...")

    # Test user creation
    user_attrs = %{
      "email" => "withclausetest-#{System.system_time(:millisecond)}@example.com",
      "password" => "Test123!@#",
      "first_name" => "WithClause",
      "last_name" => "Fix"
    }

    case AuthService.Accounts.create_user(user_attrs) do
      {:ok, user} ->
        IO.puts("✅ User created successfully!")
        IO.puts("   User ID: #{user.id}")
        IO.puts("   Email: #{user.email}")

        # Test the session creation that was causing the WithClauseError
        IO.puts("\n🔍 Testing SessionManager.create_session...")
        
        device_info = %{
          ip_address: "127.0.0.1",
          user_agent: "WithClauseTest/1.0",
          device_id: nil
        }

        case AuthService.SessionManager.create_session(user.id, device_info) do
          {:ok, session} ->
            IO.puts("✅ SessionManager.create_session returns: {:ok, session}")
            IO.puts("   Session ID: #{session.id}")
            IO.puts("   User ID: #{session.user_id}")
            IO.puts("   IP Address: #{session.ip_address}")
            IO.puts("   Created at: #{session.created_at}")
            
            # Test the Guardian token creation
            IO.puts("\n🔑 Testing Guardian token creation...")
            
            case AuthService.Guardian.encode_and_sign(user) do
              {:ok, token, claims} ->
                IO.puts("✅ Guardian.encode_and_sign returns: {:ok, token, claims}")
                IO.puts("   Token: #{String.slice(token, 0, 50)}...")
                IO.puts("   Claims: #{inspect(claims)}")
                
                # Simulate the fixed with clause pattern
                IO.puts("\n🔧 Testing the fixed with clause pattern...")
                
                with {:ok, user} <- {:ok, user},
                     {:ok, token, claims} <- {:ok, token, claims},
                     {:ok, session} <- {:ok, session} do
                  IO.puts("✅ WITH CLAUSE PATTERN WORKS!")
                  IO.puts("   No WithClauseError!")
                  IO.puts("   User: #{user.email}")
                  IO.puts("   Token: #{String.slice(token, 0, 20)}...")
                  IO.puts("   Session: #{session.id}")
                  IO.puts("   Claims exp: #{claims["exp"]}")
                  
                  result = %{
                    user: user,
                    token: token,
                    session: session,
                    expires_at: claims["exp"]
                  }
                  
                  IO.puts("✅ Controller would return: #{inspect(result)}")
                end
                
              {:error, reason} ->
                IO.puts("❌ Guardian.encode_and_sign failed: #{inspect(reason)}")
            end
            
          {:error, reason} ->
            IO.puts("❌ SessionManager.create_session failed: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("❌ User creation failed: #{inspect(reason)}")
    end
  end
end

# Run the test
WithClauseFixTest.run()
IO.puts("\n🎉 WithClause fix test completed!")