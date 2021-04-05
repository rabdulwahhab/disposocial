defmodule Disposocial.DispoServer do
  use GenServer

  require Logger
  alias DisposocialWeb.Endpoint
  alias Disposocial.{Dispos, Posts, Repo, DispoAgent, DispoRegistry, DispoSupervisor, Comments}

  def registry(id) do
    {:via, Registry, {DispoRegistry, id}}
  end

  # API

  def start(id) do
    # Start a new DispoServer Process and get it supervised
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [id]},
      restart: :transient,
      type: :worker
    }
    DispoSupervisor.start_child(spec)
  end

  def peek(id) do
    GenServer.call(registry(id), :peek)
  end

  def get_dispo(id) do
    GenServer.call(registry(id), :get_dispo)
  end

  def post_post(id, attrs) do
    GenServer.call(registry(id), {:post_post, attrs})
  end

  def post_comment(id, attrs) do
    GenServer.call(registry(id), {:post_comment, attrs})
  end

  # def broadcast_feed(id) do
  #   GenServer.cast(registry(id), :broadcast_feed)
  # end

  # Helpers


  # Callbacks

  def start_link(id) do
    # Starts the Process instance and calls init
    GenServer.start_link(__MODULE__, id, name: registry(id))
  end

  @impl true
  def init(id) do
    # REQUIRED: This is invoked when the GenServer process is started and is
    # called by `start_link`. Blocking until it returns.
    dispo =
      if prevState = DispoAgent.get(id) do
        prevState
      else
        DispoAgent.put(id, Dispos.get_dispo!(id))
        DispoAgent.get(id)
      end

    # send self destruct message in on death date in the future
    # NOTE problem if ms too large?? ex. death a week from now
    ms_from_now = DateTime.diff(dispo.death, DateTime.utc_now(), :millisecond)
    Process.send_after(self(), :death, ms_from_now)

    # Init time remaining reminder
    next_reminder = round(ms_from_now / 2)
    Process.send_after(self(), {:reminder, next_reminder}, next_reminder)

    Logger.info("Dispo Server started: id --> #{inspect(id)}, pid --> #{inspect(self())}")
    {:ok, dispo}
  end

  @impl true
  def handle_call(:peek, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_dispo, _from, state) do
    {:reply, Dispos.present(state), state}
  end

  @impl true
  def handle_call({:post_post, attrs}, _from, state) do
    case Posts.create_post(attrs) do
      # NOTE potentially too much memory to keep preloading??
      {:ok, post} -> {:reply, {:ok, Posts.present(post)}, Repo.preload(state, [:posts])}
      {:error, chgset} -> {:reply, {:error, chgset}, state}
    end
  end

  @impl true
  def handle_call({:post_comment, attrs}, _from, state) do
    case Comments.create_comment(attrs) do
      {:ok, comment} -> {:reply, {:ok, Comments.present(comment)}, state}
      {:error, chgset} -> {:reply, {:error, chgset}, state}
    end
  end

  # @impl true
  # def handle_cast(:broadcast_feed, state) do
  #   # TODO broadcast on channel topic (dispo)
  #   {:noreply, state}
  # end

  @doc"""
  Exponential backoff reminders of termination date.
  """
  @impl true
  def handle_info({:reminder, ms_left}, state) do
    death_coming = 60 * 1000 # min time in ms that reminders no longer necessary
    unless ms_left < death_coming do
      Logger.notice("DispoServer #{inspect(state.id)}, #{inspect(self())} broadcasting reminder")
      Endpoint.broadcast!("dispo:#{to_string(state.id)}", "remind", %{data: ms_left})
      next_reminder = round(ms_left / 2)
      Process.send_after(self(), {:reminder, next_reminder}, next_reminder)
    end
    {:noreply, state}
  end

  @impl true
  def handle_info(:death, state) do
    # self destruct
    Endpoint.broadcast!("dispo:#{to_string(state.id)}", "angel_of_death", %{})
    Dispos.delete_dispo_and_remnants(state.id)
    # Goodbye
    {:stop, :normal, state}
  end

  @impl true
  def terminate(:normal, state) do
    # The final stand
    Logger.info("DispoServer #{inspect(self())} died peacefully with state --> #{inspect(state)}")
  end

  @impl true
  def terminate({reason, _}, state) do
    Logger.critical("DispoServer #{inspect(self())} terminated abnormally (#{inspect(reason)}) with state --> #{inspect(state)}")
  end

end
