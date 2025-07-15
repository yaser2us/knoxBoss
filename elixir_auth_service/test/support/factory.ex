defmodule AuthService.Factory do
  @moduledoc """
  Factory for generating test data using ExMachina.
  """
  
  use ExMachina.Ecto, repo: AuthService.Repo
  
  alias AuthService.Accounts.User
  
  def user_factory do
    %User{
      id: Ecto.UUID.generate(),
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      first_name: "Test",
      last_name: "User",
      role: "user",
      is_active: true,
      email_verified: true,
      email_verified_at: DateTime.utc_now(),
      failed_login_attempts: 0,
      locked_at: nil,
      last_login_at: nil,
      last_login_ip: nil,
      api_key: nil,
      api_key_created_at: nil,
      password_reset_token: nil,
      password_reset_expires_at: nil,
      email_verification_token: nil,
      email_verification_expires_at: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
  
  def admin_user_factory do
    struct!(
      user_factory(),
      %{
        role: "admin",
        email: sequence(:admin_email, &"admin#{&1}@example.com")
      }
    )
  end
  
  def locked_user_factory do
    struct!(
      user_factory(),
      %{
        failed_login_attempts: 5,
        locked_at: DateTime.utc_now(),
        is_active: false
      }
    )
  end
  
  def user_with_api_key_factory do
    api_key = :crypto.strong_rand_bytes(32) |> Base.encode64()
    
    struct!(
      user_factory(),
      %{
        api_key: api_key,
        api_key_created_at: DateTime.utc_now()
      }
    )
  end
  
  def session_factory do
    %{
      id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      device_id: Ecto.UUID.generate(),
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
      metadata: %{}
    }
  end
end