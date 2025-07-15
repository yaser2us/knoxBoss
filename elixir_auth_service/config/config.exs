import Config

# Helper function to parse cluster nodes
defmodule ConfigHelpers do
  def parse_cluster_nodes(nil), do: []
  def parse_cluster_nodes(nodes_string) do
    nodes_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end
end

# Configure the main application
config :auth_service,
  ecto_repos: [AuthService.Repo],
  generators: [context_app: :auth_service]

# Configures the endpoint
config :auth_service, AuthService.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: AuthService.Phoenix.ErrorView, accepts: ~w(json)],
  pubsub_server: AuthService.PubSub,
  live_view: [signing_salt: "auth_service"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :session_id]

# Guardian configuration
config :auth_service, AuthService.Guardian,
  issuer: "auth_service",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_secret_key_change_in_production",
  ttl: {1, :hour},
  verify_issuer: true,
  serializer: AuthService.GuardianSerializer

# Database configuration
config :auth_service, AuthService.Repo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "new_password",
  database: System.get_env("DB_NAME") || "auth_service_dev",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Redis configuration
config :redix,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  database: String.to_integer(System.get_env("REDIS_DB") || "0")

# Horde configuration for distributed state
config :horde,
  node_name: System.get_env("NODE_NAME") || "auth_service@127.0.0.1"

# Libcluster configuration for node discovery
config :libcluster,
  topologies: [
    auth_cluster: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "230.1.1.251",
        multicast_ttl: 1,
        secret: System.get_env("CLUSTER_SECRET") || "dev_cluster_secret"
      ]
    ]
  ]

# Telemetry configuration
config :telemetry_poller, :default, period: 5_000

# Phoenix configuration
config :phoenix, :json_library, Jason

# CORS configuration
config :cors_plug,
  origin: ["*"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# Auth service specific configuration
config :auth_service,
  # Token settings
  jwt_secret: System.get_env("JWT_SECRET") || "change_this_in_production",
  token_ttl: String.to_integer(System.get_env("TOKEN_TTL") || "3600"), # 1 hour
  refresh_ttl: String.to_integer(System.get_env("REFRESH_TTL") || "604800"), # 7 days

  # Session settings
  session_ttl: String.to_integer(System.get_env("SESSION_TTL") || "86400"), # 24 hours
  max_sessions_per_user: String.to_integer(System.get_env("MAX_SESSIONS_PER_USER") || "10"),

  # Security settings
  max_login_attempts: String.to_integer(System.get_env("MAX_LOGIN_ATTEMPTS") || "5"),
  lockout_duration: String.to_integer(System.get_env("LOCKOUT_DURATION") || "900"), # 15 minutes
  password_min_length: String.to_integer(System.get_env("PASSWORD_MIN_LENGTH") || "8"),

  # Rate limiting
  rate_limit_window: String.to_integer(System.get_env("RATE_LIMIT_WINDOW") || "60"), # 1 minute
  rate_limit_max_requests: String.to_integer(System.get_env("RATE_LIMIT_MAX_REQUESTS") || "100"),

  # Clustering
  enable_clustering: System.get_env("ENABLE_CLUSTERING") == "true",
  cluster_nodes: System.get_env("CLUSTER_NODES") |> ConfigHelpers.parse_cluster_nodes(),

  # Phoenix integration
  enable_phoenix: System.get_env("ENABLE_PHOENIX") == "true",

  # CORS settings
  cors_origins: System.get_env("CORS_ORIGINS") || "*",

  # Monitoring
  enable_telemetry: System.get_env("ENABLE_TELEMETRY") != "false",
  telemetry_endpoint: System.get_env("TELEMETRY_ENDPOINT")

# Environment-specific configuration
import_config "#{Mix.env()}.exs"
