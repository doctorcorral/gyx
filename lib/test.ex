defmodule Test do
  def test_agent do
    IO.puts("////////")
    Agents.BlackjackAgent.start_link()
    Env.Blackjack.start_link()
    Env.Blackjack.reset()
    env = Env.Blackjack.get_state_abstraction()
    #IO.inspect(env)
    Agents.BlackjackAgent.q_get(env, 0)
    Agents.BlackjackAgent.q_set(env, 0, 13)
    Agents.BlackjackAgent.q_set(env, 1, 42)
    #IO.inspect(Agents.BlackjackAgent.q_get(env, 1))
    IO.inspect(Agents.BlackjackAgent.get_q())

    env2 = Env.Blackjack.step(1).next_state
    Agents.BlackjackAgent.q_set(env2, 1, 7)
    Agents.BlackjackAgent.q_get(env2, 1)
    r = Agents.BlackjackAgent.get_action(env)
    IO.inspect(Agents.BlackjackAgent.get_q())
    IO.inspect(r)

    env3 = Env.Blackjack.step(0).next_state
    Agents.BlackjackAgent.get_action(env3)


  end
end
