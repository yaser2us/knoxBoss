import Config

# Configure the database for development
config :auth_service, AuthService.Repo,
  username: "postgres",
  password: "new_password",
  database: "auth_service_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  start_apps_before_migration: [:ssl]

# Configure the endpoint for development
config :auth_service, AuthService.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Set a higher stacktrace during development
config :logger, :console, format: "[$level] $message\n"

# Set level to debug for development
config :logger, level: :debug

# Phoenix LiveDashboard configuration
config :auth_service, AuthService.Endpoint,
  live_dashboard: [
    metrics: AuthService.Telemetry
  ]

# Development-specific auth settings
config :auth_service,
  # Enable Phoenix for development
  enable_phoenix: true,

  # Disable clustering for development
  enable_clustering: false,

  # Relaxed security for development
  max_login_attempts: 10,
  lockout_duration: 300, # 5 minutes

  # Development JWT secret (change this!)
  jwt_secret: "dev_jwt_secret_change_in_production",

  # CORS allows all origins in development
  cors_origins: "*"

# Disable swoosh api client as it is only required for production adapters
# config :swoosh, :api_client, false

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
