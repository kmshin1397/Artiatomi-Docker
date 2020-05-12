# artiatomi-tools
A containerized wrapper around the Artiatomi cryo-electron tomography software to facilitate distribution/use, as well as various scripts to help drive processing using the software.

## Getting Started

These instructions will get you easily set up with Artiatomi through this package, powered by Docker.

### External dependencies
Note that the Artiatomi package relies heavily on access to a CUDA-capable NVIDIA graphics card, and currently only supports Linux systems.
Thus, having a suitable GPU and Linux are a necessity for this package as well.
In addition, the following external packages are required and should thus be installed first:

* Docker - https://docs.docker.com/engine/install/

* The latest NVIDIA driver for your GPU - Using the package manager may be easiest (https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#package-manager-installation) 
	* Note that you do not need the entire CUDA Toolkit, just the NVIDIA driver (and proper kernel headers). See the linked page for more details. 
	* For example, if you were on Redhat/CentOS Linux you would run `sudo yum install nvidia-driver-latest-dkms`.
	* On Ubuntu, you might run `sudo apt-get install nvidia-(version number)`

* sshpass - https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/

### A quick introduction to Docker

Docker is a tool which simplifies the software development and distribution process using containers. A container is an isolated unit of software and its dependencies designed to be portable and reliably compatible with varying computing environments. In the case of Artiatomi and this package, whenever the start_artia.sh script is called, it will spawn a Docker container on your machine which already contains Artiatomi and all of its dependencies. Simply put, this container will act as an isolated, virtual machine (it's not really a virtual machine in the traditional sense but that is beyond the scope of this introduction) which can run Artiatomi and has access to any files on the local machine you give it access to. You will be able to SSH into the Artiatomi container, or just open bash shells into it (the **open\_artia\_shell.sh** script can do this for you) as with any other "remote" machine.

### Setting up artiatomi-tools

To begin, navigate to a directory in which you want to place the package and run the following commands:

```
git clone https://github.com/kmshin1397/artiatomi-tools.git

cd artiatomi-tools

chmod +x start_artia.sh

chmod +x close_artia.sh
```
The scripts to enable your own Artiatomi instances should now be enabled.

To use the included Matlab scripts, simply add the matlab folder in the repository to your Matlab path.



## Running Artiatomi

Running Artiatomi with the artiatomi-tools package revolves around the **start_artia.sh** script. When you first run the script, you will be prompted for a path to a directory to give Artiatomi access to. The Artiatomi container spawned by the script will only be able to see and access the directory given here within your local filesystem, so you should make sure any necessary data files and configuration files are under this directory. Remember that you can always close and start up a new Artiatomi instance if you need access to different locations throughout the data processing pipeline.

After providing a directory to mount onto the container, you will be presented with two options: **"Run Artiatomi tools except Clicker"** and **"Run Clicker"**. Clicker is the GUI tool in Artiatomi used to visualize tilt stacks, click gold fiducials, and run tiltseries alignments. Since it is the only GUI tool within the package and thus needs access to your screen instead of interacting through an SSH connection, it requires significantly different parameters when starting the Docker container. Thus, you can choose to either start an Artiatomi instance to run the Clicker app, or to start an instance to serve as an SSH server which can run all other Artiatomi tools.

### Run Artiatomi tools except Clicker

When using this option, a big part of communicating with the Artiatomi container will rely on SSH (especially if you are using the matlab scripts provided as SSH is Matlab's primary method of communicating with the container). To make this process easier, **start_artia.sh** will try to set up an SSH key with the spawned instance so that you do not have to constantly put in passwords to establish connections to the container (the default container password is set to "Artiatomi"). To support this, you will be prompted to use **ssh-keygen** to generate a SSH key for your machine if one is not found.

When you select this option, the **start_artia.sh script** will pull down the Artiatomi Docker image from Docker Hub (https://hub.docker.com/repository/docker/kmshin1397/artiatomi/general) and spawn a container from it on your machine. Note that if this is the first time you are running the script, or the Docker image has been updated since the last time you started an Artiatomi container, it will need to download the latest image and thus may take awhile.  

Once the Artiatomi container has been started, the script will establish a SSH connection to the container from your local machine, setting up an SSH key. If successful, you should see a message telling you that Artiatomi is now set up on a port. Save this port number as you will need it to tell Matlab where to connect to to run Artiatomi tools when using the Matlab processing scripts.

After the SSH connection is set up, the script will begin a shell into the Artiatomi container so that you may interact with it as if a normal shell on your own machine. The Artiatomi tools should already be added to the PATH in the shell; the directory you specified in the beginning should be available at the same path. If you want additional shells into the Artiatomi container, you may run the **open\_artia\_shell.sh** to start a new shell.

When you are finished with Artiatomi for now, you may call `exit` in this shell to close it; the script will then ask you if you want to shutdown the running container. You may keep it running to let other processes continue SSH-ing into it, but you will need to manually shut it down later using **close_artia.sh** before spawning a new Artiatomi container.

### Run Clicker

This option will simply start the Clicker app with access to the directory you specify in the beginning of the run. Clicker containers will be cleaned up automatically once you close the app. 

*If you have multiple GPUs and you find the Clicker app not starting, it may help to go into the start_artia.sh script and edit the gpus option on line 128. You may try changing it from 'all' to a number for the GPU device ID, i.e 0 or 1.*

## Using the Matlab scripts/processing scripts provided

To use the included Matlab scripts, add the matlab folder to your Matlab path within Matlab. you will need to change variables within the scripts, i.e. filepaths to your data. The scripts are based off the older code snippets found in the Artiatomi Tutorial PDF, so better context beyond what is found in the script comments may be found there. These are definitely not as general purpose as they could be and may need fiddling with to make work for your specific project. You will also find in the **processing_scripts** folder any non-Matlab scripts useful to processing cryo-ET data with Artiatomi as well.

You will also need the standard Artiatomi Matlab functions found in the [official Artiatomi package](https://github.com/uermel/Artiatomi) itself. Since the Docker image in this repository contains all compiled tools for Artiatomi, you only need to clone the official repository to add its matlab folder to your Matlab path. 

The Artiatomi Tutorial PDF mentioned above is also included in the official Artiatomi repository, in LaTex form. If you do not have the means to compile it into a more presentable PDF on your local machine, you can copy paste the docs/Tutorial/Tutorial.tex file in the official Artiatomi repository into a file on an online LaTex editor like [Overleaf](https://www.overleaf.com/).

### Example workflow

Below is an example set of steps that can be taken to process a set of data using the provided scripts. Not all may be necessary case by case, i.e. alignment can be done with the included Clicker instead of IMOD then importing the IMOD alignments.

1. Align stacks in an IMOD project using batchtomo
2. Run **setup\_artia\_reconstructions.m** to transfer IMOD alignments and create Artiatomi MOTLs. 
3. Run **get\_motl\_names\_and\_tomonrs.py** to output the MOTL paths created to be imported into Matlab later for averaging.
4. Run **emsart_reconstruct.sh"** to reconstruct all the stacks using EmSART.
5. Run **setup\_artia\_sta.m** to set up a SubTomogramAverageMPI run.
6. Set up initial reference and configuration file for sub-tomogram averaging and run (see Artiatomi tutorial and [wiki](https://github.com/uermel/Artiatomi/wiki) for details).
7. Run **refine\_align.m** to run interative local refinement for the tomograms based on the STA results.
8. Run **refine\_extract.m** to extract the locally refinement particles to use for averaging again.

## Authors

* **Kyung Min Shin** - California Institute of Technology

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* Matlab scripts based off of templates written by [Utz Ermel](https://github.com/uermel)
