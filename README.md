# Auto Updating Wowsim Docker Container

* Windows: Intall WSL https://learn.microsoft.com/en-us/windows/wsl/install and use WSL terminal (WIN+wsl)
* Mac/Linux bash should be installed already, can use `./` shortcuts if currently running in bash, otherwise prepend with `bash`
* Install docker https://www.docker.com/products/docker-desktop/
* update `tz.env` file to preferred timezone, otherwise defaults to `America/Denver`
* `$ bash build.sh` to build docker container
* `$ bash run.sh` to start container and browse to http://localhost:3333
* `$ bash stop.sh` to stop the running container
* `$ bash bash.sh` to open a shell within container
* `$ bash version-check.sh` to check current sim version
