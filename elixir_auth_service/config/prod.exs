import Config

# Configure the database for production
config :auth_service, AuthService.Repo,
  username: System.get_env("DB_USERNAME") || "auth_service",
  password: System.get_env("DB_PASSWORD") || raise("DB_PASSWORD environment variable is not set"),
  database: System.get_env("DB_NAME") || "auth_service_prod",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "15"),
  socket_options: [:inet6]

# Configure the endpoint for production
config :auth_service, AuthService.Endpoint,
  url: [host: System.get_env("APP_HOST") || "localhost", port: 443],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE environment variable is not set"),
  check_origin: System.get_env("CHECK_ORIGIN") |> parse_check_origin(),
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Configure Guardian for production
config :auth_service, AuthService.Guardian,
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || raise("GUARDIAN_SECRET_KEY environment variable is not set"),
  ttl: {String.to_integer(System.get_env("TOKEN_TTL") || "3600"), :second}

# Configure logging for production
config :logger, level: :info

# Configure SSL if enabled
if System.get_env("SSL_ENABLED") == "true" do
  config :auth_service, AuthService.Endpoint,
    https: [
      port: String.to_integer(System.get_env("SSL_PORT") || "443"),
      cipher_suite: :strong,
      keyfile: System.get_env("SSL_KEY_PATH"),
      certfile: System.get_env("SSL_CERT_PATH"),
      transport_options: [socket_opts: [:inet6]]
    ],
    force_ssl: [rewrite_on: [:x_forwarded_proto]]
end

# Production-specific auth settings
config :auth_service,
  # Enable all features for production
  enable_phoenix: true,
  enable_clustering: true,
  enable_telemetry: true,
  
  # Security settings
  max_login_attempts: String.to_integer(System.get_env("MAX_LOGIN_ATTEMPTS") || "5"),
  lockout_duration: String.to_integer(System.get_env("LOCKOUT_DURATION") || "900"), # 15 minutes
  password_min_length: String.to_integer(System.get_env("PASSWORD_MIN_LENGTH") || "8"),
  
  # Token settings
  jwt_secret: System.get_env("JWT_SECRET") || raise("JWT_SECRET environment variable is not set"),
  token_ttl: String.to_integer(System.get_env("TOKEN_TTL") || "3600"), # 1 hour
  refresh_ttl: String.to_integer(System.get_env("REFRESH_TTL") || "604800"), # 7 days
  
  # Session settings
  session_ttl: String.to_integer(System.get_env("SESSION_TTL") || "86400"), # 24 hours
  max_sessions_per_user: String.to_integer(System.get_env("MAX_SESSIONS_PER_USER") || "10"),
  
  # Rate limiting
  rate_limit_window: String.to_integer(System.get_env("RATE_LIMIT_WINDOW") || "60"), # 1 minute
  rate_limit_max_requests: String.to_integer(System.get_env("RATE_LIMIT_MAX_REQUESTS") || "100"),
  
  # CORS (be more restrictive in production)
  cors_origins: System.get_env("CORS_ORIGINS") || raise("CORS_ORIGINS environment variable is not set"),
  
  # Telemetry
  telemetry_endpoint: System.get_env("TELEMETRY_ENDPOINT")

# Configure Redis for production
config :redix,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379"),
  password: System.get_env("REDIS_PASSWORD"),
  database: String.to_integer(System.get_env("REDIS_DB") || "0"),
  ssl: System.get_env("REDIS_SSL") == "true"

# Configure clustering for production
config :libcluster,
  topologies: [
    auth_cluster: [
      strategy: parse_cluster_strategy(),
      config: parse_cluster_config()
    ]
  ]

# Configure telemetry for production
config :telemetry_poller, :default, period: 30_000

# Runtime configuration
config :auth_service, AuthService.Repo,
  ssl: System.get_env("DB_SSL") == "true",
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: System.get_env("DB_SSL_CACERTFILE"),
    server_name_indication: String.to_charlist(System.get_env("DB_HOST") || "localhost")
  ]

# Helper functions for production configuration
defp parse_check_origin(nil), do: false
defp parse_check_origin(origins) do
  origins
  |> String.split(",")
  |> Enum.map(&String.trim/1)
end

defp parse_cluster_strategy do
  case System.get_env("CLUSTER_STRATEGY") do
    "kubernetes" -> Cluster.Strategy.Kubernetes
    "gossip" -> Cluster.Strategy.Gossip
    "epmd" -> Cluster.Strategy.Epmd
    _ -> Cluster.Strategy.Gossip
  end
end

defp parse_cluster_config do
  strategy = System.get_env("CLUSTER_STRATEGY")
  
  case strategy do
    "kubernetes" ->
      [
        mode: :dns,
        kubernetes_node_basename: System.get_env("KUBERNETES_NODE_BASENAME") || "auth_service",
        kubernetes_selector: System.get_env("KUBERNETES_SELECTOR") || "app=auth_service",
        kubernetes_namespace: System.get_env("KUBERNETES_NAMESPACE") || "default",
        polling_interval: String.to_integer(System.get_env("CLUSTER_POLLING_INTERVAL") || "5000")
      ]
    
    "gossip" ->
      [
        port: String.to_integer(System.get_env("GOSSIP_PORT") || "45892"),
        if_addr: System.get_env("GOSSIP_IF_ADDR") || "0.0.0.0",
        multicast_addr: System.get_env("GOSSIP_MULTICAST_ADDR") || "230.1.1.251",
        multicast_ttl: String.to_integer(System.get_env("GOSSIP_MULTICAST_TTL") || "1"),
        secret: System.get_env("CLUSTER_SECRET") || raise("CLUSTER_SECRET environment variable is not set")
      ]
    
    "epmd" ->
      [
        hosts: System.get_env("CLUSTER_HOSTS") |> parse_cluster_hosts()
      ]
    
    _ ->
      []
  end
end

defp parse_cluster_hosts(nil), do: []
defp parse_cluster_hosts(hosts_string) do
  hosts_string
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(&String.to_atom/1)
end