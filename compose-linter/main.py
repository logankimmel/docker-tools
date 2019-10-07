import yaml
import fileinput
import os
import copy
import re
import collections

MAX_VALUES = {
    "CPU_LIMIT": {
        "default": "0.5",
        "path": "services.*.deploy.resources.limits.cpus"
    },
    "MEM_LIMIT": {
        "default": "2000m",
        "path": "services.*.deploy.resources.limits.memory"
    },
    "MAX_RETRY": {
        "default": "0",
        "path": "services.*.deploy.restart_policy.max_attempts"
    },
    "MAX_REPLICAS": {
        "default": "12",
        "path": "services.*.deploy.replicas"
    }
}

def set_defaults():
    values = copy.deepcopy(MAX_VALUES)
    for key in MAX_VALUES:
        if key in os.environ:
            values[key]["default"] = os.getenv(key)
        else:
            values[key]["default"] = MAX_VALUES[key]["default"]
    print("Default values: %s" %(values))
    return values
        
def set_compose(compose):
    print("Parsing Compose file:")
    print(compose)
    try:
        cy = yaml.safe_load(compose)
    except yaml.YAMLError as exc:
        print(exc)
    
    return cy

def get_service_paths(cy, path):
    service_paths = []
    keys = path.split(".")
    if keys[1] == "*":
        services = cy["services"].keys()
    else: 
        services = [keys[1]]
    
    for service in services:
        service_path = []
        for k in range(0, len(keys)):
            if k == 1:
                service_path.append(service)
            else:
                service_path.append(keys[k])
        service_paths.append(service_path)
    print(service_paths)
    return service_paths
    
# get_values retuns a list of dicts for each path and the value
# ex: {"path": ['services', 'web', 'deploy', 'restart_policy', 'max_attempts'], "value": "3"}    

def get_values(cy, path):
    service_paths = get_service_paths(cy, path)
    values = []
    for service_path in service_paths:
        spec = copy.deepcopy(cy)
        for i in range(0, len(service_path)):
            if i == len(service_path) - 1:
                try: 
                    spec[service_path[i]]
                except KeyError:
                    print("Key: %s not found" %(service_path[i]))
                    continue
                values.append({"path": service_path, "value": spec[service_path[i]]})
            else:
                try: 
                    spec[service_path[i]]
                except KeyError:
                    print("Key: %s not found" %(service_path[i]))
                    continue
                spec = spec[service_path[i]]
    return values

def set_value(cy, current_value, max_value):
    path = current_value["path"]
    spec = {}
    for i, e in reversed(list(enumerate(path))):
        builder = {}
        if i == len(path) - 1:
            spec[e] = max_value
        else:
            builder[e] = spec
            spec = builder
    new_yaml = copy.deepcopy(cy)
    return dict_merge(new_yaml, spec)

def dict_merge(dct, merge_dct):
    """ Recursive dict merge. Inspired by :meth:``dict.update()``, instead of
    updating only top-level keys, dict_merge recurses down into dicts nested
    to an arbitrary depth, updating keys. The ``merge_dct`` is merged into
    ``dct``.
    :param dct: dict onto which the merge is executed
    :param merge_dct: dct merged into dct
    :return: None
    """
    for k, _ in merge_dct.items():
        if (k in dct and isinstance(dct[k], dict)
                and isinstance(merge_dct[k], collections.Mapping)):
            dict_merge(dct[k], merge_dct[k])
        else:
            dct[k] = merge_dct[k]
    return dct   

def check_values(cy, values):
    new_yaml = copy.deepcopy(cy)
    for option in values:
        max_value = values[option]["default"]
        found_values = get_values(cy, values[option]["path"])
        for found_value in found_values:
            if int(re.sub('[^0-9]','',str(found_value["value"]))) > int(re.sub('[^0-9]','',str(max_value))):
                print("Found values: %s, max value: %s for %s" %(found_value["value"], max_value, option))
                new_yaml = set_value(new_yaml, found_value, max_value)
    return new_yaml

def main():
    compose_file = ''
    for line in fileinput.input():
            compose_file += line
            pass
    cy = set_compose(compose_file)
    values = set_defaults()
    new_yaml = check_values(cy, values)
    noalias_dumper = yaml.dumper.SafeDumper
    noalias_dumper.ignore_aliases = lambda self, data: True
    print(yaml.dump(new_yaml, default_flow_style=False, Dumper=noalias_dumper))
    
    if "OUTPUT_FILE" in os.environ:
        with open(os.getenv("OUTPUT_FILE"), 'w') as yaml_file:
            yaml.dump(new_yaml, yaml_file, default_flow_style=False, Dumper=noalias_dumper)
main()
