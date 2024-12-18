defmodule DisposocialWeb.DefaultChannel do
  use DisposocialWeb, :channel

  require Logger

  @impl true
  def join("default:init", _payload, socket) do
    Logger.debug("Init default channel")
    {:ok, socket}
  end

  #@impl true
  #def handle_in("default:register", _params) do
    # TODO validate (proper fields, name not in use,
    # password good, email validation), hash password,
    # create db User, set session + api token
  #end

  # @impl true
  # def join("default:lobby", payload, socket) do
  #   if authorized?(payload) do
  #     {:ok, socket}
  #   else
  #     {:error, %{reason: "unauthorized"}}
  #   end
  # end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (default:lobby).
  # @impl true
  # def handle_in("shout", payload, socket) do
  #   broadcast(socket, "shout", payload)
  #   {:noreply, socket}
  # end

  # Add authorization logic here as required.
  # defp authorized?(_payload) do
  #   true
  # end
end
