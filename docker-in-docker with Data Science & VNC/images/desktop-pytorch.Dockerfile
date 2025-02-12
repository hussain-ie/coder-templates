FROM codercom/enterprise-vnc:ubuntu

RUN exec bash -l
## install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

ENV PATH=/home/coder/.local/bin:$PATH

ARG TF_VERSION=

RUN pip3 install jupyterlab


RUN mkdir -p $XFCE_DEST_DIR
RUN cp -rT $XFCE_BASE_DIR $XFCE_DEST_DIR

# Create user data directory
RUN mkdir -p /home/coder/data
# make user share directory
RUN mkdir -p /home/coder/share


# Install and start filebrowser
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

#RUN nohup filebrowser --noauth --root /home/coder --port=4040 --address=0.0.0.0 >/dev/null 2>&1 &
RUN nohup code-server --auth none --port 13337 --host 0.0.0.0 &



RUN cp /etc/zsh/newuser.zshrc.recommended /home/coder/.zshrc
RUN echo "export PATH=/home/coder/.local/bin:$PATH" >> /home/coder/.bashrc
RUN echo "export PATH=/home/coder/.local/bin:$PATH" >> /home/coder/.zshrc

##RUN echo "nohup supervisord"  >> /home/coder/.zshrc
RUN echo "nohup code-server --auth none --port 13337 &" >> /home/coder/.zshrc
##RUN echo "nohup jupyter lab --port=8888 --ServerApp.token=''  --ip='*' &"  >> /home/coder/.zshrc
##RUN echo "nohup filebrowser --noauth --root /home/coder >/dev/null 2>&1 &" >> /home/coder/.zshrc
RUN source /home/coder/.zshrc

##RUN echo "nohup supervisord"  >> /home/coder/.bashrc
RUN echo "nohup code-server --auth none --port 13337 &" >> /home/coder/.bashrc
##RUN echo "nohup jupyter lab --port=8888 --ServerApp.token='' --ip='*' &"  >> /home/coder/.bashrc
##RUN echo "nohup filebrowser --noauth --root /home/coder >/dev/null 2>&1 &" >> /home/coder/.bashrc

RUN pip3 install --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cu121
RUN pip3 install --upgrade matplotlib nltk numpy pandas Pillow plotly PyYAML flask
RUN pip3 install --upgrade scipy scikit-image scikit-learn sympy seaborn transformers tqdm


USER root

RUN apt-get update
RUN apt-get install nano -y

#RUN chown -R coder:coder /opt

###RUN sudo chmod 666 /var/run/docker.sock

USER coder
