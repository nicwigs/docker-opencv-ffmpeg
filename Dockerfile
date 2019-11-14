FROM nvidia/cuda:10.0-cudnn7-devel-ubuntu18.04

ARG PYTHON_VERSION=3.7
ARG OPENCV_VERSION=4.1.1

# Install all dependencies for OpenCV
RUN apt-get -y update --fix-missing && \
    apt-get -y install --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-dev \
        $( [ ${PYTHON_VERSION%%.*} -ge 3 ] && echo "python${PYTHON_VERSION%%.*}-distutils" ) \
        wget \
        unzip \
        cmake \
        libtbb2 \
        gfortran \
        apt-utils \
        pkg-config \
        checkinstall \
        qt5-default \
        build-essential \
        libatlas-base-dev \
        libgtk2.0-dev \
        libavcodec57 \
        libavcodec-dev \
        libavformat57 \
        libavformat-dev \
        libavutil-dev \
        libswscale4 \
        libswscale-dev \
        libjpeg8-dev \
        libpng-dev \
        libtiff5-dev \
        libdc1394-22 \
        libdc1394-22-dev \
        libxine2-dev \
        libv4l-dev \
        libgstreamer1.0 \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-0 \
        libgstreamer-plugins-base1.0-dev \
        libglew-dev \
        libpostproc-dev \
        libeigen3-dev \
        libtbb-dev \
        zlib1g-dev \
        libsm6 \
        libxext6 \
        libxrender1 \
        autoconf \
        automake \
        libtool \
        yasm \
        libjpeg-dev \
        libtiff-dev \
        libpq-dev \
    && \


# install python dependencies
    sysctl -w net.ipv4.ip_forward=1 && \
    wget https://bootstrap.pypa.io/get-pip.py --progress=bar:force:noscroll --no-check-certificate && \
    python${PYTHON_VERSION} get-pip.py && \
    rm get-pip.py && \
    pip${PYTHON_VERSION} install numpy && \

# Install OpenCV
    wget https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip -O opencv.zip --progress=bar:force:noscroll --no-check-certificate && \
    unzip -q opencv.zip && \
    mv /opencv-${OPENCV_VERSION} /opencv && \
    rm opencv.zip && \
    wget https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip -O opencv_contrib.zip --progress=bar:force:noscroll --no-check-certificate && \
    unzip -q opencv_contrib.zip && \
    mv /opencv_contrib-${OPENCV_VERSION} /opencv_contrib && \
    rm opencv_contrib.zip && \

# Prepare build
    mkdir /opencv/build && \
    cd /opencv/build && \
    cmake \
      -D CMAKE_BUILD_TYPE=RELEASE \
      -D BUILD_PYTHON_SUPPORT=ON \
      -D BUILD_DOCS=ON \
      -D BUILD_PERF_TESTS=OFF \
      -D BUILD_TESTS=OFF \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
      -D BUILD_opencv_python3=$( [ ${PYTHON_VERSION%%.*} -ge 3 ] && echo "ON" || echo "OFF" ) \
      -D BUILD_opencv_python2=$( [ ${PYTHON_VERSION%%.*} -lt 3 ] && echo "ON" || echo "OFF" ) \
      -D PYTHON${PYTHON_VERSION%%.*}_EXECUTABLE=$(which python${PYTHON_VERSION}) \
      -D PYTHON_DEFAULT_EXECUTABLE=$(which python${PYTHON_VERSION}) \
      -D OPENCV_GENERATE_PKGCONFIG=ON \
      -D BUILD_EXAMPLES=OFF \
      -D WITH_IPP=OFF \
      -D WITH_FFMPEG=ON \
      -D WITH_GSTREAMER=ON \
      -D WITH_V4L=ON \
      -D WITH_LIBV4L=ON \
      -D WITH_TBB=ON \
      -D WITH_QT=ON \
      -D WITH_OPENGL=ON \
      -D ENABLE_PRECOMPILED_HEADERS=OFF \
      .. \
    && \

# Build, Test and Install
    cd /opencv/build && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \

# cleaning
    apt-get -y remove \
        gfortran \
        apt-utils \
        checkinstall \
        libatlas-base-dev \
        libgtk2.0-dev \
        libavcodec-dev \
        libavutil-dev \
        libjpeg8-dev \
        libpng12-dev \
        libtiff5-dev \
        libdc1394-22-dev \
        libxine2-dev \
        libv4l-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libglew-dev \
        libpostproc-dev \
        libeigen3-dev \
        zlib1g-dev \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /opencv_contrib && \
    rm -rf /opencv && \

# Set the default python and install PIP packages
    update-alternatives --install /usr/bin/python${PYTHON_VERSION%%.*} python${PYTHON_VERSION%%.*} /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1 && \

# Call default command.
    python --version && \
    python -c "import cv2 ; print(cv2.__version__)"

RUN cd /usr/local/lib/pkgconfig && mv opencv4.pc opencv.pc

RUN apt-get install -y python3-setuptools
RUN apt-get install -y git && \
    apt-get autoremove -y && \
    apt-get clean

RUN git clone https://github.com/FFmpeg/nv-codec-headers.git /root/nv-codec-headers && \
    cd root/nv-codec-headers && \
    git checkout sdk/9.0 && \
    make && \
    make install && \
    cd .. && rm -rf nv-codec-headers

RUN apt-get install -y libx264-dev && \
    apt-get autoremove -y && \
    apt-get clean

RUN git clone https://github.com/FFmpeg/FFmpeg /root/ffmpeg && \ 
    cd /root/ffmpeg && ./configure \ 
    --enable-gpl \ 
    --enable-nvenc --enable-cuda \
    --enable-cuvid \
    --enable-libx264 \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-cflags=-I/usr/local/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 && \
    make -j8 && \
    make install -j8 && \
    cd /root && rm -rf ffmpeg

#Check
RUN ffmpeg -codecs|grep nvenc

# Lib for encoding
RUN apt-get install -y libnvidia-compute-430 libnvidia-decode-430 libnvidia-encode-430 libnvidia-ifr1-430 libnvidia-fbc1-430 libnvidia-gl-430 && \
    apt-get autoremove -y && \
    apt-get clean