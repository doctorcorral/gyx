defmodule Gyx.Experiment do
  @moduledoc """
  A named learning run: environment, algorithm, and trainer options.

  Each name is a directory under `experiments/` by default:

      experiments/cart/experiment.json
      experiments/cart/agent.bin

  JSON is the spec and metrics. `agent.bin` is a versioned ETF of the
  learned state. `encode` functions and Axon graphs are rebuilt from
  `Gyx.Trainers.Presets` on load. The Mix CLI and the optional `ui/`
  app both call this module.
  """

  alias Gyx.Experiment.Checkpoint
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
    {fresh?, opts} = Keyword.pop(opts, :fresh, false)
    {built, preset} = Presets.build(exp.algo, exp.env)
    agent = if exp.agent && not fresh?, do: exp.agent, else: built

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

  @doc """
  Greedy evaluation of a checkpointed agent.

  Pass `env:` to evaluate on another id (same observation/action
  contract), e.g. native `Hopper-v4` → `gymnasium/Hopper-v4`.
  """
  @spec eval(t(), keyword()) :: t()
  def eval(%__MODULE__{} = exp, opts \\ []) do
    agent = exp.agent || raise ArgumentError, "experiment has no checkpoint"
    env = opts |> Keyword.get(:env, exp.env) |> to_string()

    eval_opts =
      env
      |> Presets.eval_opts()
      |> then(fn preset ->
        if env == exp.env, do: maybe_env_opts(preset, exp.env_opts), else: preset
      end)
      |> Keyword.merge(clean(opts, [:episodes, :max_steps, :seed]))

    %{exp | eval_return: Episodic.evaluate(env, agent, eval_opts)}
  end

  @spec save(t(), Path.t()) :: :ok | {:error, term()}
  def save(%__MODULE__{} = exp, dir \\ "experiments") do
    name = exp.name || raise ArgumentError, "experiment needs a :name to save"
    File.mkdir_p!(root(dir, name))

    with :ok <- File.write(spec_path(dir, name), Jason.encode!(to_map(exp), pretty: true)) do
      write_agent(exp, dir, name)
    end
  end

  @spec load(String.t(), Path.t()) :: {:ok, t()} | {:error, term()}
  def load(name, dir \\ "experiments") do
    with {:ok, json} <- File.read(spec_path(dir, name)),
         {:ok, map} <- Jason.decode(json) do
      attach_agent(from_map(map), dir, name)
    end
  end

  @spec list(Path.t()) :: [String.t()]
  def list(dir \\ "experiments") do
    case File.ls(dir) do
      {:ok, names} ->
        names
        |> Enum.filter(&File.regular?(spec_path(dir, &1)))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @spec root(Path.t(), String.t()) :: Path.t()
  def root(dir, name), do: Path.join(dir, name)

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
    |> maybe_checkpoint(exp.agent)
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

  defp spec_path(dir, name), do: Path.join(root(dir, name), "experiment.json")
  defp agent_path(dir, name), do: Path.join(root(dir, name), "agent.bin")

  defp attach_agent(exp, dir, name) do
    case File.read(agent_path(dir, name)) do
      {:ok, bin} ->
        case Checkpoint.restore(exp, bin) do
          {:ok, agent} -> {:ok, %{exp | agent: agent}}
          {:error, reason} -> {:error, reason}
        end

      {:error, :enoent} ->
        {:ok, exp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_agent(%{agent: nil}, dir, name) do
    _ = File.rm(agent_path(dir, name))
    :ok
  end

  defp write_agent(exp, dir, name) do
    File.write(agent_path(dir, name), Checkpoint.dump(exp))
  end

  defp maybe_checkpoint(map, nil), do: map

  defp maybe_checkpoint(map, _agent) do
    Map.put(map, "checkpoint", %{"v" => 1, "format" => "etf", "file" => "agent.bin"})
  end

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
