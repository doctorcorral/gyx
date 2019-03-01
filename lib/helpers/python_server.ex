defmodule Gyx.Python.PythonServer do
  use GenServer
  alias Gyx.Python.HelperAsync

  def start_link() do
     GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
     #start the python session and keep pid in state
     python_session = HelperAsync.start()
     #register this process as the message handler
     HelperAsync.call(python_session, :test, :register_handler, [self()])
     {:ok, python_session}
  end

  def cast_count(count) do
     {:ok, pid} = start_link()
     GenServer.cast(pid, {:count, count})
  end

  def call_count(count) do
     {:ok, pid} = start_link()
     # :infinity timeout only for demo purposes
     GenServer.call(pid, {:count, count}, :infinity)
  end

  def handle_call({:count, count}, _from, session) do
     result = HelperAsync.call(session, :test, :long_counter, [count])
     {:reply, result, session}
  end

  def handle_cast({:count, count}, session) do
    HelperAsync.cast(session, count)
    IO.inspect("XXXXXX")
    {:noreply, session}
  end

  def handle_info({:python, message}, session) do
     IO.puts("Received message from python: #{inspect message}")

     #stop elixir process
     {:stop, :normal,  session}
  end

  def terminate(_reason, session) do
    HelperAsync.stop(session)
    :ok
  end

end
