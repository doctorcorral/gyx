defprotocol Gyx.Agent do
  @moduledoc """
  Action selection and learning used by `Gyx.Trainers.Episodic`.
  """

  @spec act(t(), term(), term()) :: term()
  def act(agent, observation, actions)

  @spec learn(t(), Gyx.Core.Exp.t(), [term()]) :: t()
  def learn(agent, exp, actions)

  @spec finish_episode(t()) :: t()
  def finish_episode(agent)

  @spec eval(t()) :: t()
  def eval(agent)
end
