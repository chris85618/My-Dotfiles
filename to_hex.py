#!/usr/bin/env python3
from sys import argv

def to_hex(string):
    return ' '.join([hex(n) for n in list(string.encode())])

if __name__ == '__main__':
    for string in argv[1:]:
        print(to_hex(string))
