defmodule SimpleRegistrationTest do
  use ExUnit.Case
  
  alias AuthService.Accounts
  alias AuthService.Accounts.User
  
  describe "user registration" do
    test "creates user with valid data" do
      user_params = %{
        email: "test@example.com",
        password: "Test123!@#",
        first_name: "Test",
        last_name: "User"
      }
      
      {:ok, user} = Accounts.create_user(user_params)
      
      assert user.email == "test@example.com"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.password_hash
      assert Bcrypt.verify_pass("Test123!@#", user.password_hash)
      refute Bcrypt.verify_pass("wrongpassword", user.password_hash)
    end
    
    test "authenticates user with correct credentials" do
      user_params = %{
        email: "auth@example.com",
        password: "Test123!@#",
        first_name: "Auth",
        last_name: "User"
      }
      
      {:ok, _user} = Accounts.create_user(user_params)
      
      {:ok, authenticated_user} = Accounts.authenticate_user("auth@example.com", "Test123!@#")
      assert authenticated_user.email == "auth@example.com"
      
      {:error, :invalid_credentials} = Accounts.authenticate_user("auth@example.com", "wrongpassword")
    end
    
    test "user model schema works correctly" do
      user = %User{
        email: "schema@example.com",
        first_name: "Schema",
        last_name: "Test",
        roles: ["user"],
        permissions: ["read"],
        profile_data: %{theme: "dark"}
      }
      
      assert user.email == "schema@example.com"
      assert user.roles == ["user"]
      assert user.permissions == ["read"]
      assert user.profile_data == %{theme: "dark"}
    end
  end
end