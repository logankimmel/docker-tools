# Docker Compose Linter
This takes a Docker Compose yaml file as input and makes sure values aren't set greater than the defined max. It will also set reservations to half of the defined limit for the corresponding value.

### Supported Max Values
* CPU_LIMIT
* MEM_LIMIT
* MAX_RETRY
* MAX_REPLICAS

### Limit Defaults:
```
{
    "CPU_LIMIT": {
        "default": "0.5",
        "path": "services.*.deploy.resources.limits.cpus"
    },
    "MEM_LIMIT": {
        "default": "1000m",
        "path": "services.*.deploy.resources.limits.memory"
    },
    "MAX_RETRY": {
        "default": "0",
        "path": "services.*.deploy.restart_policy.max_attempts"
    },
    "MAX_REPLICAS": {
        "default": "12",
        "path": "services.*.deploy.replicas",
        "required": True # This signifies that the value is required to exist in the compose file
    }
}
```

### Usage
#### Build docker container
`docker build -t compose-linter .`
#### Run
The default limits can be overridden by passing in environment variables and the yaml output can be written to a file with the `OUTPUT_FILE` option
Ex: 
```
cat ../stack_example.yml | docker run -i --rm \
    -e MAX_REPLICAS=4 -v /tmp/output:/data -e OUTPUT_FILE=/data/output.yml \
    compose-linter -
```