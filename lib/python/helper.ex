defmodule Gyx.Python.Helper do
  @doc """
  ## Parameters
    - path: directory to include in python path (charlist)
  """
  def python_instance(path) when is_list(path) do
    {:ok, pid} = :python.start([{:python_path, to_charlist(path)}])
    pid
  end

  def python_instance(_) do
    {:ok, pid} = :python.start()
    pid
  end

  @doc """
  Call python function using MFA format
  """
  def call_python_pid(pid, module, function, arguments \\ []) do
    pid
    |> :python.call(module, function, arguments)
  end

  def call_python(module, function, args \\ []) do
    default_instance()
    |> call_python_pid(module, function, args)
  end

  defp default_instance() do
    path =
      [:code.priv_dir(:gyx), "python"]
      |> Path.join()

    python_instance(to_charlist(path))
  end
end
