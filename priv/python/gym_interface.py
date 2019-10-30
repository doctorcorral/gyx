import gym
from erlport.erlang import set_encoder, set_decoder
from erlport.erlterms import List

def make(envname):
    print("🐍 🐍 🐍 -- Imporing Gym environment from Python:")
    en = str(envname, encoding='ascii')
    print("⏩ ⏩ ⏩ -- {0}".format(envname))
    env = gym.make(en)
    initial_state = env.reset()
    action_space = str(env.action_space).strip()
    observation_space = str(env.observation_space).strip()
    return (env, initial_state, action_space, observation_space)


def step(env, _step):
    state, reward, done, info = env.step(_step)
    return (env, (state, float(reward), done, info))


def render(env):
    #    env.env.ale.saveScreenPNG(b'test_image.png')
    #res = env.render(mode='rgb_array')
    env.render()


def reset(env):
    initial_state = env.reset()
    return (env,
            initial_state,
            str(env.action_space).strip(),
            str(env.observation_space).strip())


def action_space_sample(env):
    return env.action_space.sample()


def getScreenRGB2(env, channel):
    #    return List([List([List(j[0]) for j in i]) 
    print(env.ale.getScreenRGB2().shape)
    return List([List([j[int(channel)] for j in i]) 
                    for i in env.ale.getScreenRGB2()])
