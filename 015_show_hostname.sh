#!/bin/bash
hostname | xargs -d. | awk '{print $1}' | grep -v '^$' | figlet
