defmodule Gyx.Gym.Utils do
  @moduledoc """
  This module contains auxiliary functions to achieve full
  compatibility with Gym, including functions to obtain
  Gyx space representations from Gym space specs.
  """
  @space_types [{~r/Discrete\((?<n>\d+)\)/, :discrete},
                {~r/Box\((?<shape>((\d)+,)+)\)/, :box}]

  @doc """
  This function takes the __repr__ response from Gym spaces
  and creates an equivalent Gyx Space struct
  """
  def gyx_space(gym_space_string) do
    gym_space_string |> parse |> create_space
  end

  defp parse(gym_space_string) do
    {regex, type} =
      Enum.find(@space_types, {nil, :unknown}, fn {regex, _} ->
        Regex.match?(regex, to_string(gym_space_string))
      end)

    {type, Regex.named_captures(regex, to_string(gym_space_string))}
  end

  defp create_space({:discrete, capture}),
    do: %Gyx.Core.Spaces.Discrete{n: String.to_integer(Map.get(capture, "n"))}

  defp create_space({:box, capture}) do
    shape =
      Map.get(capture, "shape")
      |> String.trim(",")
      |> String.split(",")
      |> Enum.map(&String.to_integer(&1))
      |> List.to_tuple()

    %Gyx.Core.Spaces.Box{shape: shape}
  end

  defp create_space({:unknown, nil}), do: %{}
end
