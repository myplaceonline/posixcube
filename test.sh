#!/bin/sh
cube_echo "Hello World"
cube_printf "Hello World from %5s" $$
cube_error_echo "Goodbye World"
cube_error_printf "Goodbye World from %5s" $$
cube_throw "Fatal error"
