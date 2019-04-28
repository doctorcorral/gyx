
![test](https://raw.githubusercontent.com/doctorcorral/gyx/master/images/gyxheader.png)

# Gyx

The goal of this project is to explore the intrinsically distributed qualities of Elixir for implementing real world Reinforcement Learning environments. 

At this moment, this repository contains ad hoc implementations of environments and interacting agents. 
Initial abstractions are already stablished, so higher level programs like training procedures can seamesly be integrated with particular environment, agents, and learning strategies.

## Usage
### Solve Blackjack with [SARSA](https://en.wikipedia.org/wiki/State%E2%80%93action%E2%80%93reward%E2%80%93state%E2%80%93action)
Environments in `Gyx` can be implemented by using [`Env`](https://github.com/doctorcorral/gyx/blob/master/lib/framework/env.ex) behaviour.

A wrapper environment module for calling [OpenAI Gym](https://gym.openai.com/) environments can be found in [`Gyx.Gym.Environment`](https://github.com/doctorcorral/gyx/blob/master/lib/Gym/environment.ex)

> NOTE: Gym library must be installed. You can do it by yourself or 
use the `Dockerfile` on this repo for developlment purposes. 
Just run `docker build -t gyx ./` on this directory, then `docker run gyx` will
allow you to have everything set up, run `iex -S mix` and start playing. 

For a Gym environment to be used, it is necessary to initialize the `Gyx` process to a particular environment by calling `make/1`

```Elixir
iex(1)> Gyx.Gym.Environment.make("Blackjack-v0")
```

Now, the process `Gyx.Gym.Environment` will handle environment state and reference for the serving `:python` process.

Now it is possible to run a training session with

```Elixir
iex(2)> Gyx.Trainers.TrainerSarsa.train
```

Here, `Gyx.Trainers.TrainerSarsa.train` is already configured to use environment `Gyx.Gym.Environment` and agent `Gyx.Agents.SARSA.Agent` wich in turn, is configured to use `Gyx.Qstorage.QGenServer` as a *Q* table storage module.

After finishing the training, optimal *Q* values can be seen with 

```Elixir
iex(3)> Gyx.Qstorage.QGenServer.get_q
```


