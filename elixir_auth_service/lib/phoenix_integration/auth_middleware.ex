defmodule AuthService.Phoenix.AuthMiddleware do
  @moduledoc """
  Phoenix middleware for authentication and authorization.
  
  This middleware provides:
  - JWT token validation
  - Session management
  - Rate limiting
  - CORS handling
  - Request logging
  - Security headers
  """
  
  import Plug.Conn
  require Logger
  
  alias AuthService.{Guardian, SessionManager, TokenCluster}
  
  @behaviour Plug
  
  defmacro __using__(opts) do
    quote do
      import Plug.Conn
      require Logger
      
      alias AuthService.{Guardian, SessionManager, TokenCluster}
      
      @behaviour Plug
      
      # Default init function that can be overridden
      def init(opts) do
        opts
        |> Keyword.put_new(:enabled, true)
        |> Keyword.put_new(:required, false)
        |> Keyword.put_new(:check_session, true)
        |> Keyword.put_new(:rate_limit, true)
        |> Keyword.put_new(:cors, true)
        |> Keyword.put_new(:security_headers, true)
      end
      
      # Import all functions from the main middleware module
      import AuthService.Phoenix.AuthMiddleware
      
      defoverridable init: 1
    end
  end
  
  def init(opts) do
    opts
    |> Keyword.put_new(:enabled, true)
    |> Keyword.put_new(:required, false)
    |> Keyword.put_new(:check_session, true)
    |> Keyword.put_new(:rate_limit, true)
    |> Keyword.put_new(:cors, true)
    |> Keyword.put_new(:security_headers, true)
  end
  
  def call(conn, opts) do
    if opts[:enabled] do
      conn
      |> maybe_add_cors_headers(opts)
      |> maybe_add_security_headers(opts)
      |> maybe_check_rate_limit(opts)
      |> maybe_authenticate(opts)
      |> maybe_validate_session(opts)
      |> log_request()
    else
      conn
    end
  end
  
  # CORS Headers
  defp maybe_add_cors_headers(conn, opts) do
    if opts[:cors] do
      conn
      |> put_resp_header("access-control-allow-origin", get_allowed_origins())
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "authorization, content-type, x-session-id, x-device-id")
      |> put_resp_header("access-control-expose-headers", "authorization, x-session-id")
      |> put_resp_header("access-control-max-age", "86400")
    else
      conn
    end
  end
  
  # Security Headers
  defp maybe_add_security_headers(conn, opts) do
    if opts[:security_headers] do
      conn
      |> put_resp_header("x-frame-options", "DENY")
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("x-xss-protection", "1; mode=block")
      |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
      |> put_resp_header("content-security-policy", "default-src 'self'")
      |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    else
      conn
    end
  end
  
  # Rate Limiting
  defp maybe_check_rate_limit(conn, opts) do
    if opts[:rate_limit] do
      case check_rate_limit(conn) do
        :ok ->
          conn
        
        {:error, :rate_limited} ->
          conn
          |> put_status(:too_many_requests)
          |> put_resp_header("retry-after", "60")
          |> Phoenix.Controller.json(%{error: "Rate limit exceeded"})
          |> halt()
      end
    else
      conn
    end
  end
  
  # Authentication
  defp maybe_authenticate(conn, opts) do
    case get_token_from_conn(conn) do
      {:ok, token} ->
        case Guardian.validate_token(token, get_token_opts(conn)) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} ->
                conn
                |> assign(:current_user, user)
                |> assign(:current_token, token)
                |> assign(:token_claims, claims)
              
              {:error, reason} ->
                handle_auth_error(conn, reason, opts)
            end
          
          {:error, reason} ->
            handle_auth_error(conn, reason, opts)
        end
      
      {:error, :no_token} ->
        if opts[:required] do
          handle_auth_error(conn, :no_token, opts)
        else
          conn
        end
      
      {:error, reason} ->
        handle_auth_error(conn, reason, opts)
    end
  end
  
  # Session Validation
  defp maybe_validate_session(conn, opts) do
    if opts[:check_session] && conn.assigns[:current_user] do
      case get_session_id_from_conn(conn) do
        {:ok, session_id} ->
          case SessionManager.is_session_valid?(session_id) do
            true ->
              # Update session activity
              SessionManager.update_activity(session_id)
              assign(conn, :current_session_id, session_id)
            
            false ->
              handle_auth_error(conn, :invalid_session, opts)
          end
        
        {:error, :no_session} ->
          # Session not required for token-only auth
          conn
        
        {:error, reason} ->
          handle_auth_error(conn, reason, opts)
      end
    else
      conn
    end
  end
  
  # Request Logging
  defp log_request(conn) do
    user_id = get_in(conn.assigns, [:current_user, :id])
    session_id = conn.assigns[:current_session_id]
    
    Logger.info("Request processed", %{
      method: conn.method,
      path: conn.request_path,
      user_id: user_id,
      session_id: session_id,
      ip: get_client_ip(conn),
      user_agent: get_user_agent(conn),
      status: conn.status || 200
    })
    
    conn
  end
  
  # Helper Functions
  
  defp get_token_from_conn(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        {:ok, token}
      
      [token] ->
        {:ok, token}
      
      [] ->
        # Try to get from query params
        case conn.query_params["token"] do
          nil -> {:error, :no_token}
          token -> {:ok, token}
        end
    end
  end
  
  defp get_session_id_from_conn(conn) do
    case get_req_header(conn, "x-session-id") do
      [session_id] ->
        {:ok, session_id}
      
      [] ->
        # Try to get from query params
        case conn.query_params["session_id"] do
          nil -> {:error, :no_session}
          session_id -> {:ok, session_id}
        end
    end
  end
  
  defp handle_auth_error(conn, reason, opts) do
    if opts[:required] do
      error_message = case reason do
        :no_token -> "Authentication required"
        :invalid_token -> "Invalid token"
        :token_expired -> "Token expired"
        :token_blacklisted -> "Token revoked"
        :invalid_session -> "Session invalid"
        :resource_not_found -> "User not found"
        _ -> "Authentication failed"
      end
      
      Logger.warn("Authentication failed", %{
        reason: reason,
        ip: get_client_ip(conn),
        path: conn.request_path
      })
      
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{error: error_message})
      |> halt()
    else
      conn
    end
  end
  
  defp check_rate_limit(conn) do
    client_ip = get_client_ip(conn)
    cache_key = "rate_limit:#{client_ip}"
    
    case Cachex.get(:auth_cache, cache_key) do
      {:ok, nil} ->
        Cachex.put(:auth_cache, cache_key, 1, ttl: :timer.minutes(1))
        :ok
      
      {:ok, requests} when requests < 100 ->
        Cachex.put(:auth_cache, cache_key, requests + 1, ttl: :timer.minutes(1))
        :ok
      
      {:ok, _} ->
        {:error, :rate_limited}
    end
  end
  
  defp get_token_opts(conn) do
    [
      client_ip: get_client_ip(conn),
      user_agent: get_user_agent(conn),
      device_id: get_device_id(conn)
    ]
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
  
  defp get_allowed_origins do
    Application.get_env(:auth_service, :cors_origins, "*")
  end
end

# Convenience modules for different auth requirements

defmodule AuthService.Phoenix.RequireAuth do
  @moduledoc """
  Middleware that requires authentication.
  """
  
  use AuthService.Phoenix.AuthMiddleware
  
  def init(opts) do
    opts
    |> Keyword.put(:required, true)
  end
  
  def call(conn, opts) do
    AuthService.Phoenix.AuthMiddleware.call(conn, opts)
  end
end

defmodule AuthService.Phoenix.OptionalAuth do
  @moduledoc """
  Middleware that allows optional authentication.
  """
  
  use AuthService.Phoenix.AuthMiddleware
  
  def init(opts) do
    opts
    |> Keyword.put(:required, false)
  end
  
  def call(conn, opts) do
    AuthService.Phoenix.AuthMiddleware.call(conn, opts)
  end
end

defmodule AuthService.Phoenix.ApiAuth do
  @moduledoc """
  Middleware for API authentication (no session required).
  """
  
  use AuthService.Phoenix.AuthMiddleware
  
  def init(opts) do
    opts
    |> Keyword.put(:required, true)
    |> Keyword.put(:check_session, false)
  end
  
  def call(conn, opts) do
    AuthService.Phoenix.AuthMiddleware.call(conn, opts)
  end
end