defmodule GyxUI.EnvLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint GyxUI.Endpoint

  test "FrozenLake Down moves the agent down on a deterministic lake" do
    {:ok, view, _html} = live(build_conn(), "/")
    html = render_change(view, "select", %{id: "FrozenLake-v1"})
    assert html =~ "is_slippery"
    assert html =~ "obs=0"

    html = render_click(view, "act", %{"action" => "1"})
    assert html =~ "obs=4"
    assert html =~ "Down"
    refute html =~ "slipped"
  end

  test "CartPole and MountainCar expose Train Q-learning" do
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "Train Q-learning"
    assert html =~ "CartPole-v1"

    html = render_change(view, "select", %{id: "MountainCar-v0"})
    assert html =~ "Train Q-learning"
    assert html =~ "MountainCar"
  end

  test "algorithm picker switches the train label and lists new envs" do
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "Pendulum-v1"
    assert html =~ "Acrobot-v1"
    assert html =~ "SARSA"

    html = render_change(view, "algo", %{algo: "sarsa"})
    assert html =~ "Train SARSA"

    html = render_change(view, "select", %{id: "Pendulum-v1"})
    assert html =~ "Torque"
    assert html =~ "Pendulum"

    html = render_change(view, "algo", %{algo: "reinforce"})
    assert html =~ "Train REINFORCE"

    html = render_change(view, "algo", %{algo: "a2c"})
    assert html =~ "Train A2C"

    html = render_change(view, "algo", %{algo: "ppo"})
    assert html =~ "Train PPO"

    html = render_change(view, "select", %{id: "Hopper-v4"})
    assert html =~ "Hopper"
    assert html =~ "scene3d"
    assert html =~ "a0"
    assert html =~ "Train PPO"
  end

  test "is_slippery can be toggled as a parameter" do
    {:ok, view, _html} = live(build_conn(), "/")
    render_change(view, "select", %{id: "FrozenLake-v1"})

    html = render_change(view, "params", %{"is_slippery" => "true", "map_name" => "4x4"})
    assert html =~ "is_slippery=true"

    html = render_change(view, "params", %{"is_slippery" => "false", "map_name" => "4x4"})
    assert html =~ "is_slippery=false"
  end

  test "training progress updates the completion bar and learning curve" do
    {:ok, view, html} = live(build_conn(), "/")
    refute html =~ "Learning curve"

    send(
      view.pid,
      {:train_progress, "CartPole-v1", "q_learning", 0,
       %{
         episode: 40,
         episodes: 100,
         return: 18.0,
         mean: 12.5,
         curve: [4.0, 8.0, 12.0, 18.0],
         smooth: [4.0, 6.0, 8.0, 10.5]
       }}
    )

    html = render(view)
    assert html =~ "Learning"
    assert html =~ "ep 40/100"
    assert html =~ "mean 12.5"
    assert html =~ "last 18.0"
    assert html =~ "width: 40.0%"
    assert html =~ "Learning curve"
    assert html =~ "<polyline"
  end

  test "chrome exposes theme toggle and grouped catalogs" do
    {:ok, _view, html} = live(build_conn(), "/")
    assert html =~ "theme-toggle"
    assert html =~ "Classic · Elixir"
    assert html =~ "Native Farama · Elixir MJCF"
    assert html =~ "Tree · approximate"
    assert html =~ "Gymnasium · C MuJoCo"
    assert html =~ "Gymnasium · Atari"
    assert html =~ "gymnasium/Hopper-v4"
    assert html =~ "gymnasium/ALE/Pong-v5"
    assert html =~ "tree/Hopper-v4"
    assert html =~ "Pure Elixir environment"
    assert html =~ "Random policy"
    assert html =~ "gyx-mark.png"
    assert html =~ "Playground"
    assert html =~ "Reinforcement Learning"
  end

  @tag :atari
  test "Pong shows the ALE viewport, pixel stage, and joystick" do
    {:ok, view, _html} = live(build_conn(), "/")
    html = render_change(view, "select", %{id: "gymnasium/ALE/Pong-v5"})
    assert html =~ "Gymnasium · Atari"
    assert html =~ "gymnasium/ALE/Pong-v5"
    assert html =~ "stage-atari"
    assert html =~ "pixels"
    assert html =~ "ALE/Stella"
    assert html =~ "FIRE"
    assert html =~ "Left"
    assert html =~ "image/png"
    assert html =~ "Train A2C"
    refute html =~ "Switch physics backend"
  end

  test "backend card names the running engine and offers sibling backends" do
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "Classic · Elixir"
    assert html =~ "No MuJoCo and no Python"
    refute html =~ "Switch physics backend"

    html = render_change(view, "select", %{id: "Hopper-v4"})
    assert html =~ "Native Elixir · EXLA" or html =~ "Native Elixir · BEAM"
    assert html =~ "Gold-tested vs gymnasium.make"
    assert html =~ "Switch physics backend"
    assert html =~ "Tree (approx)"
    assert html =~ "C MuJoCo"
    assert html =~ "Hopper-v4"

    html = render_change(view, "select", %{id: "tree/Hopper-v4"})
    assert html =~ "Tree · approximate"
    assert html =~ "Not a Farama gold match"
    assert html =~ "tree/Hopper-v4"
    assert html =~ "Gyx.Physics.Tree"
  end

  test "serves the gyx mark from the README logo" do
    conn = get(build_conn(), "/images/gyx-mark.png")
    assert conn.status == 200
    assert binary_part(conn.resp_body, 0, 8) == <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  end
end
