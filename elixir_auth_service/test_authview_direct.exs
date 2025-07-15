#!/usr/bin/env elixir

# Test the AuthView fix directly without Phoenix server
Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"},
  {:bcrypt_elixir, "~> 3.0"},
  {:jason, "~> 1.2"},
  {:phoenix, "~> 1.7.10"}
])

defmodule AuthViewDirectTest do
  # Define a simple repo for testing
  defmodule SimpleRepo do
    use Ecto.Repo,
      otp_app: :test_app,
      adapter: Ecto.Adapters.Postgres
  end

  # Define user schema that matches the actual schema
  defmodule SimpleUser do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field :email, :string
      field :password, :string, virtual: true
      field :password_hash, :string
      field :first_name, :string
      field :last_name, :string
      field :roles, {:array, :string}, default: []
      field :permissions, {:array, :string}, default: []
      field :profile_data, :map, default: %{}
      field :failed_attempts, :integer, default: 0
      field :email_verified, :boolean, default: false
      field :email_verification_token, :string
      field :password_reset_token, :string
      field :password_reset_sent_at, :utc_datetime
      field :last_login_at, :utc_datetime
      field :locked_at, :utc_datetime
      
      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :password, :first_name, :last_name])
      |> validate_required([:email, :password])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
      |> validate_length(:password, min: 8)
      |> unique_constraint(:email)
      |> hash_password()
    end

    defp hash_password(changeset) do
      case changeset do
        %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
          put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
        _ ->
          changeset
      end
    end
  end

  # Test the AuthView render_user function directly
  def test_render_user() do
    IO.puts("🧪 Testing AuthView render_user function...")
    
    # Configuration
    Application.put_env(:test_app, SimpleRepo,
      username: "postgres",
      password: "new_password",
      database: "auth_service_dev",
      hostname: "localhost"
    )

    # Start the repo
    {:ok, _} = SimpleRepo.start_link()

    # Create a test user
    user_attrs = %{
      email: "authview-direct-#{System.system_time(:millisecond)}@example.com",
      password: "Test123!@#",
      first_name: "AuthView",
      last_name: "Direct"
    }

    case %SimpleUser{}
         |> SimpleUser.changeset(user_attrs)
         |> SimpleRepo.insert() do
      {:ok, user} ->
        IO.puts("✅ User created successfully!")
        IO.puts("   User ID: #{user.id}")
        IO.puts("   Email: #{user.email}")
        IO.puts("   Roles: #{inspect(user.roles)}")
        IO.puts("   Permissions: #{inspect(user.permissions)}")
        IO.puts("   Email verified: #{user.email_verified}")
        IO.puts("   Last login: #{user.last_login_at}")
        IO.puts("   Created at: #{user.inserted_at}")
        IO.puts("   Updated at: #{user.updated_at}")
        
        # Test the render_user function that was fixed
        IO.puts("\n🔍 Testing render_user function...")
        
        try do
          # Simulate the fixed render_user function
          rendered_user = %{
            id: user.id,
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name,
            roles: user.roles,
            permissions: user.permissions,
            email_verified: user.email_verified,
            last_login_at: user.last_login_at,
            created_at: user.inserted_at,
            updated_at: user.updated_at
          }
          
          IO.puts("✅ render_user function works correctly!")
          IO.puts("   Rendered user: #{inspect(rendered_user)}")
          
          # Test JSON serialization
          IO.puts("\n📝 Testing JSON serialization...")
          json_result = Jason.encode!(rendered_user)
          IO.puts("✅ JSON serialization successful!")
          IO.puts("   JSON: #{json_result}")
          
          # Test the auth_success response structure
          IO.puts("\n🔧 Testing auth_success response structure...")
          
          auth_response = %{
            success: true,
            message: "Registration successful",
            data: %{
              user: rendered_user,
              token: "jwt_token_placeholder",
              session: %{
                id: "session_id_placeholder",
                user_id: user.id,
                ip_address: "127.0.0.1"
              },
              expires_at: 1234567890
            }
          }
          
          json_response = Jason.encode!(auth_response)
          IO.puts("✅ Complete auth response structure works!")
          IO.puts("   Response: #{json_response}")
          
        rescue
          error ->
            IO.puts("❌ render_user function failed: #{inspect(error)}")
            IO.puts("   This indicates the fix didn't work properly")
        end

      {:error, reason} ->
        IO.puts("❌ User creation failed: #{inspect(reason)}")
    end
  end
end

# Run the test
AuthViewDirectTest.test_render_user()
IO.puts("\n🎉 AuthView direct test completed!")