#!/bin/bash

set -x # echo on
set -euo pipefail

mvn dependency:go-offline -B

mvn package -B