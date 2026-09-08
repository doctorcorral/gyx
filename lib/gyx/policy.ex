defmodule Gyx.Policy do
  @moduledoc """
  Predicate-chain policies, matching Synthex / CSHRL `PredProg` evaluation.

  A chain is a list of `{predicate, action}` clauses. The first predicate
  that holds on the observation list wins; otherwise `default` is used.
  """

  @type pred :: term()
  @type feature :: term()
  @type chain :: [{pred(), term()}]
  @type obs :: [number()] | tuple()

  @spec chain_action(chain(), term(), obs()) :: term()
  def chain_action(chain, default, obs) do
    obs = List.wrap(obs) |> List.flatten() |> normalize_obs()

    Enum.find_value(chain, default, fn {pred, action} ->
      if eval_pred(pred, obs), do: action
    end)
  end

  @spec eval_pred(pred(), [number()]) :: boolean()
  def eval_pred(nil, _obs), do: true
  def eval_pred("truep", _obs), do: true
  def eval_pred(:truep, _obs), do: true
  def eval_pred("falsep", _obs), do: false
  def eval_pred(:falsep, _obs), do: false
  def eval_pred(["feat", feat], obs), do: eval_feature(feat, obs)
  def eval_pred(["not", pred], obs), do: not eval_pred(pred, obs)
  def eval_pred(["and", a, b], obs), do: eval_pred(a, obs) and eval_pred(b, obs)
  def eval_pred(["or", a, b], obs), do: eval_pred(a, obs) or eval_pred(b, obs)
  def eval_pred({:feat, feat}, obs), do: eval_feature(feat, obs)
  def eval_pred({:not, pred}, obs), do: not eval_pred(pred, obs)
  def eval_pred({:and, a, b}, obs), do: eval_pred(a, obs) and eval_pred(b, obs)
  def eval_pred({:or, a, b}, obs), do: eval_pred(a, obs) or eval_pred(b, obs)
  def eval_pred(_, _obs), do: false

  defp eval_feature(["axis", i, thresh], obs), do: at(obs, i) < thresh
  defp eval_feature(["diag", i, j, coeff], obs), do: coeff * at(obs, i) + at(obs, j) < 0

  defp eval_feature(["sq_diag", i, j, coeff], obs),
    do: coeff * at(obs, i) * at(obs, i) + at(obs, j) < 0

  defp eval_feature(["prod", i, j, thresh], obs), do: at(obs, i) * at(obs, j) < thresh

  defp eval_feature(["tridiag", i, j, k, ci, cj], obs) do
    ci * at(obs, i) + cj * at(obs, j) + at(obs, k) < 0
  end

  defp eval_feature(["sin_axis", i, thresh], obs), do: :math.sin(at(obs, i)) < thresh
  defp eval_feature(["cos_axis", i, thresh], obs), do: :math.cos(at(obs, i)) < thresh
  defp eval_feature(["wavelet_box", i, lo, hi], obs), do: at(obs, i) >= lo and at(obs, i) < hi

  defp eval_feature(["wavelet_ricker", i, b, a, t], obs) do
    z = (at(obs, i) - b) / a
    (1.0 - z * z) * :math.exp(-(z * z) / 2.0) < t
  end

  defp eval_feature(["swap_outcome", _k, pred], obs), do: eval_pred(pred, obs)
  defp eval_feature(["swap_outcome_neg", _k, pred], obs), do: not eval_pred(pred, obs)
  defp eval_feature(_, _obs), do: false

  defp at(obs, i) when is_integer(i) and i >= 0, do: Enum.at(obs, i) || 0.0

  defp normalize_obs(obs) do
    Enum.map(obs, fn
      x when is_number(x) -> x * 1.0
      x when is_tuple(x) -> normalize_obs(Tuple.to_list(x))
      x -> x
    end)
    |> List.flatten()
  end
end
