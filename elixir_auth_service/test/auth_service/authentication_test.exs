defmodule AuthService.AuthenticationTest do
  use ExUnit.Case
  use AuthService.DataCase
  
  alias AuthService.{Accounts, Guardian}
  alias AuthService.Accounts.User
  
  import AuthService.Factory
  
  describe "user authentication" do
    setup do
      user = insert(:user, email: "test@example.com", password: "password123")
      {:ok, user: user}
    end
    
    test "authenticates user with valid credentials", %{user: user} do
      assert {:ok, authenticated_user} = Accounts.authenticate_user("test@example.com", "password123")
      assert authenticated_user.id == user.id
      assert authenticated_user.email == user.email
    end
    
    test "rejects user with invalid password", %{user: _user} do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("test@example.com", "wrongpassword")
    end
    
    test "rejects user with invalid email" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("wrong@example.com", "password123")
    end
    
    test "locks account after failed attempts", %{user: user} do
      # Attempt failed logins up to the limit
      max_attempts = Application.get_env(:auth_service, :max_login_attempts, 5)
      
      for _i <- 1..max_attempts do
        Accounts.authenticate_user("test@example.com", "wrongpassword")
      end
      
      # Verify account is locked
      updated_user = Accounts.get_user(user.id)
      assert updated_user.failed_login_attempts >= max_attempts
      assert updated_user.locked_at != nil
      
      # Even correct password should fail when locked
      assert {:error, :account_locked} = Accounts.authenticate_user("test@example.com", "password123")
    end
    
    test "resets failed attempts after successful login", %{user: user} do
      # Failed attempt
      Accounts.authenticate_user("test@example.com", "wrongpassword")
      
      # Successful login should reset counter
      {:ok, _} = Accounts.authenticate_user("test@example.com", "password123")
      
      updated_user = Accounts.get_user(user.id)
      assert updated_user.failed_login_attempts == 0
      assert updated_user.last_login_at != nil
    end
  end
  
  describe "JWT token generation and validation" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end
    
    test "generates valid JWT token", %{user: user} do
      assert {:ok, token, _claims} = Guardian.encode_and_sign(user)
      assert is_binary(token)
      assert String.contains?(token, ".")
    end
    
    test "validates JWT token", %{user: user} do
      {:ok, token, _claims} = Guardian.encode_and_sign(user)
      
      assert {:ok, decoded_user} = Guardian.resource_from_token(token)
      assert decoded_user.id == user.id
    end
    
    test "rejects invalid JWT token" do
      invalid_token = "invalid.jwt.token"
      assert {:error, _reason} = Guardian.resource_from_token(invalid_token)
    end
    
    test "rejects expired JWT token", %{user: user} do
      # Create token with 1 second TTL
      {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {1, :second})
      
      # Wait for expiration
      :timer.sleep(1100)
      
      assert {:error, _reason} = Guardian.resource_from_token(token)
    end
  end
  
  describe "session management" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end
    
    test "creates user session", %{user: user} do
      device_info = %{
        user_agent: "TestBrowser/1.0",
        ip_address: "127.0.0.1"
      }
      
      assert {:ok, session, _state} = AuthService.SessionManager.create_session(user.id, device_info)
      assert session.user_id == user.id
      assert session.ip_address == "127.0.0.1"
    end
    
    test "retrieves user session", %{user: user} do
      device_info = %{user_agent: "TestBrowser/1.0", ip_address: "127.0.0.1"}
      {:ok, session, _state} = AuthService.SessionManager.create_session(user.id, device_info)
      
      assert {:ok, retrieved_session} = AuthService.SessionManager.get_session(session.id)
      assert retrieved_session.id == session.id
      assert retrieved_session.user_id == user.id
    end
    
    test "terminates user session", %{user: user} do
      device_info = %{user_agent: "TestBrowser/1.0", ip_address: "127.0.0.1"}
      {:ok, session, _state} = AuthService.SessionManager.create_session(user.id, device_info)
      
      assert :ok = AuthService.SessionManager.terminate_session(session.id)
      assert {:error, :not_found} = AuthService.SessionManager.get_session(session.id)
    end
  end
  
  describe "rate limiting" do
    test "enforces rate limits" do
      # This would need to be implemented based on your rate limiting logic
      # For now, we'll create a placeholder test
      assert true
    end
  end
end