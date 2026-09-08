defmodule Mix.Tasks.Gyx.Interact do
  @shortdoc "Reset and step a Gyx environment from the command line"
  @moduledoc """
  Opens a `Gyx.Session` and either plays random steps or a given action list.

      mix gyx.interact CartPole-v1
      mix gyx.interact CartPole-v1 --seed 0 --steps 8
      mix gyx.interact CartPole-v1 --action 1 --action 0 --render ansi
      mix gyx.interact Hopper-v4 --action 0.1,0.0,-0.1 --steps 3
  """

  use Mix.Task

  alias Gyx.{Agents.Random, Session}

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [seed: :integer, steps: :integer, action: :keep, render: :string]
      )

    id = List.first(rest) || Mix.raise("Usage: mix gyx.interact ENV_ID [options]")
    Mix.Task.run("app.start")

    session =
      case Session.start(id, seed: Keyword.get(opts, :seed)) do
        {:ok, session} -> session
        {:error, reason} -> Mix.raise("Could not start #{id}: #{inspect(reason)}")
      end

    Mix.shell().info("#{session.id} obs=#{fmt_obs(session.obs)}")

    scripted = Enum.map(Keyword.get_values(opts, :action), &parse_action/1)
    steps = Keyword.get(opts, :steps, if(scripted == [], do: 5, else: length(scripted)))

    session =
      Enum.reduce_while(1..steps, {session, scripted}, fn _, {session, queue} ->
        if Session.done?(session) do
          {:halt, {session, queue}}
        else
          {action, queue} = next_action(session, queue)

          case Session.step(session, action) do
            {:ok, session} ->
              Mix.shell().info(
                "  action=#{inspect(action)} reward=#{session.last_exp.reward} obs=#{fmt_obs(session.obs)}"
              )

              {:cont, {session, queue}}

            {:error, reason} ->
              Mix.raise("step failed: #{inspect(reason)}")
          end
        end
      end)
      |> elem(0)

    maybe_render(session, Keyword.get(opts, :render))

    Mix.shell().info(
      "return=#{session.return} terminated=#{session.terminated} truncated=#{session.truncated}"
    )
  end

  defp next_action(session, []),
    do: {Random.act(%Random{}, session.obs, session.env.action_space), []}

  defp next_action(_session, [action | rest]), do: {action, rest}

  defp maybe_render(_session, nil), do: :ok

  defp maybe_render(session, mode) do
    case Session.render(session, String.to_existing_atom(mode)) do
      {:ok, out} when is_binary(out) -> Mix.shell().info(out)
      {:ok, out} -> Mix.shell().info(inspect(out))
      {:error, reason} -> Mix.shell().error("render failed: #{inspect(reason)}")
    end
  end

  defp parse_action(raw) do
    raw = String.trim(raw)

    cond do
      String.contains?(raw, ",") ->
        raw |> String.split(",") |> Enum.map(&parse_number/1) |> List.to_tuple()

      true ->
        parse_number(raw)
    end
  end

  defp parse_number(raw) do
    case Integer.parse(raw) do
      {n, ""} ->
        n

      _ ->
        case Float.parse(raw) do
          {f, ""} -> f
          _ -> Mix.raise("bad action #{inspect(raw)}")
        end
    end
  end

  defp fmt_obs(%Nx.Tensor{} = tensor) do
    {type, bits} = Nx.type(tensor)
    dims = tensor |> Nx.shape() |> Tuple.to_list() |> Enum.join("×")
    "#{dims} #{type}#{bits}"
  end

  defp fmt_obs(obs), do: inspect(obs)
end
