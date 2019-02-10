defmodule Gyx.Gym do
  @moduledoc """
  This module is an API for accessing
  Python OpenAI Gym methods
  """
  alias Gyx.Python.Helper

  def make(environment_name) do
    Helper.call_python(:gym_interface, :make, [environment_name])
  end

  def step(environment, action) do
    Helper.call_python(:gym_interface, :step, [environment, action])
  end

  def render(environment) do
    Helper.call_python(:gym_interface, :render, [environment])
  end

  def reset(environment) do
    Helper.call_python(:gym_interface, :reset, [environment])
  end

end
