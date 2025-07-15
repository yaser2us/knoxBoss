defmodule AuthService.Phoenix.AuthController do
  @moduledoc """
  Phoenix controller for authentication endpoints.
  
  This controller provides:
  - User registration and login
  - Token generation and validation
  - Session management
  - Password reset functionality
  - Multi-factor authentication
  """
  
  use Phoenix.Controller, namespace: AuthService.Phoenix
  
  alias AuthService.{Accounts, TokenCluster, SessionManager, Guardian}
  alias AuthService.Phoenix.{AuthView, ErrorView}
  
  import Plug.Conn
  require Logger
  
  action_fallback AuthService.Phoenix.FallbackController
  
  @doc """
  User registration with secure password hashing.
  """
  def register(conn, params) do
    user_params = case params do
      %{"user" => user_data} -> user_data
      %{"email" => _email} = direct_params -> direct_params
      _ -> params
    end
    with {:ok, user} <- Accounts.create_user(user_params),
         {:ok, token, claims} <- Guardian.encode_and_sign(user),
         {:ok, session} <- SessionManager.create_session(user.id, get_device_info(conn)) do
      
      Logger.info("User registered successfully", %{
        user_id: user.id,
        email: user.email,
        node: Node.self()
      })
      
      conn
      |> put_status(:created)
      |> put_view(AuthView)
      |> render("auth_success.json", %{
        user: user,
        token: token,
        session: session,
        expires_at: claims["exp"]
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("error.json", changeset: changeset)
      
      {:error, reason} ->
        Logger.error("Registration failed: #{inspect(reason)}")
        
        conn
        |> put_status(:bad_request)
        |> put_view(ErrorView)
        |> render("error.json", message: "Registration failed")
    end
  end
  
  @doc """
  User login with rate limiting and security checks.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    # Rate limiting check
    client_ip = get_client_ip(conn)
    
    case check_rate_limit(client_ip, "login") do
      :ok ->
        perform_login(conn, email, password)
      
      {:error, :rate_limited} ->
        conn
        |> put_status(:too_many_requests)
        |> put_view(ErrorView)
        |> render("error.json", message: "Too many login attempts")
    end
  end
  
  @doc """
  Token validation endpoint.
  """
  def validate_token(conn, %{"token" => token}) do
    case Guardian.validate_token(token, get_token_opts(conn)) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            conn
            |> put_view(AuthView)
            |> render("token_valid.json", %{
              user: user,
              claims: claims,
              valid: true
            })
          
          {:error, _} ->
            conn
            |> put_status(:unauthorized)
            |> put_view(ErrorView)
            |> render("error.json", message: "Invalid token")
        end
      
      {:error, reason} ->
        Logger.warn("Token validation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("error.json", message: "Invalid or expired token")
    end
  end
  
  @doc """
  Token refresh endpoint.
  """
  def refresh_token(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.refresh_token(refresh_token, get_token_opts(conn)) do
      {:ok, new_token, new_claims} ->
        conn
        |> put_view(AuthView)
        |> render("token_refresh.json", %{
          token: new_token,
          expires_at: new_claims["exp"]
        })
      
      {:error, reason} ->
        Logger.warn("Token refresh failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("error.json", message: "Invalid refresh token")
    end
  end
  
  @doc """
  User logout - invalidates token and session.
  """
  def logout(conn, _params) do
    with {:ok, token, _claims} <- Guardian.Plug.current_token(conn),
         :ok <- TokenCluster.blacklist_token(token, "user_logout"),
         session_id <- get_session_id(conn),
         :ok <- SessionManager.terminate_session(session_id) do
      
      conn
      |> put_view(AuthView)
      |> render("logout_success.json", %{message: "Logged out successfully"})
    else
      {:error, reason} ->
        Logger.error("Logout failed: #{inspect(reason)}")
        
        conn
        |> put_status(:bad_request)
        |> put_view(ErrorView)
        |> render("error.json", message: "Logout failed")
    end
  end
  
  @doc """
  Revoke all user tokens (useful for password changes).
  """
  def revoke_all_tokens(conn, _params) do
    with {:ok, _token, claims} <- Guardian.Plug.current_token(conn),
         user_id <- claims["user_id"],
         :ok <- TokenCluster.revoke_user_tokens(user_id),
         :ok <- SessionManager.terminate_user_sessions(user_id) do
      
      conn
      |> put_view(AuthView)
      |> render("revoke_success.json", %{message: "All tokens revoked successfully"})
    else
      {:error, reason} ->
        Logger.error("Token revocation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:bad_request)
        |> put_view(ErrorView)
        |> render("error.json", message: "Token revocation failed")
    end
  end
  
  @doc """
  Get current user information.
  """
  def me(conn, _params) do
    with {:ok, user} <- Guardian.Plug.current_resource(conn),
         {:ok, session_analytics} <- SessionManager.get_session_analytics(user.id) do
      
      conn
      |> put_view(AuthView)
      |> render("user_info.json", %{
        user: user,
        session_analytics: session_analytics
      })
    else
      {:error, reason} ->
        Logger.error("Get user info failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("error.json", message: "Unauthorized")
    end
  end
  
  @doc """
  Get user's active sessions.
  """
  def sessions(conn, _params) do
    with {:ok, user} <- Guardian.Plug.current_resource(conn),
         sessions <- SessionManager.get_user_sessions(user.id) do
      
      conn
      |> put_view(AuthView)
      |> render("sessions.json", %{sessions: sessions})
    else
      {:error, reason} ->
        Logger.error("Get sessions failed: #{inspect(reason)}")
        
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("error.json", message: "Unauthorized")
    end
  end
  
  @doc """
  Terminate a specific session.
  """
  def terminate_session(conn, %{"session_id" => session_id}) do
    with {:ok, user} <- Guardian.Plug.current_resource(conn),
         :ok <- verify_session_ownership(user.id, session_id),
         :ok <- SessionManager.terminate_session(session_id) do
      
      conn
      |> put_view(AuthView)
      |> render("session_terminated.json", %{
        message: "Session terminated successfully"
      })
    else
      {:error, :not_authorized} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("error.json", message: "Not authorized to terminate this session")
      
      {:error, reason} ->
        Logger.error("Session termination failed: #{inspect(reason)}")
        
        conn
        |> put_status(:bad_request)
        |> put_view(ErrorView)
        |> render("error.json", message: "Session termination failed")
    end
  end
  
  @doc """
  Generate API key for service-to-service communication.
  """
  def generate_api_key(conn, %{"service_name" => service_name, "permissions" => permissions}) do
    with {:ok, user} <- Guardian.Plug.current_resource(conn),
         true <- has_admin_permission?(user),
         {:ok, api_key, claims} <- Guardian.generate_api_key(service_name, permissions) do
      
      Logger.info("API key generated", %{
        service_name: service_name,
        permissions: permissions,
        admin_user: user.id
      })
      
      conn
      |> put_view(AuthView)
      |> render("api_key.json", %{
        api_key: api_key,
        service_name: service_name,
        permissions: permissions,
        expires_at: claims["exp"]
      })
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("error.json", message: "Admin permission required")
      
      {:error, reason} ->
        Logger.error("API key generation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:bad_request)
        |> put_view(ErrorView)
        |> render("error.json", message: "API key generation failed")
    end
  end
  
  # Private Functions
  
  defp perform_login(conn, email, password) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        with {:ok, token, claims} <- Guardian.create_token(user, %{}, get_token_opts(conn)),
             {:ok, session} <- SessionManager.create_session(user.id, get_device_info(conn)) do
          
          Logger.info("User logged in successfully", %{
            user_id: user.id,
            email: user.email,
            ip: get_client_ip(conn)
          })
          
          conn
          |> put_view(AuthView)
          |> render("auth_success.json", %{
            user: user,
            token: token,
            session: session,
            expires_at: claims["exp"]
          })
        else
          {:error, reason} ->
            Logger.error("Login session creation failed: #{inspect(reason)}")
            
            conn
            |> put_status(:internal_server_error)
            |> put_view(ErrorView)
            |> render("error.json", message: "Login failed")
        end
      
      {:error, :invalid_credentials} ->
        increment_failed_attempts(get_client_ip(conn))
        
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("error.json", message: "Invalid credentials")
      
      {:error, :account_locked} ->
        conn
        |> put_status(:locked)
        |> put_view(ErrorView)
        |> render("error.json", message: "Account locked")
    end
  end
  
  defp get_token_opts(conn) do
    [
      client_ip: get_client_ip(conn),
      user_agent: get_user_agent(conn),
      device_id: get_device_id(conn)
    ]
  end
  
  defp get_device_info(conn) do
    %{
      ip_address: get_client_ip(conn),
      user_agent: get_user_agent(conn),
      device_id: get_device_id(conn)
    }
  end
  
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end
  
  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> "unknown"
    end
  end
  
  defp get_device_id(conn) do
    case get_req_header(conn, "x-device-id") do
      [device_id | _] -> device_id
      [] -> nil
    end
  end
  
  defp get_session_id(conn) do
    case get_req_header(conn, "x-session-id") do
      [session_id | _] -> session_id
      [] -> nil
    end
  end
  
  defp check_rate_limit(client_ip, action) do
    cache_key = "rate_limit:#{action}:#{client_ip}"
    
    case Cachex.get(:auth_cache, cache_key) do
      {:ok, nil} ->
        Cachex.put(:auth_cache, cache_key, 1, ttl: :timer.minutes(15))
        :ok
      
      {:ok, attempts} when attempts < 5 ->
        Cachex.put(:auth_cache, cache_key, attempts + 1, ttl: :timer.minutes(15))
        :ok
      
      {:ok, _} ->
        {:error, :rate_limited}
    end
  end
  
  defp increment_failed_attempts(client_ip) do
    cache_key = "failed_attempts:#{client_ip}"
    
    case Cachex.get(:auth_cache, cache_key) do
      {:ok, nil} ->
        Cachex.put(:auth_cache, cache_key, 1, ttl: :timer.minutes(15))
      
      {:ok, attempts} ->
        Cachex.put(:auth_cache, cache_key, attempts + 1, ttl: :timer.minutes(15))
    end
  end
  
  defp verify_session_ownership(user_id, session_id) do
    case SessionManager.get_session(session_id) do
      {:ok, session} ->
        if session.user_id == user_id do
          :ok
        else
          {:error, :not_authorized}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp has_admin_permission?(user) do
    "admin" in (user.roles || [])
  end
end