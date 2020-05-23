# This Dockerfile details how the Artiatomi image at kmshin1397/artiatomi:latest was built
# to be pulled down by the start_artia.sh script. However, the Dockerfile should be moved 
# to within the actual official Artiatomi repository before docker build is called with it
# for the image to actually build properly.

FROM nvidia/cudagl:10.2-devel as builder
RUN apt-get update && apt-get install -y --no-install-recommends \
        mesa-utils \
        ocl-icd-libopencl1 \
        clinfo && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd
RUN apt-get update -y && apt-get install -y lsb-release && apt-get clean all
RUN apt-get install -y openmpi-bin openmpi-common openssh-client openssh-server libopenmpi-dev
RUN apt-get install -y libfftw3-dev libfftw3-doc
RUN apt-get install -y qt5-default libqt5opengl5-dev

RUN wget https://github.com/Kitware/CMake/releases/download/v3.15.5/cmake-3.15.5-Linux-x86_64.sh \
      -q -O /tmp/cmake-install.sh \
      && chmod u+x /tmp/cmake-install.sh \
      && mkdir /usr/bin/cmake \
      && /tmp/cmake-install.sh --skip-license --prefix=/usr/bin/cmake \
      && rm /tmp/cmake-install.sh

ENV PATH="/usr/bin/cmake/bin:${PATH}"

# Dependencies for Google Ceres, used by refineAlign
RUN apt-get install -y libgoogle-glog-dev
# BLAS & LAPACK
RUN apt-get install -y libatlas-base-dev
# Eigen3
RUN apt-get install -y libeigen3-dev
# SuiteSparse and CXSparse (optional)
# - If you want to build Ceres as a *static* library (the default)
#   you can use the SuiteSparse package in the main Ubuntu package
#   repository:
RUN apt-get install -y libsuitesparse-dev

RUN mkdir ceres
WORKDIR ./ceres
RUN wget http://ceres-solver.org/ceres-solver-1.14.0.tar.gz
RUN tar zxf ceres-solver-1.14.0.tar.gz
RUN mkdir ceres-bin && cd ceres-bin && cmake ../ceres-solver-1.14.0
RUN cd ceres-bin && make -j3 && make install


WORKDIR ..
RUN mkdir Artiatomi
WORKDIR ./Artiatomi

# Make cmake cache
COPY ./CMakeLists.txt ./CMakeLists.txt
COPY ./src ./src
RUN mkdir build && cd build && cmake ..

# Copy over segments of the Artiatomi package and build
FROM builder as executables
RUN cd build && make ImageStackAlignator
RUN cd build && make Clicker
RUN cd build && make EmSART
RUN cd build && make EmSARTSubVols
RUN cd build && make EmSARTRefine
RUN cd build && make AddParticles
RUN cd build && make SubTomogramAverageMPI
RUN cd build && pwd

RUN apt-get install -y git
RUN git clone https://github.com/uermel/cAligner.git

RUN cd cAligner && mkdir build && cd build && cmake .. && make cAligner

COPY --from=builder /ceres ./ceres

# Now that we have builds of the tools, go to what we minimally need to run
# the tools
FROM nvidia/cudagl:10.2-devel as runtime_env
RUN apt-get update && apt-get install -y --no-install-recommends \
        mesa-utils \
        ocl-icd-libopencl1 \
        clinfo && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd
RUN apt-get update -y && apt-get install -y lsb-release && apt-get clean all
RUN apt-get install -y openmpi-bin openmpi-common openssh-client openssh-server libopenmpi-dev
RUN apt-get install -y libfftw3-dev libfftw3-doc
RUN apt-get install -y qt5-default libqt5opengl5-dev
RUN apt-get install -y sudo
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,video,utility,display,graphics

# Google Ceres, used by refineAlign
RUN apt-get install -y libgoogle-glog-dev
# BLAS & LAPACK
RUN apt-get install -y libatlas-base-dev
# Eigen3
RUN apt-get install -y libeigen3-dev
# SuiteSparse and CXSparse (optional)
# - If you want to build Ceres as a *static* library (the default)
#   you can use the SuiteSparse package in the main Ubuntu package
#   repository:
RUN apt-get install -y libsuitesparse-dev
COPY --from=executables /Artiatomi/ceres ./ceres
RUN wget https://github.com/Kitware/CMake/releases/download/v3.15.5/cmake-3.15.5-Linux-x86_64.sh \
      -q -O /tmp/cmake-install.sh \
      && chmod u+x /tmp/cmake-install.sh \
      && mkdir /usr/bin/cmake \
      && /tmp/cmake-install.sh --skip-license --prefix=/usr/bin/cmake \
      && rm /tmp/cmake-install.sh

ENV PATH="/usr/bin/cmake/bin:${PATH}"
RUN cd ceres/ceres-bin && make install

# Set up ssh server
RUN mkdir /var/run/sshd

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22

RUN useradd -ms /bin/bash -u 1000 -g 0 -G root,artiatomi Artiatomi
RUN echo 'Artiatomi:Artiatomi' | chpasswd
USER Artiatomi
WORKDIR /home/Artiatomi

RUN (umask 077 && test -d /home/Artiatomi/.ssh || mkdir /home/Artiatomi/.ssh)
RUN (umask 077 && touch /home/Artiatomi/.ssh/authorized_keys)

# Copy over executables built in previous stages
COPY --from=executables /Artiatomi/build ./build
COPY --from=executables /Artiatomi/cAligner/build ./cAligner/build

ENV PATH="/home/Artiatomi/cAligner/build:/home/Artiatomi/build:${PATH}"