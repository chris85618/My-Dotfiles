#!/bin/bash

bb() {
    (umask 022 && command bitbake "$@")
}
