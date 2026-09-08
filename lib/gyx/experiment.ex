defmodule Gyx.Experiment do
  @moduledoc """
  A named learning run: environment, algorithm, and trainer options.

  Specs are JSON files under `experiments/` by default. `run/2` uses
  `Gyx.Trainers.Presets` + `Gyx.Trainers.Episodic`. The Mix CLI and the
  optional `ui/` app both call this module.
  """

  alias Gyx.Trainers.{Episodic, Presets}

  defstruct name: nil,
            env: nil,
            algo: "a2c",
            episodes: nil,
            max_steps: nil,
            seed: 1,
            env_opts: [],
            returns: [],
            eval_return: nil,
            agent: nil

  @type t :: %__MODULE__{
          name: String.t() | nil,
          env: String.t(),
          algo: String.t(),
          episodes: pos_integer() | nil,
          max_steps: pos_integer() | nil,
          seed: integer(),
          env_opts: keyword(),
          returns: [float()],
          eval_return: float() | nil,
          agent: struct() | nil
        }

  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    env = opts |> Keyword.fetch!(:env) |> to_string()
    algo = opts |> Keyword.get(:algo, "a2c") |> to_string()

    unless Presets.available?(algo, env) do
      raise ArgumentError, "#{Presets.algo_label(algo)} has no preset for #{env}"
    end

    struct!(
      __MODULE__,
      name: Keyword.get(opts, :name),
      env: env,
      algo: algo,
      episodes: Keyword.get(opts, :episodes),
      max_steps: Keyword.get(opts, :max_steps),
      seed: Keyword.get(opts, :seed, 1),
      env_opts: Keyword.get(opts, :env_opts, [])
    )
  end

  @spec available?(String.t(), String.t()) :: boolean()
  def available?(algo, env), do: Presets.available?(algo, env)

  @spec algorithms() :: [{String.t(), String.t()}]
  def algorithms, do: Presets.algorithms()

  @spec run(t(), keyword()) :: t()
  def run(%__MODULE__{} = exp, opts \\ []) do
    {agent, preset} = Presets.build(exp.algo, exp.env)

    train_opts =
      preset
      |> put_if(exp.seed, :seed)
      |> put_if(exp.episodes, :episodes)
      |> put_if(exp.max_steps, :max_steps)
      |> maybe_env_opts(exp.env_opts)
      |> Keyword.merge(clean(opts, [:on_progress, :episodes, :max_steps, :seed]))

    result = Episodic.train(exp.env, agent, train_opts)
    eval = Episodic.evaluate(exp.env, result.agent, Presets.eval_opts(exp.env))

    %{
      exp
      | agent: result.agent,
        returns: result.returns,
        eval_return: eval,
        episodes: result.episodes
    }
  end

  @spec save(t(), Path.t()) :: :ok | {:error, term()}
  def save(%__MODULE__{} = exp, dir \\ "experiments") do
    name = exp.name || raise ArgumentError, "experiment needs a :name to save"
    File.mkdir_p!(dir)
    File.write(path(dir, name), Jason.encode!(to_map(exp), pretty: true))
  end

  @spec load(String.t(), Path.t()) :: {:ok, t()} | {:error, term()}
  def load(name, dir \\ "experiments") do
    with {:ok, json} <- File.read(path(dir, name)),
         {:ok, map} <- Jason.decode(json) do
      {:ok, from_map(map)}
    end
  end

  @spec list(Path.t()) :: [String.t()]
  def list(dir \\ "experiments") do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&String.trim_trailing(&1, ".json"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = exp) do
    %{
      "name" => exp.name,
      "env" => exp.env,
      "algo" => exp.algo,
      "episodes" => exp.episodes,
      "max_steps" => exp.max_steps,
      "seed" => exp.seed,
      "returns" => exp.returns,
      "eval_return" => exp.eval_return
    }
  end

  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    new(
      name: map["name"],
      env: map["env"],
      algo: map["algo"] || "a2c",
      episodes: map["episodes"],
      max_steps: map["max_steps"],
      seed: map["seed"] || 1
    )
    |> Map.put(:returns, map["returns"] || [])
    |> Map.put(:eval_return, map["eval_return"])
  end

  defp path(dir, name), do: Path.join(dir, "#{name}.json")

  defp put_if(opts, nil, _key), do: opts
  defp put_if(opts, value, key), do: Keyword.put(opts, key, value)

  defp clean(opts, keys) do
    opts
    |> Keyword.take(keys)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp maybe_env_opts(opts, []), do: opts
  defp maybe_env_opts(opts, env_opts), do: Keyword.put(opts, :env, env_opts)
end
