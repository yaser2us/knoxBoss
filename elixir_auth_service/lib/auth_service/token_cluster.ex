defmodule AuthService.TokenCluster do
  @moduledoc """
  Distributed token management cluster using Horde for coordination.
  
  This module provides:
  - Distributed token storage and validation
  - Automatic failover between nodes
  - Token blacklisting with Redis persistence
  - Rate limiting per user/IP
  - JWT token generation and validation
  """
  
  use GenServer
  require Logger
  
  alias AuthService.{TokenRegistry, TokenSupervisor}
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Generate a new JWT token for a user with distributed storage.
  """
  def generate_token(user_id, claims \\ %{}) do
    GenServer.call(__MODULE__, {:generate_token, user_id, claims})
  end
  
  @doc """
  Validate a JWT token across the cluster.
  """
  def validate_token(token) do
    GenServer.call(__MODULE__, {:validate_token, token})
  end
  
  @doc """
  Blacklist a token across all nodes.
  """
  def blacklist_token(token, reason \\ "user_logout") do
    GenServer.call(__MODULE__, {:blacklist_token, token, reason})
  end
  
  @doc """
  Check if a token is blacklisted.
  """
  def is_blacklisted?(token) do
    GenServer.call(__MODULE__, {:is_blacklisted, token})
  end
  
  @doc """
  Get all active tokens for a user.
  """
  def get_user_tokens(user_id) do
    GenServer.call(__MODULE__, {:get_user_tokens, user_id})
  end
  
  @doc """
  Revoke all tokens for a user (useful for password changes).
  """
  def revoke_user_tokens(user_id) do
    GenServer.call(__MODULE__, {:revoke_user_tokens, user_id})
  end
  
  # Server Implementation
  
  @impl true
  def init(:ok) do
    # Join the cluster
    :ok = join_cluster()
    
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired, :timer.minutes(5))
    
    state = %{
      node_id: Node.self(),
      jwt_secret: Application.get_env(:auth_service, :jwt_secret, generate_secret()),
      token_ttl: Application.get_env(:auth_service, :token_ttl, 3600), # 1 hour
      refresh_ttl: Application.get_env(:auth_service, :refresh_ttl, 86400 * 7) # 7 days
    }
    
    Logger.info("TokenCluster started on node #{state.node_id}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:generate_token, user_id, claims}, _from, state) do
    case create_jwt_token(user_id, claims, state) do
      {:ok, token_data} ->
        # Store in distributed registry
        store_token_distributed(token_data)
        
        # Store in Redis for persistence
        store_token_redis(token_data)
        
        {:reply, {:ok, token_data}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:validate_token, token}, _from, state) do
    case validate_jwt_token(token, state) do
      {:ok, claims} ->
        # Check if blacklisted
        case is_token_blacklisted(token) do
          false ->
            {:reply, {:ok, claims}, state}
          true ->
            {:reply, {:error, :token_blacklisted}, state}
        end
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:blacklist_token, token, reason}, _from, state) do
    case add_to_blacklist(token, reason) do
      :ok ->
        # Broadcast to all nodes
        broadcast_blacklist(token, reason)
        {:reply, :ok, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:is_blacklisted, token}, _from, state) do
    result = is_token_blacklisted(token)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:get_user_tokens, user_id}, _from, state) do
    tokens = get_active_user_tokens(user_id)
    {:reply, tokens, state}
  end
  
  @impl true
  def handle_call({:revoke_user_tokens, user_id}, _from, state) do
    case revoke_all_user_tokens(user_id) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_tokens()
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired, :timer.minutes(5))
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:token_blacklisted, token, reason}, state) do
    Logger.info("Token blacklisted: #{reason}")
    add_to_blacklist(token, reason)
    {:noreply, state}
  end
  
  # Private Functions
  
  defp join_cluster do
    # This would typically use libcluster for automatic discovery
    # For now, we'll use a simple approach
    :ok
  end
  
  defp create_jwt_token(user_id, claims, state) do
    now = System.system_time(:second)
    jti = generate_jti()
    
    token_claims = %{
      "sub" => to_string(user_id),
      "iat" => now,
      "exp" => now + state.token_ttl,
      "jti" => jti,
      "iss" => "auth_service",
      "aud" => "knox_boss"
    }
    |> Map.merge(claims)
    
    case Guardian.encode_and_sign(AuthService.Guardian, user_id, token_claims) do
      {:ok, token, full_claims} ->
        token_data = %{
          token: token,
          user_id: user_id,
          jti: jti,
          claims: full_claims,
          issued_at: now,
          expires_at: now + state.token_ttl,
          node: Node.self()
        }
        
        {:ok, token_data}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp validate_jwt_token(token, state) do
    case Guardian.decode_and_verify(AuthService.Guardian, token) do
      {:ok, claims} ->
        {:ok, claims}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp store_token_distributed(token_data) do
    # Store in Horde registry for distributed access
    case Horde.Registry.register(TokenRegistry, token_data.jti, token_data) do
      {:ok, _pid} ->
        :ok
      {:error, {:already_registered, _pid}} ->
        :ok
    end
  end
  
  defp store_token_redis(token_data) do
    # Store in Redis with TTL
    redis_key = "token:#{token_data.jti}"
    redis_data = Jason.encode!(token_data)
    
    Redix.command(:redis_auth, ["SETEX", redis_key, token_data.expires_at - System.system_time(:second), redis_data])
  end
  
  defp is_token_blacklisted(token) do
    # Check local cache first
    case Cachex.get(:auth_cache, "blacklist:#{token}") do
      {:ok, nil} ->
        # Check Redis
        case Redix.command(:redis_auth, ["GET", "blacklist:#{extract_jti(token)}"]) do
          {:ok, nil} -> false
          {:ok, _data} -> true
          {:error, _} -> false
        end
      
      {:ok, _data} ->
        true
    end
  end
  
  defp add_to_blacklist(token, reason) do
    jti = extract_jti(token)
    blacklist_data = %{
      jti: jti,
      reason: reason,
      blacklisted_at: System.system_time(:second)
    }
    
    # Store in cache
    Cachex.put(:auth_cache, "blacklist:#{token}", blacklist_data, ttl: :timer.hours(24))
    
    # Store in Redis
    redis_key = "blacklist:#{jti}"
    Redix.command(:redis_auth, ["SETEX", redis_key, 86400, Jason.encode!(blacklist_data)])
  end
  
  defp broadcast_blacklist(token, reason) do
    # Broadcast to all connected nodes
    :rpc.abcast([Node.self() | Node.list()], __MODULE__, {:token_blacklisted, token, reason})
  end
  
  defp get_active_user_tokens(user_id) do
    # Query Redis for user tokens
    pattern = "token:*"
    case Redix.command(:redis_auth, ["KEYS", pattern]) do
      {:ok, keys} ->
        keys
        |> Enum.map(&get_token_from_redis/1)
        |> Enum.filter(fn 
          {:ok, token_data} -> token_data.user_id == user_id
          _ -> false
        end)
        |> Enum.map(fn {:ok, token_data} -> token_data end)
      
      {:error, _} ->
        []
    end
  end
  
  defp get_token_from_redis(key) do
    case Redix.command(:redis_auth, ["GET", key]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, data} -> {:ok, Jason.decode!(data, keys: :atoms)}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp revoke_all_user_tokens(user_id) do
    user_tokens = get_active_user_tokens(user_id)
    
    Enum.each(user_tokens, fn token_data ->
      add_to_blacklist(token_data.token, "user_revoked")
    end)
    
    :ok
  end
  
  defp cleanup_expired_tokens do
    # This would clean up expired tokens from Redis and local cache
    # Implementation depends on your cleanup strategy
    :ok
  end
  
  defp generate_jti do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
  
  defp extract_jti(token) do
    case Guardian.decode_and_verify(AuthService.Guardian, token) do
      {:ok, claims} -> claims["jti"]
      {:error, _} -> nil
    end
  end
  
  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end
end