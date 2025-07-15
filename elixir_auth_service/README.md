# AuthService - Distributed Elixir Authentication Service

A production-ready, distributed authentication service built with Elixir/OTP, designed for high availability and scalability.

## Features

### 🔐 Authentication & Authorization
- **JWT Token Management**: Secure token generation and validation with distributed blacklisting
- **Session Management**: Distributed session storage with automatic cleanup
- **Role-Based Access Control**: Flexible permissions and role system
- **Multi-Factor Authentication**: Support for MFA integration
- **Rate Limiting**: Built-in protection against brute force attacks

### 🚀 Distributed Architecture
- **OTP Supervision Trees**: Fault-tolerant process management
- **Horde Integration**: Distributed registry and dynamic supervision
- **Redis Clustering**: Persistent token and session storage
- **Libcluster Support**: Automatic node discovery and clustering
- **Cross-Node Communication**: Seamless failover and replication

### 🛡️ Security Features
- **Bcrypt Password Hashing**: Secure password storage
- **Token Blacklisting**: Immediate token revocation across all nodes
- **Account Lockout**: Configurable failed attempt protection
- **IP-based Rate Limiting**: Per-IP request throttling
- **Security Headers**: Comprehensive security header management

### 🔧 Production Ready
- **Phoenix Integration**: Ready-to-use controllers and middleware
- **Telemetry Monitoring**: Comprehensive metrics and health checks
- **Docker Support**: Containerized deployment
- **Database Migrations**: Versioned schema management
- **Configuration Management**: Environment-based configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AuthService.Application                      │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │   TokenCluster  │  │ SessionManager  │  │    Telemetry    │     │
│  │   (Distributed  │  │  (Distributed   │  │   (Metrics &    │     │
│  │   JWT Manager)  │  │   Sessions)     │  │   Monitoring)   │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │ Horde Registry  │  │ Horde Supervisor│  │  Redis Pool     │     │
│  │  (Distributed   │  │   (Dynamic      │  │  (Persistent    │     │
│  │   Registry)     │  │   Supervision)  │  │   Storage)      │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │     Database    │  │     Cachex      │  │   Phoenix       │     │
│  │   (PostgreSQL)  │  │   (In-Memory    │  │  (HTTP API)     │     │
│  │                 │  │    Cache)       │  │                 │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- PostgreSQL 12+
- Redis 6+

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd elixir_auth_service
```

2. Install dependencies:
```bash
mix deps.get
```

3. Configure your environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Set up the database:
```bash
mix ecto.setup
```

5. Start the service:
```bash
mix phx.server
```

### Configuration

Key environment variables:

```bash
# Database
DB_USERNAME=postgres
DB_PASSWORD=yourpassword
DB_NAME=auth_service_prod
DB_HOST=localhost
DB_PORT=5432

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=yourpassword

# JWT
JWT_SECRET=your-super-secret-jwt-key
TOKEN_TTL=3600
REFRESH_TTL=604800

# Clustering
ENABLE_CLUSTERING=true
CLUSTER_STRATEGY=gossip
CLUSTER_SECRET=your-cluster-secret

# Security
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_DURATION=900
CORS_ORIGINS=https://yourdomain.com
```

## API Endpoints

### Authentication

**POST** `/api/auth/register`
```json
{
  "user": {
    "email": "user@example.com",
    "password": "securepassword123",
    "first_name": "John",
    "last_name": "Doe"
  }
}
```

**POST** `/api/auth/login`
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**POST** `/api/auth/logout`
```bash
curl -X POST http://localhost:4000/api/auth/logout \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Token Management

**POST** `/api/auth/validate-token`
```json
{
  "token": "YOUR_JWT_TOKEN"
}
```

**POST** `/api/auth/refresh-token`
```json
{
  "refresh_token": "YOUR_REFRESH_TOKEN"
}
```

**POST** `/api/auth/revoke-all-tokens`
```bash
curl -X POST http://localhost:4000/api/auth/revoke-all-tokens \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### User Management

**GET** `/api/auth/me`
```bash
curl -X GET http://localhost:4000/api/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**GET** `/api/auth/sessions`
```bash
curl -X GET http://localhost:4000/api/auth/sessions \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**DELETE** `/api/auth/sessions/:session_id`
```bash
curl -X DELETE http://localhost:4000/api/auth/sessions/SESSION_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Phoenix Integration

### Router Configuration

```elixir
defmodule YourApp.Router do
  use YourApp, :router
  
  pipeline :api do
    plug :accepts, ["json"]
    plug AuthService.Phoenix.OptionalAuth
  end
  
  pipeline :authenticated do
    plug :accepts, ["json"]
    plug AuthService.Phoenix.RequireAuth
  end
  
  scope "/api", YourApp do
    pipe_through :api
    
    # Public routes
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/validate-token", AuthController, :validate_token
  end
  
  scope "/api", YourApp do
    pipe_through :authenticated
    
    # Protected routes
    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout
    get "/auth/sessions", AuthController, :sessions
  end
end
```

### Controller Usage

```elixir
defmodule YourApp.Controller do
  use YourApp, :controller
  
  def protected_action(conn, _params) do
    current_user = conn.assigns.current_user
    
    json(conn, %{
      message: "Hello, #{current_user.email}!",
      user: current_user
    })
  end
end
```

## Deployment

### Docker

```dockerfile
FROM elixir:1.14-alpine

# Install system dependencies
RUN apk add --no-cache build-base npm git python3

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy source code
COPY . .

# Compile the application
RUN mix deps.compile
RUN mix compile

# Create release
RUN mix release

# Runtime configuration
ENV MIX_ENV=prod
ENV PORT=4000

EXPOSE 4000

# Start the application
CMD ["_build/prod/rel/auth_service/bin/auth_service", "start"]
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
      - name: auth-service
        image: your-registry/auth-service:latest
        ports:
        - containerPort: 4000
        env:
        - name: ENABLE_CLUSTERING
          value: "true"
        - name: CLUSTER_STRATEGY
          value: "kubernetes"
        - name: KUBERNETES_SELECTOR
          value: "app=auth-service"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: auth-service-secrets
              key: jwt-secret
```

## Monitoring

### Telemetry Metrics

The service provides comprehensive metrics:

- **Authentication**: Success/failure rates, duration
- **Tokens**: Generation, validation, blacklisting
- **Sessions**: Creation, termination, duration
- **Security**: Invalid attempts, rate limiting
- **Performance**: Database queries, cache hit rates
- **Cluster**: Node status, distribution

### Health Checks

```bash
# Health check endpoint
curl http://localhost:4000/health

# Cluster status
curl http://localhost:4000/cluster/status

# Metrics endpoint (Prometheus format)
curl http://localhost:4000/metrics
```

## Security Best Practices

1. **Environment Variables**: Store secrets in environment variables
2. **HTTPS Only**: Always use HTTPS in production
3. **CORS Configuration**: Restrict origins in production
4. **Rate Limiting**: Configure appropriate limits
5. **Token Expiration**: Use short-lived tokens with refresh
6. **Account Lockout**: Enable failed attempt protection
7. **Security Headers**: Enable all security headers
8. **Regular Updates**: Keep dependencies updated

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/auth_service/token_cluster_test.exs
```

## Development

### Project Structure

```
lib/
├── auth_service/
│   ├── accounts/           # User management
│   ├── application.ex      # OTP application
│   ├── guardian.ex         # JWT implementation
│   ├── session_manager.ex  # Session management
│   ├── telemetry.ex        # Monitoring
│   └── token_cluster.ex    # Token management
├── phoenix_integration/    # Phoenix controllers/middleware
config/                     # Configuration files
priv/                       # Database migrations
test/                       # Test files
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [Create an issue](https://github.com/your-org/auth-service/issues)
- Documentation: [Wiki](https://github.com/your-org/auth-service/wiki)
- Community: [Discord/Slack channel]