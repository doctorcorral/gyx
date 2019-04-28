FROM ubuntu:18.04
RUN apt update && apt install -y wget python3 python3-pip emacs vim
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get -y update
RUN apt-get install -y esl-erlang elixir
RUN mix local.hex --force
#RUN mix deps.get

RUN pip3 install https://download.pytorch.org/whl/cpu/torch-1.0.1.post2-cp36-cp36m-linux_x86_64.whl
RUN pip3 install torchvision gym ipython

ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  

ENV MIX_ENV dev

#RUN echo 'alias python="python3"' >> ~/.bashrc

ENV LANG en_US.UTF-8 

COPY . /gyx
WORKDIR /gyx
#ENTRYPOINT ["iex", "-S", "mix"]