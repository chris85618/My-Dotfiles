#!/usr/bin/env python3
from sys import argv

def to_text(*num_list):
    return bytes(num_list).decode('ascii')

if __name__ == '__main__':
    base_index = 1
    if argv[1] in ('o', 'O',):
        base = 8
    elif argv[1] in ('h', 'H',):
        base = 16
    elif argv[1] in ('d', 'D',):
        base = 10
    else:
        base = 0
        base_index = 0

    num_list = argv[(base_index + 1):]

    print(to_text(*[int(num, base) for num in num_list]))
