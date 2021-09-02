#!/usr/bin/env python3
'''
usage: cbmc <file> <checks> --json-ui --verbosity 4 | ./formatCBMCOutput.py
'''

import sys, json, argparse
from collections import defaultdict, OrderedDict #OrderedDict for removing duplicates
NL = '\n'
ABSOLUTE_PATHS = False

def parse_source_location(array_info):
    source_loc = array_info['sourceLocation']
    line_num, file_name = source_loc['line'], source_loc['file']
    if ABSOLUTE_PATHS:
        working_dir = source_loc['workingDirectory']
        file_name = f'{working_dir}/{file_name}'
    return f"{file_name}:{line_num}: note: "


def parse_data(array_info):
    return array_info['data'] if 'data' in array_info else "?"


def parse_assingment(array_info):
    result_str = []
    result_str.append(parse_source_location(array_info))

    if array_info['assignmentType'] == "actual-parameter":
        result_str.append(f"function_parameter_set_in:")
    if 'function' not in array_info['sourceLocation']:
        result_str.append(f"entry_point_function:")
    else:
        result_str.append(f"{array_info['sourceLocation']['function']}:")
    result_str.append(
        f"{array_info['sourceLocation']['line']}:{array_info['value']['name']}:{8*' '}{array_info['lhs']} = "
    )
    if 'elements' in array_info['value']:
        result_str.append(
            f"{[parse_data(val['value']) for val in array_info['value']['elements']]}{NL}"
        )
    else:
        result_str.append(f"{parse_data(array_info['value'])}{NL}")
    return ''.join(result_str)


def parse_function(array_info):
    result_str = []
    result_str.append(parse_source_location(array_info))

    if 'function' not in array_info['sourceLocation']:
        result_str.append(f"from_entry_point_function:")
    else:
        result_str.append(f"from_{array_info['sourceLocation']['function']}:")

    result_str.append(
        f"{array_info['stepType']}:{array_info['function']['displayName']}{NL}")
    return ''.join(result_str)


def parse_trace(trace_arr):
    result_str = []
    for index, step in enumerate(trace_arr):
        if 'hidden' in step and step['hidden'] or \
           'internal' in step and step['internal']  or \
           'sourceLocation' not in step:
            continue
        if 'function' in step:
            result_str.append(parse_function(step))
        elif 'assignmentType' in step:
            result_str.append(parse_assingment(step))
        elif 'reason' in step:
            result_str.append(
                f"{parse_source_location(step)}{step['reason']}{NL}")

    return ''.join(list(OrderedDict.fromkeys(result_str)))  #remove duplicates


def parse_it():
    errors = defaultdict(list)
    try:
        parsed = json.load(sys.stdin)
    except ValueError:
        print(f"Error: CBMC_WARNING:{NL}cbmc: fatal error: CBMC crashed")
        return errors

    if 'cProverStatus' not in parsed[-1]:
        print(f"Error: CBMC_WARNING:{NL}cbmc: fatal error: CBMC crashed")
        return errors

    if {'cProverStatus': 'success'} in parsed:
        return errors

    for result in parsed[-3]['result']:
        if result['status'] == "FAILURE": #and\
            if 'sourceLocation' not in result['trace'][-1]: #memory leak detected\
                file_name = '<unknown>'
                fun_name  = '<unknown>'
                line_num  = '<unknown>'
            
                reason = result['description']
                proprty = result['property']
            else:
                source_loc = result['trace'][-1]['sourceLocation']
                file_name = source_loc['file']
                fun_name = source_loc['function']
                line_num = source_loc['line']
                if ABSOLUTE_PATHS:
                    working_dir = source_loc['workingDirectory']
                    file_name = f'{working_dir}/{file_name}'

                info = result['trace'][-1]
                reason = info['reason']
                proprty = info['property']
                
            trace = parse_trace(result['trace'])
            
            errors[(file_name, fun_name)].append(
                (line_num, reason, proprty, trace))
    return errors


def print_it(error_dict):
    for file_and_func_name in error_dict.keys():
        file_name, func_name = file_and_func_name
        for err in error_dict[file_and_func_name]:
            err_prefix = "Error: CBMC_WARNING:"
            print(f"{err_prefix}")
            if file_name != '<unknown>' and func_name != '<unknown>':
                print(f"{file_name}: scope_hint: In function ‘{func_name}’:")
            line_num, proprty, trace = err[0], err[1], err[3]
            reason = err[2].split('.')[1]
            print(
                f"{file_name}:{line_num}: error: {reason} : {proprty}{NL}{trace}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='cbmc to csgrep conversion')
    parser.add_argument("-a", "--absolute-paths", action="store_true", help="make all paths absolute")
    arguments = parser.parse_args()
    ABSOLUTE_PATHS = arguments.absolute_paths
    print_it(parse_it())
