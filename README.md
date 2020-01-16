
![test](https://raw.githubusercontent.com/doctorcorral/gyx/master/images/gyxheader-elixir.png)

# Gyx

The goal of this project is to explore the intrinsically distributed qualities of Elixir for implementing real world Reinforcement Learning environments. 

At this moment, this repository contains ad hoc implementations of environments and interacting agents. 
Initial abstractions are already stablished, so higher level programs like training procedures can seamesly be integrated with particular environment, agents, and learning strategies.

## Usage
### Solve Blackjack with [SARSA](https://en.wikipedia.org/wiki/State%E2%80%93action%E2%80%93reward%E2%80%93state%E2%80%93action)
Environments in `Gyx` can be implemented by using [`Env`](https://github.com/doctorcorral/gyx/blob/master/lib/core/env.ex) behaviour.

A wrapper environment module for calling [OpenAI Gym](https://gym.openai.com/) environments can be found in [`Gyx.Environments.Gym`](https://github.com/doctorcorral/gyx/blob/master/lib/environments/gym/environment.ex)

> NOTE: Gym library must be installed. You can do it by yourself or 
use the `Dockerfile` on this repo for developlment purposes. 
Just run `docker build -t gyx ./` on this directory, then `docker run -it gyx bash` will
allow you to have everything set up, run `iex -S mix` and start playing. 

For a Gym environment to be used, it is necessary to initialize the `Gyx` process to a particular environment by calling `make/1`

```Elixir
iex(1)> Gyx.Environments.Gym.start_link [], name: :gym
```
Named process `:gym` can now be associated with a particular gym environment

```Elixir
iex(2)> Gyx.Environments.Gym.make :gym, "Blackjack-v0"
```

Environment interactions are performed through `step`, getting an experience back

```Elixir
iex(3)> Gyx.Environments.Gym.step :gym, 1
%Gyx.Core.Exp{
  action: 1,
  done: false,
  info: %{gym_info: {:"$erlport.opaque", :python, <<128, 2, 125, 113, 0, 46>>}},
  next_state: {20, 7, false},
  reward: 0.0,
  state: {13, 7, false}
}
```

Environment processes IDs can be used directly
```Elixir
iex(4)> alias Gyx.Environments.Gym
iex(5)> {:ok, gym_proc} = Gym.start_link [], [] 
iex(6)> Gym.make gym_proc, "SpaceInvaders-v0"
```

It is possible to render the screen for Gym based environments with `Gyx.Environments.Gym.render` which relies on the internal Python Gym render method, alternatively, the screen can be rendered directly on the terminal.
```Elixir
iex(7)> Gym.render gym_proc, :terminal, scale: 0.9
```

<img src="https://raw.githubusercontent.com/doctorcorral/gyx/master/images/spaceinvs1.png)" align="left" height="42" width="42" >

Any Environment contains action and observation space definitions, which can be used to sample random actions and observations
```Elixir
iex(7)> action_space = :sys.get_state(gym_proc).action_space
%Gyx.Core.Spaces.Discrete{n:6, random_algorithm: :explus, seed: {1, 2, 3}}
iex(8)> Gyx.Core.Spaces.sample action_space
{:ok, 4}
```
