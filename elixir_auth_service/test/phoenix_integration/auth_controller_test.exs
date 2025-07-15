defmodule AuthService.Phoenix.AuthControllerTest do
  use ExUnit.Case
  use Plug.Test
  
  alias AuthService.{Accounts, Router}
  
  import AuthService.Factory
  
  @opts Router.init([])
  
  describe "POST /api/v1/auth/login" do
    setup do
      user = insert(:user, email: "test@example.com", password: "password123")
      {:ok, user: user}
    end
    
    test "successfully logs in with valid credentials", %{user: _user} do
      conn = conn(:post, "/api/v1/auth/login", %{
        "email" => "test@example.com",
        "password" => "password123"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert Map.has_key?(response, "token")
      assert Map.has_key?(response, "user")
      assert response["user"]["email"] == "test@example.com"
    end
    
    test "rejects invalid credentials" do
      conn = conn(:post, "/api/v1/auth/login", %{
        "email" => "test@example.com",
        "password" => "wrongpassword"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 401
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"] == "Invalid Credentials"
    end
    
    test "rejects missing email" do
      conn = conn(:post, "/api/v1/auth/login", %{
        "password" => "password123"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 400
    end
    
    test "rejects missing password" do
      conn = conn(:post, "/api/v1/auth/login", %{
        "email" => "test@example.com"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 400
    end
    
    test "handles malformed JSON" do
      conn = conn(:post, "/api/v1/auth/login", "invalid json")
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 400
    end
  end
  
  describe "POST /api/v1/auth/register" do
    test "successfully registers new user" do
      conn = conn(:post, "/api/v1/auth/register", %{
        "email" => "newuser@example.com",
        "password" => "password123",
        "first_name" => "New",
        "last_name" => "User"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 201
      response = Jason.decode!(conn.resp_body)
      
      assert Map.has_key?(response, "user")
      assert response["user"]["email"] == "newuser@example.com"
    end
    
    test "rejects duplicate email" do
      insert(:user, email: "existing@example.com")
      
      conn = conn(:post, "/api/v1/auth/register", %{
        "email" => "existing@example.com",
        "password" => "password123",
        "first_name" => "New",
        "last_name" => "User"
      })
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 422
      response = Jason.decode!(conn.resp_body)
      
      assert response["error"] == "Validation Error"
    end
  end
  
  describe "POST /api/v1/auth/logout" do
    test "successfully logs out authenticated user" do
      user = insert(:user)
      {:ok, token, _claims} = AuthService.Guardian.encode_and_sign(user)
      
      conn = conn(:post, "/api/v1/auth/logout", %{})
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["message"] == "Successfully logged out"
    end
    
    test "rejects unauthenticated request" do
      conn = conn(:post, "/api/v1/auth/logout", %{})
      |> put_req_header("content-type", "application/json")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 401
    end
  end
  
  describe "GET /api/v1/auth/me" do
    test "returns current user info for authenticated user" do
      user = insert(:user)
      {:ok, token, _claims} = AuthService.Guardian.encode_and_sign(user)
      
      conn = conn(:get, "/api/v1/auth/me")
      |> put_req_header("authorization", "Bearer #{token}")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 200
      response = Jason.decode!(conn.resp_body)
      
      assert response["user"]["id"] == user.id
      assert response["user"]["email"] == user.email
    end
    
    test "rejects unauthenticated request" do
      conn = conn(:get, "/api/v1/auth/me")
      
      conn = Router.call(conn, @opts)
      
      assert conn.status == 401
    end
  end
end