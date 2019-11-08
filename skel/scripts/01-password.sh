#!/bin/bash

# We don't want the pi's password to be enabled when we activate ssh

echo "Disabling pi password"
usermod -L pi
