import Config

# Configure the database for test
config :auth_service, AuthService.Repo,
  username: "postgres",
  password: "postgres",
  database: "auth_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 50,
  max_overflow: 100,
  show_sensitive_data_on_connection_error: true

# Configure the endpoint for test
config :auth_service, AuthService.Endpoint,
  http: [port: 4002],
  server: false

# Test-specific auth settings
config :auth_service,
  # Enable Phoenix for testing
  enable_phoenix: true,
  
  # Disable clustering for test
  enable_clustering: false,
  
  # Fast testing settings
  max_login_attempts: 3,
  lockout_duration: 1, # 1 second for fast tests
  
  # Test JWT secret
  jwt_secret: "test_jwt_secret_for_testing_only",
  
  # High rate limits for performance testing
  rate_limit_window: 1,
  rate_limit_max_requests: 10000,
  
  # Shorter token TTL for testing
  token_ttl: 300, # 5 minutes
  refresh_ttl: 1800, # 30 minutes
  
  # CORS allows all origins in test
  cors_origins: "*"

# Configure Guardian for test
config :auth_service, AuthService.Guardian,
  issuer: "auth_service_test",
  secret_key: "test_guardian_secret_key_for_testing",
  ttl: {5, :minutes},
  verify_issuer: true,
  serializer: AuthService.GuardianSerializer

# Use a faster hashing algorithm for testing
config :bcrypt_elixir, :log_rounds, 4

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Performance test specific settings
config :auth_service, :performance_test_settings,
  # Database settings optimized for high throughput
  database_pool_size: 100,
  database_max_overflow: 200,
  
  # Memory settings
  max_memory_usage: 2_000_000_000, # 2GB
  
  # Concurrency settings
  max_concurrent_workers: 2000,
  
  # Rate limiting (disabled for performance tests)
  disable_rate_limiting: true,
  
  # Token settings
  jwt_validation_cache_size: 100_000,
  
  # Session settings
  max_sessions_per_user: 100,
  session_cleanup_interval: 60_000 # 1 minute