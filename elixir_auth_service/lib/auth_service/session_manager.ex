defmodule AuthService.SessionManager do
  @moduledoc """
  Distributed session management with OTP supervision.
  
  This module provides:
  - Distributed session storage across nodes
  - Session replication and failover
  - Session expiration and cleanup
  - User session analytics
  - Multi-device session management
  """
  
  use GenServer
  require Logger
  
  alias AuthService.{TokenRegistry, TokenCluster}
  
  defmodule Session do
    @derive {Jason.Encoder, only: [:id, :user_id, :device_id, :ip_address, :user_agent, :created_at, :last_activity, :expires_at]}
    defstruct [
      :id,
      :user_id,
      :device_id,
      :ip_address,
      :user_agent,
      :created_at,
      :last_activity,
      :expires_at,
      :metadata
    ]
  end
  
  # Client API
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end
  
  @doc """
  Create a new session for a user.
  """
  def create_session(user_id, device_info \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, user_id, device_info})
  end
  
  @doc """
  Get session information by session ID.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end
  
  @doc """
  Update session activity (extends expiration).
  """
  def update_activity(session_id) do
    GenServer.call(__MODULE__, {:update_activity, session_id})
  end
  
  @doc """
  Get all active sessions for a user.
  """
  def get_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:get_user_sessions, user_id})
  end
  
  @doc """
  Terminate a specific session.
  """
  def terminate_session(session_id) do
    GenServer.call(__MODULE__, {:terminate_session, session_id})
  end
  
  @doc """
  Terminate all sessions for a user.
  """
  def terminate_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:terminate_user_sessions, user_id})
  end
  
  @doc """
  Get session analytics for a user.
  """
  def get_session_analytics(user_id) do
    GenServer.call(__MODULE__, {:get_session_analytics, user_id})
  end
  
  @doc """
  Check if a session is valid and active.
  """
  def is_session_valid?(session_id) do
    GenServer.call(__MODULE__, {:is_session_valid, session_id})
  end
  
  # Server Implementation
  
  @impl true
  def init(:ok) do
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_expired_sessions, :timer.minutes(5))
    
    state = %{
      sessions: %{},
      user_sessions: %{},
      session_ttl: Application.get_env(:auth_service, :session_ttl, 3600 * 24), # 24 hours
      max_sessions_per_user: Application.get_env(:auth_service, :max_sessions_per_user, 10)
    }
    
    Logger.info("SessionManager started on node #{Node.self()}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_session, user_id, device_info}, _from, state) do
    case create_new_session(user_id, device_info, state) do
      {:ok, session, new_state} ->
        # Store in distributed registry
        store_session_distributed(session)
        
        # Store in Redis for persistence
        store_session_redis(session)
        
        {:reply, {:ok, session}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case get_session_from_storage(session_id) do
      {:ok, session} ->
        {:reply, {:ok, session}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:update_activity, session_id}, _from, state) do
    case update_session_activity(session_id, state) do
      {:ok, session} ->
        {:reply, {:ok, session}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_user_sessions, user_id}, _from, state) do
    sessions = get_active_user_sessions(user_id)
    {:reply, sessions, state}
  end
  
  @impl true
  def handle_call({:terminate_session, session_id}, _from, state) do
    case terminate_session_impl(session_id, state) do
      :ok ->
        {:reply, :ok, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:terminate_user_sessions, user_id}, _from, state) do
    case terminate_all_user_sessions(user_id, state) do
      :ok ->
        {:reply, :ok, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_session_analytics, user_id}, _from, state) do
    analytics = calculate_session_analytics(user_id)
    {:reply, analytics, state}
  end
  
  @impl true
  def handle_call({:is_session_valid, session_id}, _from, state) do
    case get_session_from_storage(session_id) do
      {:ok, session} ->
        valid = is_session_active?(session)
        {:reply, valid, state}
      
      {:error, _} ->
        {:reply, false, state}
    end
  end
  
  @impl true
  def handle_info(:cleanup_expired_sessions, state) do
    cleanup_expired_sessions()
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_expired_sessions, :timer.minutes(5))
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp create_new_session(user_id, device_info, state) do
    now = System.system_time(:second)
    session_id = generate_session_id()
    
    # Check if user has too many sessions
    current_sessions = get_active_user_sessions(user_id)
    if length(current_sessions) >= state.max_sessions_per_user do
      # Remove oldest session
      oldest_session = Enum.min_by(current_sessions, & &1.created_at)
      terminate_session_impl(oldest_session.id, state)
    end
    
    session = %Session{
      id: session_id,
      user_id: user_id,
      device_id: device_info[:device_id],
      ip_address: device_info[:ip_address],
      user_agent: device_info[:user_agent],
      created_at: now,
      last_activity: now,
      expires_at: now + state.session_ttl,
      metadata: device_info[:metadata] || %{}
    }
    
    # Update state
    new_sessions = Map.put(state.sessions, session_id, session)
    new_user_sessions = Map.update(state.user_sessions, user_id, [session_id], &[session_id | &1])
    
    new_state = %{
      state |
      sessions: new_sessions,
      user_sessions: new_user_sessions
    }
    
    {:ok, session, new_state}
  end
  
  defp get_session_from_storage(session_id) do
    # First check local registry
    case Horde.Registry.lookup(TokenRegistry, "session:#{session_id}") do
      [{_pid, session}] ->
        {:ok, session}
      
      [] ->
        # Check Redis
        case get_session_from_redis(session_id) do
          {:ok, session} ->
            {:ok, session}
          
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  defp store_session_distributed(session) do
    # Store in Horde registry
    case Horde.Registry.register(TokenRegistry, "session:#{session.id}", session) do
      {:ok, _pid} ->
        :ok
      
      {:error, {:already_registered, _pid}} ->
        :ok
    end
  end
  
  defp store_session_redis(session) do
    # Store in Redis with TTL
    redis_key = "session:#{session.id}"
    redis_data = Jason.encode!(session)
    ttl = session.expires_at - System.system_time(:second)
    
    Redix.command(:redis_auth, ["SETEX", redis_key, ttl, redis_data])
  end
  
  defp get_session_from_redis(session_id) do
    case Redix.command(:redis_auth, ["GET", "session:#{session_id}"]) do
      {:ok, nil} ->
        {:error, :not_found}
      
      {:ok, data} ->
        session = Jason.decode!(data, keys: :atoms)
        session_struct = struct(Session, session)
        {:ok, session_struct}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp update_session_activity(session_id, state) do
    case get_session_from_storage(session_id) do
      {:ok, session} ->
        now = System.system_time(:second)
        updated_session = %{
          session |
          last_activity: now,
          expires_at: now + state.session_ttl
        }
        
        # Update in storage
        store_session_distributed(updated_session)
        store_session_redis(updated_session)
        
        {:ok, updated_session}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp get_active_user_sessions(user_id) do
    # Query Redis for user sessions
    pattern = "session:*"
    
    case Redix.command(:redis_auth, ["KEYS", pattern]) do
      {:ok, keys} ->
        keys
        |> Enum.map(&get_session_from_redis_key/1)
        |> Enum.filter(fn
          {:ok, session} -> 
            session.user_id == user_id && is_session_active?(session)
          _ -> 
            false
        end)
        |> Enum.map(fn {:ok, session} -> session end)
      
      {:error, _} ->
        []
    end
  end
  
  defp get_session_from_redis_key(key) do
    case Redix.command(:redis_auth, ["GET", key]) do
      {:ok, nil} ->
        {:error, :not_found}
      
      {:ok, data} ->
        session = Jason.decode!(data, keys: :atoms)
        session_struct = struct(Session, session)
        {:ok, session_struct}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp terminate_session_impl(session_id, _state) do
    # Remove from Redis
    Redix.command(:redis_auth, ["DEL", "session:#{session_id}"])
    
    # Remove from distributed registry
    case Horde.Registry.lookup(TokenRegistry, "session:#{session_id}") do
      [{pid, _session}] ->
        Horde.Registry.unregister(TokenRegistry, "session:#{session_id}")
      
      [] ->
        :ok
    end
    
    # Also revoke any associated tokens
    TokenCluster.revoke_user_tokens(session_id)
    
    :ok
  end
  
  defp terminate_all_user_sessions(user_id, state) do
    user_sessions = get_active_user_sessions(user_id)
    
    Enum.each(user_sessions, fn session ->
      terminate_session_impl(session.id, state)
    end)
    
    :ok
  end
  
  defp calculate_session_analytics(user_id) do
    sessions = get_active_user_sessions(user_id)
    
    %{
      total_sessions: length(sessions),
      active_sessions: Enum.count(sessions, &is_session_active?/1),
      devices: sessions |> Enum.map(& &1.device_id) |> Enum.uniq() |> length(),
      locations: sessions |> Enum.map(& &1.ip_address) |> Enum.uniq() |> length(),
      oldest_session: sessions |> Enum.min_by(& &1.created_at, fn -> nil end),
      newest_session: sessions |> Enum.max_by(& &1.created_at, fn -> nil end)
    }
  end
  
  defp is_session_active?(session) do
    now = System.system_time(:second)
    session.expires_at > now
  end
  
  defp cleanup_expired_sessions do
    # Get all session keys from Redis
    case Redix.command(:redis_auth, ["KEYS", "session:*"]) do
      {:ok, keys} ->
        expired_keys = 
          keys
          |> Enum.filter(fn key ->
            case get_session_from_redis_key(key) do
              {:ok, session} -> !is_session_active?(session)
              _ -> true
            end
          end)
        
        # Remove expired sessions
        if length(expired_keys) > 0 do
          Redix.command(:redis_auth, ["DEL" | expired_keys])
          Logger.info("Cleaned up #{length(expired_keys)} expired sessions")
        end
      
      {:error, reason} ->
        Logger.error("Failed to cleanup expired sessions: #{inspect(reason)}")
    end
  end
  
  defp generate_session_id do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end