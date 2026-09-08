defmodule Gyx.Core.Spaces.Box do
  @moduledoc """
  A bounded numeric space.

  1-D `:f32` boxes still sample as float tuples (classic control, MuJoCo
  vectors). Rank ≥ 2 or `:u8` boxes sample as Nx tensors — that is the
  observation type for image wraps such as Atari.
  """

  @type dtype :: :u8 | :s32 | :s64 | :f32 | :f64

  defstruct low: 0.0,
            high: 1.0,
            shape: {1},
            dtype: :f32,
            seed: {1, 2, 3},
            random_algorithm: :exsplus

  @type t :: %__MODULE__{
          low: number() | tuple(),
          high: number() | tuple(),
          shape: tuple(),
          dtype: dtype(),
          random_algorithm: atom(),
          seed: {integer(), integer(), integer()}
        }

  @doc "True when points in this box are Nx tensors rather than float tuples."
  @spec tensor?(__MODULE__.t()) :: boolean()
  def tensor?(%__MODULE__{dtype: :u8}), do: true
  def tensor?(%__MODULE__{shape: shape}) when tuple_size(shape) > 1, do: true
  def tensor?(%__MODULE__{}), do: false

  @spec nx_type(dtype() | String.t()) :: Nx.Type.t()
  def nx_type(:u8), do: {:u, 8}
  def nx_type(:s32), do: {:s, 32}
  def nx_type(:s64), do: {:s, 64}
  def nx_type(:f32), do: {:f, 32}
  def nx_type(:f64), do: {:f, 64}
  def nx_type("uint8"), do: {:u, 8}
  def nx_type("int32"), do: {:s, 32}
  def nx_type("int64"), do: {:s, 64}
  def nx_type("float32"), do: {:f, 32}
  def nx_type("float64"), do: {:f, 64}
  def nx_type("u8"), do: {:u, 8}
  def nx_type("f32"), do: {:f, 32}
  def nx_type("f64"), do: {:f, 64}
end
