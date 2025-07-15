defmodule AuthService.Router do
  @moduledoc """
  Phoenix router for the AuthService application.
  
  This router defines all HTTP routes for the authentication service,
  including API endpoints and health checks.
  """
  
  use Phoenix.Router
  
  import Plug.Conn
  import Phoenix.Controller
  
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_security_headers
    plug :fetch_session
  end
  
  pipeline :authenticated do
    plug AuthService.Phoenix.RequireAuth
  end
  
  pipeline :admin do
    plug AuthService.Phoenix.RequireAuth
    plug :require_admin_role
  end
  
  # Public health check endpoint
  get "/health", AuthService.HealthController, :check
  
  # Authentication API routes (backward compatibility)
  scope "/api", AuthService.Phoenix do
    pipe_through :api
    
    # Authentication endpoints
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh_token
    post "/auth/logout", AuthController, :logout
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
    post "/auth/verify-email", AuthController, :verify_email
    post "/auth/resend-verification", AuthController, :resend_verification
    post "/auth/validate", AuthController, :validate_token
    
    # Authenticated routes
    scope "/auth" do
      pipe_through :authenticated
      
      get "/me", AuthController, :current_user
      put "/me", AuthController, :update_profile
      post "/change-password", AuthController, :change_password
      get "/sessions", AuthController, :list_sessions
      delete "/sessions/:session_id", AuthController, :terminate_session
      delete "/sessions", AuthController, :terminate_all_sessions
    end
  end

  # Authentication API routes (v1)
  scope "/api/v1", AuthService.Phoenix do
    pipe_through :api
    
    # Authentication endpoints
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh_token
    post "/auth/logout", AuthController, :logout
    post "/auth/forgot-password", AuthController, :forgot_password
    post "/auth/reset-password", AuthController, :reset_password
    post "/auth/verify-email", AuthController, :verify_email
    post "/auth/resend-verification", AuthController, :resend_verification
    
    # Token validation (can be used by other services)
    post "/auth/validate", AuthController, :validate_token
    
    # Authenticated routes
    scope "/auth" do
      pipe_through :authenticated
      
      get "/me", AuthController, :current_user
      put "/me", AuthController, :update_profile
      post "/change-password", AuthController, :change_password
      get "/sessions", AuthController, :list_sessions
      delete "/sessions/:session_id", AuthController, :terminate_session
      delete "/sessions", AuthController, :terminate_all_sessions
    end
    
    # Admin routes
    scope "/admin" do
      pipe_through [:authenticated, :admin]
      
      get "/users", AuthController, :list_users
      get "/users/:id", AuthController, :get_user
      put "/users/:id", AuthController, :update_user
      delete "/users/:id", AuthController, :delete_user
      post "/users/:id/unlock", AuthController, :unlock_user
      post "/users/:id/generate-api-key", AuthController, :generate_api_key
      delete "/users/:id/revoke-api-key", AuthController, :revoke_api_key
      
      get "/sessions", AuthController, :list_all_sessions
      delete "/sessions/:session_id", AuthController, :admin_terminate_session
      
      get "/stats", AuthController, :auth_stats
    end
  end
  
  # Metrics endpoint for monitoring
  scope "/metrics" do
    pipe_through :api
    
    get "/", AuthService.MetricsController, :index
    get "/health", AuthService.MetricsController, :health
    get "/ready", AuthService.MetricsController, :ready
  end
  
  # Development routes
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:api]
      get "/info", AuthService.DevController, :info
    end
  end
  
  # Fallback for unmatched routes
  match :*, "/*path", AuthService.FallbackController, :not_found
  
  # Helper function to require admin role
  defp require_admin_role(conn, _opts) do
    case get_session(conn, :current_user) do
      %{role: "admin"} -> conn
      _ -> 
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{error: "Admin access required"})
        |> halt()
    end
  end
  
  # Helper function to add secure headers
  defp put_security_headers(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", "default-src 'self'")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end
end