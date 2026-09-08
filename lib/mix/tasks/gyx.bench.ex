defmodule Mix.Tasks.Gyx.Bench do
  @shortdoc "Compare native Farama, tree, gymnasium wrap, and Python MuJoCo step time"
  @moduledoc """
  Wall-clock `reset`/`step` throughput for four backends:

  * **native** — Farama (`Hopper-v4`) via the EXLA-compiled engine
  * **tree** — approximate `Gyx.Physics.Tree` (`tree/Hopper-v4`)
  * **wrap** — `gymnasium/Hopper-v4` (Elixir Port → real MuJoCo)
  * **gym** — in-process Python `gymnasium.make`

      mix gyx.bench
      mix gyx.bench --steps 4000 --warmup 200
      mix gyx.bench --id Hopper-v4 --id Ant-v4

  No rendering. Random actions. Native aims to match Farama; wrap/gym are C MuJoCo.
  """

  use Mix.Task

  alias Gyx.Core.Spaces

  @ids [
    "InvertedPendulum-v4",
    "InvertedDoublePendulum-v4",
    "Reacher-v4",
    "Swimmer-v4",
    "Hopper-v4",
    "Walker2d-v4",
    "HalfCheetah-v4",
    "Ant-v4"
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [steps: :integer, warmup: :integer, seed: :integer, id: :keep, python: :string]
      )

    steps = Keyword.get(opts, :steps, 2000)
    warmup = Keyword.get(opts, :warmup, 100)
    seed = Keyword.get(opts, :seed, 0)
    ids = Keyword.get_values(opts, :id) |> then(fn [] -> @ids; ids -> ids end)
    python = Keyword.get(opts, :python, System.find_executable("python3") || "python3")

    Mix.Task.run("app.start")
    :rand.seed(:exsss, {seed, 1_337, 42})

    Mix.shell().info(
      "native Farama vs tree vs gymnasium/* vs Python MuJoCo — #{steps} steps (#{warmup} warmup), no render"
    )

    native = Map.new(ids, fn id -> {id, bench_gyx(id, steps, warmup, seed)} end)

    tree =
      Map.new(ids, fn id ->
        {id, bench_gyx("tree/#{id}", steps, warmup, seed)}
      end)

    wrap =
      if Gyx.Envs.Gymnasium.available?() do
        Map.new(ids, fn id ->
          {id, bench_gyx("gymnasium/#{id}", steps, warmup, seed)}
        end)
      else
        Mix.shell().error("gymnasium/* wrappers unavailable")
        %{}
      end

    gym = bench_python(python, ids, steps, warmup, seed)
    print_table(ids, native, tree, wrap, gym)
  end

  defp bench_gyx(id, steps, warmup, seed) do
    {:ok, env} = Gyx.make(id)
    {env, _, _} = Gyx.reset(env, seed: seed)
    {env, _} = run_steps(env, warmup)

    {us, {_env, resets}} = :timer.tc(fn -> run_steps(env, steps) end)
    seconds = us / 1_000_000

    %{
      id: id,
      steps: steps,
      resets: resets,
      seconds: seconds,
      steps_per_sec: steps / seconds,
      us_per_step: us / steps
    }
  end

  defp run_steps(env, n) do
    Enum.reduce(1..n, {env, 0}, fn _, {env, resets} ->
      {:ok, action} = Spaces.sample(env.action_space)

      case Gyx.step(env, action) do
        {:ok, env, %{terminated: t, truncated: tr}} when t or tr ->
          {env, _, _} = Gyx.reset(env)
          {env, resets + 1}

        {:ok, env, _} ->
          {env, resets}
      end
    end)
  end

  defp bench_python(python, ids, steps, warmup, seed) do
    script = Path.join([:code.priv_dir(:gyx), "bench", "gymnasium_mujoco.py"])

    id_args = Enum.flat_map(ids, fn id -> ["--id", id] end)

    args =
      [
        script,
        "--steps",
        Integer.to_string(steps),
        "--warmup",
        Integer.to_string(warmup),
        "--seed",
        Integer.to_string(seed)
      ] ++ id_args

    case System.cmd(python, args, stderr_to_stdout: false) do
      {out, 0} ->
        out
        |> Jason.decode!()
        |> Map.new(fn row -> {row["id"], atomize_row(row)} end)

      {out, code} ->
        Mix.shell().error("Python gym bench failed (#{code}): #{String.slice(out, 0, 400)}")
        %{}
    end
  rescue
    e ->
      Mix.shell().error("Python gym bench unavailable: #{Exception.message(e)}")
      %{}
  end

  defp atomize_row(%{"error" => err} = row) do
    %{id: row["id"], error: err}
  end

  defp atomize_row(row) do
    %{
      id: row["id"],
      steps: row["steps"],
      resets: row["resets"],
      seconds: row["seconds"],
      steps_per_sec: row["steps_per_sec"],
      us_per_step: row["us_per_step"]
    }
  end

  defp print_table(ids, native, tree, wrap, gym) do
    Mix.shell().info("")

    Mix.shell().info(
      row([
        "env",
        "native /s",
        "tree /s",
        "wrap /s",
        "gym /s",
        "nat μs",
        "tree μs",
        "wrap μs",
        "gym μs",
        "gym/nat"
      ])
    )

    Mix.shell().info(String.duplicate("-", 118))

    Enum.each(ids, fn id ->
      Mix.shell().info(row(format_row(id, native[id], tree[id], wrap[id], gym[id])))
    end)
  end

  defp format_row(id, native, tree, wrap, gym) do
    [
      id,
      sps(native),
      sps(tree),
      sps(wrap),
      sps(gym),
      us(native),
      us(tree),
      us(wrap),
      us(gym),
      overhead(native, gym)
    ]
  end

  defp sps(nil), do: "—"
  defp sps(%{error: _}), do: "err"
  defp sps(%{steps_per_sec: n}), do: fmt(n)

  defp us(nil), do: "—"
  defp us(%{error: _}), do: "—"
  defp us(%{us_per_step: n}), do: fmt(n)

  defp overhead(%{steps_per_sec: w}, %{steps_per_sec: g}) when g > 0 do
    "#{fmt(g / w)}x"
  end

  defp overhead(_, _), do: "—"

  defp row(cols) do
    widths = [28, 10, 10, 10, 10, 9, 9, 9, 9, 9]

    cols
    |> Enum.zip(widths)
    |> Enum.map(fn {c, w} -> String.pad_trailing(to_string(c), w) end)
    |> Enum.join(" ")
  end

  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 1)
  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
end
