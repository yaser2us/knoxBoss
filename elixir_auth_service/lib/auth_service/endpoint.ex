defmodule AuthService.Endpoint do
  @moduledoc """
  Phoenix endpoint for the AuthService application.
  
  This endpoint provides HTTP/HTTPS access to the authentication service,
  including REST API endpoints and WebSocket connections.
  """
  
  use Phoenix.Endpoint, otp_app: :auth_service
  
  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_auth_service_key",
    signing_salt: "auth_service_signing_salt",
    same_site: "Lax"
  ]
  
  # WebSocket endpoint for future real-time features
  # socket "/socket", AuthService.UserSocket,
  #   websocket: true,
  #   longpoll: false
  
  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :auth_service,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)
  
  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :auth_service
  end
  
  # Request logging for development
  if code_reloading? do
    plug Plug.Logger
  end
  
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  
  # Add CORS support
  plug CORSPlug,
    origin: &AuthService.Endpoint.cors_origins/0,
    max_age: 86400,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since", "X-CSRF-Token"]
  
  # Authentication middleware
  plug AuthService.Phoenix.OptionalAuth
  
  # Router
  plug AuthService.Router
  
  @doc """
  Get CORS origins from configuration.
  """
  def cors_origins do
    case Application.get_env(:auth_service, :cors_origins, "*") do
      "*" -> ["*"]
      origins when is_binary(origins) -> String.split(origins, ",") |> Enum.map(&String.trim/1)
      origins when is_list(origins) -> origins
      _ -> ["*"]
    end
  end
  
  @doc """
  Callback invoked for dynamically configuring the endpoint.
  
  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end