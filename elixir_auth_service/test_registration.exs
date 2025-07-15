#!/usr/bin/env elixir

# Simple script to test user registration and authentication without HTTP
Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"},
  {:bcrypt_elixir, "~> 3.0"},
  {:jason, "~> 1.2"}
])

defmodule TestRunner do
  # Define a simple user schema
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

  # Define a simple repo
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

    # Test user creation
    IO.puts("🧪 Testing User Registration...")

    user_attrs = %{
      email: "test-#{System.system_time(:millisecond)}@example.com",
      password: "Test123!@#",
      first_name: "Test",
      last_name: "User"
    }

    case %SimpleUser{}
         |> SimpleUser.changeset(user_attrs)
         |> SimpleRepo.insert() do
      {:ok, user} ->
        IO.puts("✅ User created successfully!")
        IO.puts("   - ID: #{user.id}")
        IO.puts("   - Email: #{user.email}")
        IO.puts("   - Name: #{user.first_name} #{user.last_name}")
        IO.puts("   - Password hash: #{String.slice(user.password_hash, 0, 20)}...")
        
        # Test password verification
        IO.puts("\n🔑 Testing Password Verification...")
        if Bcrypt.verify_pass("Test123!@#", user.password_hash) do
          IO.puts("✅ Password verification successful!")
        else
          IO.puts("❌ Password verification failed!")
        end
        
        # Test wrong password
        if Bcrypt.verify_pass("wrongpassword", user.password_hash) do
          IO.puts("❌ Wrong password incorrectly verified!")
        else
          IO.puts("✅ Wrong password correctly rejected!")
        end
        
      {:error, %Ecto.Changeset{} = changeset} ->
        IO.puts("❌ User creation failed:")
        Enum.each(changeset.errors, fn {field, {message, _opts}} ->
          IO.puts("   - #{field}: #{message}")
        end)
        
      {:error, reason} ->
        IO.puts("❌ Database error: #{inspect(reason)}")
    end

    IO.puts("\n🎉 Authentication system test completed!")
  end
end

# Run the test
TestRunner.run()