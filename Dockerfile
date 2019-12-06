FROM ubuntu:18.04
LABEL maintainer="ricardo@simbiotic.ai"

RUN apt update && apt install -y wget python3 python3-pip emacs
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get -y update
RUN apt-get install -y esl-erlang elixir
RUN apt-get install -y python-opengl
RUN apt-get install -y xvfb xserver-xephyr vnc4server
RUN apt-get install -y python-pil scrot
RUN apt-get install -y lsof telnet
RUN apt-get install -y build-essential erlang-dev libatlas-base-dev

WORKDIR /gyx
COPY . .

RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get

RUN mv /gyx/priv/.iex.exs ~/

#RUN pip3 install https://download.pytorch.org/whl/cpu/torch-1.0.1.post2-cp36-cp36m-linux_x86_64.whl
#RUN pip3 install torchvision 
RUN pip3 install ipython
RUN pip3 install pyvirtualdisplay
RUN pip3 install gym[atari]
#RUN pip3 install gym-retro

ENV TERM xterm
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  

ENV APP_NAME gyx
ENV MIX_ENV dev