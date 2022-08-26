# kind-local-registry-carto-example
A simple script to run cartographer and kpack on kind with no external container registry

This example requires `kapp` `kubectl` `kind` and `helm` to work properly.

Run `./deploy.sh` to do all of the things. If everything worked, you should end
up with a `dev-0` pod that is serving a hello-world app on port 8080.
