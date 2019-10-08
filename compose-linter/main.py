import yaml
import fileinput
import os
import copy
import re
import collections
import sys

MAX_VALUES = {
    "CPU_LIMIT": {
        "default": "0.5",
        "path": "services.*.deploy.resources.limits.cpus"
    },
    "MEM_LIMIT": {
        "default": "1000m",
        "path": "services.*.deploy.resources.limits.memory",
        "unit": "memory"
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

REQUIRED = {
    "CPU_RES": {
        "path": "services.*.deploy.resources.reservations.cpus",
        "link": "CPU_LIMIT",
    },
    "MEM_RES": {
        "path": "services.*.deploy.resources.reservations.memory",
        "link": "MEM_LIMIT",
        "unit": "memory"
    }
}

def set_reservations(compose_yaml):
    """ Sets reservations to half of set corresponding link
    :param compose_yaml: Current Compose yaml
    :return: updated compose file with reservations set
    """
    for _,v in REQUIRED.items():
        service_paths = get_service_paths(compose_yaml, v["path"])
        for path in service_paths:
            service_name = path[1]
            link_path = MAX_VALUES[v["link"]]["path"].split(".")
            # Replace wildcare with service name we are iterating on
            link_path.insert(1, service_name)
            link_path.pop(2)
            link_value = get_value(compose_yaml, link_path)
            if v.get("unit", False) == "memory":
                res_value = str(unit_converter(link_value, "memory")/2) + "M"
            else:
                res_value = float(link_value)/2
            compose_yaml = set_value(compose_yaml, path, res_value)
    return compose_yaml

def set_defaults():
    values = copy.deepcopy(MAX_VALUES)
    for key in MAX_VALUES:
        if key in os.environ:
            values[key]["default"] = os.getenv(key)
        else:
            values[key]["default"] = MAX_VALUES[key]["default"]
    print("Default values: %s\n\n" %(values))
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
    return service_paths
    
# get_values retuns a list of dicts for each path and the value
# ex: {"path": ['services', 'web', 'deploy', 'restart_policy', 'max_attempts'], "value": "3"}    

def get_values(cy, option):
    """ Get value for each path from the input compose file.
    :param cy: Original docker-compose file
    :param path: Path to retrieve the docker file
    :return: dict ex: {"path": ['services', 'web', 'deploy', 'restart_policy', 'max_attempts'], "value": "3"}
    """
    service_paths = get_service_paths(cy, option["path"])
    values = []
    for service_path in service_paths:
        value = get_value(cy,service_path)
        required = option.get("required", False)
        if value == None and required:
            print("Key: %s not found" %(".".join(service_path)))
            sys.exit(1)
        values.append({"path":service_path, "value":value})
    return values

def get_value(cy, service_path):
    spec = copy.deepcopy(cy)
    for i in range(0, len(service_path)):
        if i == len(service_path) - 1:
            try: 
                spec[service_path[i]]
                value = spec[service_path[i]]
                return value
            except KeyError:
                value = None
        else:
            try: 
                spec[service_path[i]]
            except KeyError:
                value = None
                return value
            spec = spec[service_path[i]]

def set_value(cy, path, new_value):
    spec = {}
    for i, e in reversed(list(enumerate(path))):
        builder = {}
        if i == len(path) - 1:
            spec[e] = new_value
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
                and isinstance(merge_dct[k], collections.abc.Mapping)):
            dict_merge(dct[k], merge_dct[k])
        else:
            dct[k] = merge_dct[k]
    return dct   

def unit_converter(val, unit):
    """ Converts Unit to a float for comparison.
    :param string val: value to be converted
    :return: float
    """
    # If memory, convert to Mb
    if unit == "memory":
        val = to_mb(val)
    return float(re.sub('[^0-9,.]','',str(val)))

def to_mb(val):
    u = re.sub('[0-9]','', str(val))
    if u.upper() == "M":
        return val
    num = float(re.sub('[^0-9]','',str(val)))
    return str(num*1024**1) + "M"

def check_values(cy, values):
    new_yaml = copy.deepcopy(cy)
    for option in values:
        max_value = values[option]["default"]
        found_values = get_values(cy, values[option])
        unit = values[option].get("unit", None)
        print(found_values)
        for found_value in found_values:
            if found_value["value"] == None:
                print("Found values: %s, max value: %s for %s" %(found_value["value"], max_value, option))
                new_yaml = set_value(new_yaml, found_value["path"], max_value)
            else:
                m_val = unit_converter(max_value, unit) 
                f_val = unit_converter(found_value["value"], unit)
                if f_val > m_val:
                    print("Found values: %s, max value: %s for %s" %(found_value["value"], max_value, option))
                    new_yaml = set_value(new_yaml, found_value["path"], max_value)
    return new_yaml

def return_yaml(new_yaml):
    noalias_dumper = yaml.dumper.SafeDumper
    noalias_dumper.ignore_aliases = lambda self, data: True
    
    print("\nNEW COMPOSE FILE:\n===============================\n")
    print(yaml.dump(new_yaml, default_flow_style=False, Dumper=noalias_dumper))
    
    if "OUTPUT_FILE" in os.environ:
        with open(os.getenv("OUTPUT_FILE"), 'w') as yaml_file:
            yaml.dump(new_yaml, yaml_file, default_flow_style=False, Dumper=noalias_dumper)

def main():
    compose_file = ''
    for line in fileinput.input():
            compose_file += line
            pass
    cy = set_compose(compose_file)
    values = set_defaults()
    new_yaml = check_values(cy, values)
    new_yaml = set_reservations(new_yaml)
    return_yaml(new_yaml)

main()
