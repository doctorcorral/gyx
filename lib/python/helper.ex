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
  def call_python(pid, module, function, arguments \\ []) do
    pid
    |>:python.call(module, function, arguments)

  end
end
